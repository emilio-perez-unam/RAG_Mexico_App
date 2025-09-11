import 'dart:convert';
import 'package:http/http.dart' as http;

/// Remote datasource for interacting with DeepSeek-R1 API
class DeepSeekDatasource {
  static const String _baseUrl = 'https://api.deepseek.com/v1';
  static const String _defaultModel = 'deepseek-reasoner';
  static const double _defaultTemperature = 0.6;
  static const int _defaultMaxTokens = 32768;

  final String apiKey;
  final http.Client? httpClient;

  DeepSeekDatasource({
    required this.apiKey,
    http.Client? httpClient,
  }) : httpClient = httpClient ?? http.Client();

  /// Send a message to DeepSeek-R1 (alias for sendChatCompletion for compatibility)
  Future<DeepSeekResponse> sendMessage(
    String message, {
    String? model,
    double? temperature,
    int? maxTokens,
    bool enforceThinking = false,
    List<Map<String, dynamic>>? previousMessages,
  }) async {
    return sendChatCompletion(
      message: message,
      model: model,
      temperature: temperature,
      maxTokens: maxTokens,
      enforceThinking: enforceThinking,
      previousMessages: previousMessages,
    );
  }

  /// Send a chat completion request to DeepSeek-R1
  Future<DeepSeekResponse> sendChatCompletion({
    required String message,
    String? model,
    double? temperature,
    int? maxTokens,
    bool enforceThinking = false,
    List<Map<String, dynamic>>? previousMessages,
  }) async {
    try {
      final messages = [
        if (previousMessages != null) ...previousMessages,
        {
          'role': 'user',
          'content': message,
        },
      ];

      final requestBody = {
        'model': model ?? _defaultModel,
        'messages': messages,
        'temperature': temperature ?? _defaultTemperature,
        'max_tokens': maxTokens ?? _defaultMaxTokens,
        'stream': false,
      };

      // Enforce thinking pattern if requested
      if (enforceThinking) {
        requestBody['response_format'] = {
          'type': 'text',
          'prefix': '<think>\n',
        };
      }

      final response = await httpClient!.post(
        Uri.parse('$_baseUrl/chat/completions'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $apiKey',
        },
        body: jsonEncode(requestBody),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return DeepSeekResponse.fromJson(data);
      } else {
        throw DeepSeekException(
          'API request failed with status ${response.statusCode}: ${response.body}',
          statusCode: response.statusCode,
        );
      }
    } catch (e) {
      if (e is DeepSeekException) rethrow;
      throw DeepSeekException('Network error: $e');
    }
  }

  /// Send a reasoning request with specific formatting for math problems
  Future<DeepSeekResponse> solveMathProblem({
    required String problem,
    String? model,
  }) async {
    final formattedMessage = '''
Please reason step by step, and put your final answer within \\boxed{}.

Problem: $problem
''';

    return sendChatCompletion(
      message: formattedMessage,
      model: model,
      enforceThinking: true,
    );
  }

  /// Send a code generation request
  Future<DeepSeekResponse> generateCode({
    required String prompt,
    String? language,
    String? model,
  }) async {
    final formattedMessage = '''
${language != null ? 'Generate $language code for the following:' : 'Generate code for the following:'}

$prompt

Please provide clean, well-commented code with explanations.
''';

    return sendChatCompletion(
      message: formattedMessage,
      model: model,
      enforceThinking: true,
    );
  }

  /// Analyze data or documents
  Future<DeepSeekResponse> analyzeContent({
    required String content,
    required String question,
    String? fileName,
    String? model,
  }) async {
    String formattedMessage;

    if (fileName != null) {
      // Use the official file template format
      formattedMessage = '''
[file name]: $fileName
[file content begin]
$content
[file content end]
$question
''';
    } else {
      formattedMessage = '''
Content to analyze:
$content

Question: $question
''';
    }

    return sendChatCompletion(
      message: formattedMessage,
      model: model,
      enforceThinking: true,
    );
  }

