package com.example.unittest;

import android.util.Log;
import java.io.File;
import java.io.FileOutputStream;
import java.io.IOException;

public class PrinterNative {
    private static final String TAG = "PrinterNative";
    private static final int CHUNK_SIZE = 2000; // Small chunks for buffer safety
    
    public PrinterNative() {
        // Simple constructor
    }
    
    /**
     * Print raw bytes to the specified port
     * Opens port, sends data, and closes port automatically
     * 
     * @param portPath The serial port path (e.g., "/dev/ttyS3")
     * @param data The raw byte array to send
     * @return true if successful, false otherwise
     */
    public boolean printBytes(String portPath, byte[] data) {
        FileOutputStream output = null;
        
        try {
            // Check if port exists
            File device = new File(portPath);
            if (!device.exists()) {
                Log.e(TAG, "Device not found: " + portPath);
                return false;
            }
            
            // Set permissions
            try {
                Runtime.getRuntime().exec("chmod 666 " + portPath);
                Thread.sleep(50);
            } catch (Exception e) {
                Log.w(TAG, "Could not set permissions: " + e.getMessage());
            }
            
            // Open port
            output = new FileOutputStream(device);
            
            // Send data in chunks
            int offset = 0;
            while (offset < data.length) {
                int length = Math.min(CHUNK_SIZE, data.length - offset);
                output.write(data, offset, length);
                output.flush();
                offset += length;
                
                // Small delay between chunks
                if (offset < data.length) {
                   
                }
            }
            
            Log.d(TAG, "Successfully sent " + data.length + " bytes to " + portPath);
            return true;
            
        } catch (Exception e) {
            Log.e(TAG, "Error printing bytes: " + e.getMessage());
            e.printStackTrace();
            return false;
            
        } finally {
            // Always close the port
            if (output != null) {
                try {
                    output.close();
                } catch (IOException e) {
                    Log.e(TAG, "Error closing port: " + e.getMessage());
                }
            }
        }
    }
}