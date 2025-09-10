import 'package:flutter/material.dart';
import 'dart:developer'; // For logging errors.

import '../../../../core/constants/app_colors.dart';
import '../../../../core/config/env_config.dart';
import '../../../../data/datasources/remote/openrouter_openai_datasource.dart';
import '../../../../data/datasources/remote/openrouter_datasource.dart';
import 'package:dio/dio.dart';
import '../../../../injection_container.dart';
import 'widgets/ai_response_message.dart';
import 'widgets/message_input.dart';
import 'widgets/user_message_bubble.dart';

// The ChatMessage class is updated to hold both structured data for the UI
// and the raw response string for conversation history.
class ChatMessage {
  final String? text;
  final AIResponseData? responseData;
  final String? rawResponseForHistory; // Field to store raw text for history
  final bool isUser;
  final DateTime timestamp;
  final bool isError;

  ChatMessage({
    this.text,
    this.responseData,
    this.rawResponseForHistory,
    required this.isUser,
    required this.timestamp,
    this.isError = false,
  }) : assert(isUser ? text != null : responseData != null || isError);
}

class LegalChatScreen extends StatefulWidget {
  const LegalChatScreen({super.key});

  @override
  State<LegalChatScreen> createState() => _LegalChatScreenState();
}

class _LegalChatScreenState extends State<LegalChatScreen> {
  // Removed unused _legalRagService and only keep the datasource.
  late final OpenRouterOpenAIDatasource _openRouterDatasource;
  late final OpenRouterDatasource _openRouterDatasourceFallback; // Dio-based fallback
  String _currentStreamingMessage = '';
  bool _isStreaming = false;
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<ChatMessage> _messages = [];
  bool _isLoading = false;
  
  // Model selection - you can switch between different models
  // Options: 'qwen/qwen3-235b-a22b-thinking-2507' (powerful reasoning)
  //          'anthropic/claude-3.5-sonnet' (fast and high quality)
  //          'openai/gpt-4-turbo-preview' (fast and reliable)
  //          'meta-llama/llama-3.1-70b-instruct' (fast open source)
  final String _selectedModel = 'qwen/qwen3-235b-a22b-thinking-2507';

