import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:logger/logger.dart';
import '../../../core/constants/app_colors.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/ui_components/custom_button.dart';
import '../../widgets/ui_components/custom_text_field.dart';
import '../../widgets/ui_components/custom_card.dart';
import '../../widgets/ui_components/loading_indicators.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final Logger _logger = Logger(
    printer: PrettyPrinter(
      methodCount: 0,
      errorMethodCount: 5,
      lineLength: 50,
      colors: true,
      printEmojis: true,
      dateTimeFormat: DateTimeFormat.onlyTimeAndSinceStart,
    ),
  );
  bool _isPasswordVisible = false;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _logger.i('LoginScreen initialized');
  }

  @override
  void dispose() {
    _logger.i('LoginScreen disposing');
    _emailController.dispose();
    _passwordController.dispose();
    // Don't close logger here as it might be used in async callbacks
    super.dispose();
  }

  Future<void> _handleLogin() async {
    _logger.d('Login attempt started');
    
    if (!_formKey.currentState!.validate()) {
      _logger.w('Form validation failed');
      return;
    }

    final email = _emailController.text.trim();
    _logger.i('Attempting login for email: $email');

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      _logger.d('Getting AuthProvider instance');
      final authProvider = context.read<AuthProvider>();
      
      _logger.d('Calling signIn method');
      await authProvider.signIn(
        email: email,
        password: _passwordController.text,
      );

      _logger.i('Login successful for: $email');
      // Navigation will be handled by auth state listener
    } catch (e, stackTrace) {
      _logger.e('Login failed', error: e, stackTrace: stackTrace);
      setState(() {
        _errorMessage = e.toString();
      });
    } finally {
      if (mounted) {
        _logger.d('Resetting loading state');
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final size = MediaQuery.of(context).size;
    
    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: LoadingOverlay(
        isLoading: _isLoading,
        message: 'Iniciando sesión...',
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                colorScheme.primary.withValues(alpha: 0.05),
                colorScheme.secondary.withValues(alpha: 0.02),
              ],
            ),
          ),
          child: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24.0),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Animated Logo and Title
                      TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0, end: 1),
                        duration: const Duration(milliseconds: 800),
                        curve: Curves.easeOutBack,
                        builder: (context, value, child) {
                          return Transform.scale(
                            scale: value,
                            child: Container(
                              width: 80,
                              height: 80,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    colorScheme.primary,
                                    colorScheme.secondary,
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(20),
                                boxShadow: [
                                  BoxShadow(
                                    color: colorScheme.primary.withValues(alpha: 0.3),
                                    blurRadius: 20,
                                    offset: const Offset(0, 10),
                                  ),
                                ],
                              ),
                              child: Icon(
                                Icons.gavel,
                                size: 48,
                                color: colorScheme.onPrimary,
                              ),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 32),
                      Text(
                        'Legal RAG México',
                        style: theme.textTheme.headlineLarge?.copyWith(
                          color: colorScheme.primary,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Sistema de Búsqueda Legal Inteligente',
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 48),

                      // Login Form Card
                      CustomCard(
                        variant: CardVariant.elevated,
                        padding: const EdgeInsets.all(32),
                        child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              'Iniciar Sesión',
                              style: theme.textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 32),

                            // Email Field
                            CustomTextField(
                              label: 'Correo Electrónico',
                              hint: 'tu@email.com',
                              controller: _emailController,
                              enabled: !_isLoading,
                              keyboardType: TextInputType.emailAddress,
                              textInputAction: TextInputAction.next,
                              prefixIcon: const Icon(Icons.email_outlined),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  _logger.d('Email validation failed: empty');
                                  return 'Por favor ingresa tu correo electrónico';
                                }
                                if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$')
                                    .hasMatch(value)) {
                                  _logger.d('Email validation failed: invalid format - $value');
                                  return 'Por favor ingresa un correo válido';
                                }
                                _logger.d('Email validation passed');
                                return null;
                              },
                            ),
                            const SizedBox(height: 20),

                            // Password Field
                            CustomTextField(
                              label: 'Contraseña',
                              controller: _passwordController,
                              enabled: !_isLoading,
                              obscureText: true,
                              textInputAction: TextInputAction.done,
                              onSubmitted: (_) => _handleLogin(),
                              prefixIcon: const Icon(Icons.lock_outline),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  _logger.d('Password validation failed: empty');
                                  return 'Por favor ingresa tu contraseña';
                                }
                                if (value.length < 6) {
                                  _logger.d('Password validation failed: too short (${value.length} chars)');
                                  return 'La contraseña debe tener al menos 6 caracteres';
                                }
                                _logger.d('Password validation passed');
                                return null;
                              },
                            ),
                            const SizedBox(height: 12),

                            // Forgot Password Link
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton(
                                onPressed: _isLoading
                                    ? null
                                    : () {
                                        _logger.d('Navigating to forgot password screen');
                                        Navigator.pushNamed(
                                            context, '/forgot-password');
                                      },
                                child: const Text('¿Olvidaste tu contraseña?'),
                              ),
                            ),
                            const SizedBox(height: 16),

                            // Error Message
                            if (_errorMessage != null)
                              AnimatedContainer(
                                duration: const Duration(milliseconds: 300),
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: colorScheme.errorContainer.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: colorScheme.error.withValues(alpha: 0.3),
                                    width: 1,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.error_outline,
                                      color: colorScheme.error,
                                      size: 20,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        _errorMessage!,
                                        style: theme.textTheme.bodySmall?.copyWith(
                                          color: colorScheme.error,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            if (_errorMessage != null)
                              const SizedBox(height: 20),

                            // Login Button
                            CustomButton(
                              text: 'Iniciar Sesión',
                              onPressed: _isLoading ? null : _handleLogin,
                              isFullWidth: true,
                              size: ButtonSize.large,
                              leadingIcon: Icons.login,
                            ),
                            const SizedBox(height: 20),

                            // Divider
                            const Row(
                              children: [
                                Expanded(child: Divider()),
                                Padding(
                                  padding: EdgeInsets.symmetric(
                                      horizontal: 16),
                                ),
                                Expanded(child: Divider()),
                              ],
                            ),
                            const SizedBox(height: 16),
                          ],
                        ),
                      ),
                      ),  // Close CustomCard
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
