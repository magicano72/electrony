import 'package:shared_preferences/shared_preferences.dart';

class StorageHelper {
  // Static method to clear the PDF file path
  static Future<void> clearPdfFilePath() async {
    SharedPreferences pref = await SharedPreferences.getInstance();
    await pref.remove('pdfFilePath');
  }
}
