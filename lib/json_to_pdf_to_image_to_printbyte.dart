import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:image/image.dart' as img;
import 'dart:convert';
import 'package:flutter/rendering.dart';
import 'package:printing/printing.dart';

class JsonToPdfPrinterSimple {
  // PDF configuration
  static const double PDF_WIDTH = 58.0 * PdfPageFormat.mm;
  static const double PDF_HEIGHT = 210.0 * PdfPageFormat.mm;

  /// Main function: JSON → PDF → Show in popup (PDF preview only)
  Future<void> showPdfFromJson(String jsonString, BuildContext context) async {
    try {
      // 1. Parse JSON
      final jsonData = json.decode(jsonString);

      // 2. Create PDF
      final pdfData = await _createPdf(jsonData);

      // 3. Show PDF in simplified popup
      await _showSimplePdfDialog(context, pdfData);
    } catch (e) {
      _showErrorDialog(context, 'Error processing JSON: $e');
      print('PDF Error: $e');
    }
  }

  /// Show simplified PDF dialog without PdfPreview widget
  Future<void> _showSimplePdfDialog(
      BuildContext context, Uint8List pdfData) async {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext dialogContext) {
        return Dialog(
          insetPadding: const EdgeInsets.all(20),
          child: Container(
            width: MediaQuery.of(context).size.width * 0.9,
            height: MediaQuery.of(context).size.height * 0.7,
            child: Column(
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade600,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(8),
                      topRight: Radius.circular(8),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.picture_as_pdf, color: Colors.white),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'PDF สร้างเสร็จแล้ว!',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'Sarabun',
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white),
                        onPressed: () => Navigator.of(dialogContext).pop(),
                      ),
                    ],
                  ),
                ),

                // Content Area
                Expanded(
                  child: Container(
                    color: Colors.grey.shade100,
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.check_circle,
                          size: 80,
                          color: Colors.green.shade600,
                        ),
                        const SizedBox(height: 20),
                        const Text(
                          'ไฟล์ PDF ถูกสร้างเรียบร้อยแล้ว!',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'Sarabun',
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'ขนาดไฟล์: ${(pdfData.length / 1024).toStringAsFixed(1)} KB',
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.grey,
                            fontFamily: 'Sarabun',
                          ),
                        ),
                        const SizedBox(height: 30),
                        const Text(
                          'เลือกการดำเนินการ:',
                          style: TextStyle(
                            fontSize: 16,
                            fontFamily: 'Sarabun',
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Action buttons
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(8),
                      bottomRight: Radius.circular(8),
                    ),
                  ),
                  child: Column(
                    children: [
                      // Share button
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () async {
                            try {
                              await Printing.sharePdf(
                                bytes: pdfData,
                                filename:
                                    'Receipt_${DateTime.now().millisecondsSinceEpoch}.pdf',
                              );
                            } catch (e) {
                              _showErrorDialog(
                                  context, 'ไม่สามารถแชร์ PDF ได้: $e');
                            }
                          },
                          icon: const Icon(Icons.share),
                          label: const Text(
                            'แชร์ PDF',
                            style: TextStyle(fontFamily: 'Sarabun'),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),

                      // System print button
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () async {
                            try {
                              await Printing.layoutPdf(
                                onLayout: (format) => pdfData,
                                name:
                                    'Receipt_${DateTime.now().millisecondsSinceEpoch}',
                              );
                            } catch (e) {
                              _showErrorDialog(
                                  context, 'ไม่สามารถเปิดหน้าพิมพ์ได้: $e');
                            }
                          },
                          icon: const Icon(Icons.print),
                          label: const Text(
                            'พิมพ์ (ระบบ)',
                            style: TextStyle(fontFamily: 'Sarabun'),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),

                      // Preview as image button (alternative)
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () async {
                            Navigator.of(dialogContext).pop();
                            await _showPdfAsImagePreview(context, pdfData);
                          },
                          icon: const Icon(Icons.image),
                          label: const Text(
                            'ดูตัวอย่างเป็นรูปภาพ',
                            style: TextStyle(fontFamily: 'Sarabun'),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),

                      // Close button
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () => Navigator.of(dialogContext).pop(),
                          icon: const Icon(Icons.close),
                          label: const Text(
                            'ปิด',
                            style: TextStyle(fontFamily: 'Sarabun'),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.grey,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Show PDF as image preview (fallback method)
  Future<void> _showPdfAsImagePreview(
      BuildContext context, Uint8List pdfData) async {
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const AlertDialog(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('กำลังแปลง PDF เป็นรูปภาพ...',
                  style: TextStyle(fontFamily: 'Sarabun')),
            ],
          ),
        ),
      );

      // Convert PDF to image using safe method
      final image = await _pdfToImageSafe(pdfData);

      // Close loading dialog
      Navigator.of(context).pop();

      if (image != null) {
        // Show image preview
        showDialog(
          context: context,
          builder: (context) => Dialog(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  color: Colors.blue.shade600,
                  child: Row(
                    children: [
                      const Icon(Icons.image, color: Colors.white),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'ตัวอย่าง PDF',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'Sarabun',
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                ),
                Container(
                  height: 400,
                  child: SingleChildScrollView(
                    child: Image.memory(
                      img.encodePng(image),
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(16),
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('ปิด',
                        style: TextStyle(fontFamily: 'Sarabun')),
                  ),
                ),
              ],
            ),
          ),
        );
      } else {
        _showErrorDialog(context, 'ไม่สามารถแปลง PDF เป็นรูปภาพได้');
      }
    } catch (e) {
      Navigator.of(context).pop(); // Close loading dialog
      _showErrorDialog(context, 'Error converting PDF: $e');
    }
  }

  /// Safe PDF to image conversion
  Future<img.Image?> _pdfToImageSafe(Uint8List pdfBytes) async {
    try {
      final raster = await Printing.raster(pdfBytes, pages: [0]).first;
      final pngBytes = await raster.toPng();
      return img.decodePng(pngBytes);
    } catch (e) {
      print('Error in _pdfToImageSafe: $e');
      return null;
    }
  }

  /// Show error dialog
  void _showErrorDialog(BuildContext context, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title:
            const Text('ข้อผิดพลาด', style: TextStyle(fontFamily: 'Sarabun')),
        content: Text(message, style: const TextStyle(fontFamily: 'Sarabun')),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('ตกลง', style: TextStyle(fontFamily: 'Sarabun')),
          ),
        ],
      ),
    );
  }

  /// Create PDF from JSON data with Thai font support
  Future<Uint8List> _createPdf(Map<String, dynamic> data) async {
    final pdf = pw.Document();

    // Try to load Thai font
    pw.Font? thaiFont;
    try {
      final fontData =
          await rootBundle.load('assets/fonts/Sarabun-Regular.ttf');
      thaiFont = pw.Font.ttf(fontData);
    } catch (e) {
      print('Warning: Could not load Thai font, using default font');
    }

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat(PDF_WIDTH, PDF_HEIGHT),
        margin: const pw.EdgeInsets.all(8),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Header
              if (data['header'] != null) ...[
                pw.Center(
                  child: pw.Text(
                    data['header']['title'] ?? '',
                    style: pw.TextStyle(
                      font: thaiFont,
                      fontSize: 16,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ),
                if (data['header']['subtitle'] != null)
                  pw.Center(
                    child: pw.Text(
                      data['header']['subtitle'],
                      style: pw.TextStyle(font: thaiFont, fontSize: 10),
                    ),
                  ),
                pw.SizedBox(height: 8),
                pw.Divider(),
              ],

              // Order info
              if (data['orderInfo'] != null) ...[
                _buildInfoRow(
                    'Order #', data['orderInfo']['orderNumber'], thaiFont),
                _buildInfoRow('Date', data['orderInfo']['date'], thaiFont),
                _buildInfoRow(
                    'Customer', data['orderInfo']['customer'], thaiFont),
                pw.SizedBox(height: 8),
                pw.Divider(),
              ],

              // Items
              if (data['items'] != null && data['items'] is List) ...[
                ...data['items']
                    .map((item) => pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text(
                              item['name'] ?? '',
                              style: pw.TextStyle(font: thaiFont, fontSize: 10),
                            ),
                            pw.Row(
                              mainAxisAlignment:
                                  pw.MainAxisAlignment.spaceBetween,
                              children: [
                                pw.Text(
                                  '  ${item['quantity']} x ${item['price']}',
                                  style:
                                      pw.TextStyle(font: thaiFont, fontSize: 9),
                                ),
                                pw.Text(
                                  '${item['total']}',
                                  style:
                                      pw.TextStyle(font: thaiFont, fontSize: 9),
                                ),
                              ],
                            ),
                            pw.SizedBox(height: 3),
                          ],
                        ))
                    .toList(),
                pw.Divider(),
              ],

              // Summary
              if (data['summary'] != null) ...[
                if (data['summary']['subtotal'] != null)
                  _buildSummaryRow(
                      'Subtotal', data['summary']['subtotal'], thaiFont),
                if (data['summary']['tax'] != null)
                  _buildSummaryRow('Tax', data['summary']['tax'], thaiFont),
                if (data['summary']['discount'] != null)
                  _buildSummaryRow(
                      'Discount', data['summary']['discount'], thaiFont),
                pw.Divider(),
                _buildSummaryRow(
                  'Total',
                  data['summary']['total'] ?? '',
                  thaiFont,
                  bold: true,
                  fontSize: 12,
                ),
              ],

              // Footer
              if (data['footer'] != null) ...[
                pw.SizedBox(height: 16),
                pw.Center(
                  child: pw.Text(
                    data['footer']['message'] ?? '',
                    style: pw.TextStyle(font: thaiFont, fontSize: 9),
                    textAlign: pw.TextAlign.center,
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );

    return pdf.save();
  }

  // Helper methods with Thai font support
  pw.Widget _buildInfoRow(String label, String? value, pw.Font? font) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(label + ':', style: pw.TextStyle(font: font, fontSize: 10)),
        pw.Text(value ?? '', style: pw.TextStyle(font: font, fontSize: 10)),
      ],
    );
  }

  pw.Widget _buildSummaryRow(String label, dynamic value, pw.Font? font,
      {bool bold = false, double fontSize = 10}) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(
          label + ':',
          style: pw.TextStyle(
            font: font,
            fontSize: fontSize,
            fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
          ),
        ),
        pw.Text(
          value.toString(),
          style: pw.TextStyle(
            font: font,
            fontSize: fontSize,
            fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
          ),
        ),
      ],
    );
  }
}

