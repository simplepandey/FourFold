import 'dart:convert';
import 'package:http/http.dart' as http;

// Browsers follow redirects internally with their own (much higher) limits,
// so dart:io's low default cap never applies here — plain http.post/get is fine.
Future<Map<String, dynamic>> otpHttpRequest(
  String url,
  Map<String, dynamic> body, {
  required bool isPost,
  Duration timeout = const Duration(seconds: 15),
  int maxRedirects = 25,
}) async {
  final uri = Uri.parse(url);
  final response = isPost
      ? await http
          .post(uri, headers: {'Content-Type': 'application/json; charset=UTF-8'}, body: jsonEncode(body))
          .timeout(timeout)
      : await http.get(uri, headers: {'Content-Type': 'application/json; charset=UTF-8'}).timeout(timeout);

  if (response.statusCode >= 200 && response.statusCode < 400) {
    return jsonDecode(response.body) as Map<String, dynamic>;
  }
  throw Exception(
    'Failed to ${isPost ? 'post' : 'get'} data: ${response.statusCode}, ${response.body}',
  );
}
