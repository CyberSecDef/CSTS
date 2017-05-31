public class ISOFile{ 
    public unsafe static void Create(string Path, object Stream, int BlockSize, int TotalBlocks){ 
        int bytes = 0; 
        byte[] buf = new byte[BlockSize]; 
        System.IntPtr ptr = (System.IntPtr)(&bytes); 
        System.IO.FileStream o = System.IO.File.OpenWrite(Path); 
        System.Runtime.InteropServices.ComTypes.IStream i = Stream as System.Runtime.InteropServices.ComTypes.IStream; 
 
        if (o == null) { return; }
        while (TotalBlocks-- > 0) {
            i.Read(buf, BlockSize, ptr); 
            o.Write(buf, 0, bytes); 
        }
        o.Flush(); 
        o.Close(); 
    }
}