using System;
using System.Diagnostics;
using System.IO;
class L {
  static void Main() {
    var dir = AppDomain.CurrentDomain.BaseDirectory;
    var exe = Path.Combine(dir, "Game", "LTGame.exe");
    if (File.Exists(exe)) Process.Start(new ProcessStartInfo(exe) { WorkingDirectory = Path.GetDirectoryName(exe), UseShellExecute = true });
  }
}