  /// Specialized method for legal document analysis
  Future<DeepSeekResponse> analyzeLegalDocument({
    required String documentContent,
    required String query,
    String? documentType,
    String? jurisdiction,
  }) async {
    final formattedMessage = '''
Analyze the following legal document and answer the query.
${documentType != null ? 'Document Type: $documentType' : ''}
${jurisdiction != null ? 'Jurisdiction: $jurisdiction' : ''}

[Document Content Begin]
$documentContent
[Document Content End]

Query: $query

Please provide a detailed legal analysis with relevant citations and reasoning.
''';

    return sendChatCompletion(
      message: formattedMessage,
      enforceThinking: true,
    );
  }

  /// Perform legal reasoning based on Mexican law
  Future<DeepSeekResponse> performLegalReasoning({
    required String question,
    String? relevantLaws,
    String? caseContext,
  }) async {
    final formattedMessage = '''
Please analyze the following legal question according to Mexican law. 
Provide step-by-step reasoning and cite relevant legal provisions.

Question: $question

${relevantLaws != null ? 'Relevant Laws:\n$relevantLaws\n' : ''}
${caseContext != null ? 'Case Context:\n$caseContext\n' : ''}

Structure your response as follows:
1. Legal Issue Identification
2. Applicable Law
3. Legal Analysis
4. Conclusion
''';

    return sendChatCompletion(
      message: formattedMessage,
      enforceThinking: true,
    );
  }

  /// Get available models
  Future<List<DeepSeekModel>> getAvailableModels() async {
    try {
      final response = await httpClient!.get(
        Uri.parse('$_baseUrl/models'),
        headers: {
          'Authorization': 'Bearer $apiKey',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final models = (data['data'] as List)
            .map((model) => DeepSeekModel.fromJson(model))
            .toList();
        return models;
      } else {
        throw DeepSeekException(
          'Failed to fetch models: ${response.body}',
          statusCode: response.statusCode,
        );
      }
    } catch (e) {
      if (e is DeepSeekException) rethrow;
      throw DeepSeekException('Failed to fetch models: $e');
    }
  }

  /// Check API health status
  Future<bool> checkHealth() async {
    try {
      final models = await getAvailableModels();
      return models.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  /// Clean up resources
  void dispose() {
    httpClient?.close();
  }
}

/// Response model for DeepSeek API
class DeepSeekResponse {
  final String id;
  final String object;
  final int created;
  final String model;
  final List<Choice> choices;
  final Usage usage;

  DeepSeekResponse({
    required this.id,
    required this.object,
    required this.created,
    required this.model,
    required this.choices,
    required this.usage,
  });

  factory DeepSeekResponse.fromJson(Map<String, dynamic> json) {
    return DeepSeekResponse(
      id: json['id'],
      object: json['object'],
      created: json['created'],
      model: json['model'],
      choices: (json['choices'] as List)
          .map((choice) => Choice.fromJson(choice))
          .toList(),
      usage: Usage.fromJson(json['usage']),
    );
  }

  String get content => choices.isNotEmpty ? choices.first.message.content : '';

  /// Extract content without thinking tags if present
  String get contentWithoutThinking {
    final content = this.content;
    final thinkPattern = RegExp(r'<think>.*?</think>', dotAll: true);
    return content.replaceAll(thinkPattern, '').trim();
  }

  /// Extract only the thinking portion if present
  String? get thinkingContent {
    final content = this.content;
    final thinkPattern = RegExp(r'<think>(.*?)</think>', dotAll: true);
    final match = thinkPattern.firstMatch(content);
    return match?.group(1)?.trim();
  }

  /// Extract boxed answer for math problems
  String? get boxedAnswer {
    final content = this.content;
    final boxPattern = RegExp(r'\\boxed\{([^}]+)\}');
    final match = boxPattern.firstMatch(content);
    return match?.group(1);
  }

  /// Convert to simple map for easy access
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'object': object,
      'created': created,
      'model': model,
      'content': content,
      'usage': {
        'prompt_tokens': usage.promptTokens,
        'completion_tokens': usage.completionTokens,
        'total_tokens': usage.totalTokens,
      },
    };
  }
}

/// Choice model for API responses
class Choice {
  final int index;
  final Message message;
  final String finishReason;

