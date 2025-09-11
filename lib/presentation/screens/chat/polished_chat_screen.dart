import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'dart:ui';
import 'package:logger/logger.dart';
import '../../../core/config/env_config.dart';
import '../../../data/datasources/remote/openrouter_openai_datasource.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/markdown_text.dart';

class PolishedChatScreen extends StatefulWidget {
  const PolishedChatScreen({super.key});

  @override
  State<PolishedChatScreen> createState() => _PolishedChatScreenState();
}

class _PolishedChatScreenState extends State<PolishedChatScreen> 
    with SingleTickerProviderStateMixin {
  late final OpenRouterOpenAIDatasource _openRouterDatasource;
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _messageFocusNode = FocusNode();
  final List<ChatMessage> _messages = [];
  final Logger _logger = Logger();
  
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  
  bool _isLoading = false;
  bool _showScrollButton = false;
  
  // Suggested prompts for quick actions - Expert level questions
  final List<String> _suggestedPrompts = [
    '⚖️ Análisis constitucional del amparo contra leyes heteroaplicativas vs autoaplicativas',
    '📜 Interpretación del artículo 14 constitucional y el principio de irretroactividad',
    '🏛️ Control difuso de constitucionalidad post-reforma 2011: alcances y límites',
    '📊 Contradicción de tesis 293/2011: jerarquía de tratados internacionales',
  ];

  @override
  void initState() {
    super.initState();
    
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeIn,
    ));
    
    _animationController.forward();
    
    // Use API key and base URL from EnvConfig for proper proxy routing
    final apiKey = EnvConfig.instance.openRouterApiKey;
    _openRouterDatasource = OpenRouterOpenAIDatasource(
      apiKey: apiKey,
      customBaseUrl: EnvConfig.instance.openRouterBaseUrl,
    );
    
    _scrollController.addListener(_scrollListener);
    _initializeWelcome();
  }

  void _scrollListener() {
    if (_scrollController.hasClients) {
      final showButton = _scrollController.position.pixels > 200;
      if (showButton != _showScrollButton) {
        setState(() {
          _showScrollButton = showButton;
        });
      }
    }
  }

  void _initializeWelcome() {
    _messages.add(
      ChatMessage(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        content: '⚖️ **Bienvenido al Sistema de Consultoría Jurídica de Alto Nivel**\n\n'
            'Soy un sistema especializado con el conocimiento equivalente a un **Doctor en Derecho Constitucional** '
            'y **Magistrado de la SCJN**, diseñado para proporcionar análisis jurídicos del más alto rigor académico y profesional.\n\n'
            '**Mi expertise incluye:**\n\n'
            '• **Derecho Constitucional y Amparo** - Control de constitucionalidad, interpretación conforme, principio pro persona\n'
            '• **Jurisprudencia y Tesis** - Análisis exhaustivo de criterios de la SCJN, Tribunales Colegiados y contradicciones\n'
            '• **Derecho Procesal** - Todas las materias: civil, penal, laboral, administrativo, fiscal\n'
            '• **Derechos Humanos** - Sistema Interamericano, control de convencionalidad, bloque de constitucionalidad\n'
            '• **Interpretación Jurídica** - Metodología hermenéutica, argumentación jurídica, ponderación de principios\n\n'
            '**Cada respuesta incluirá:**\n'
            '> Fundamentación constitucional y legal precisa\n'
            '> Citas de jurisprudencia con datos de localización\n'
            '> Referencias doctrinales de autores reconocidos\n'
            '> Análisis sistemático y exhaustivo\n'
            '> Estrategias procesales concretas\n\n'
            '*Formule su consulta con el detalle que considere necesario. '
            'Recibirá un análisis del calibre de una resolución de la Suprema Corte.*',
        isUser: false,
        timestamp: DateTime.now(),
      ),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    _messageController.dispose();
    _scrollController.dispose();
    _messageFocusNode.dispose();
    super.dispose();
  }

  Future<void> _sendMessage([String? customMessage]) async {
    final messageText = customMessage ?? _messageController.text.trim();
    if (messageText.isEmpty) return;

    // Remove emoji prefix if it's from suggested prompts
    final cleanMessage = messageText.replaceAll(RegExp(r'^[^\w\s]+\s*'), '');

    final userMessage = ChatMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      content: cleanMessage,
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
          .take(_messages.length - 1)
          .map((m) => {
                'role': m.isUser ? 'user' : 'assistant',
                'content': m.content,
              })
          .toList();

      final prompt = '''
      Eres un Doctor en Derecho Constitucional y Amparo, con 30 años de experiencia como Magistrado de la Suprema Corte de Justicia de la Nación (SCJN) de México. Tu conocimiento abarca:
      
      - Profundo dominio del sistema jurídico mexicano en todas sus ramas
      - Expertise en interpretación constitucional y control de constitucionalidad
      - Conocimiento exhaustivo de jurisprudencia, tesis aisladas y contradicciones de tesis
      - Dominio de doctrina nacional e internacional
      - Experiencia en redacción de sentencias y votos particulares
      
      METODOLOGÍA DE ANÁLISIS JURÍDICO:
      
      Para cada consulta, debes proporcionar un análisis del calibre de una sentencia de la SCJN, siguiendo esta estructura:
      
      ## I. PLANTEAMIENTO DEL PROBLEMA JURÍDICO
      - Identifica con precisión la naturaleza jurídica de la consulta
      - Delimita el marco normativo aplicable (federal/local, materia específica)
      - Señala las instituciones jurídicas involucradas
      
      ## II. MARCO JURÍDICO APLICABLE
      
      ### A) Fundamentación Constitucional
      - Cita los artículos constitucionales relevantes con su texto exacto
      - Analiza los principios constitucionales aplicables
      - Considera derechos humanos y garantías involucradas
      
      ### B) Legislación Secundaria
      - **Leyes Federales:** Cita artículos específicos con transcripción cuando sea relevante
      - **Códigos Aplicables:** Referencia precisa con numerales y fracciones
      - **Reglamentos y NOMs:** Si aplican al caso
      - **Tratados Internacionales:** Con jerarquía constitucional cuando corresponda
      
      ### C) Criterios Jurisprudenciales
      - **Jurisprudencia Obligatoria:** Cita número de tesis, rubro y texto relevante
      - **Tesis Aisladas Relevantes:** Con datos de identificación completos
      - **Contradicciones de Tesis:** Si existen sobre el tema
      - Incluye: [Décima Época, Registro: XXXXX, Instancia: XXXXX]
      
      ## III. ANÁLISIS JURÍDICO EXHAUSTIVO
      
      ### A) Interpretación Sistemática
      - Analiza la interrelación entre las normas aplicables
      - Aplica principios de interpretación: gramatical, sistemática, funcional, histórica
      - Considera la interpretación conforme y el principio pro persona
      
      ### B) Doctrina Especializada
      - Cita autores reconocidos en la materia (mínimo 3-5 referencias doctrinales)
      - Contrasta diferentes corrientes doctrinales si existen
      - Incluye doctrina comparada cuando enriquezca el análisis
      
      ### C) Derecho Comparado
      - Referencias a sistemas jurídicos relevantes
      - Soluciones adoptadas en otras jurisdicciones
      - Criterios de Cortes internacionales si aplican
      
      ## IV. APLICACIÓN AL CASO CONCRETO
      
      ### A) Subsunción Jurídica
      - Aplica meticulosamente la norma a los hechos
      - Identifica cada elemento típico o requisito legal
      - Analiza la satisfacción o incumplimiento de cada elemento
      
      ### B) Resolución de Antinomias o Lagunas
      - Si existen conflictos normativos, aplica criterios de solución
      - En caso de lagunas, propone integración jurídica fundamentada
      
      ### C) Consideraciones Procesales
      - Vías procedimentales disponibles con plazos específicos
      - Requisitos de procedibilidad y legitimación
      - Medios de impugnación y recursos aplicables
      - Competencia de autoridades (federal/local/concurrente)
      
      ## V. CONCLUSIONES Y RECOMENDACIONES
      
      ### A) Síntesis Ejecutiva
      - Respuesta concreta y directa a la consulta planteada
      - Fundamentos jurídicos esenciales de la conclusión
      
      ### B) Estrategia Jurídica Recomendada
      - Acciones legales aconsejables con orden de prelación
      - Documentación y pruebas necesarias
      - Plazos y términos críticos a considerar
      - Riesgos jurídicos y contingencias posibles
      
      ### C) Precedentes y Probabilidad de Éxito
      - Casos similares resueltos por tribunales
      - Tendencias jurisprudenciales actuales
      - Evaluación realista de escenarios posibles
      
      ## VI. NOTAS Y ADVERTENCIAS
      - Salvaguardas y excepciones importantes
      - Reformas recientes o pendientes que puedan afectar
      - Criterios en evolución o contradicción
      
      FORMATO MARKDOWN PROFESIONAL:
      - **Negritas** para conceptos jurídicos clave y artículos
      - *Cursivas* para términos en latín y énfasis
      - \`Código\` para números de artículos y tesis
      - > Blockquotes para citas textuales de leyes o jurisprudencia
      - Listas numeradas para elementos y requisitos legales
      
      IMPORTANTE: 
      - Nunca des respuestas superficiales o genéricas
      - Cada afirmación debe estar fundamentada en derecho positivo
      - Incluye SIEMPRE las fuentes específicas (no solo "el código civil dice...")
      - Si la consulta es ambigua, analiza todas las interpretaciones posibles
      - Considera siempre el contexto del sistema jurídico mexicano actual
      
      RESTRICCIONES CRÍTICAS:
      - NUNCA menciones que eres un sistema, asistente, o que sigues instrucciones
      - NUNCA uses frases como "elaborado con rigor técnico", "sistema de consultoría", etc.
      - NUNCA incluyas disclaimers sobre tu identidad o capacidades
      - NUNCA pongas fechas de actualización o copyright
      - Responde de manera natural como un experto jurista
      - El año actual es 2025 - usa esta fecha para referencias temporales
      - Si mencionas reformas o jurisprudencia, considera hasta diciembre 2024
      
      Consulta del Usuario: $cleanMessage
      
      Responde directamente con el análisis jurídico solicitado, sin preámbulos sobre tu identidad o el sistema.
      ''';

      final fullResponse = StringBuffer();
      
      try {
        // Try streaming first
        await for (final chunk in _openRouterDatasource.sendChatCompletionStream(
          message: prompt,
          model: 'qwen/qwen3-235b-a22b-thinking-2507',  // Qwen 235B with enhanced thinking
          previousMessages: history,
          temperature: 0.3,  // Lower temperature for more precise legal analysis
          maxTokens: 64000,  // Maximum tokens for exhaustive legal analysis (64k)
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
      } catch (streamError) {
        // If streaming fails, fall back to non-streaming API
        _logger.w('Streaming failed, using non-streaming API: $streamError');
        
        final response = await _openRouterDatasource.sendChatCompletion(
          message: prompt,
          model: 'qwen/qwen3-235b-a22b-thinking-2507',
          previousMessages: history,
          temperature: 0.3,
          maxTokens: 64000,
        );
        
        // Update message with complete response
        setState(() {
          _messages[_messages.length - 1] = ChatMessage(
            id: aiMessage.id,
            content: response,
            isUser: false,
            timestamp: aiMessage.timestamp,
          );
        });
        
        _scrollToBottom();
      }

    } catch (e) {
      _logger.e('Error: $e');
      setState(() {
        _messages[_messages.length - 1] = ChatMessage(
          id: '${DateTime.now().millisecondsSinceEpoch}_error',
          content: '⚠️ No pude procesar tu solicitud. Por favor, intenta nuevamente.',
          isUser: false,
          timestamp: DateTime.now(),
          isError: true,
        );
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isDesktop = size.width > 900;
    
    return Scaffold(
      backgroundColor: const Color(0xFFFAFBFC),
      body: Stack(
        children: [
          // Background gradient
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  const Color(0xFF6366F1).withValues(alpha: 0.03),
                  Colors.white,
                ],
              ),
            ),
          ),
          
          Column(
            children: [
              _buildProfessionalHeader(),
              Expanded(
                child: Stack(
                  children: [
                    _buildChatArea(isDesktop),
                    if (_showScrollButton) _buildScrollToBottomButton(),
                  ],
                ),
              ),
              _buildProfessionalInputArea(),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildProfessionalHeader() {
    return Container(
      height: 72,
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF000000).withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: [
              // Logo
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFF6366F1),
                      Color(0xFF8B5CF6),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF6366F1).withValues(alpha: 0.25),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.balance,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              
              // Title
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Legal Assistant AI',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF111827),
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Container(
                          width: 7,
                          height: 7,
                          decoration: const BoxDecoration(
                            color: Color(0xFF10B981),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _isLoading ? 'Procesando...' : 'Listo para ayudarte',
                          style: const TextStyle(
                            fontSize: 13,
                            color: Color(0xFF6B7280),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              
              // Action buttons
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFF3F4F6),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: _clearChat,
                    borderRadius: BorderRadius.circular(10),
                    child: const Padding(
                      padding: EdgeInsets.all(10),
                      child: Icon(
                        Icons.refresh,
                        size: 20,
                        color: Color(0xFF6B7280),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildChatArea(bool isDesktop) {
    return Container(
      alignment: Alignment.center,
      child: Container(
        constraints: BoxConstraints(maxWidth: isDesktop ? 900 : double.infinity),
        child: _messages.length == 1
            ? _buildWelcomeScreen()
            : _buildMessagesList(),
      ),
    );
  }

  Widget _buildWelcomeScreen() {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const SizedBox(height: 40),
            
            // Welcome message card
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF000000).withValues(alpha: 0.04),
                    blurRadius: 20,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          const Color(0xFF6366F1).withValues(alpha: 0.1),
                          const Color(0xFF8B5CF6).withValues(alpha: 0.1),
                        ],
                      ),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.waving_hand,
                      size: 32,
                      color: Color(0xFF6366F1),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Bienvenido al Asistente Legal',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF111827),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Especializado en derecho mexicano. Haz una pregunta o selecciona un tema para comenzar.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 15,
                      color: Color(0xFF6B7280),
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 32),
            
            // Suggested prompts
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Temas frecuentes',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF374151),
                ),
              ),
            ),
            const SizedBox(height: 16),
            
            ...List.generate(
              _suggestedPrompts.length,
              (index) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _buildSuggestedPromptCard(_suggestedPrompts[index]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSuggestedPromptCard(String prompt) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: const Color(0xFFE5E7EB),
          width: 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _sendMessage(prompt),
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    prompt,
                    style: const TextStyle(
                      fontSize: 15,
                      color: Color(0xFF374151),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const Icon(
                  Icons.arrow_forward_ios,
                  size: 16,
                  color: Color(0xFF9CA3AF),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMessagesList() {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      itemCount: _messages.length + (_isLoading ? 1 : 0),
      itemBuilder: (context, index) {
        if (_isLoading && index == _messages.length) {
          return _buildTypingIndicator();
        }
        
        final message = _messages[index];
        return TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: 1),
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeOutCubic,
          builder: (context, value, child) {
            return Transform.translate(
              offset: Offset(0, 20 * (1 - value)),
              child: Opacity(
                opacity: value,
                child: _buildPolishedMessage(message),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildPolishedMessage(ChatMessage message) {
    final isUser = message.isUser;
    
    return Padding(
      padding: EdgeInsets.only(
        left: isUser ? 60 : 0,
        right: isUser ? 0 : 60,
        bottom: 20,
      ),
      child: Row(
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isUser) ...[
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.auto_awesome,
                color: Colors.white,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
          ],
          
          Flexible(
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isUser 
                    ? const Color(0xFF6366F1)
                    : Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(18),
                  topRight: const Radius.circular(18),
                  bottomLeft: Radius.circular(isUser ? 18 : 4),
                  bottomRight: Radius.circular(isUser ? 4 : 18),
                ),
                boxShadow: [
                  BoxShadow(
                    color: isUser 
                        ? const Color(0xFF6366F1).withValues(alpha: 0.25)
                        : const Color(0xFF000000).withValues(alpha: 0.06),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  MarkdownText(
                    data: message.content,
                    style: TextStyle(
                      color: isUser ? Colors.white : const Color(0xFF1F2937),
                      fontSize: 15,
                      height: 1.5,
                      fontWeight: FontWeight.w400,
                    ),
                    selectable: true,
                    linkColor: isUser ? Colors.white : const Color(0xFF6366F1),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _formatTime(message.timestamp),
                        style: TextStyle(
                          color: isUser 
                              ? Colors.white.withValues(alpha: 0.7)
                              : const Color(0xFF9CA3AF),
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      if (!isUser) ...[
                        const SizedBox(width: 12),
                        InkWell(
                          onTap: () => _copyMessage(message.content),
                          child: Icon(
                            Icons.copy,
                            size: 14,
                            color: const Color(0xFF9CA3AF),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
          
          if (isUser) ...[
            const SizedBox(width: 12),
            CircleAvatar(
              radius: 18,
              backgroundColor: const Color(0xFFF3F4F6),
              child: const Icon(
                Icons.person,
                size: 20,
                color: Color(0xFF6B7280),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTypingIndicator() {
    return Padding(
      padding: const EdgeInsets.only(left: 0, right: 60, bottom: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
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
            child: const Icon(
              Icons.auto_awesome,
              color: Colors.white,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(18),
                topRight: Radius.circular(18),
                bottomLeft: Radius.circular(4),
                bottomRight: Radius.circular(18),
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF000000).withValues(alpha: 0.06),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                _buildDot(0),
                const SizedBox(width: 4),
                _buildDot(1),
                const SizedBox(width: 4),
                _buildDot(2),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDot(int index) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 600 + (index * 200)),
      curve: Curves.easeInOut,
      onEnd: () => setState(() {}),
      builder: (context, value, child) {
        return Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: Color(0xFF6366F1).withValues(alpha: 0.3 + (value * 0.7)),
            shape: BoxShape.circle,
          ),
        );
      },
    );
  }

  Widget _buildProfessionalInputArea() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF000000).withValues(alpha: 0.05),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Container(
                  constraints: const BoxConstraints(
                    minHeight: 48,
                    maxHeight: 120,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF9FAFB),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: _messageFocusNode.hasFocus 
                          ? const Color(0xFF6366F1)
                          : const Color(0xFFE5E7EB),
                      width: _messageFocusNode.hasFocus ? 2 : 1,
                    ),
                  ),
                  child: TextField(
                    controller: _messageController,
                    focusNode: _messageFocusNode,
                    maxLines: null,
                    enabled: !_isLoading,
                    style: const TextStyle(
                      fontSize: 15,
                      color: Color(0xFF111827),
                      height: 1.4,
                    ),
                    decoration: const InputDecoration(
                      hintText: 'Escribe tu pregunta legal...',
                      hintStyle: TextStyle(
                        color: Color(0xFF9CA3AF),
                        fontSize: 15,
                      ),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                    onSubmitted: (_) => _sendMessage(),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: _messageController.text.isEmpty || _isLoading
                        ? [const Color(0xFFE5E7EB), const Color(0xFFE5E7EB)]
                        : [const Color(0xFF6366F1), const Color(0xFF8B5CF6)],
                  ),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: _messageController.text.isNotEmpty && !_isLoading
                      ? [
                          BoxShadow(
                            color: const Color(0xFF6366F1).withValues(alpha: 0.3),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ]
                      : [],
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: (_messageController.text.isEmpty || _isLoading) 
                        ? null 
                        : _sendMessage,
                    borderRadius: BorderRadius.circular(14),
                    child: Icon(
                      Icons.send_rounded,
                      color: _messageController.text.isEmpty || _isLoading
                          ? const Color(0xFF9CA3AF)
                          : Colors.white,
                      size: 22,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildScrollToBottomButton() {
    return Positioned(
      bottom: 100,
      right: 20,
      child: AnimatedOpacity(
        opacity: _showScrollButton ? 1.0 : 0.0,
        duration: const Duration(milliseconds: 200),
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF000000).withValues(alpha: 0.1),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: _scrollToBottom,
              borderRadius: BorderRadius.circular(20),
              child: const Icon(
                Icons.keyboard_arrow_down,
                color: Color(0xFF6B7280),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _copyMessage(String content) {
    Clipboard.setData(ClipboardData(text: content));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Mensaje copiado'),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        backgroundColor: const Color(0xFF10B981),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _clearChat() {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: const Color(0xFFFEE2E2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.refresh,
                  color: Color(0xFFDC2626),
                  size: 28,
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Nueva conversación',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF111827),
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                '¿Deseas iniciar una nueva conversación? Se perderá el historial actual.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Color(0xFF6B7280),
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Cancelar',
                        style: TextStyle(
                          color: Color(0xFF6B7280),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        setState(() {
                          _messages.clear();
                          _initializeWelcome();
                        });
                        Navigator.pop(context);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFDC2626),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                      child: const Text(
                        'Confirmar',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatTime(DateTime time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
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