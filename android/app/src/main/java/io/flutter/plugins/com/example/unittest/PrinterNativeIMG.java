package com.example.unittest;

import android.util.Log;
import java.io.*;

public class PrinterNativeIMG extends FileOutputStream {
    private static final String TAG = "PrinterNativeIMG";
    
    // Printer Commands
    private static final byte[] HW_INIT = {0x1b, 0x40}; // Hardware init
    private static final byte[] LF = {0x0a}; // Line Feed
    private static final byte[] ESC_d = {0x1b, 0x64}; // Feed n lines
    private static final byte[] ESC_a = {0x1b, 0x61}; // Alignment
    private static final byte[] GS_v = {0x1d, 0x76, 0x30}; // Print raster bit image
    private static final byte[] ESC_3 = {0x1b, 0x33}; // Line spacing
    private static final byte[] ESC_L = {0x1b, 0x4c}; // Left margin
    private static final int CHUNK_SIZE = 512;

    public PrinterNativeIMG(String portPath) throws FileNotFoundException {
        super(new File(portPath));
    }

    public boolean printImage(byte[] data) {
        try {
            // Reset printer
            write(HW_INIT);
            flush();
            Thread.sleep(50);

            // Center alignment
            write(ESC_a);
            write(1); // center
            flush();

            // Set line spacing 24
            write(ESC_3);
            write(24);
            flush();

            // Set left margin 0
            write(ESC_L);
            write(0);
            write(0);
            flush();

            // Print raster bit image
            int width = 384; // Fixed width for 48mm printer
            int nL = width & 0xff;
            int nH = (width >> 8) & 0xff;

            write(GS_v); // GS v 0
            write(nL);
            write(nH);

            // Send image data in chunks
            int offset = 0;
            while (offset < data.length) {
                int length = Math.min(CHUNK_SIZE, data.length - offset);
                write(data, offset, length);
                flush();
                offset += length;
                Thread.sleep(20);
            }

            // Feed 3 lines
            write(ESC_d);
            write(3);
            flush();

            return true;

        } catch (Exception e) {
            Log.e(TAG, "Print error: " + e.getMessage());
            return false;
        }
    }

    @Override
    public void close() throws IOException {
        try {
            write(HW_INIT);
            flush();
        } finally {
            super.close();
        }
    }
}
