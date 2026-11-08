using System;
using System.Diagnostics;
class WaitLauncher {
    static void Main() {
        var psi = new ProcessStartInfo("powershell.exe", "-NoProfile -Command \"Start-Sleep -Seconds 8\"");
        psi.UseShellExecute = false;
        var p = Process.Start(psi);
        Console.WriteLine("child=" + p.Id);
    }
}
