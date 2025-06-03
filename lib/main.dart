import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'json_to_pdf_to_image_to_printbyte.dart'; // Add this import
import 'dart:convert'; // For utf8 encoding

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: const MyHomePage(),
      theme: ThemeData(
        // Set Thai font as default
        fontFamily: 'Sarabun',
        textTheme: const TextTheme(
          bodyLarge: TextStyle(fontFamily: 'Sarabun'),
          bodyMedium: TextStyle(fontFamily: 'Sarabun'),
          titleLarge: TextStyle(fontFamily: 'Sarabun'),
        ),
      ),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({Key? key}) : super(key: key);

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  final _channel = const MethodChannel('com.example.unittest/printer');
  bool _isPrinting = false;
  String _status = 'Ready';

  // Add JSON printer instances
  final _jsonToPdfPrinter = JsonToPdfPrinterSimple();
  final _jsonToEscPos = JsonToEscPos();

  // Printer configuration
  static const String PORT_PATH = '/dev/ttyS3';
  static const int PRINTER_WIDTH = 500; // 50mm printer in dots

  // ESC/POS Commands
  static const List<int> ESC_INIT = [0x1B, 0x40];
  static const List<int> ESC_ALIGN_CENTER = [0x1B, 0x61, 0x01];
  static const List<int> ESC_ALIGN_LEFT = [0x1B, 0x61, 0x00];
  static const List<int> ESC_LINE_SPACING_24 = [0x1B, 0x33, 24];
  static const List<int> ESC_LINE_SPACING_30 = [0x1B, 0x33, 30];
  static const List<int> ESC_BIT_IMAGE = [0x1B, 0x2A, 33];
  static const List<int> LF = [0x0A];
  static const List<int> ESC_FEED_3 = [0x1B, 0x64, 0x03];
  static const List<int> SWAP_INT_COLOR = [0, 1];
  Future<void> _printImage() async {
    setState(() {
      _isPrinting = true;
      _status = 'Processing image...';
    });

    try {
      // 1. Load image
      final data = await rootBundle.load('assets/logo4.png');
      final originalImage = img.decodeImage(data.buffer.asUint8List());
      if (originalImage == null) throw Exception('Failed to decode image');

      setState(() => _status = 'Resizing image...');

      // 2. Resize image to 400px width
      int adjustedHeight(int originalHeight) =>
          (originalHeight / 8 * 0.7).ceil() * 8;
      final resizedImage = img.copyResize(
        originalImage,
        width: 400,
        height: adjustedHeight(originalImage.height),
      );

      final height = resizedImage.height;

      setState(() => _status = 'Printing image...');

      // 3. Print image 8 vertical dots at a time (back to row by row)
      for (int y = 0; y < height; y += 8) {
        List<int> bytes = [];

        // Set line spacing
        bytes.addAll([0x1B, 0x33, 8]);

        // Left half (0-199)
        bytes.addAll([0x1B, 0x24, 0x00, 0x00]); // Position 0
        bytes.addAll([0x1B, 0x2A, 0x01, 200, 0]); // ESC * 1 200 0

        for (int x = 0; x < 200; x++) {
          int byte = 0;
          for (int bit = 0; bit < 8; bit++) {
            int pxY = y + bit;
            if (pxY >= height) continue;
            final pixel = resizedImage.getPixel(x, pxY);
            final isBlack = img.getLuminance(pixel) < 128;
            byte |= SWAP_INT_COLOR[isBlack ? 1 : 0] << (7 - bit);
          }
          bytes.add(byte);
        }

        // Right half (200-399)
        bytes.addAll([0x1B, 0x24, 200, 0x00]); // Position 200
        bytes.addAll([0x1B, 0x2A, 0x01, 200, 0]);

        for (int x = 200; x < 400; x++) {
          int byte = 0;
          for (int bit = 0; bit < 8; bit++) {
            int pxY = y + bit;
            if (pxY >= height) continue;
            final pixel = resizedImage.getPixel(x, pxY);
            final isBlack = img.getLuminance(pixel) < 128;
            byte |= SWAP_INT_COLOR[isBlack ? 1 : 0] << (7 - bit);
          }
          bytes.add(byte);
        }

        // Line feed
        bytes.add(0x0A);

        // Send each row to printer
        await _channel.invokeMethod('printBytes', {
          'portPath': '/dev/ttyS3',
          'data': Uint8List.fromList(bytes),
        });

        // Update progress
        if (y % 40 == 0) {
          // Update every 5 rows
          setState(
              () => _status = 'Printing... ${((y / height) * 100).round()}%');
        }
      }

      setState(() => _status = 'Image printed successfully!');
    } catch (e) {
      setState(() => _status = 'Print error: $e');
      print('Print error: $e');
    } finally {
      setState(() => _isPrinting = false);
    }
  }

  Future<void> _printTestPattern() async {
    setState(() {
      _isPrinting = true;
      _status = 'Printing test...';
    });

    try {
      List<int> commands = [];

      // Simple test pattern
      commands.addAll(ESC_INIT);
      commands.addAll(ESC_ALIGN_CENTER);
      commands.addAll('=== TEST PRINT ===\n'.codeUnits);
      commands.addAll(ESC_ALIGN_LEFT);
      commands.addAll('Printer Width: $PRINTER_WIDTH dots\n'.codeUnits);
      commands.addAll('Port: $PORT_PATH\n'.codeUnits);
      commands.addAll(ESC_FEED_3);

      await _channel.invokeMethod('printBytes', {
        'portPath': PORT_PATH,
        'data': Uint8List.fromList(commands),
      });

      setState(() => _status = 'Test completed!');
    } catch (e) {
      setState(() => _status = 'Error: $e');
    } finally {
      setState(() => _isPrinting = false);
    }
  }

  Future<void> _printCustom() async {
    setState(() {
      _isPrinting = true;
      _status = 'Sending custom data...';
    });

    try {
      // Example: Send raw hex data
      List<int> customData = [
        0x1B, 0x40, // ESC @
        // Add your custom commands here
        0x48, 0x65, 0x6C, 0x6C, 0x6F, // "Hello"
        0x0A, // LF
        0x1B, 0x64, 0x03, // Feed 3 lines
      ];

      await _channel.invokeMethod('printBytes', {
        'portPath': PORT_PATH,
        'data': Uint8List.fromList(customData),
      });

      setState(() => _status = 'Custom data sent!');
    } catch (e) {
      setState(() => _status = 'Error: $e');
    } finally {
      setState(() => _isPrinting = false);
    }
  }

  Future<void> _sendStartIgnoreProtocol() async {
    setState(() {
      _isPrinting = true;
      _status = 'Sending START_ignore_protocol...';
    });

    try {
      final result = await _channel.invokeMethod('sendStartIgnoreProtocol');
      setState(() => _status = result);
    } catch (e) {
      setState(() => _status = 'Protocol Error: $e');
    } finally {
      setState(() => _isPrinting = false);
    }
  }

  // Add simple Thai test method
  Future<void> _printSimpleThaiTest() async {
    setState(() {
      _isPrinting = true;
      _status = 'กำลังทดสอบภาษาไทย...';
    });

    try {
      List<int> commands = [];

      // Initialize printer with Thai support
      commands.addAll([0x1B, 0x40]); // ESC @ (reset)
      commands.addAll([0x1B, 0x74, 0x11]); // ESC t 17 (CP874 for Thai)
      commands.addAll([0x1B, 0x52, 0x0E]); // ESC R 14 (Thailand)

      // Center align
      commands.addAll([0x1B, 0x61, 0x01]);

      // Double size
      commands.addAll([0x1D, 0x21, 0x11]);

      // Thai text using UTF-8 encoding
      final thaiText1 = utf8.encode('ทดสอบภาษาไทย');
      commands.addAll(thaiText1);
      commands.add(0x0A);

      // Normal size
      commands.addAll([0x1D, 0x21, 0x00]);

      final thaiText2 = utf8.encode('สวัสดีครับ');
      commands.addAll(thaiText2);
      commands.add(0x0A);

      final thaiText3 = utf8.encode('ขอบคุณที่ใช้บริการ');
      commands.addAll(thaiText3);
      commands.add(0x0A);

      // Left align
      commands.addAll([0x1B, 0x61, 0x00]);

      final thaiText4 = utf8.encode('เครื่องพิมพ์ทำงานได้ปกติ');
      commands.addAll(thaiText4);
      commands.add(0x0A);

      final thaiText5 = utf8.encode('1234567890 abcABC');
      commands.addAll(thaiText5);
      commands.add(0x0A);

      commands.addAll([0x1B, 0x64, 0x03]); // Feed 3 lines

      await _channel.invokeMethod('printBytes', {
        'portPath': PORT_PATH,
        'data': Uint8List.fromList(commands),
      });

      setState(() => _status = 'ทดสอบภาษาไทยสำเร็จ!');
    } catch (e) {
      setState(() => _status = 'ข้อผิดพลาด: $e');
    } finally {
      setState(() => _isPrinting = false);
    }
  }

  // Update JSON receipt with clearer Thai text
  Future<void> _printJsonReceipt() async {
    setState(() {
      _isPrinting = true;
      _status = 'กำลังประมวลผลใบเสร็จ JSON...';
    });

    try {
      // Sample JSON data with clear Thai content
      final String exampleJson = '''
      {
        "header": {
          "title": "ใบเสร็จรับเงิน",
          "subtitle": "ร้านค้าตัวอย่าง"
        },
        "orderInfo": {
          "orderNumber": "12345",
          "date": "15/01/2024 14:30",
          "customer": "นายสมชาย ใจดี"
        },
        "items": [
          {
            "name": "ข้าวผัด",
            "quantity": 2,
            "price": 50.00,
            "total": 100.00
          },
          {
            "name": "น้ำอัดลม",
            "quantity": 1,
            "price": 15.00,
            "total": 15.00
          },
          {
            "name": "ไก่ทอด",
            "quantity": 1,
            "price": 35.00,
            "total": 35.00
          }
        ],
        "summary": {
          "subtotal": 150.00,
          "tax": 10.50,
          "discount": 0.00,
          "total": 160.50
        },
        "footer": {
          "message": "ขอบคุณครับ\\nโทร 02-123-4567"
        }
      }
      ''';

      // Use direct ESC/POS conversion with Thai support
      await _jsonToEscPos.printFromJson(exampleJson);

      setState(() => _status = 'พิมพ์ใบเสร็จ JSON สำเร็จแล้ว!');
    } catch (e) {
      setState(() => _status = 'ข้อผิดพลาดในการพิมพ์ JSON: $e');
      print('JSON print error: $e');
    } finally {
      setState(() => _isPrinting = false);
    }
  }

  // Add JSON to PDF method with Thai content
  Future<void> _printJsonToPdf() async {
    setState(() {
      _isPrinting = true;
      _status = 'กำลังแปลง JSON เป็น PDF เป็นรูปภาพ...';
    });

    try {
      final String exampleJson = '''
      {
        "header": {
          "title": "ใบกำกับภาษี",
          "subtitle": "ใบเสร็จรับเงินแบบมืออาชีพ"
        },
        "orderInfo": {
          "orderNumber": "INV-2024-001",
          "date": "2024-01-15 14:30",
          "customer": "คุณสมหญิง รักษ์ดี"
        },
        "items": [
          {
            "name": "บริการพรีเมียม",
            "quantity": 1,
            "price": 100.00,
            "total": 100.00
          },
          {
            "name": "ฟีเจอร์เพิ่มเติม",
            "quantity": 2,
            "price": 25.00,
            "total": 50.00
          }
        ],
        "summary": {
          "subtotal": 150.00,
          "tax": 15.00,
          "total": 165.00
        },
        "footer": {
          "message": "ขอบคุณสำหรับธุรกิจของคุณ!\\nติดต่อ: support@company.com"
        }
      }
      ''';

      // แก้ไขจาก printFromJson เป็น showPdfFromJson
      await _jsonToPdfPrinter.showPdfFromJson(exampleJson, context);

      setState(() => _status = 'แสดง PDF สำเร็จแล้ว!');
    } catch (e) {
      setState(() => _status = 'ข้อผิดพลาดในการแสดง PDF: $e');
      print('PDF show error: $e');
    } finally {
      setState(() => _isPrinting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('เครื่องพิมพ์ความร้อนพร้อม JSON',
            style: TextStyle(fontFamily: 'Sarabun')),
        backgroundColor: Colors.indigo,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // Status
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: _isPrinting ? Colors.blue.shade50 : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (_isPrinting)
                    const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  const SizedBox(width: 10),
                  Text(
                    _status,
                    style: const TextStyle(fontSize: 16, fontFamily: 'Sarabun'),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 30),

            // Protocol button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isPrinting ? null : _sendStartIgnoreProtocol,
                icon: const Icon(Icons.send),
                label: const Text('ส่ง START_ignore_protocol',
                    style: TextStyle(fontFamily: 'Sarabun')),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.all(16),
                  backgroundColor: Colors.orange,
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Simple Thai test button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isPrinting ? null : _printSimpleThaiTest,
                icon: const Icon(Icons.translate),
                label: const Text('ทดสอบภาษาไทยง่าย ๆ',
                    style: TextStyle(fontFamily: 'Sarabun')),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.all(16),
                  backgroundColor: Colors.red,
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Test Pattern button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isPrinting ? null : _printTestPattern,
                icon: const Icon(Icons.text_snippet),
                label: const Text('พิมพ์ลายทดสอบ',
                    style: TextStyle(fontFamily: 'Sarabun')),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.all(16),
                  backgroundColor: Colors.green,
                ),
              ),
            ),

            const SizedBox(height: 16),

            // JSON Receipt button (ESC/POS direct)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isPrinting ? null : _printJsonReceipt,
                icon: const Icon(Icons.receipt_long),
                label: const Text('พิมพ์ใบเสร็จ JSON (ESC/POS)',
                    style: TextStyle(fontFamily: 'Sarabun')),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.all(16),
                  backgroundColor: Colors.deepPurple,
                ),
              ),
            ),

            const SizedBox(height: 16),

            // JSON to PDF button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isPrinting ? null : _printJsonToPdf,
                icon: const Icon(Icons.picture_as_pdf),
                label: const Text('พิมพ์ JSON ผ่าน PDF (ขั้นสูง)',
                    style: TextStyle(fontFamily: 'Sarabun')),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.all(16),
                  backgroundColor: Colors.indigo,
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Image button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isPrinting ? null : _printImage,
                icon: const Icon(Icons.image),
                label: const Text('พิมพ์รูปโลโก้',
                    style: TextStyle(fontFamily: 'Sarabun')),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.all(16),
                  backgroundColor: Colors.blue,
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Custom bytes button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isPrinting ? null : _printCustom,
                icon: const Icon(Icons.code),
                label: const Text('ส่งไบต์กำหนดเอง',
                    style: TextStyle(fontFamily: 'Sarabun')),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.all(16),
                  backgroundColor: Colors.teal,
                ),
              ),
            ),

            const SizedBox(height: 30),

            // Info section
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.amber.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text(
                    'การทดสอบเครื่องพิมพ์ JSON:',
                    style: TextStyle(
                        fontWeight: FontWeight.bold, fontFamily: 'Sarabun'),
                  ),
                  SizedBox(height: 8),
                  Text('• ESC/POS: แปลง JSON เป็นคำสั่งพิมพ์โดยตรง (เร็วกว่า)',
                      style: TextStyle(fontFamily: 'Sarabun')),
                  Text('• PDF: JSON → PDF → รูปภาพ → พิมพ์ (รูปแบบสวยกว่า)',
                      style: TextStyle(fontFamily: 'Sarabun')),
                  Text('• ทั้งสองวิธีรองรับรูปแบบ JSON เดียวกัน',
                      style: TextStyle(fontFamily: 'Sarabun')),
                  SizedBox(height: 8),
                  Text(
                    'พอร์ต: /dev/ttyS3 | ความกว้าง: 500 จุด',
                    style: TextStyle(fontSize: 12, fontFamily: 'Sarabun'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
