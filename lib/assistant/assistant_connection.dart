enum AssistantService {
  openai('OpenAI', 'https://api.openai.com/v1'),
  gemini(
    'Google Gemini',
    'https://generativelanguage.googleapis.com/v1beta/openai',
  ),
  xai('xAI / Grok', 'https://api.x.ai/v1'),
  openRouter('OpenRouter', 'https://openrouter.ai/api/v1'),
  custom('', '');

  const AssistantService(this.label, this.url);
  final String label;
  final String url;
}

final class AssistantConnection {
  const AssistantConnection({
    required this.service,
    required this.endpoint,
    required this.model,
    required this.apiKey,
  });

  final AssistantService service;
  final Uri endpoint;
  final String model;
  final String apiKey;

  Map<String, String> toJson() => {
    'provider': service.name,
    'baseUrl': endpoint.toString(),
    'model': model,
    'key': apiKey,
  };

  static AssistantConnection? fromJson(Map<String, dynamic> data) {
    final provider = data['provider'];
    final service = provider == null
        ? AssistantService.openai
        : AssistantService.values
              .where((item) => item.name == provider)
              .firstOrNull;
    final model = data['model'];
    final key = data['key'];
    if (service == null ||
        model is! String ||
        model.trim().isEmpty ||
        key is! String) {
      return null;
    }
    final url = service == AssistantService.custom
        ? data['baseUrl']
        : service.url;
    final endpoint = url is String ? parseEndpoint(url) : null;
    if (endpoint == null ||
        (key.isEmpty && service != AssistantService.custom)) {
      return null;
    }
    return AssistantConnection(
      service: service,
      endpoint: endpoint,
      model: model,
      apiKey: key,
    );
  }

  static Uri? parseEndpoint(String url) {
    final uri = Uri.tryParse(url.trim());
    if (uri == null ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        uri.hasQuery ||
        uri.hasFragment) {
      return null;
    }
    final loopback = const {'localhost', '127.0.0.1', '::1'}.contains(uri.host);
    if (uri.scheme != 'https' && !(uri.scheme == 'http' && loopback)) {
      return null;
    }
    // The SDK appends /chat/completions. Accept that suffix when pasted.
    final path = uri.path
        .replaceFirst(RegExp(r'/+$'), '')
        .replaceFirst(RegExp(r'/chat/completions$'), '');
    return uri.replace(path: path);
  }
}
