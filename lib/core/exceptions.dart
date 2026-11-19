import 'dart:convert';

enum LlmErrorKind {
  network,
  timeout,
  unauthorized,
  invalidRequest,
  modelNotFound,
  rateLimited,
  server,
  protocol,
  cancelled,
}

class LlmException implements Exception {
  const LlmException(
    this.kind,
    this.message, {
    this.statusCode,
    this.errorType,
  });

  factory LlmException.fromHttp(int statusCode, String body) {
    final decoded = _tryDecode(body);
    final error = decoded?['error'];
    String? message;
    String? type;
    if (error is Map<String, dynamic>) {
      message = error['message']?.toString();
      type = error['type']?.toString();
    } else if (error is String) {
      message = error;
    }
    final text = (message ?? body).trim();
    final kind = switch (statusCode) {
      401 || 403 => LlmErrorKind.unauthorized,
      404 => LlmErrorKind.modelNotFound,
      429 => LlmErrorKind.rateLimited,
      >= 500 => LlmErrorKind.server,
      400 => _badRequestKind(type, text.toLowerCase()),
      _ => LlmErrorKind.invalidRequest,
    };
    return LlmException(
      kind,
      text.isEmpty ? 'HTTP $statusCode' : text,
      statusCode: statusCode,
      errorType: type,
    );
  }

  final LlmErrorKind kind;
  final String message;
  final int? statusCode;
  final String? errorType;

  String get userMessage => switch (kind) {
    LlmErrorKind.network => 'Network error. Check the LAN/VPN connection.',
    LlmErrorKind.timeout => 'The request timed out. Try again.',
    LlmErrorKind.unauthorized =>
      'Authentication failed. Check the API key in Settings.',
    LlmErrorKind.modelNotFound => 'Model not found. Refresh the model list.',
    LlmErrorKind.rateLimited => 'Rate limited. Try again shortly.',
    LlmErrorKind.server => 'Server error: $message',
    LlmErrorKind.invalidRequest => message,
    LlmErrorKind.protocol => 'Unexpected server response: $message',
    LlmErrorKind.cancelled => 'Cancelled.',
  };

  @override
  String toString() => message;

  static LlmErrorKind _badRequestKind(String? type, String message) {
    final normalizedType = (type ?? '').toLowerCase();
    if (normalizedType.contains('no_db_connection') ||
        message.contains('api key') ||
        message.contains('authentication')) {
      return LlmErrorKind.unauthorized;
    }
    if (message.contains('invalid model') || message.contains('model name')) {
      return LlmErrorKind.modelNotFound;
    }
    return LlmErrorKind.invalidRequest;
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
