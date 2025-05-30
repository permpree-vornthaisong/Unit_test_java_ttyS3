package com.example.unittest;

import android.util.Log;
import java.io.File;
import java.io.FileInputStream;
import java.io.IOException;

public class WeightReader {

  private static final String TAG = "WeightReader";
  private FileInputStream input;
  // **เพิ่มสองบรรทัดนี้เพื่อติดตามสถานะพอร์ตที่เปิดอยู่**
  private String currentPortPath = null;
  private int currentBaudRate = 0; // เก็บ baud rate ที่ใช้เปิดพอร์ต

  // เพิ่ม Constructor เพื่อให้สามารถสร้าง object ได้ (ถ้ายังไม่มี)
  public WeightReader() {
    // Initialization logic if needed
  }

  /**
   * Opens the specified serial port for reading.
   *
   * @param portPath The path to the serial port (e.g., "/dev/ttyS8").
   * @param baudRate The baud rate for the serial port.
   * @return true if the port was opened successfully, false otherwise.
   */
  public boolean openPort(String portPath, int baudRate) {
    // ตรวจสอบว่าพอร์ตเดียวกันเปิดอยู่แล้วหรือไม่
    if (isPortCurrentlyOpen(portPath, baudRate)) {
      Log.w(
        TAG,
        "WeightReader: Port " +
        portPath +
        " is already open with baud rate " +
        baudRate
      );
      return true;
    }

    try {
      closePort(); // ปิดการเชื่อมต่อเดิมก่อนเสมอ

      File device = new File(portPath);
      // ตรวจสอบว่าไฟล์พอร์ตมีอยู่และสามารถอ่านได้
      if (!device.exists() || !device.canRead()) {
        Log.e(
          TAG,
          "WeightReader: Device not found or not readable: " + portPath
        );
        this.currentPortPath = null; // รีเซ็ตสถานะ
        this.currentBaudRate = 0;
        return false;
      }

      input = new FileInputStream(device); // เปิด FileInputStream เพื่ออ่านข้อมูล
      this.currentPortPath = portPath;
      this.currentBaudRate = baudRate;
      Log.d(
        TAG,
        "WeightReader: Port opened successfully at " +
        baudRate +
        " baud for reading."
      );
      return true;
    } catch (IOException e) {
      this.currentPortPath = null; // รีเซ็ตสถานะหากเปิดไม่สำเร็จ
      this.currentBaudRate = 0;
      Log.e(TAG, "WeightReader: Error opening port: " + e.getMessage());
      return false;
    }
  }

  /**
   * Reads data from the specified serial port and prints it to Logcat.
   * This method does not parse or adjust weight; it only displays raw data.
   *
   * @param portPath The path to the serial port (e.g., "/dev/ttyS8").
   * @param baudRate The baud rate for the serial port.
   * @return The raw data read from the port as a String, or null if an error occurs or no data is read.
   */
  public String readAndLogRawData(String portPath, int baudRate) {
    try {
      // ถ้าพอร์ตยังไม่ได้เปิด หรือพารามิเตอร์ไม่ตรงกัน ให้พยายามเปิดพอร์ตก่อน
      if (!isPortCurrentlyOpen(portPath, baudRate)) {
        Log.d(
          TAG,
          "WeightReader: Port not open or parameters changed. Attempting to open: " +
          portPath +
          " @ " +
          baudRate
        );
        if (!openPort(portPath, baudRate)) {
          Log.e(
            TAG,
            "WeightReader: Failed to open port for reading: " + portPath
          );
          return null;
        }
      }

      if (input == null) {
        Log.e(
          TAG,
          "WeightReader: Input stream is null after attempting to open port."
        );
        return null;
      }

      // อ่านข้อมูลจาก serial port
      byte[] buffer = new byte[128]; // ปรับขนาด buffer ตามข้อมูลที่คาดว่าจะได้รับ
      int bytesRead = input.read(buffer); // อ่านข้อมูลจากพอร์ต

      if (bytesRead > 0) {
        String data = new String(buffer, 0, bytesRead).trim(); // แปลง byte array เป็น String และ trim ช่องว่าง
        Log.d(
          TAG,
          "WeightReader: Raw data received from " +
          portPath +
          ": '" +
          data +
          "'"
        ); // พิมพ์ข้อมูลลง Logcat
        return data; // ส่งข้อมูลดิบที่อ่านได้กลับไป
      } else {
        Log.d(TAG, "WeightReader: No bytes read from " + portPath);
        return null; // ไม่มีข้อมูลให้อ่าน
      }
    } catch (IOException e) {
      Log.e(
        TAG,
        "WeightReader: Error reading from port " +
        portPath +
        ": " +
        e.getMessage()
      );
      return null; // เกิดข้อผิดพลาดในการอ่าน
    }
  }

  /**
   * Checks if this WeightReader instance currently has the specified serial port open
   * with the given baud rate.
   *
   * @param portPath The path to the serial port.
   * @param baudRate The baud rate of the serial port.
   * @return true if the port is currently open by this instance with matching parameters, false otherwise.
   */
  public boolean isPortCurrentlyOpen(String portPath, int baudRate) {
    return (
      this.input != null && // ต้องมี input stream ที่ทำงานอยู่
      this.currentPortPath != null &&
      this.currentPortPath.equals(portPath) &&
      this.currentBaudRate == baudRate
    );
  }

  /**
   * Closes the serial port.
   */
  public void closePort() {
    try {
      if (input != null) {
        input.close(); // ปิด FileInputStream
        input = null;
        Log.d(TAG, "WeightReader: Port closed.");
      }
    } catch (IOException e) {
      Log.e(TAG, "WeightReader: Error closing input stream: " + e.getMessage());
    } finally {
      // **ล้างสถานะเมื่อปิดพอร์ต**
      currentPortPath = null;
      currentBaudRate = 0;
    }
  }
}
