using System;
using System.IO;
using System.Text;
using System.Drawing;
using System.Runtime.InteropServices;

namespace csts{
	
	
	internal static class SafeNativeMethods{
		[DllImport("shell32.dll", EntryPoint = "ExtractAssociatedIcon", CharSet = CharSet.Auto)]
		internal static extern IntPtr ExtractAssociatedIcon(HandleRef hInst, StringBuilder iconPath, ref int index);
	}
		
	public class iconTools{
		/// <summary>
		/// Returns an icon representation of an image contained in the specified file.
		/// This function is identical to System.Drawing.Icon.ExtractAssociatedIcon, xcept this version works.
		/// </summary>
		/// <param name="filePath">The path to the file that contains an image.</param>
		/// <returns>The System.Drawing.Icon representation of the image contained in the specified file.</returns>
		/// <exception cref="System.ArgumentException">filePath does not indicate a valid file.</exception>
		public static Icon  ExtractAssociatedIcon(String filePath)
		{
			int index = 0;

			Uri uri;
			if (filePath == null)
			{
				throw new ArgumentException(String.Format("'{0}' is not valid for '{1}'", "null", "filePath"), "filePath");
			}
			try
			{
				uri = new Uri(filePath);
			}
			catch (UriFormatException)
			{
				filePath = Path.GetFullPath(filePath);
				uri = new Uri(filePath);
			}
			//if (uri.IsUnc)
			//{
			//  throw new ArgumentException(String.Format("'{0}' is not valid for '{1}'", filePath, "filePath"), "filePath");
			//}
			if (uri.IsFile)
			{
				if (!File.Exists(filePath))
				{
					//IntSecurity.DemandReadFileIO(filePath);
					throw new FileNotFoundException(filePath);
				}

				StringBuilder iconPath = new StringBuilder(260);
				iconPath.Append(filePath);

				IntPtr handle = SafeNativeMethods.ExtractAssociatedIcon(new HandleRef(null, IntPtr.Zero), iconPath, ref index);
				if (handle != IntPtr.Zero)
				{
					//IntSecurity.ObjectFromWin32Handle.Demand();
					return Icon.FromHandle(handle);
				}
			}
			return null;
		}
	}
	
	
}