// Keep JsonToEscPos class for ESC/POS direct printing
class JsonToEscPos {
  final MethodChannel _channel =
      const MethodChannel('com.example.unittest/printer');
  static const String PORT_PATH = '/dev/ttyS3';

  Future<void> printFromJson(String jsonString) async {
    final data = json.decode(jsonString);
    List<int> commands = [];

    // Initialize printer
    commands.addAll([0x1B, 0x40]); // ESC @

    // Header
    if (data['header'] != null) {
      commands.addAll([0x1B, 0x61, 0x01]); // Center align
      commands.addAll([0x1D, 0x21, 0x11]); // Double height/width
      commands.addAll((data['header']['title'] ?? '').codeUnits);
      commands.add(0x0A); // LF

      commands.addAll([0x1D, 0x21, 0x00]); // Normal size
      if (data['header']['subtitle'] != null) {
        commands.addAll(data['header']['subtitle'].codeUnits);
        commands.add(0x0A);
      }

      commands.addAll([0x1B, 0x61, 0x00]); // Left align
      commands.addAll('--------------------------------'.codeUnits);
      commands.add(0x0A);
    }

    // Order info
    if (data['orderInfo'] != null) {
      commands.addAll('Order #: ${data['orderInfo']['orderNumber']}'.codeUnits);
      commands.add(0x0A);
      commands.addAll('Date: ${data['orderInfo']['date']}'.codeUnits);
      commands.add(0x0A);
      commands.addAll('Customer: ${data['orderInfo']['customer']}'.codeUnits);
      commands.add(0x0A);
      commands.addAll('--------------------------------'.codeUnits);
      commands.add(0x0A);
    }

    // Items
    if (data['items'] != null) {
      for (var item in data['items']) {
        commands.addAll(item['name'].toString().codeUnits);
        commands.add(0x0A);

        String qty = item['quantity'].toString().padRight(3);
        String price = item['price'].toString().padLeft(7);
        String total = item['total'].toString().padLeft(8);
        commands.addAll('  $qty x $price = $total'.codeUnits);
        commands.add(0x0A);
      }
      commands.addAll('--------------------------------'.codeUnits);
      commands.add(0x0A);
    }

    // Summary
    if (data['summary'] != null) {
      if (data['summary']['subtotal'] != null) {
        String label = 'Subtotal:'.padRight(20);
        String value = data['summary']['subtotal'].toString().padLeft(10);
        commands.addAll('$label$value'.codeUnits);
        commands.add(0x0A);
      }

      if (data['summary']['tax'] != null) {
        String label = 'Tax:'.padRight(20);
        String value = data['summary']['tax'].toString().padLeft(10);
        commands.addAll('$label$value'.codeUnits);
        commands.add(0x0A);
      }

      commands.addAll('================================'.codeUnits);
      commands.add(0x0A);

      commands.addAll([0x1D, 0x21, 0x11]); // Double size
      String label = 'TOTAL:'.padRight(15);
      String value = data['summary']['total'].toString().padLeft(10);
      commands.addAll('$label$value'.codeUnits);
      commands.add(0x0A);
      commands.addAll([0x1D, 0x21, 0x00]); // Normal size
    }

    // Footer
    if (data['footer'] != null) {
      commands.add(0x0A);
      commands.addAll([0x1B, 0x61, 0x01]); // Center
      commands.addAll(data['footer']['message'].toString().codeUnits);
      commands.add(0x0A);
    }

    // Feed and cut
    commands.addAll([0x1B, 0x64, 0x05]); // Feed 5 lines

    // Send to printer
    await _channel.invokeMethod('printBytes', {
      'portPath': PORT_PATH,
      'data': Uint8List.fromList(commands),
    });
  }
}
