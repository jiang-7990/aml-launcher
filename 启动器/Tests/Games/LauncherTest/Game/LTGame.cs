using System;
using System.IO;
class P {
  static void Main() {
    var d = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData), "LauncherTest");
    Directory.CreateDirectory(d);
    var f = Path.Combine(d, "save.dat");
    int n = 0;
    if (File.Exists(f)) int.TryParse(File.ReadAllText(f).Trim(), out n);
    n++;
    File.WriteAllText(f, n.ToString());
    System.Threading.Thread.Sleep(900);
  }
}