  @override
  void initState() {
    super.initState();
    // Get API key from environment configuration
    try {
      // Hardcoded for immediate testing
      final apiKey = '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';
      // Use the OpenAI Dart library for proper streaming support
      _openRouterDatasource = OpenRouterOpenAIDatasource(
        apiKey: apiKey,
      );
      _initializeChat();
    } catch (e) {
      log('Failed to initialize OpenRouter: $e');
      // Show error to user
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Error: API configuration not found. Please check settings.'),
              backgroundColor: Colors.red,
            ),
          );
        }
      });
    }
  }

  // Initializes the chat with a welcome message from the AI.
  void _initializeChat() {
    const initialRawContent =
        'Hola, soy tu asistente legal especializado en derecho mexicano. Puedo ayudarte con consultas sobre el Código Civil, jurisprudencia de la SCJN, doctrina y mi biblioteca jurídica.\n\n¿En qué puedo asistirte hoy?';

    final initialResponse = AIResponseData(
      confidence: 0.95,
      sections: [
        ResponseSection(
          title: 'Bienvenido',
          paragraphs: [
            'Hola, soy tu asistente legal especializado en derecho mexicano. Puedo ayudarte con consultas sobre el Código Civil, jurisprudencia de la SCJN, doctrina y mi biblioteca jurídica.'
          ],
        ),
        ResponseSection(title: '¿En qué puedo asistirte hoy?', paragraphs: []),
      ],
      sources: [],
    );

    _messages.add(
      ChatMessage(
        responseData: initialResponse,
        rawResponseForHistory:
            initialRawContent, // Store raw content for history
        isUser: false,
        timestamp: DateTime.now(),
      ),
    );
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    // OpenRouterDatasource doesn't need disposal
    super.dispose();
  }

  // Helper function to parse the structured response from the LLM
  AIResponseData _parseLlmResponse(String content) {
    final sections = <ResponseSection>[];
    // Split the content by the numbered headings (e.g., "1. Legal Issue")
    final parts = content.split(RegExp(r'\n\d+\.\s+'));

    if (parts.length > 1) {
      // The first part before "1." is often an introduction.
      if (parts[0].trim().isNotEmpty) {
        sections.add(
            ResponseSection(title: "Resumen", paragraphs: [parts[0].trim()]));
      }
      // Process the numbered sections
      for (int i = 1; i < parts.length; i++) {
        final sectionContent = parts[i];
        final lines = sectionContent.split('\n');
        final title = lines.first.trim();
        final paragraphs =
            lines.skip(1).where((line) => line.trim().isNotEmpty).toList();
        sections.add(ResponseSection(title: title, paragraphs: paragraphs));
      }
    } else {
      // If no numbered list is found, treat the whole content as one section.
      sections.add(
          ResponseSection(title: "Respuesta", paragraphs: [content.trim()]));
    }

    return AIResponseData(
      confidence:
          0.9, // Confidence is not provided by the API, so we use a default.
      sections: sections,
      sources: [
        LegalSource(
            title: 'Lista de fuentes',
            icon: Icons.smart_toy,
            type: 'IA Generativa')
      ],
    );
  }

  Future<void> _sendMessage() async {
    final messageText = _messageController.text.trim();
    if (messageText.isEmpty) return;

    setState(() {
      _messages.add(ChatMessage(
        text: messageText,
        isUser: true,
        timestamp: DateTime.now(),
      ));
      _messageController.clear();
      _isLoading = true;
    });

    _scrollToBottom();

    try {
      // --- LIVE API CALL ---
      // Build conversation history for context
      // With 256k context window and 100k max output, we have ~156k for history
      final history = _messages
          .where((m) => !m.isError) // Don't include previous errors in history
          .map((m) => {
                'role': m.isUser ? 'user' : 'assistant',
                'content': m.isUser
                    ? m.text
                    : m.rawResponseForHistory, // Use the correct field
              })
          .where((m) => m['content'] != null)
          .toList();

      // Remove the last message (the one we just added) to avoid duplication
      if (history.isNotEmpty) {
        history.removeLast();
      }

      // Manually construct the prompt that was in `performLegalReasoning`
      final legalPrompt = '''
      Please analyze the following legal question according to Mexican law. 
      Provide step-by-step reasoning and cite relevant legal provisions.

      Question: $messageText

      Structure your response as follows:
      1. Legal Issue Identification
      2. Applicable Law
      3. Legal Analysis
      4. Conclusion
      ''';

      // Initialize streaming message
      setState(() {
        _isStreaming = true;
        _currentStreamingMessage = '';
        // Add a placeholder message that will be updated as content streams in
        _messages.add(ChatMessage(
          responseData: AIResponseData(
            confidence: 0.95,
            sections: [
              ResponseSection(
                title: 'Procesando...',
                paragraphs: [''],
              ),
            ],
            sources: [],
          ),
          rawResponseForHistory: '',
          isUser: false,
          timestamp: DateTime.now(),
        ));
      });

      // Collect the full response
      final fullResponse = StringBuffer();
      
      // Use real streaming from the openai_dart library
      try {
        await for (final chunk in _openRouterDatasource.sendChatCompletionStream(
          message: legalPrompt,
          model: _selectedModel,  // Use the selected model
          previousMessages: history,
          temperature: 0.7,
          maxTokens: 100000,
        )) {
          fullResponse.write(chunk);
          
          // Update the streaming message in real-time
          setState(() {
            _currentStreamingMessage = fullResponse.toString();
            // Update the last message with the current content
            if (_messages.isNotEmpty && !_messages.last.isUser) {
              final updatedResponse = _parseLlmResponse(_currentStreamingMessage);
              _messages[_messages.length - 1] = ChatMessage(
                responseData: updatedResponse,
                rawResponseForHistory: _currentStreamingMessage,
                isUser: false,
                timestamp: _messages.last.timestamp,
              );
            }
          });
          
          // Auto-scroll as content arrives
          _scrollToBottom();
        }
      } catch (streamError) {
        // If streaming fails (e.g., CORS), fall back to non-streaming
        log('Streaming failed, falling back to non-streaming: $streamError');
        
        final response = await _openRouterDatasource.sendChatCompletion(
          message: legalPrompt,
          model: _selectedModel,
          previousMessages: history,
          temperature: 0.7,
          maxTokens: 100000,
        );
        
        fullResponse.write(response);
        
        // Simulate streaming for better UX
        final words = response.split(' ');
        for (int i = 0; i < words.length; i++) {
          await Future.delayed(Duration(milliseconds: 20));
          
          setState(() {
            _currentStreamingMessage = words.take(i + 1).join(' ');
            if (_messages.isNotEmpty && !_messages.last.isUser) {
              final updatedResponse = _parseLlmResponse(_currentStreamingMessage);
              _messages[_messages.length - 1] = ChatMessage(
                responseData: updatedResponse,
                rawResponseForHistory: _currentStreamingMessage,
                isUser: false,
                timestamp: _messages.last.timestamp,
              );
            }
          });
          
          if (i % 10 == 0) _scrollToBottom();
        }
      }

      // Final update with complete response
      final finalContent = fullResponse.toString();
      print('===== STREAMING COMPLETE =====');
      print('Total length: ${finalContent.length}');
      
      final structuredResponse = _parseLlmResponse(finalContent);
      
      setState(() {
        _isStreaming = false;
        // Update the last message with the final parsed response
        if (_messages.isNotEmpty && !_messages.last.isUser) {
          _messages[_messages.length - 1] = ChatMessage(
            responseData: structuredResponse,
            rawResponseForHistory: finalContent,
            isUser: false,
            timestamp: _messages.last.timestamp,
          );
        }
      });
    } catch (e) {
      log('API Error: $e'); // Log the full error for debugging
      final errorResponse = AIResponseData(
        confidence: 0,
        sections: [
          ResponseSection(title: 'Error de Comunicación', paragraphs: [
            'No se pudo obtener una respuesta del servicio legal.',
            'Detalles: ${e.toString()}'
          ])
        ],
        sources: [],
      );
      setState(() {
        _messages.add(ChatMessage(
          responseData: errorResponse,
          rawResponseForHistory:
              'Lo siento, ocurrió un error al procesar tu consulta. Por favor, intenta nuevamente.',
          isUser: false,
          timestamp: DateTime.now(),
          isError: true,
        ));
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
      _scrollToBottom();
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _clearHistory() {
    setState(() {
      _messages.clear();
      _initializeChat();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundGray,
      appBar: AppBar(
        backgroundColor: AppColors.primaryBlue,
        elevation: 0,
        title: const Text('Legal RAG México',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'history') _showHistoryDialog();
              if (value == 'new_chat') _showNewChatDialog();
              if (value == 'settings') _showSettingsDialog();
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                  value: 'history',
                  child: Row(children: [
                    Icon(Icons.history, size: 20),
                    SizedBox(width: 8),
                    Text('Historial de consultas')
                  ])),
              const PopupMenuItem(
                  value: 'new_chat',
                  child: Row(children: [
                    Icon(Icons.add_comment, size: 20),
                    SizedBox(width: 8),
                    Text('Nueva conversación')
                  ])),
              const PopupMenuItem(
                  value: 'settings',
                  child: Row(children: [
                    Icon(Icons.settings, size: 20),
                    SizedBox(width: 8),
                    Text('Configuración')
                  ])),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              // The item count is increased by 1 when loading to show the indicator.
              itemCount: _messages.length + (_isLoading ? 1 : 0),
              itemBuilder: (context, index) {
                // If this is the last item and we are loading, show the typing indicator.
                if (_isLoading && index == _messages.length) {
                  return _buildTypingIndicator();
                }
                final message = _messages[index];
                if (message.isUser) {
                  return UserMessageBubble(message: message.text!);
                } else {
                  return AIResponseMessage(
                    response: message.responseData!,
                    timestamp: message.timestamp,
                  );
                }
              },
            ),
          ),
          _buildInputArea(),
        ],
      ),
    );
  }

  Widget _buildInputArea() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
              child: _buildQuickActions(),
            ),
            MessageInput(
              controller: _messageController,
              onSend: (_) => _sendMessage(),
              isLoading: _isLoading,
            ),
          ],
        ),
      ),
    );
  }

  // New private method to build the typing indicator bubble.
  Widget _buildTypingIndicator() {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8.0),
        padding: const EdgeInsets.symmetric(vertical: 15.0, horizontal: 20.0),
        decoration: BoxDecoration(
          color: AppColors.backgroundGray,
          borderRadius: BorderRadius.circular(20.0),
        ),
        child: const TypingIndicator(),
      ),
    );
  }

  Widget _buildQuickActions() {
    final quickActions = [
      'Responsabilidad Civil',
      'Contratos',
      'Obligaciones',
      'Derecho Familiar',
    ];
    return SizedBox(
      height: 36,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: quickActions.length,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        itemBuilder: (context, index) {
          final action = quickActions[index];
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ActionChip(
              label: Text(action),
              onPressed: _isLoading
                  ? null
                  : () {
                      _messageController.text =
                          'Explícame sobre $action en el derecho mexicano';
                      _sendMessage();
                    },
              backgroundColor: AppColors.backgroundGray,
              labelStyle:
                  const TextStyle(color: AppColors.textPrimary, fontSize: 12),
            ),
          );
        },
      ),
    );
  }

  void _showHistoryDialog() {
    showDialog(
        context: context,
        builder: (context) => AlertDialog(
              title: const Text('Historial de consultas'),
              content: const Text(
                  'Aquí podrás ver tu historial de consultas anteriores. Esta función estará disponible próximamente.'),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cerrar'))
              ],
            ));
  }

  void _showNewChatDialog() {
    showDialog(
        context: context,
        builder: (context) => AlertDialog(
              title: const Text('Nueva conversación'),
              content: const Text(
                  '¿Deseas iniciar una nueva conversación? Esto borrará el historial actual.'),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancelar')),
                TextButton(
                    onPressed: () {
                      Navigator.pop(context);
                      _clearHistory();
                    },
                    child: const Text('Confirmar')),
              ],
            ));
  }

  void _showSettingsDialog() {
    showDialog(
        context: context,
        builder: (context) => AlertDialog(
              title: const Text('Configuración'),
              content: const Text(
                  'Aquí podrás configurar las preferencias de la aplicación. Esta función estará disponible próximamente.'),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cerrar'))
              ],
            ));
  }
}

/// A widget that displays an animated "typing" indicator.
class TypingIndicator extends StatefulWidget {
  const TypingIndicator({super.key});

  @override
  State<TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<TypingIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 50,
      height: 20,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: List.generate(3, (index) {
          return FadeTransition(
            opacity: DelayTween(begin: 0.2, end: 1.0, delay: 0.3 * index)
                .animate(_controller),
            child: const CircleAvatar(
              radius: 4.5,
              backgroundColor: AppColors.textSecondary,
            ),
          );
        }),
      ),
    );
  }
}

/// A custom Tween for creating delayed animations in a sequence.
class DelayTween extends Tween<double> {
  final double delay;

  DelayTween({required double begin, required double end, required this.delay})
      : super(begin: begin, end: end);

  @override
  double lerp(double t) {
    // This clamps the animation to start only after the delay.
    return super.lerp((t - delay).clamp(0.0, 1.0));
  }
}
