import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:math' as math;
import 'package:logger/logger.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/responsive_helper.dart';
import '../../../data/datasources/remote/openrouter_openai_datasource.dart';
import '../../widgets/ui_components/custom_button.dart';
import '../../widgets/ui_components/custom_card.dart';
import '../../widgets/ui_components/loading_indicators.dart';

class ModernLegalChatScreen extends StatefulWidget {
  const ModernLegalChatScreen({super.key});

  @override
  State<ModernLegalChatScreen> createState() => _ModernLegalChatScreenState();
}

class _ModernLegalChatScreenState extends State<ModernLegalChatScreen>
    with TickerProviderStateMixin {
  late final OpenRouterOpenAIDatasource _openRouterDatasource;
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _messageFocusNode = FocusNode();
  final List<ChatMessage> _messages = [];
  
  bool _isLoading = false;
  bool _isSidebarOpen = false;
  bool _isTyping = false;
  String _currentStreamingMessage = '';
  
  late AnimationController _sidebarAnimationController;
  late Animation<Offset> _sidebarAnimation;
  
  final Logger _logger = Logger();

  @override
  void initState() {
    super.initState();
    
    _sidebarAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    
    _sidebarAnimation = Tween<Offset>(
      begin: const Offset(-1, 0),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _sidebarAnimationController,
      curve: Curves.easeOutCubic,
    ));
    
    // Initialize with API key
    const apiKey = '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';
    _openRouterDatasource = OpenRouterOpenAIDatasource(apiKey: apiKey);
    
    _initializeChat();
  }

  void _initializeChat() {
    _messages.add(
      ChatMessage(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        content: '¡Hola! Soy tu asistente legal especializado en derecho mexicano. ¿En qué puedo ayudarte hoy?',
        isUser: false,
        timestamp: DateTime.now(),
        status: MessageStatus.delivered,
      ),
    );
  }

  @override
  void dispose() {
    _sidebarAnimationController.dispose();
    _messageController.dispose();
    _scrollController.dispose();
    _messageFocusNode.dispose();
    super.dispose();
  }

  void _toggleSidebar() {
    setState(() {
      _isSidebarOpen = !_isSidebarOpen;
      if (_isSidebarOpen) {
        _sidebarAnimationController.forward();
      } else {
        _sidebarAnimationController.reverse();
      }
    });
  }

  Future<void> _sendMessage() async {
    final messageText = _messageController.text.trim();
    if (messageText.isEmpty) return;

    final userMessage = ChatMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      content: messageText,
      isUser: true,
      timestamp: DateTime.now(),
      status: MessageStatus.sending,
    );

    setState(() {
      _messages.add(userMessage);
      _messageController.clear();
      _isLoading = true;
      _isTyping = true;
    });

    _scrollToBottom();

    try {
      // Create AI response message placeholder
      final aiMessage = ChatMessage(
        id: '${DateTime.now().millisecondsSinceEpoch}_ai',
        content: '',
        isUser: false,
        timestamp: DateTime.now(),
        status: MessageStatus.sending,
      );
      
      setState(() {
        _messages.add(aiMessage);
      });

      // Build conversation history
      final history = _messages
          .where((m) => m.status == MessageStatus.delivered && m.content.isNotEmpty)
          .map((m) => {
                'role': m.isUser ? 'user' : 'assistant',
                'content': m.content,
              })
          .toList();

      final prompt = '''
      Eres un experto en derecho mexicano. Responde de manera profesional y detallada.
      
      Pregunta: $messageText
      
      Proporciona una respuesta estructurada con:
      1. Análisis legal
      2. Fundamentos jurídicos aplicables
      3. Conclusión práctica
      ''';

      // Stream the response
      final fullResponse = StringBuffer();
      
      await for (final chunk in _openRouterDatasource.sendChatCompletionStream(
        message: prompt,
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
            status: MessageStatus.delivered,
          );
        });
        
        _scrollToBottom();
      }

      // Update message statuses
      setState(() {
        // Update user message status
        final userIndex = _messages.indexWhere((m) => m.id == userMessage.id);
        if (userIndex != -1) {
          _messages[userIndex] = userMessage.copyWith(status: MessageStatus.delivered);
        }
        _isTyping = false;
      });

    } catch (e) {
      _logger.e('Error sending message: $e');
      
      setState(() {
        _messages.add(
          ChatMessage(
            id: '${DateTime.now().millisecondsSinceEpoch}_error',
            content: 'Lo siento, hubo un error al procesar tu mensaje. Por favor, intenta de nuevo.',
            isUser: false,
            timestamp: DateTime.now(),
            status: MessageStatus.error,
          ),
        );
        _isTyping = false;
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final size = MediaQuery.of(context).size;
    final isDesktop = ResponsiveHelper.isDesktop(context);
    
    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: Stack(
        children: [
          // Main Chat Area
          Row(
            children: [
              // Sidebar space (when open on desktop)
              if (isDesktop && _isSidebarOpen)
                const SizedBox(width: 300),
              
              // Chat Content
              Expanded(
                child: Column(
                  children: [
                    // Modern App Bar
                    _buildModernAppBar(context),
                    
                    // Messages Area
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              colorScheme.surface,
                              colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                            ],
                          ),
                        ),
                        child: _buildMessagesArea(context),
                      ),
                    ),
                    
                    // Input Area
                    _buildModernInputArea(context),
                  ],
                ),
              ),
            ],
          ),
          
          // Sidebar Overlay
          if (_isSidebarOpen || isDesktop)
            _buildSidebar(context),
        ],
      ),
    );
  }

  Widget _buildModernAppBar(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    return Container(
      height: 72,
      decoration: BoxDecoration(
        color: colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: colorScheme.shadow.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            // Menu Button
            IconButton(
              icon: AnimatedIcon(
                icon: AnimatedIcons.menu_close,
                progress: _sidebarAnimationController,
              ),
              onPressed: _toggleSidebar,
              style: IconButton.styleFrom(
                backgroundColor: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
              ),
            ),
            const SizedBox(width: 16),
            
            // Title and Status
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              colorScheme.primary,
                              colorScheme.secondary,
                            ],
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.smart_toy,
                          color: colorScheme.onPrimary,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Asistente Legal IA',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Row(
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  color: Colors.green,
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.green.withValues(alpha: 0.4),
                                      blurRadius: 8,
                                      spreadRadius: 2,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                _isTyping ? 'Escribiendo...' : 'En línea',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
            
            // Action Buttons
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.search),
                  onPressed: () {},
                  tooltip: 'Buscar en conversación',
                ),
                IconButton(
                  icon: const Icon(Icons.more_vert),
                  onPressed: () {},
                  tooltip: 'Más opciones',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessagesArea(BuildContext context) {
    final theme = Theme.of(context);
    
    if (_messages.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.chat_bubble_outline,
              size: 64,
              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 16),
            Text(
              'Inicia una conversación',
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
              ),
            ),
          ],
        ),
      );
    }
    
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      itemCount: _messages.length,
      itemBuilder: (context, index) {
        final message = _messages[index];
        final showDate = index == 0 ||
            !_isSameDay(message.timestamp, _messages[index - 1].timestamp);
        
        return Column(
          children: [
            if (showDate) _buildDateSeparator(context, message.timestamp),
            _buildModernMessageBubble(context, message),
          ],
        );
      },
    );
  }

  Widget _buildDateSeparator(BuildContext context, DateTime date) {
    final theme = Theme.of(context);
    final dateStr = _formatDate(date);
    
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        children: [
          Expanded(
            child: Divider(
              color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              dateStr,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
              ),
            ),
          ),
          Expanded(
            child: Divider(
              color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModernMessageBubble(BuildContext context, ChatMessage message) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final screenWidth = MediaQuery.of(context).size.width;
    final maxWidth = math.min(screenWidth * 0.7, 600.0);
    
    final isUser = message.isUser;
    
    return Padding(
      padding: EdgeInsets.only(
        left: isUser ? 48 : 0,
        right: isUser ? 0 : 48,
        bottom: 8,
      ),
      child: Row(
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Avatar for AI
          if (!isUser) ...[
            Container(
              width: 36,
              height: 36,
              margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    colorScheme.primary,
                    colorScheme.secondary,
                  ],
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                Icons.smart_toy,
                color: colorScheme.onPrimary,
                size: 20,
              ),
            ),
          ],
          
          // Message Content
          Flexible(
            child: Column(
              crossAxisAlignment: isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                Container(
                  constraints: BoxConstraints(maxWidth: maxWidth),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: isUser
                        ? colorScheme.primary
                        : colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(20),
                      topRight: const Radius.circular(20),
                      bottomLeft: Radius.circular(isUser ? 20 : 4),
                      bottomRight: Radius.circular(isUser ? 4 : 20),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: (isUser ? colorScheme.primary : colorScheme.shadow)
                            .withValues(alpha: 0.1),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SelectableText(
                        message.content,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: isUser
                              ? colorScheme.onPrimary
                              : colorScheme.onSurface,
                          height: 1.4,
                        ),
                      ),
                      if (message.status == MessageStatus.sending && !isUser && message.content.isEmpty)
                        PulsatingDots(
                          color: colorScheme.primary,
                          size: 6,
                        ),
                    ],
                  ),
                ),
                
                // Timestamp and Status
                Padding(
                  padding: const EdgeInsets.only(top: 4, left: 4, right: 4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _formatTime(message.timestamp),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                          fontSize: 11,
                        ),
                      ),
                      if (isUser) ...[
                        const SizedBox(width: 4),
                        _buildStatusIcon(message.status, colorScheme),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          // Avatar for User
          if (isUser) ...[
            const SizedBox(width: 8),
            CircleAvatar(
              radius: 18,
              backgroundColor: colorScheme.secondaryContainer,
              child: Icon(
                Icons.person,
                size: 20,
                color: colorScheme.onSecondaryContainer,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatusIcon(MessageStatus status, ColorScheme colorScheme) {
    switch (status) {
      case MessageStatus.sending:
        return Icon(
          Icons.access_time,
          size: 14,
          color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
        );
      case MessageStatus.delivered:
        return Icon(
          Icons.done_all,
          size: 14,
          color: colorScheme.primary,
        );
      case MessageStatus.error:
        return Icon(
          Icons.error_outline,
          size: 14,
          color: colorScheme.error,
        );
    }
  }

  Widget _buildModernInputArea(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: colorScheme.shadow.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Container(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // Attachment Button
              IconButton(
                icon: const Icon(Icons.attach_file),
                onPressed: () {},
                style: IconButton.styleFrom(
                  foregroundColor: colorScheme.onSurfaceVariant,
                ),
                tooltip: 'Adjuntar archivo',
              ),
              
              // Input Field
              Expanded(
                child: Container(
                  constraints: const BoxConstraints(maxHeight: 120),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _messageController,
                          focusNode: _messageFocusNode,
                          maxLines: null,
                          keyboardType: TextInputType.multiline,
                          textInputAction: TextInputAction.newline,
                          enabled: !_isLoading,
                          style: theme.textTheme.bodyLarge,
                          decoration: InputDecoration(
                            hintText: 'Escribe tu consulta legal...',
                            hintStyle: theme.textTheme.bodyLarge?.copyWith(
                              color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                            ),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 12,
                            ),
                          ),
                          onSubmitted: (_) => _sendMessage(),
                        ),
                      ),
                      
                      // Emoji Button
                      IconButton(
                        icon: const Icon(Icons.emoji_emotions_outlined),
                        onPressed: () {},
                        style: IconButton.styleFrom(
                          foregroundColor: colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                        ),
                        tooltip: 'Emojis',
                      ),
                    ],
                  ),
                ),
              ),
              
              const SizedBox(width: 8),
              
              // Send/Voice Button
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      colorScheme.primary,
                      colorScheme.secondary,
                    ],
                  ),
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  icon: Icon(
                    _messageController.text.isEmpty ? Icons.mic : Icons.send,
                    color: colorScheme.onPrimary,
                  ),
                  onPressed: _isLoading
                      ? null
                      : _messageController.text.isEmpty
                          ? () {} // Voice recording
                          : _sendMessage,
                  style: IconButton.styleFrom(
                    foregroundColor: colorScheme.onPrimary,
                  ),
                  tooltip: _messageController.text.isEmpty ? 'Grabar audio' : 'Enviar',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSidebar(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDesktop = ResponsiveHelper.isDesktop(context);
    
    return AnimatedPositioned(
      duration: const Duration(milliseconds: 300),
      left: _isSidebarOpen ? 0 : (isDesktop ? -300 : -MediaQuery.of(context).size.width),
      top: 0,
      bottom: 0,
      width: isDesktop ? 300 : MediaQuery.of(context).size.width * 0.85,
      child: Container(
        decoration: BoxDecoration(
          color: colorScheme.surface,
          boxShadow: [
            BoxShadow(
              color: colorScheme.shadow.withValues(alpha: 0.1),
              blurRadius: 20,
              offset: const Offset(2, 0),
            ),
          ],
        ),
        child: Column(
          children: [
            // Sidebar Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    colorScheme.primary.withValues(alpha: 0.1),
                    colorScheme.secondary.withValues(alpha: 0.05),
                  ],
                ),
              ),
              child: SafeArea(
                bottom: false,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'Conversaciones',
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Spacer(),
                        if (!isDesktop)
                          IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: _toggleSidebar,
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    
                    // New Chat Button
                    CustomButton(
                      text: 'Nueva Conversación',
                      leadingIcon: Icons.add,
                      onPressed: () {
                        setState(() {
                          _messages.clear();
                          _initializeChat();
                        });
                        if (!isDesktop) _toggleSidebar();
                      },
                      variant: ButtonVariant.primary,
                      isFullWidth: true,
                    ),
                  ],
                ),
              ),
            ),
            
            // Search Bar
            Padding(
              padding: const EdgeInsets.all(16),
              child: TextField(
                decoration: InputDecoration(
                  hintText: 'Buscar conversaciones...',
                  prefixIcon: const Icon(Icons.search),
                  filled: true,
                  fillColor: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                ),
              ),
            ),
            
            // Chat History List
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                children: [
                  _buildChatHistoryItem(
                    context,
                    'Consulta sobre contratos',
                    'Necesito información sobre...',
                    DateTime.now().subtract(const Duration(hours: 2)),
                    true,
                  ),
                  _buildChatHistoryItem(
                    context,
                    'Derecho laboral',
                    '¿Cuáles son los requisitos para...',
                    DateTime.now().subtract(const Duration(days: 1)),
                    false,
                  ),
                  _buildChatHistoryItem(
                    context,
                    'Amparo directo',
                    'Procedimiento para interponer...',
                    DateTime.now().subtract(const Duration(days: 3)),
                    false,
                  ),
                ],
              ),
            ),
            
            // Sidebar Footer
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(
                    color: colorScheme.outlineVariant.withValues(alpha: 0.3),
                  ),
                ),
              ),
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.settings),
                    title: const Text('Configuración'),
                    onTap: () {},
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  ListTile(
                    leading: const Icon(Icons.help_outline),
                    title: const Text('Ayuda'),
                    onTap: () {},
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChatHistoryItem(
    BuildContext context,
    String title,
    String lastMessage,
    DateTime timestamp,
    bool isActive,
  ) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: isActive
            ? colorScheme.primaryContainer.withValues(alpha: 0.2)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: () {
            if (!ResponsiveHelper.isDesktop(context)) {
              _toggleSidebar();
            }
          },
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      _formatRelativeTime(timestamp),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  lastMessage,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Helper methods
  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    if (_isSameDay(date, now)) {
      return 'Hoy';
    } else if (_isSameDay(date, now.subtract(const Duration(days: 1)))) {
      return 'Ayer';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }

  String _formatTime(DateTime time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }

  String _formatRelativeTime(DateTime time) {
    final now = DateTime.now();
    final difference = now.difference(time);
    
    if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h';
    } else {
      return '${difference.inDays}d';
    }
  }
}

// Chat Message Model
class ChatMessage {
  final String id;
  final String content;
  final bool isUser;
  final DateTime timestamp;
  final MessageStatus status;

  ChatMessage({
    required this.id,
    required this.content,
    required this.isUser,
    required this.timestamp,
    required this.status,
  });

  ChatMessage copyWith({
    String? id,
    String? content,
    bool? isUser,
    DateTime? timestamp,
    MessageStatus? status,
  }) {
    return ChatMessage(
      id: id ?? this.id,
      content: content ?? this.content,
      isUser: isUser ?? this.isUser,
      timestamp: timestamp ?? this.timestamp,
      status: status ?? this.status,
    );
  }
}

enum MessageStatus { sending, delivered, error }