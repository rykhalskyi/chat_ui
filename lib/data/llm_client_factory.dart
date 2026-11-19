import '../domain/llm/llm_client.dart';
import 'api_client_factory.dart';
import 'litellm_client.dart';

class LlmClientFactory {
  const LlmClientFactory({this.apiClientFactory = const ApiClientFactory()});

  final ApiClientFactory apiClientFactory;

  LlmClient create({
    required String baseUrl,
    required String apiKey,
    String? connectAddress,
  }) {
    return LiteLlmClient(
      baseUrl: baseUrl,
      apiKey: apiKey,
      clientFactory: () =>
          apiClientFactory.create(connectAddress: connectAddress),
    );
  }
}
