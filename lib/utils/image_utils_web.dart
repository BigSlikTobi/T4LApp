import 'package:js/js.dart';
import 'package:js/js_util.dart';
import 'package:app/utils/logger.dart';

@JS('imageProxy.convertToBase64')
external Future<String> _convertToBase64JS(String url);

Future<String> getProxiedImageUrl(String url) async {
  // Skip proxying for data URLs, asset URLs, or relative URLs
  if (url.startsWith('data:') ||
      url.startsWith('assets/') ||
      url.startsWith('/')) {
    return url;
  }

  try {
    // Try to convert to base64 using the JS proxy
    final result = await promiseToFuture(_convertToBase64JS(url));
    if (result != null && result.toString().startsWith('data:image')) {
      return result.toString();
    }

    // If conversion fails but we got some result, try using a fallback URL
    // This ensures we never return the direct external URL which would cause CORS errors
    return "https://images.weserv.nl/?url=${Uri.encodeComponent(url)}";
  } catch (e) {
    AppLogger.error('Image proxy error', e);
    // If JS proxy completely fails, use a fallback proxy service directly
    return "https://images.weserv.nl/?url=${Uri.encodeComponent(url)}";
  }
}
