class ApiUris {
  static String normalizeBase(String baseUrl) {
    var base = baseUrl.trim();
    while (base.endsWith('/')) {
      base = base.substring(0, base.length - 1);
    }
    return base;
  }

  static Uri models(String baseUrl) {
    final base = normalizeBase(baseUrl);
    if (base.endsWith('/models')) {
      return Uri.parse(base);
    }
    if (base.endsWith('/v1')) {
      return Uri.parse('$base/models');
    }
    return Uri.parse('$base/v1/models');
  }

  static Uri chatCompletions(String baseUrl) {
    final base = normalizeBase(baseUrl);
    if (base.endsWith('/chat/completions')) {
      return Uri.parse(base);
    }
    if (base.endsWith('/v1')) {
      return Uri.parse('$base/chat/completions');
    }
    return Uri.parse('$base/v1/chat/completions');
  }
}
