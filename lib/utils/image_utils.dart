import 'package:flutter/foundation.dart';

// Web-specific imports
export 'image_utils_web.dart' if (dart.library.io) 'image_utils_io.dart';

Future<String> getProxiedImageUrl(String url) async {
  // For non-web platforms, return the original URL
  if (!kIsWeb) {
    return url;
  }

  // For web, the implementation is in image_utils_web.dart
  return url;
}
