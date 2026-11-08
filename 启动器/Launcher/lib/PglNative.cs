using System;
using System.Runtime.InteropServices;

public static class PglWin
{
    [DllImport("user32.dll")] public static extern bool SetProcessDPIAware();
    [DllImport("dwmapi.dll")] public static extern int DwmSetWindowAttribute(IntPtr hwnd, int attr, ref int val, int size);
    [DllImport("uxtheme.dll", CharSet = CharSet.Unicode)] public static extern int SetWindowTheme(IntPtr hwnd, string subApp, string subId);
    [DllImport("user32.dll")] public static extern bool ShowScrollBar(IntPtr hwnd, int bar, bool show);
    [DllImport("user32.dll")] public static extern bool ReleaseCapture();
    [DllImport("user32.dll", CharSet = CharSet.Unicode)] public static extern IntPtr SendMessage(IntPtr hwnd, uint msg, IntPtr wParam, IntPtr lParam);
    [DllImport("uxtheme.dll", EntryPoint = "#135")] static extern int SetPreferredAppMode(int mode);
    [DllImport("uxtheme.dll", EntryPoint = "#133")] static extern bool AllowDarkModeForWindow(IntPtr hwnd, bool allow);
    [DllImport("uxtheme.dll", EntryPoint = "#136")] static extern void FlushMenuThemes();

    public static void DragMove(IntPtr hwnd)
    {
        ReleaseCapture();
        SendMessage(hwnd, 0xA1, (IntPtr)2, IntPtr.Zero);
    }

    public static void EnableDarkMode(IntPtr hwnd)
    {
        try { SetPreferredAppMode(2); AllowDarkModeForWindow(hwnd, true); FlushMenuThemes(); } catch { }
    }
}

public static class PglIcon
{
    [DllImport("user32.dll", CharSet = CharSet.Unicode)]
    static extern int PrivateExtractIcons(string file, int index, int cx, int cy, IntPtr[] icons, int[] ids, int count, int flags);

    [DllImport("user32.dll")]
    public static extern bool DestroyIcon(IntPtr hIcon);

    public static IntPtr Extract(string path, int size)
    {
        IntPtr[] icons = new IntPtr[1];
        int[] ids = new int[1];
        int n = PrivateExtractIcons(path, 0, size, size, icons, ids, 1, 0);
        if (n <= 0) return IntPtr.Zero;
        return icons[0];
    }
}

public static class PglJob
{
    [DllImport("kernel32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
    static extern IntPtr CreateJobObject(IntPtr attrs, string name);
    [DllImport("kernel32.dll", SetLastError = true)]
    static extern bool AssignProcessToJobObject(IntPtr job, IntPtr process);
    [DllImport("kernel32.dll", SetLastError = true)]
    static extern bool QueryInformationJobObject(IntPtr job, int infoClass, IntPtr info, int cbInfo, IntPtr ret);
    [DllImport("kernel32.dll", SetLastError = true)]
    static extern bool CloseHandle(IntPtr handle);

    [StructLayout(LayoutKind.Sequential)]
    struct BASIC
    {
        public long TotalUserTime;
        public long TotalKernelTime;
        public long ThisPeriodTotalUserTime;
        public long ThisPeriodTotalKernelTime;
        public uint TotalPageFaultCount;
        public uint TotalProcesses;
        public uint ActiveProcesses;
        public uint TotalTerminatedProcesses;
    }

    public static IntPtr Create() { return CreateJobObject(IntPtr.Zero, null); }
    public static bool Assign(IntPtr job, IntPtr process) { return AssignProcessToJobObject(job, process); }

    public static int Active(IntPtr job)
    {
        int len = Marshal.SizeOf(typeof(BASIC));
        IntPtr buf = Marshal.AllocHGlobal(len);
        try
        {
            if (!QueryInformationJobObject(job, 1, buf, len, IntPtr.Zero)) return -1;
            BASIC b = (BASIC)Marshal.PtrToStructure(buf, typeof(BASIC));
            return (int)b.ActiveProcesses;
        }
        finally { Marshal.FreeHGlobal(buf); }
    }

    public static void Close(IntPtr job) { if (job != IntPtr.Zero) CloseHandle(job); }
}