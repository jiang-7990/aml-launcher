using System;
using System.IO;
using System.Threading;

class FakeGame
{
    static void Main()
    {
        string dir = Path.Combine(
            Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData),
            "FakeGame");
        Directory.CreateDirectory(dir);
        string save = Path.Combine(dir, "save.dat");

        int n = 0;
        if (File.Exists(save))
        {
            int.TryParse(File.ReadAllText(save).Trim(), out n);
        }
        n++;
        File.WriteAllText(save, n.ToString());
        Console.WriteLine("FakeGame run #" + n);
        Console.WriteLine("save: " + save);
        Thread.Sleep(700);
    }
}
