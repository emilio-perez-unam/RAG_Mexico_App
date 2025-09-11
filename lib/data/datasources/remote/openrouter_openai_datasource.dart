import 'package:openai_dart/openai_dart.dart';
import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:logger/logger.dart';
import 'package:http/http.dart' as http;

/// OpenRouter datasource using OpenAI Dart client for streaming support
class OpenRouterOpenAIDatasource {
  late final OpenAIClient _client;
  final String _apiKey;
  final Logger _logger = Logger(
    printer: PrettyPrinter(
      methodCount: 0,
      errorMethodCount: 5,
      lineLength: 50,
      colors: true,
      printEmojis: false,
    ),
  );
  
  OpenRouterOpenAIDatasource({
    required String apiKey,
    String? customBaseUrl,
  }) : _apiKey = apiKey {
    // Use Cloudflare Worker to handle CORS for browser deployment
    // The worker proxies requests to OpenRouter with proper CORS headers
    final baseUrl = customBaseUrl ?? 
      (kIsWeb 
        ? 'https://openrouter-proxy.emilio-perez.workers.dev/api/v1'  // Your Cloudflare Worker endpoint
        : 'https://openrouter.ai/api/v1');  // Direct access for non-web platforms
    
    // Create a custom HTTP client that might handle CORS better
    final httpClient = http.Client();
    
    _client = OpenAIClient(
      baseUrl: baseUrl,
      apiKey: apiKey,
      headers: {
        // OpenRouter requires these specific headers
        'HTTP-Referer': 'https://legalragmexico.com',
        'X-Title': 'Legal RAG Mexico',
      },
      client: httpClient,
    );
    
    _logger.i('OpenRouterOpenAIDatasource initialized');
    _logger.i('Base URL: $baseUrl');
    _logger.i('Running on web: $kIsWeb');
    _logger.i(kIsWeb 
      ? 'Using Cloudflare Worker proxy for CORS handling' 
      : 'Using direct OpenRouter API access');
    _logger.i('Using openai_dart version 0.5.5 with custom HTTP client');
    
    // Debug: Log the actual API key being used (first and last 4 chars only for security)
    final keyLength = apiKey.length;
    final maskedKey = keyLength > 8 
      ? '${apiKey.substring(0, 4)}...${apiKey.substring(keyLength - 4)}' 
      : 'KEY_TOO_SHORT';
    _logger.i('API Key being used: $maskedKey (length: $keyLength)');
    _logger.i('API Key starts with: ${apiKey.substring(0, 10)}...');
  }

  /// Test if the API is accessible from the current environment
  Future<bool> testApiAccess() async {
    try {
      _logger.i('Testing API access to OpenRouter...');
      _logger.i('Using API key: ${_apiKey.substring(0, 20)}...');
      
      // Log the exact headers that will be sent
      _logger.i('Headers configured in OpenAIClient:');
      _logger.i('- HTTP-Referer: https://legalragmexico.com');
      _logger.i('- X-Title: Legal RAG Mexico');
      _logger.i('- Authorization: Bearer ${_apiKey.substring(0, 15)}...');
      
      // Try a minimal API call to test connectivity
      final response = await _client.createChatCompletion(
        request: CreateChatCompletionRequest(
          model: ChatCompletionModel.modelId('qwen/qwen3-235b-a22b-thinking-2507'),
          messages: [
            ChatCompletionMessage.user(
              content: ChatCompletionUserMessageContent.string('test'),
            ),
          ],
          maxTokens: 1,
        ),
      );
      
      _logger.i(kIsWeb 
        ? 'API test successful! Cloudflare Worker proxy is working.' 
        : 'API test successful! Direct access is working.');
      return true;
    } catch (e) {
      _logger.e('API test failed: $e');
      
      // Parse error for more details
      if (e.toString().contains('401')) {
        _logger.e('Authentication failed - API key may be invalid or expired');
        _logger.e('Please check your OpenRouter API key at https://openrouter.ai/keys');
      }
      
      if (kIsWeb && e.toString().contains('Failed to fetch')) {
        _logger.w('Running on web - Request failed.');
        _logger.w('Check Cloudflare Worker logs at: https://dash.cloudflare.com/');
        _logger.w('Worker endpoint: https://openrouter-proxy.emilio-perez.workers.dev/');
      }
      
      return false;
    }
  }
  
  /// Send a chat completion request with streaming support
  Stream<String> sendChatCompletionStream({
    required String message,
    String model = 'qwen/qwen3-235b-a22b-thinking-2507',
    List<Map<String, dynamic>>? previousMessages,
    double temperature = 0.7,
    int maxTokens = 100000,
  }) async* {
    try {
      _logger.d('Sending streaming request to OpenRouter...');
      _logger.d('Model: $model');
      _logger.d('Message: $message');
      
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

      // Yield content as it arrives with better error handling
      await for (final res in stream) {
        try {
          final choices = res.choices;
          if (choices != null && choices.isNotEmpty) {
            final delta = choices.first.delta;
            final content = delta?.content;
            if (content != null && content.isNotEmpty) {
              // Handle potential string/number content
              if (content is String) {
                yield content;
              } else {
                // Log unexpected content type but continue
                _logger.w('Unexpected content type: ${content.runtimeType}');
              }
            }
          }
        } catch (parseError) {
          // Log parsing error but continue streaming
          _logger.w('Stream parsing warning: $parseError');
          // Continue to next chunk instead of breaking the stream
          continue;
        }
      }
    } catch (e) {
      _logger.e('OpenRouter streaming error: $e');
      throw Exception('Failed to get streaming response: $e');
    }
  }

  /// Send a regular (non-streaming) chat completion request
  Future<String> sendChatCompletion({
    required String message,
    String model = 'qwen/qwen3-235b-a22b-thinking-2507',
    List<Map<String, dynamic>>? previousMessages,
    double temperature = 0.7,
    int maxTokens = 100000,
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
      _logger.e('OpenRouter error: $e');
      throw Exception('Failed to get response: $e');
    }
  }

  void dispose() {
    // Client doesn't need explicit disposal
  }
}