using System;
using System.IO;
class P {
  static void Main() {
    var app = Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData);
    var local = Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData);
    var saves = Path.Combine(app, "LearnTest", "saves");
    Directory.CreateDirectory(saves);
    var f = Path.Combine(saves, "slot1.sav");
    int n = File.Exists(f) ? int.Parse(File.ReadAllText(f).Trim()) : 0;
    File.WriteAllText(f, (n + 1).ToString());
    var logs = Path.Combine(app, "LearnTest", "logs");
    Directory.CreateDirectory(logs);
    File.AppendAllText(Path.Combine(logs, "app.log"), DateTime.Now + " run\n");
    var root = Path.Combine(app, "LearnTest");
    File.WriteAllText(Path.Combine(root, "settings.ini"), "vol=7\n");
    var cache = Path.Combine(local, "LearnTest", "cache");
    Directory.CreateDirectory(cache);
    File.WriteAllBytes(Path.Combine(cache, "blob.bin"), new byte[2048]);
    System.Threading.Thread.Sleep(600);
  }
}