  Choice({
    required this.index,
    required this.message,
    required this.finishReason,
  });

  factory Choice.fromJson(Map<String, dynamic> json) {
    return Choice(
      index: json['index'],
      message: Message.fromJson(json['message']),
      finishReason: json['finish_reason'] ?? '',
    );
  }
}

/// Message model
class Message {
  final String role;
  final String content;

  Message({
    required this.role,
    required this.content,
  });

  factory Message.fromJson(Map<String, dynamic> json) {
    return Message(
      role: json['role'],
      content: json['content'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'role': role,
      'content': content,
    };
  }
}

/// Usage statistics model
class Usage {
  final int promptTokens;
  final int completionTokens;
  final int totalTokens;

  Usage({
    required this.promptTokens,
    required this.completionTokens,
    required this.totalTokens,
  });

  factory Usage.fromJson(Map<String, dynamic> json) {
    return Usage(
      promptTokens: json['prompt_tokens'],
      completionTokens: json['completion_tokens'],
      totalTokens: json['total_tokens'],
    );
  }

  /// Calculate approximate cost (example rates, adjust based on actual pricing)
  double calculateCost({
    double promptTokenRate = 0.001, // per 1K tokens
    double completionTokenRate = 0.002, // per 1K tokens
  }) {
    return (promptTokens / 1000 * promptTokenRate) +
        (completionTokens / 1000 * completionTokenRate);
  }
}

/// Model information
class DeepSeekModel {
  final String id;
  final String object;
  final int created;
  final String ownedBy;

  DeepSeekModel({
    required this.id,
    required this.object,
    required this.created,
    required this.ownedBy,
  });

  factory DeepSeekModel.fromJson(Map<String, dynamic> json) {
    return DeepSeekModel(
      id: json['id'],
      object: json['object'],
      created: json['created'],
      ownedBy: json['owned_by'],
    );
  }

  bool get isReasoningModel => id.contains('reasoner');
  bool get isDistillModel => id.contains('distill');
}

/// Custom exception for DeepSeek API errors
class DeepSeekException implements Exception {
  final String message;
  final int? statusCode;

  DeepSeekException(this.message, {this.statusCode});

  @override
  String toString() => 'DeepSeekException: $message';

  bool get isAuthError => statusCode == 401;
  bool get isRateLimitError => statusCode == 429;
  bool get isServerError => statusCode != null && statusCode! >= 500;
}

/// Configuration class for DeepSeek API
class DeepSeekConfig {
  final String apiKey;
  final String model;
  final double temperature;
  final int maxTokens;
  final bool enforceThinking;

  const DeepSeekConfig({
    required this.apiKey,
    this.model = DeepSeekDatasource._defaultModel,
    this.temperature = DeepSeekDatasource._defaultTemperature,
    this.maxTokens = DeepSeekDatasource._defaultMaxTokens,
    this.enforceThinking = false,
  });

  /// Create config from environment variables
  factory DeepSeekConfig.fromEnvironment() {
    return DeepSeekConfig(
      apiKey: const String.fromEnvironment('DEEPSEEK_API_KEY'),
      model: const String.fromEnvironment(
        'DEEPSEEK_MODEL',
        defaultValue: DeepSeekDatasource._defaultModel,
      ),
      temperature: double.parse(
        const String.fromEnvironment(
          'DEEPSEEK_TEMPERATURE',
          defaultValue: '0.6',
        ),
      ),
      maxTokens: int.parse(
        const String.fromEnvironment(
          'DEEPSEEK_MAX_TOKENS',
          defaultValue: '32768',
        ),
      ),
      enforceThinking: const bool.fromEnvironment(
        'DEEPSEEK_ENFORCE_THINKING',
        defaultValue: false,
      ),
    );
  }
}
