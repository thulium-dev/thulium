import 'package:dartantic_ai/dartantic_ai.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:thulium/assistant/assistant_connection.dart';
import 'package:thulium/assistant/assistant_model.dart';

void main() {
  test('restores saved OpenAI credentials from before provider selection', () {
    final connection = AssistantConnection.fromJson({
      'key': 'test-key',
      'model': 'gpt-4o-mini',
    })!;

    expect(connection.service, AssistantService.openai);
    expect(connection.endpoint.toString(), AssistantService.openai.url);
    expect(connection.apiKey, 'test-key');
  });

  test('accepts a base URL or a pasted completions URL', () {
    expect(
      AssistantConnection.parseEndpoint(
        ' https://gateway.example/openai/v1/chat/completions/ ',
      ).toString(),
      'https://gateway.example/openai/v1',
    );
    expect(
      AssistantConnection.parseEndpoint('http://127.0.0.1:11434/v1'),
      isNotNull,
    );
    for (final url in [
      'http://gateway.example/v1',
      'https://user:key@gateway.example/v1',
      'https://gateway.example/v1?token=key',
      'https://gateway.example/v1#fragment',
      'gateway.example/v1',
    ]) {
      expect(AssistantConnection.parseEndpoint(url), isNull, reason: url);
    }
  });

  test('the agent streams from the configured URL with its own key', () async {
    final endpoint = Uri.parse('https://gateway.example/custom/v1');
    final client = MockClient((request) async {
      expect(request.url.toString(), '$endpoint/chat/completions');
      expect(request.headers['authorization'], 'Bearer test-key');
      expect(request.body, contains('"model":"custom-model"'));
      return http.Response(
        'data: {"id":"sample","object":"chat.completion.chunk","created":0,'
        '"model":"custom-model","choices":[{"index":0,"delta":{"content":"Hello"},'
        '"finish_reason":null}]}\n\n'
        'data: {"id":"sample","object":"chat.completion.chunk","created":0,'
        '"model":"custom-model","choices":[{"index":0,"delta":{},'
        '"finish_reason":"stop"}]}\n\n'
        'data: [DONE]\n\n',
        200,
        headers: {'content-type': 'text/event-stream'},
      );
    });
    final connection = AssistantConnection(
      service: AssistantService.custom,
      endpoint: endpoint,
      model: 'custom-model',
      apiKey: 'test-key',
    );
    final agent = Agent.forProvider(
      AssistantModelProvider(client, connection),
      chatModelName: connection.model,
    );

    final text = await agent
        .sendStream('Hi')
        .map((chunk) => chunk.output)
        .join();
    expect(text, 'Hello');
  });
}
