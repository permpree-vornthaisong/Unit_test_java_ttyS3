import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(home: MyHomePage());
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

  Future<void> _printImage() async {
    setState(() {
      _isPrinting = true;
      _status = 'Processing image...';
    });

    try {
      // 1. Load image
      final data = await rootBundle.load('assets/LOGO.png');
      final originalImage = img.decodeImage(data.buffer.asUint8List());
      if (originalImage == null) throw Exception('Failed to decode image');

      setState(() => _status = 'Enhancing image quality...');

      // 2. Convert to grayscale and apply contrast enhancement
      final grayscaleImage = img.grayscale(originalImage);
      final contrastImage = img.adjustColor(grayscaleImage, contrast: 1.3);

      // 3. Resize to optimal width (384 pixels for 48mm printer)
      final resizedImage = img.copyResize(
        contrastImage,
        width: 384,
        height: (contrastImage.height * 384 / contrastImage.width).round(),
        interpolation: img.Interpolation.cubic,
      );

      setState(() => _status = 'Converting to printer format...');

      // 4. Apply dithering for better quality
      final ditheredImage = _applyFloydSteinbergDithering(resizedImage);
      final height = ditheredImage.height;

      setState(() => _status = 'Printing image...');

      // 5. Initialize printer
      List<int> initCommands = [];
      initCommands.addAll(ESC_INIT);
      initCommands.addAll(ESC_ALIGN_CENTER);
      initCommands.addAll([0x1B, 0x33, 24]); // Set line spacing to 24/180 inch

      await _channel.invokeMethod('printBytes', {
        'portPath': '/dev/ttyS3',
        'data': Uint8List.fromList(initCommands),
      });

      // 6. Print image using bit image mode
      for (int y = 0; y < height; y += 24) {
        // 24-pin mode for better quality
        List<int> rowBytes = [];

        // ESC * mode for 24-pin graphics
        rowBytes.addAll([0x1B, 0x2A, 33]); // ESC * ! (24-pin double-density)

        int actualWidth = 384;
        rowBytes.add(actualWidth & 0xFF);
        rowBytes.add((actualWidth >> 8) & 0xFF);

        // Generate 24-pin data
        for (int x = 0; x < actualWidth; x++) {
          // Each column needs 3 bytes for 24 pins
          int byte1 = 0, byte2 = 0, byte3 = 0;

          for (int pin = 0; pin < 8; pin++) {
            if (y + pin < height && _isBlackPixel(ditheredImage, x, y + pin)) {
              byte1 |= (1 << (7 - pin));
            }
          }

          for (int pin = 0; pin < 8; pin++) {
            if (y + pin + 8 < height &&
                _isBlackPixel(ditheredImage, x, y + pin + 8)) {
              byte2 |= (1 << (7 - pin));
            }
          }

          for (int pin = 0; pin < 8; pin++) {
            if (y + pin + 16 < height &&
                _isBlackPixel(ditheredImage, x, y + pin + 16)) {
              byte3 |= (1 << (7 - pin));
            }
          }

          rowBytes.addAll([byte1, byte2, byte3]);
        }

        rowBytes.add(0x0A); // Line feed

        // Send row to printer
        await _channel.invokeMethod('printBytes', {
          'portPath': '/dev/ttyS3',
          'data': Uint8List.fromList(rowBytes),
        });

        // Update progress
        setState(
            () => _status = 'Printing... ${((y / height) * 100).round()}%');
      }

      // Final spacing
      await _channel.invokeMethod('printBytes', {
        'portPath': '/dev/ttyS3',
        'data': Uint8List.fromList([0x1B, 0x64, 0x03]), // Feed 3 lines
      });

      setState(() => _status = 'High-quality image printed!');
    } catch (e) {
      setState(() => _status = 'Print error: $e');
      print('Print error: $e');
    } finally {
      setState(() => _isPrinting = false);
    }
  }

  // Floyd-Steinberg dithering for better image quality
  img.Image _applyFloydSteinbergDithering(img.Image image) {
    final width = image.width;
    final height = image.height;
    final result = img.Image(width: width, height: height);

    // Create error diffusion matrix
    List<List<double>> errors =
        List.generate(height, (i) => List.filled(width, 0.0));

    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        final pixel = image.getPixel(x, y);
        final gray = img.getLuminance(pixel) + errors[y][x];

        final newGray = gray < 128 ? 0 : 255;
        final error = gray - newGray;

        result.setPixel(x, y, img.ColorRgb8(newGray, newGray, newGray));

        // Distribute error to neighboring pixels
        if (x + 1 < width) {
          errors[y][x + 1] += error * 7 / 16;
        }
        if (y + 1 < height) {
          if (x - 1 >= 0) {
            errors[y + 1][x - 1] += error * 3 / 16;
          }
          errors[y + 1][x] += error * 5 / 16;
          if (x + 1 < width) {
            errors[y + 1][x + 1] += error * 1 / 16;
          }
        }
      }
    }

    return result;
  }

  bool _isBlackPixel(img.Image image, int x, int y) {
    if (x >= image.width || y >= image.height) return false;
    final pixel = image.getPixel(x, y);
    return img.getLuminance(pixel) < 128;
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Simple Printer - Raw Bytes Only'),
        backgroundColor: Colors.indigo,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
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
                    style: const TextStyle(fontSize: 16),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 40),

            // START_ignore_protocol button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isPrinting ? null : _sendStartIgnoreProtocol,
                icon: const Icon(Icons.send),
                label: const Text('Send START_ignore_protocol'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.all(16),
                  backgroundColor: Colors.orange,
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Buttons
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isPrinting ? null : _printTestPattern,
                icon: const Icon(Icons.text_snippet),
                label: const Text('Print Test Pattern'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.all(16),
                  backgroundColor: Colors.green,
                ),
              ),
            ),

            const SizedBox(height: 16),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isPrinting ? null : _printImage,
                icon: const Icon(Icons.image),
                label: const Text('Print Logo Image'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.all(16),
                  backgroundColor: Colors.blue,
                ),
              ),
            ),

            const SizedBox(height: 16),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isPrinting ? null : _printCustom,
                icon: const Icon(Icons.code),
                label: const Text('Send Custom Bytes'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.all(16),
                  backgroundColor: Colors.purple,
                ),
              ),
            ),

            const Spacer(),

            // Info
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.amber.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'Port: /dev/ttyS3 | Width: 500 dots | Auto START_ignore_protocol on startup',
                style: TextStyle(fontSize: 12),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
