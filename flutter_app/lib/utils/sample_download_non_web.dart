import 'dart:typed_data';

abstract class SampleDownloadImpl {
  static Future<void> download(Uint8List bytes, String filename) async {
    throw UnsupportedError('Sample download is only supported on web builds.');
  }
}

