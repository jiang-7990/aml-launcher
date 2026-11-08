using System;
using System.Diagnostics;
using System.IO;
using System.IO.Compression;
using System.Linq;
using System.Reflection;
using System.Text;

namespace AML
{
    internal static class Program
    {
        internal const string Version = "__VERSION__";
        private const string ResourceName = "AML.runtime.zip";

        [STAThread]
        private static int Main(string[] args)
        {
            string root = Path.GetDirectoryName(Assembly.GetExecutingAssembly().Location);
            string launcherDir = Path.Combine(root, "Launcher");
            bool repair = args.Any(a => string.Equals(a, "-Repair", StringComparison.OrdinalIgnoreCase));
            try
            {
                string startScript = Path.Combine(launcherDir, "Start.ps1");
                string runtimeVersionDir = null;
                if (!File.Exists(startScript) || repair)
                {
                    runtimeVersionDir = EnsureRuntime(root, repair);
                    startScript = Path.Combine(runtimeVersionDir, "Launcher", "Start.ps1");
                }
                EnsureSkeleton(root, runtimeVersionDir);
                if (runtimeVersionDir != null) CleanupOldRuntimes(root, runtimeVersionDir);
                Launch(startScript, root, args);
                return 0;
            }
            catch (Exception ex)
            {
                try
                {
                    string logDir = Path.Combine(root, "Logs");
                    Directory.CreateDirectory(logDir);
                    File.AppendAllText(Path.Combine(logDir, "aml-exe.log"),
                        DateTime.Now.ToString("s") + "  [ERROR] " + ex + Environment.NewLine, Encoding.UTF8);
                }
                catch { }
                return 1;
            }
        }

        private static string EnsureRuntime(string root, bool repair)
        {
            string runtimeRoot = Path.Combine(root, "Launcher", ".runtime");
            string versionDir = Path.Combine(runtimeRoot, "v" + Version);
            string okFile = Path.Combine(versionDir, ".ok");
            if (!repair && File.Exists(okFile) && File.Exists(Path.Combine(versionDir, "Launcher", "Start.ps1")))
                return versionDir;
            try
            {
                Extract(versionDir);
                return versionDir;
            }
            catch (Exception ex)
            {
                string tempRoot = Path.Combine(Path.GetTempPath(), "AML-" + Hash(root));
                string tempDir = Path.Combine(tempRoot, "v" + Version);
                Extract(tempDir);
                try
                {
                    File.AppendAllText(Path.Combine(tempRoot, "fallback.log"),
                        DateTime.Now.ToString("s") + " fallback to temp: " + ex.Message + Environment.NewLine, Encoding.UTF8);
                }
                catch { }
                return tempDir;
            }
        }

        private static void Extract(string targetDir)
        {
            if (Directory.Exists(targetDir)) Directory.Delete(targetDir, true);
            Directory.CreateDirectory(targetDir);
            using (Stream stream = Assembly.GetExecutingAssembly().GetManifestResourceStream(ResourceName))
            {
                if (stream == null) throw new InvalidOperationException("内置运行时资源缺失：" + ResourceName);
                using (var archive = new ZipArchive(stream, ZipArchiveMode.Read))
                {
                    archive.ExtractToDirectory(targetDir);
                }
            }
            File.WriteAllText(Path.Combine(targetDir, ".ok"),
                Version + "|" + DateTime.Now.ToString("s"), Encoding.UTF8);
        }

        private static void EnsureSkeleton(string root, string runtimeDir)
        {
            foreach (string dir in new[] { "Games", "Data", "Backups", "Snapshots", "Logs",
                                           Path.Combine("Launcher", "profiles"),
                                           Path.Combine("Launcher", "state"),
                                           Path.Combine("Launcher", "icons") })
            {
                Directory.CreateDirectory(Path.Combine(root, dir));
            }
            string config = Path.Combine(root, "Launcher", "config.ini");
            if (!File.Exists(config) && runtimeDir != null)
            {
                string template = Path.Combine(runtimeDir, "Launcher", "config.ini.default");
                if (File.Exists(template)) File.Copy(template, config, false);
            }
        }

        private static void CleanupOldRuntimes(string root, string currentDir)
        {
            try
            {
                string runtimeRoot = Path.Combine(root, "Launcher", ".runtime");
                if (!Directory.Exists(runtimeRoot)) return;
                string current = Path.GetFullPath(currentDir).TrimEnd('\\');
                foreach (string dir in Directory.GetDirectories(runtimeRoot))
                {
                    if (string.Equals(Path.GetFullPath(dir).TrimEnd('\\'), current, StringComparison.OrdinalIgnoreCase))
                        continue;
                    try { Directory.Delete(dir, true); } catch { }
                }
            }
            catch { }
        }

        private static void Launch(string script, string root, string[] args)
        {
            var sb = new StringBuilder();
            sb.Append("-NoProfile -ExecutionPolicy Bypass -STA -File ");
            sb.Append('"').Append(script).Append('"');
            sb.Append(" -Root ");
            sb.Append('"').Append(root).Append('"');
            foreach (string a in args)
            {
                if (string.Equals(a, "-Repair", StringComparison.OrdinalIgnoreCase)) continue;
                sb.Append(' ').Append(a.IndexOf(' ') >= 0 ? "\"" + a + "\"" : a);
            }
            var psi = new ProcessStartInfo
            {
                FileName = "powershell.exe",
                Arguments = sb.ToString(),
                UseShellExecute = false,
                CreateNoWindow = true,
                WorkingDirectory = root
            };
            Process.Start(psi);
        }

        private static string Hash(string text)
        {
            using (var md5 = System.Security.Cryptography.MD5.Create())
            {
                byte[] bytes = md5.ComputeHash(Encoding.UTF8.GetBytes(text.ToLowerInvariant()));
                return BitConverter.ToString(bytes).Replace("-", "").Substring(0, 8);
            }
        }
    }
}