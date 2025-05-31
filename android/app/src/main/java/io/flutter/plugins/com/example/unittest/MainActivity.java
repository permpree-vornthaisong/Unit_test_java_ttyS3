package com.example.unittest;

import android.util.Log;
import androidx.annotation.NonNull;
import io.flutter.embedding.android.FlutterActivity;
import io.flutter.embedding.engine.FlutterEngine;
import io.flutter.plugin.common.MethodChannel;
import java.io.File;
import java.util.ArrayList;

public class MainActivity extends FlutterActivity {

    private static final String PRINTER_CHANNEL = "com.example.unittest/printer";
    private static final String WEIGHT_CHANNEL = "com.example.unittest/printer_weight";
    private static final String TAG = "MainActivity";

    private PrinterNative printerNative;
    private WeightReader weightReader;
    private SerialCommandSender commandSender;

    @Override
    public void configureFlutterEngine(@NonNull FlutterEngine flutterEngine) {
        super.configureFlutterEngine(flutterEngine);

        printerNative = new PrinterNative();
        weightReader = new WeightReader();
        commandSender = new SerialCommandSender();

        // Send START_ignore_protocol twice on app startup
        sendStartIgnoreProtocolOnStartup();

        // MethodChannel for Printer operations
        new MethodChannel(
                flutterEngine.getDartExecutor().getBinaryMessenger(),
                PRINTER_CHANNEL
        ).setMethodCallHandler((call, result) -> {
            switch (call.method) {
                case "getPorts":
                    ArrayList<String> ports = new ArrayList<>();
                    File dev = new File("/dev");
                    File[] files = dev.listFiles((dir, name) -> name.startsWith("tty"));
                    if (files != null) {
                        for (File file : files) {
                            ports.add(file.getAbsolutePath());
                        }
                    }
                    result.success(ports);
                    break;

                case "printBytes":
                    String portPath = call.argument("portPath");
                    byte[] data = call.argument("data");

                    if (portPath == null || data == null) {
                        result.error("INVALID_ARGUMENTS", "Port path and data required", null);
                        return;
                    }

                    boolean success = printerNative.printBytes(portPath, data);
                    if (success) {
                        result.success(true);
                    } else {
                        result.error("PRINT_ERROR", "Failed to print bytes", null);
                    }
                    break;

                case "sendStartIgnoreProtocol":
                    boolean protocolSuccess = commandSender.sendStartIgnoreProtocol();
                    if (protocolSuccess) {
                        result.success("START_ignore_protocol sent successfully");
                    } else {
                        result.error("PROTOCOL_ERROR", "Failed to send START_ignore_protocol", null);
                    }
                    break;

                default:
                    result.notImplemented();
                    break;
            }
        });

        // MethodChannel for WeightReader operations
        new MethodChannel(
                flutterEngine.getDartExecutor().getBinaryMessenger(),
                WEIGHT_CHANNEL
        ).setMethodCallHandler((call, result) -> {
            switch (call.method) {
                case "readWeight":
                    String portPath = call.argument("portPath");
                    Integer baudRateInteger = call.argument("baudRate");

                    if (portPath == null || baudRateInteger == null) {
                        result.error("INVALID_ARGUMENTS",
                                "Port path and baud rate required", null);
                        return;
                    }

                    int baudRate = baudRateInteger.intValue();
                    String rawData = weightReader.readAndLogRawData(portPath, baudRate);

                    if (rawData != null) {
                        result.success(rawData);
                    } else {
                        result.error("READ_ERROR",
                                "Failed to read raw data from scale", null);
                    }
                    break;

                case "closeWeightPort":
                    weightReader.closePort();
                    result.success("Weight port closed");
                    break;

                default:
                    result.notImplemented();
                    break;
            }
        });
    }

    private void sendStartIgnoreProtocolOnStartup() {
        new Thread(() -> {
            try {
                Thread.sleep(1000); // Wait 1 second after app start
                Log.d(TAG, "Sending START_ignore_protocol on app startup...");
                boolean success = commandSender.sendStartIgnoreProtocol();
                if (success) {
                    Log.d(TAG, "START_ignore_protocol sent successfully on startup");
                } else {
                    Log.e(TAG, "Failed to send START_ignore_protocol on startup");
                }
            } catch (InterruptedException e) {
                Log.e(TAG, "Interrupted while sending startup protocol: " + e.getMessage());
            }
        }).start();
    }

    @Override
    protected void onDestroy() {
        super.onDestroy();
    }
}
