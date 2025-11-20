import 'dart:typed_data';

import 'sample_download_non_web.dart'
    if (dart.library.html) 'sample_download_web.dart';

/// Cross-platform helper that attempts to trigger a download of the provided
/// bytes as an `.xlsx` file. On unsupported platforms, the underlying
/// implementation will throw an [UnsupportedError].
Future<void> downloadSampleFile(Uint8List bytes, String filename) {
  return SampleDownloadImpl.download(bytes, filename);
}

