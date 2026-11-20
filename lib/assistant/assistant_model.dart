import 'package:dartantic_ai/dartantic_ai.dart';
import 'package:http/http.dart' as http;

import 'assistant_connection.dart';

/// Supplies a transport owned by one turn so Stop can close an in-flight
/// request even while the provider is waiting for its first streaming chunk.
final class AssistantModelProvider extends OpenAIProvider {
  AssistantModelProvider(this._client, AssistantConnection connection)
    : super(apiKey: connection.apiKey, baseUrl: connection.endpoint);

  final http.Client _client;

  @override
  ChatModel<OpenAIChatOptions> createChatModel({
    String? name,
    List<Tool>? tools,
    double? temperature,
    bool enableThinking = false,
    OpenAIChatOptions? options,
  }) => OpenAIChatModel(
    name: name ?? defaultModelNames[ModelKind.chat]!,
    apiKey: apiKey?.isEmpty == true ? null : apiKey,
    baseUrl: baseUrl,
    tools: tools,
    temperature: temperature,
    defaultOptions: options,
    client: _client,
  );
}
