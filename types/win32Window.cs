using System;
using System.Windows.Forms;

public class Win32Window : IWin32Window{
	private IntPtr _hWnd;

	public Win32Window(IntPtr handle){
		_hWnd = handle;
	}
	
	public IntPtr Handle{
		get { return _hWnd; }
	}
}