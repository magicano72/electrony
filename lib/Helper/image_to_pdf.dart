import 'dart:io';
import 'dart:typed_data';
import 'dart:ui';

import 'package:Electrony/models/sign_model.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart'; // Updated import
import 'package:syncfusion_flutter_pdf/pdf.dart' as sf_pdf;

class ImageToPDF {
  late sf_pdf.PdfDocument _document;

  Future<void> loadImage(Uint8List imageBytes) async {
    _document = sf_pdf.PdfDocument();
    final page = _document.pages.add();
    final image = sf_pdf.PdfBitmap(imageBytes);
    page.graphics.drawImage(
        image,
        Rect.fromLTWH(
            0, 0, page.getClientSize().width, page.getClientSize().height));
  }

  void addText(String text, double x, double y, int pageIndex,
      {double fontSize = 16, String color = '#000000'}) {
    if (pageIndex < 1 || pageIndex > _document.pages.count) {
      print("Invalid page index: $pageIndex. Defaulting to page 1.");
      pageIndex = 1;
    }
    final page = _document.pages[pageIndex - 1];
    final graphics = page.graphics;
    final font =
        sf_pdf.PdfStandardFont(sf_pdf.PdfFontFamily.helvetica, fontSize);
    final brush = sf_pdf.PdfSolidBrush(sf_pdf.PdfColor.fromCMYK(0, 0, 0, 100));
    graphics.drawString(text, font,
        brush: brush, bounds: Rect.fromLTWH(x, y, 500, 20));
  }

  void addImage(Uint8List imageBytes, double x, double y, int pageIndex,
      {double width = 100, double height = 100}) {
    if (pageIndex < 1 || pageIndex > _document.pages.count) {
      print("Invalid page index: $pageIndex. Defaulting to page 1.");
      pageIndex = 1;
    }
    final page = _document.pages[pageIndex - 1];
    final graphics = page.graphics;
    final image = sf_pdf.PdfBitmap(imageBytes);
    graphics.drawImage(image, Rect.fromLTWH(x, y, width, height));
  }

  void addSignature(Uint8List signatureBytes, double x, double y, int pageIndex,
      {double width = 100, double height = 50}) {
    addImage(signatureBytes, x, y, pageIndex, width: width, height: height);
  }

  Future<void> addElements(List<SignModel> elements) async {
    for (var element in elements) {
      switch (element.type) {
        case SignType.name:
          addText(element.signatureText ?? '', element.xOffset, element.yOffset,
              element.currentPage);
          break;
        case SignType.signature:
          if (element.signatureId != null) {
            final response = await http.get(Uri.parse(
                'http://139.59.134.100:8055/assets/${element.signatureId}'));
            if (response.statusCode == 200) {
              addSignature(response.bodyBytes, element.xOffset, element.yOffset,
                  element.currentPage);
            }
          }
          break;
        case SignType.date:
          addText(element.signatureText ?? '', element.xOffset, element.yOffset,
              element.currentPage);
          break;
      }
    }
  }

  Future<File> savePDF(String fileName) async {
    final output = await getTemporaryDirectory();
    final file = File("${output.path}/$fileName.pdf");
    await file.writeAsBytes(_document.saveSync());
    return file;
  }

  Future<void> sharePDF(File pdfFile) async {
    await Share.shareXFiles(
      [XFile(pdfFile.path)],
      subject: 'Generated PDF',
      text: 'Please find the attached PDF document.',
    );
  }

  Future<File> convertImageToPdf(Uint8List imageBytes, String fileName) async {
    await loadImage(imageBytes);
    return await savePDF(fileName);
  }
}
