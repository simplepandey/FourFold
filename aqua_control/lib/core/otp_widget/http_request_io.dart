import 'dart:convert';
import 'dart:io';

// MSG91's carrier-based silent/invisible verification flow (widgetInvisibleResponse,
// MDNHINT_VERIFIED) chains through more redirect hops over real cellular data than
// dart:io's default auto-follow cap of 5 allows, aborting with "Redirect limit
// exceeded" before a response is ever returned. Auto-follow is disabled here and the
// chain is walked manually instead, up to a generous limit.
Future<Map<String, dynamic>> otpHttpRequest(
  String url,
  Map<String, dynamic> body, {
  required bool isPost,
  Duration timeout = const Duration(seconds: 15),
  int maxRedirects = 25,
}) async {
  final client = HttpClient();
  try {
    return await _requestFollowingRedirects(
      client,
      url,
      body,
      isPost,
      timeout,
      maxRedirects,
      0,
    );
  } finally {
    client.close(force: true);
  }
}

Future<Map<String, dynamic>> _requestFollowingRedirects(
  HttpClient client,
  String url,
  Map<String, dynamic> body,
  bool isPost,
  Duration timeout,
  int maxRedirects,
  int redirectCount,
) async {
  if (redirectCount > maxRedirects) {
    throw Exception('Too many redirects for URL: $url');
  }

  final uri = Uri.parse(url);
  final request = isPost ? await client.postUrl(uri) : await client.getUrl(uri);
  request.followRedirects = false;
  request.headers.set(HttpHeaders.contentTypeHeader, 'application/json; charset=UTF-8');
  if (isPost) {
    request.write(jsonEncode(body));
  }

  final response = await request.close().timeout(timeout);
  final responseBody = await response.transform(utf8.decoder).join();

  if (response.statusCode >= 300 && response.statusCode < 400) {
    final location = response.headers.value(HttpHeaders.locationHeader);
    if (location != null) {
      return _requestFollowingRedirects(
        client,
        location,
        body,
        false,
        timeout,
        maxRedirects,
        redirectCount + 1,
      );
    }
  }

  if (response.statusCode >= 200 && response.statusCode < 400) {
    return jsonDecode(responseBody) as Map<String, dynamic>;
  }

  throw Exception(
    'Failed to ${isPost ? 'post' : 'get'} data: ${response.statusCode}, $responseBody',
  );
}
