import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../core/api_uris.dart';
import '../domain/entities/model_info.dart';

class ModelCatalogException implements Exception {
  const ModelCatalogException(this.message);

  final String message;

  @override
  String toString() => message;
}

class ModelCatalogClient {
  ModelCatalogClient({
    http.Client Function()? clientFactory,
    this.timeout = const Duration(seconds: 15),
  }) : _clientFactory = clientFactory ?? http.Client.new;

  final http.Client Function() _clientFactory;
  final Duration timeout;

  Future<List<ModelInfo>> fetchModels({
    required String baseUrl,
    required String apiKey,
  }) async {
    final uri = modelsUri(baseUrl);
    final client = _clientFactory();
    try {
      final headers = <String, String>{'Accept': 'application/json'};
      if (apiKey.isNotEmpty) {
        headers['Authorization'] = 'Bearer $apiKey';
      }
      final response = await client.get(uri, headers: headers).timeout(timeout);
      if (response.statusCode != 200) {
        throw ModelCatalogException(_errorMessage(response));
      }
      final decoded = jsonDecode(response.body);
      final data = decoded is Map<String, dynamic> ? decoded['data'] : null;
      if (data is! List) {
        throw const ModelCatalogException(
          'Unexpected /models response: missing "data" list.',
        );
      }
      final models =
          data
              .whereType<Map<String, dynamic>>()
              .map(ModelInfo.fromJson)
              .toList()
            ..sort((a, b) => a.id.compareTo(b.id));
      return models;
    } on TimeoutException {
      throw ModelCatalogException(
        'Timed out after ${timeout.inSeconds}s contacting $uri.',
      );
    } on http.ClientException catch (error) {
      throw ModelCatalogException('Network error: ${error.message}');
    } on FormatException {
      throw const ModelCatalogException('Server returned invalid JSON.');
    } finally {
      client.close();
    }
  }

  static Uri modelsUri(String baseUrl) => ApiUris.models(baseUrl);

  static String _errorMessage(http.Response response) {
    final decoded = _tryDecode(response.body);
    if (decoded != null) {
      final error = decoded['error'];
      if (error is Map<String, dynamic> && error['message'] is String) {
        return 'HTTP ${response.statusCode}: ${error['message']}';
      }
      if (error is String) {
        return 'HTTP ${response.statusCode}: $error';
      }
    }
    final body = response.body.trim();
    if (body.isEmpty) {
      return 'HTTP ${response.statusCode}';
    }
    final snippet = body.length > 200 ? '${body.substring(0, 200)}…' : body;
    return 'HTTP ${response.statusCode}: $snippet';
  }

  static Map<String, dynamic>? _tryDecode(String body) {
    try {
      final decoded = jsonDecode(body);
      return decoded is Map<String, dynamic> ? decoded : null;
    } on FormatException {
      return null;
    }
  }
}
