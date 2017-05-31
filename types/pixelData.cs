using System;
using System.Drawing;
using System.Drawing.Imaging;
using System.Runtime.InteropServices;
using System.Windows.Forms;
using System.Diagnostics;

namespace cyberToolSuite
{
	public class pixelDataObj
	{
		public Color BackColor;
		public Bitmap screenPixel = new Bitmap(1, 1, PixelFormat.Format32bppArgb);
		
		[DllImport("user32.dll")]
		public static extern bool GetCursorPos(ref Point lpPoint);

		[DllImport("gdi32.dll", CharSet = CharSet.Auto, SetLastError = true, ExactSpelling = true)]
		public static extern int BitBlt(IntPtr hDC, int x, int y, int nWidth, int nHeight, IntPtr hSrcDC, int xSrc, int ySrc, int dwRop);
		
		public Color Get()
		{
			Point cursor = new Point();
			GetCursorPos(ref cursor);

			return GetColorAt(cursor);
		}
		
		public Color GetColorAt(Point location)
		{
			using (Graphics gdest = Graphics.FromImage(screenPixel))
			{
				using (Graphics gsrc = Graphics.FromHwnd(IntPtr.Zero))
				{
					IntPtr hSrcDC = gsrc.GetHdc();
					IntPtr hDC = gdest.GetHdc();
					int retval = BitBlt(hDC, 0, 0, 1, 1, hSrcDC, location.X, location.Y, (int)CopyPixelOperation.SourceCopy);
					gdest.ReleaseHdc();
					gsrc.ReleaseHdc();
				}
			}

			return screenPixel.GetPixel(0, 0);
		}
	}	
}