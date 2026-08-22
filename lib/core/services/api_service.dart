import 'dart:convert';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:logger/logger.dart';
import 'package:telsoworld/core/constants/api_endpoints.dart';
import 'package:telsoworld/core/services/storage_service.dart';

/// ---------------------------------------------------------------------------
/// 🌐 ApiService (Central HTTP Network Client)
/// ---------------------------------------------------------------------------
/// Yeh service backend REST APIs ke saath communication handle karti hai.
///
/// New Developer ke liye zaroori baatein:
/// 1. `_defaultHeaders`: Agar user logged in hai, toh automatically `Authorization: Bearer <token>`
///    aur `Accept: application/json` attach karta hai. Manual header lagane ki zaroorat nahi padti.
/// 2. `get()` aur `post()` methods me automatic URL construction (`baseUrl + endpoint`)
///    aur console logging configured hai.
/// ---------------------------------------------------------------------------
class ApiService extends GetxService {
  final Logger _logger = Logger();
  StorageService get _storage => Get.find<StorageService>();

  /// 📋 Default Headers (Bearer Token + JSON accept)
  Map<String, String> get _defaultHeaders {
    final token = _storage.getToken();
    final headers = <String, String>{
      'Accept': 'application/json',
    };
    if (token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }

  /// 📥 HTTP GET Request (URL query parameters ke saath)
  Future<http.Response> get(String endpoint, {Map<String, String>? queryParams}) async {
    final uri = Uri.parse('${ApiEndpoints.baseUrl}$endpoint').replace(queryParameters: queryParams);
    _logger.i('GET Request -> $uri');
    try {
      final response = await http.get(uri, headers: _defaultHeaders);
      _logger.i('Response [${response.statusCode}] -> ${response.body}');
      return response;
    } catch (e) {
      _logger.e('GET Error -> $e');
      rethrow;
    }
  }

  /// 📤 HTTP POST Request (JSON payload ya Form-urlencoded data ke saath)
  Future<http.Response> post(String endpoint, {Map<String, dynamic>? body, bool isFormUrlEncoded = false}) async {
    final uri = Uri.parse('${ApiEndpoints.baseUrl}$endpoint');
    final headers = Map<String, String>.from(_defaultHeaders);

    dynamic formattedBody;
    if (isFormUrlEncoded) {
      headers['Content-Type'] = 'application/x-www-form-urlencoded';
      formattedBody = body?.map((key, value) => MapEntry(key, value.toString()));
    } else {
      headers['Content-Type'] = 'application/json';
      formattedBody = jsonEncode(body);
    }

    _logger.i('POST Request -> $uri\nBody: $formattedBody');
    try {
      final response = await http.post(uri, headers: headers, body: formattedBody);
      _logger.i('Response [${response.statusCode}] -> ${response.body}');
      return response;
    } catch (e) {
      _logger.e('POST Error -> $e');
      rethrow;
    }
  }
}
