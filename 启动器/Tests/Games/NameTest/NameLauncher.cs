using System;
using System.Diagnostics;
class NameLauncher {
    static void Main() {
        var psi = new ProcessStartInfo("FakeGame.exe");
        psi.UseShellExecute = false;
        var p = Process.Start(psi);
        Console.WriteLine("child=" + p.Id);
    }
}
