import 'package:openai_dart/openai_dart.dart';
import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;

/// OpenRouter datasource using OpenAI Dart client for streaming support
class OpenRouterOpenAIDatasource {
  late final OpenAIClient _client;
  
  OpenRouterOpenAIDatasource({
    required String apiKey,
  }) {
    // Use a CORS proxy for web platform
    // Options for CORS proxies:
    // - https://corsproxy.io/? (public, may be slow)
    // - https://cors-anywhere.herokuapp.com/ (requires demo access)
    // - Your own proxy server (recommended for production)
    final baseUrl = kIsWeb 
        ? 'https://corsproxy.io/?https://openrouter.ai/api/v1'
        : 'https://openrouter.ai/api/v1';
    
    _client = OpenAIClient(
      baseUrl: baseUrl,
      apiKey: apiKey,
      headers: {
        'HTTP-Referer': 'https://legalragmexico.com',
        'X-Title': 'Legal RAG Mexico',
        'Content-Type': 'application/json',
      },
    );
    print('OpenRouterOpenAIDatasource initialized with baseUrl: $baseUrl');
    print('Running on web: $kIsWeb');
  }

  /// Send a chat completion request with streaming support
  Stream<String> sendChatCompletionStream({
    required String message,
    String model = 'qwen/qwen3-235b-a22b-thinking-2507',
    List<Map<String, dynamic>>? previousMessages,
    double temperature = 0.7,
    int maxTokens = 4000,
  }) async* {
    try {
      print('Sending streaming request to OpenRouter...');
      print('Model: $model');
      print('Message: $message');
      
      // Build messages list
      final messages = <ChatCompletionMessage>[
        if (previousMessages != null)
          ...previousMessages.map((msg) {
            final role = msg['role'] as String;
            final content = msg['content'] as String;
            
            switch (role) {
              case 'system':
                return ChatCompletionMessage.system(
                  content: content,
                );
              case 'developer':
                return ChatCompletionMessage.developer(
                  content: ChatCompletionDeveloperMessageContent.text(content),
                );
              case 'user':
                return ChatCompletionMessage.user(
                  content: ChatCompletionUserMessageContent.string(content),
                );
              case 'assistant':
                return ChatCompletionMessage.assistant(
                  content: content,
                );
              default:
                return ChatCompletionMessage.user(
                  content: ChatCompletionUserMessageContent.string(content),
                );
            }
          }),
        ChatCompletionMessage.user(
          content: ChatCompletionUserMessageContent.string(message),
        ),
      ];

      // Create streaming request
      final stream = _client.createChatCompletionStream(
        request: CreateChatCompletionRequest(
          model: ChatCompletionModel.modelId(model),
          messages: messages,
          temperature: temperature,
          maxTokens: maxTokens,
        ),
      );

      // Yield content as it arrives
      await for (final res in stream) {
        final choices = res.choices;
        if (choices != null && choices.isNotEmpty) {
          final delta = choices.first.delta;
          final content = delta?.content;
          if (content != null && content.isNotEmpty) {
            yield content;
          }
        }
      }
    } catch (e) {
      print('OpenRouter streaming error: $e');
      throw Exception('Failed to get streaming response: $e');
    }
  }

  /// Send a regular (non-streaming) chat completion request
  Future<String> sendChatCompletion({
    required String message,
    String model = 'qwen/qwen3-235b-a22b-thinking-2507',
    List<Map<String, dynamic>>? previousMessages,
    double temperature = 0.7,
    int maxTokens = 4000,
  }) async {
    try {
      // Build messages list
      final messages = <ChatCompletionMessage>[
        if (previousMessages != null)
          ...previousMessages.map((msg) {
            final role = msg['role'] as String;
            final content = msg['content'] as String;
            
            switch (role) {
              case 'system':
                return ChatCompletionMessage.system(
                  content: content,
                );
              case 'developer':
                return ChatCompletionMessage.developer(
                  content: ChatCompletionDeveloperMessageContent.text(content),
                );
              case 'user':
                return ChatCompletionMessage.user(
                  content: ChatCompletionUserMessageContent.string(content),
                );
              case 'assistant':
                return ChatCompletionMessage.assistant(
                  content: content,
                );
              default:
                return ChatCompletionMessage.user(
                  content: ChatCompletionUserMessageContent.string(content),
                );
            }
          }),
        ChatCompletionMessage.user(
          content: ChatCompletionUserMessageContent.string(message),
        ),
      ];

      // Create regular request
      final response = await _client.createChatCompletion(
        request: CreateChatCompletionRequest(
          model: ChatCompletionModel.modelId(model),
          messages: messages,
          temperature: temperature,
          maxTokens: maxTokens,
        ),
      );

      if (response.choices.isNotEmpty) {
        return response.choices.first.message.content ?? '';
      }
      return '';
    } catch (e) {
      print('OpenRouter error: $e');
      throw Exception('Failed to get response: $e');
    }
  }

  void dispose() {
    // Client doesn't need explicit disposal
  }
}