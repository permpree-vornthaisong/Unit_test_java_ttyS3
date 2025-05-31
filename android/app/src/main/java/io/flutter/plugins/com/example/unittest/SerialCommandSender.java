package com.example.unittest;

import android.util.Log;
import java.io.File;
import java.io.FileOutputStream;
import java.io.IOException;

public class SerialCommandSender {

    private static final String TAG = "SerialCommandSender";
    private static final String PORT_NAME = "/dev/ttyS3";
    private static final int BAUD_RATE = 115200; // Default baud rate

    private static final byte[] START_IGNORE_PROTOCOL = {
        0x02, 0x40, 0x00, 0x02, 0x58, 0x05, 0x01, 0x00, 0x01, 0x01, 0x00,
        0x02, 0x40, 0x00, 0x02, 0x58, 0x05, 0x01, 0x00, 0x01, 0x00, 0x00
    };

    private boolean openPort(String portPath, int baudRate) {
        try {
            File device = new File(portPath);
            if (!device.exists()) {
                Log.e(TAG, "Device not found: " + portPath);
                return false;
            }

            // Set permissions
            Runtime.getRuntime().exec("chmod 666 " + portPath);
            Thread.sleep(10);

            // Configure serial port settings using stty command
            String sttyCommand = String.format("stty -F %s %d cs8 -cstopb -parity raw -echo", portPath, baudRate);
            Process process = Runtime.getRuntime().exec(sttyCommand);
            process.waitFor();

            Log.d(TAG, "Port " + portPath + " opened with baud rate " + baudRate);
            return true;

        } catch (Exception e) {
            Log.e(TAG, "Error opening port: " + e.getMessage());
            return false;
        }
    }

    public boolean sendStartIgnoreProtocol() {
        FileOutputStream output = null;

        try {
            // Open port first with proper configuration
            if (!openPort(PORT_NAME, BAUD_RATE)) {
                Log.e(TAG, "Failed to open port: " + PORT_NAME);
                return false;
            }

            // Small delay after opening port
            Thread.sleep(20);

            File device = new File(PORT_NAME);
            output = new FileOutputStream(device);

            // Send command twice
            for (int i = 0; i < 2; i++) {
                output.write(START_IGNORE_PROTOCOL);
                output.flush();
                Log.d(TAG, "Sent START_ignore_protocol command " + (i + 1) + "/2");

                if (i < 1) {
                    Thread.sleep(10); // Short delay between sends
                }
            }

            Log.d(TAG, "Successfully sent START_ignore_protocol twice to " + PORT_NAME);
            return true;

        } catch (Exception e) {
            Log.e(TAG, "Error sending START_ignore_protocol: " + e.getMessage());
            return false;

        } finally {
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
