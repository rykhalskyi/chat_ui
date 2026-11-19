import 'package:http/http.dart' as http;

import '../domain/llm/llm_client.dart';
import 'litellm_client.dart';

class LlmClientFactory {
  const LlmClientFactory({this.clientFactory});

  final http.Client Function()? clientFactory;

  LlmClient create({required String baseUrl, required String apiKey}) {
    return LiteLlmClient(
      baseUrl: baseUrl,
      apiKey: apiKey,
      clientFactory: clientFactory,
    );
  }
}
