import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'dart:math' as math;
import 'package:logger/logger.dart';
import '../../../data/datasources/remote/openrouter_openai_datasource.dart';
import '../../providers/auth_provider.dart';

class ProductionChatScreen extends StatefulWidget {
  const ProductionChatScreen({super.key});

  @override
  State<ProductionChatScreen> createState() => _ProductionChatScreenState();
}

class _ProductionChatScreenState extends State<ProductionChatScreen> {
  late final OpenRouterOpenAIDatasource _openRouterDatasource;
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _messageFocusNode = FocusNode();
  final List<ChatMessage> _messages = [];
  final Logger _logger = Logger();
  
  bool _isLoading = false;
  String _currentStreamingMessage = '';
  String? _editingMessageId;
  
  // Search functionality
  final TextEditingController _searchController = TextEditingController();
  bool _isSearching = false;
  List<int> _searchResults = [];
  int _currentSearchIndex = 0;

  @override
  void initState() {
    super.initState();
    const apiKey = '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';
    _openRouterDatasource = OpenRouterOpenAIDatasource(apiKey: apiKey);
    _loadChatHistory();
  }

  void _loadChatHistory() {
    // Load from local storage or show welcome message
    if (_messages.isEmpty) {
      _messages.add(
        ChatMessage(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          content: 'Bienvenido al asistente legal. ¿En qué puedo ayudarte hoy?',
          isUser: false,
          timestamp: DateTime.now(),
        ),
      );
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _messageFocusNode.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _sendMessage([String? customMessage]) async {
    final messageText = customMessage ?? _messageController.text.trim();
    if (messageText.isEmpty) return;

    final userMessage = ChatMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      content: messageText,
      isUser: true,
      timestamp: DateTime.now(),
    );

    setState(() {
      _messages.add(userMessage);
      if (customMessage == null) _messageController.clear();
      _isLoading = true;
    });

    _scrollToBottom();

    try {
      final aiMessage = ChatMessage(
        id: '${DateTime.now().millisecondsSinceEpoch}_ai',
        content: '',
        isUser: false,
        timestamp: DateTime.now(),
      );
      
      setState(() {
        _messages.add(aiMessage);
      });

      final history = _messages
          .where((m) => m.content.isNotEmpty)
          .take(_messages.length - 1) // Exclude the empty AI message
          .map((m) => {
                'role': m.isUser ? 'user' : 'assistant',
                'content': m.content,
              })
          .toList();

      final fullResponse = StringBuffer();
      
      await for (final chunk in _openRouterDatasource.sendChatCompletionStream(
        message: messageText,
        model: 'qwen/qwen3-235b-a22b-thinking-2507',
        previousMessages: history,
        temperature: 0.3,
        maxTokens: 64000,
      )) {
        fullResponse.write(chunk);
        
        setState(() {
          _messages[_messages.length - 1] = ChatMessage(
            id: aiMessage.id,
            content: fullResponse.toString(),
            isUser: false,
            timestamp: aiMessage.timestamp,
          );
        });
        
        _scrollToBottom();
      }

    } catch (e) {
      _logger.e('Error: $e');
      setState(() {
        _messages.add(
          ChatMessage(
            id: '${DateTime.now().millisecondsSinceEpoch}_error',
            content: 'Error al procesar tu mensaje. Por favor, intenta de nuevo.',
            isUser: false,
            timestamp: DateTime.now(),
            isError: true,
          ),
        );
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _copyMessage(String content) {
    Clipboard.setData(ClipboardData(text: content));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Mensaje copiado'),
        duration: Duration(seconds: 1),
      ),
    );
  }

  void _regenerateMessage(int index) {
    if (index > 0 && _messages[index - 1].isUser) {
      final userMessage = _messages[index - 1].content;
      setState(() {
        _messages.removeAt(index); // Remove AI response
      });
      _sendMessage(userMessage);
    }
  }

  void _editMessage(ChatMessage message) {
    setState(() {
      _editingMessageId = message.id;
      _messageController.text = message.content;
      _messageFocusNode.requestFocus();
    });
  }

  void _deleteMessage(int index) {
    setState(() {
      _messages.removeAt(index);
      // If we deleted a user message, also delete the following AI response
      if (index < _messages.length && _messages[index].isUser == false) {
        _messages.removeAt(index);
      }
    });
  }

  void _clearChat() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Limpiar conversación'),
        content: const Text('¿Estás seguro de que quieres eliminar todos los mensajes?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () {
              setState(() {
                _messages.clear();
                _loadChatHistory();
              });
              Navigator.pop(context);
            },
            child: const Text('Limpiar', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _performSearch(String query) {
    if (query.isEmpty) {
      setState(() {
        _searchResults.clear();
        _currentSearchIndex = 0;
      });
      return;
    }

    final results = <int>[];
    for (int i = 0; i < _messages.length; i++) {
      if (_messages[i].content.toLowerCase().contains(query.toLowerCase())) {
        results.add(i);
      }
    }

    setState(() {
      _searchResults = results;
      _currentSearchIndex = 0;
    });

    if (_searchResults.isNotEmpty) {
      _scrollToMessage(_searchResults[0]);
    }
  }

  void _scrollToMessage(int index) {
    // Calculate position and scroll
    final position = index * 100.0; // Approximate height per message
    _scrollController.animateTo(
      math.min(position, _scrollController.position.maxScrollExtent),
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  void _nextSearchResult() {
    if (_searchResults.isNotEmpty) {
      setState(() {
        _currentSearchIndex = (_currentSearchIndex + 1) % _searchResults.length;
      });
      _scrollToMessage(_searchResults[_currentSearchIndex]);
    }
  }

  void _previousSearchResult() {
    if (_searchResults.isNotEmpty) {
      setState(() {
        _currentSearchIndex = (_currentSearchIndex - 1 + _searchResults.length) % _searchResults.length;
      });
      _scrollToMessage(_searchResults[_currentSearchIndex]);
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final authProvider = context.watch<AuthProvider>();
    
    return Scaffold(
      backgroundColor: Color(0xFFF5F7FA),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        title: _isSearching ? _buildSearchBar() : _buildAppBarTitle(),
        actions: _buildAppBarActions(),
        bottom: _isLoading ? _buildLoadingIndicator() : null,
      ),
      body: Column(
        children: [
          if (_searchResults.isNotEmpty)
            _buildSearchResultsBar(),
          Expanded(
            child: _buildMessagesList(),
          ),
          _buildInputArea(),
        ],
      ),
    );
  }

  Widget _buildAppBarTitle() {
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
            ),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(Icons.psychology, color: Colors.white, size: 22),
        ),
        const SizedBox(width: 12),
        const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Asistente Legal',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1F2937),
              ),
            ),
            Text(
              'En línea',
              style: TextStyle(
                fontSize: 12,
                color: Color(0xFF6B7280),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSearchBar() {
    return TextField(
      controller: _searchController,
      autofocus: true,
      decoration: InputDecoration(
        hintText: 'Buscar en la conversación...',
        border: InputBorder.none,
        suffixIcon: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () {
            setState(() {
              _isSearching = false;
              _searchController.clear();
              _searchResults.clear();
            });
          },
        ),
      ),
      onChanged: _performSearch,
    );
  }

  List<Widget> _buildAppBarActions() {
    if (_isSearching) {
      return [
        IconButton(
          icon: const Icon(Icons.arrow_upward),
          onPressed: _previousSearchResult,
        ),
        IconButton(
          icon: const Icon(Icons.arrow_downward),
          onPressed: _nextSearchResult,
        ),
      ];
    }
    
    return [
      IconButton(
        icon: const Icon(Icons.search, color: Color(0xFF6B7280)),
        onPressed: () {
          setState(() {
            _isSearching = true;
          });
        },
      ),
      PopupMenuButton<String>(
        icon: const Icon(Icons.more_vert, color: Color(0xFF6B7280)),
        onSelected: (value) {
          switch (value) {
            case 'clear':
              _clearChat();
              break;
            case 'export':
              _exportChat();
              break;
          }
        },
        itemBuilder: (context) => [
          const PopupMenuItem(
            value: 'clear',
            child: Row(
              children: [
                Icon(Icons.delete_outline, size: 20),
                SizedBox(width: 8),
                Text('Limpiar chat'),
              ],
            ),
          ),
          const PopupMenuItem(
            value: 'export',
            child: Row(
              children: [
                Icon(Icons.download, size: 20),
                SizedBox(width: 8),
                Text('Exportar'),
              ],
            ),
          ),
        ],
      ),
    ];
  }

  PreferredSize _buildLoadingIndicator() {
    return PreferredSize(
      preferredSize: const Size.fromHeight(2),
      child: LinearProgressIndicator(
        backgroundColor: Colors.grey[200],
        valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF6366F1)),
      ),
    );
  }

  Widget _buildSearchResultsBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: const Color(0xFFF3F4F6),
      child: Row(
        children: [
          Text(
            '${_searchResults.isEmpty ? 0 : _currentSearchIndex + 1} de ${_searchResults.length} resultados',
            style: const TextStyle(fontSize: 14, color: Color(0xFF6B7280)),
          ),
          const Spacer(),
          TextButton(
            onPressed: () {
              setState(() {
                _searchResults.clear();
                _searchController.clear();
              });
            },
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  Widget _buildMessagesList() {
    if (_messages.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.chat_bubble_outline, size: 64, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text(
              'No hay mensajes',
              style: TextStyle(color: Colors.grey[500], fontSize: 16),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(vertical: 16),
      itemCount: _messages.length,
      itemBuilder: (context, index) {
        final message = _messages[index];
        final isHighlighted = _searchResults.contains(index);
        
        return _buildMessage(message, index, isHighlighted);
      },
    );
  }

  Widget _buildMessage(ChatMessage message, int index, bool isHighlighted) {
    final isUser = message.isUser;
    
    return Container(
      color: isHighlighted ? Colors.yellow.withValues(alpha: 0.2) : null,
      padding: EdgeInsets.only(
        left: isUser ? 48 : 16,
        right: isUser ? 16 : 48,
        top: 8,
        bottom: 8,
      ),
      child: Row(
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isUser) _buildAvatar(false),
          const SizedBox(width: 8),
          Flexible(
            child: GestureDetector(
              onLongPress: () => _showMessageOptions(message, index),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isUser ? const Color(0xFF6366F1) : Colors.white,
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(16),
                    topRight: const Radius.circular(16),
                    bottomLeft: Radius.circular(isUser ? 16 : 4),
                    bottomRight: Radius.circular(isUser ? 4 : 16),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SelectableText(
                      message.content,
                      style: TextStyle(
                        color: isUser ? Colors.white : const Color(0xFF1F2937),
                        fontSize: 15,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _formatTime(message.timestamp),
                      style: TextStyle(
                        color: isUser ? Colors.white70 : const Color(0xFF9CA3AF),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          if (isUser) _buildAvatar(true),
        ],
      ),
    );
  }

  Widget _buildAvatar(bool isUser) {
    if (isUser) {
      return CircleAvatar(
        radius: 16,
        backgroundColor: const Color(0xFFE5E7EB),
        child: const Icon(Icons.person, size: 18, color: Color(0xFF6B7280)),
      );
    } else {
      return Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Icon(Icons.psychology, color: Colors.white, size: 18),
      );
    }
  }

  Widget _buildInputArea() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFF3F4F6),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: TextField(
                  controller: _messageController,
                  focusNode: _messageFocusNode,
                  maxLines: null,
                  keyboardType: TextInputType.multiline,
                  enabled: !_isLoading,
                  decoration: const InputDecoration(
                    hintText: 'Escribe tu consulta...',
                    hintStyle: TextStyle(color: Color(0xFF9CA3AF)),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  ),
                  onSubmitted: (_) => _sendMessage(),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: _isLoading
                      ? [Colors.grey[400]!, Colors.grey[500]!]
                      : [const Color(0xFF6366F1), const Color(0xFF8B5CF6)],
                ),
                shape: BoxShape.circle,
              ),
              child: IconButton(
                icon: Icon(
                  _isLoading ? Icons.stop : Icons.send,
                  color: Colors.white,
                  size: 20,
                ),
                onPressed: _isLoading ? null : _sendMessage,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showMessageOptions(ChatMessage message, int index) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.copy),
              title: const Text('Copiar'),
              onTap: () {
                _copyMessage(message.content);
                Navigator.pop(context);
              },
            ),
            if (!message.isUser)
              ListTile(
                leading: const Icon(Icons.refresh),
                title: const Text('Regenerar'),
                onTap: () {
                  Navigator.pop(context);
                  _regenerateMessage(index);
                },
              ),
            if (message.isUser)
              ListTile(
                leading: const Icon(Icons.edit),
                title: const Text('Editar y reenviar'),
                onTap: () {
                  Navigator.pop(context);
                  _editMessage(message);
                },
              ),
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: const Text('Eliminar', style: TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.pop(context);
                _deleteMessage(index);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _exportChat() {
    final buffer = StringBuffer();
    for (final message in _messages) {
      final sender = message.isUser ? 'Usuario' : 'Asistente';
      final time = _formatTime(message.timestamp);
      buffer.writeln('[$time] $sender: ${message.content}\n');
    }
    
    Clipboard.setData(ClipboardData(text: buffer.toString()));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Conversación copiada al portapapeles'),
      ),
    );
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final difference = now.difference(time);
    
    if (difference.inMinutes < 1) {
      return 'Ahora';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes}m';
    } else if (difference.inDays < 1) {
      return '${time.hour}:${time.minute.toString().padLeft(2, '0')}';
    } else {
      return '${time.day}/${time.month}';
    }
  }
}

class ChatMessage {
  final String id;
  final String content;
  final bool isUser;
  final DateTime timestamp;
  final bool isError;

  ChatMessage({
    required this.id,
    required this.content,
    required this.isUser,
    required this.timestamp,
    this.isError = false,
  });
}