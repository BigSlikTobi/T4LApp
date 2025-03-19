import 'package:js/js.dart';
import 'package:js/js_util.dart';
import 'package:app/utils/logger.dart';

@JS('imageProxy.convertToBase64')
external Future<String> _convertToBase64JS(String url);

Future<String> getProxiedImageUrl(String url) async {
  try {
    final result = await promiseToFuture(_convertToBase64JS(url));
    if (result != null && result.toString().startsWith('data:image')) {
      return result.toString();
    }
  } catch (e) {
    AppLogger.error('Image proxy error', e);
  }
  return url;
}
