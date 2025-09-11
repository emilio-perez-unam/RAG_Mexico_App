import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';
import 'injection_container.dart' as di;
import 'core/config/env_config.dart';
import 'app.dart';

void main() async {
  final logger = Logger(
    printer: PrettyPrinter(
      methodCount: 0,
      errorMethodCount: 5,
      lineLength: 50,
      colors: true,
      printEmojis: true,
      dateTimeFormat: DateTimeFormat.onlyTimeAndSinceStart,
    ),
  );
  
  logger.i('==========================================');
  logger.i('Starting Legal RAG México Application');
  logger.i('==========================================');
  
  logger.d('Ensuring Flutter widgets are initialized');
  WidgetsFlutterBinding.ensureInitialized();
  logger.d('Flutter widgets initialized successfully');

  try {
    // Initialize environment configuration
    logger.i('Step 1: Loading environment configuration');
    await EnvConfig.initialize();
    logger.i('Environment configuration loaded successfully');
    
    // Initialize dependency injection
    logger.i('Step 2: Initializing dependency injection');
    await di.initializeDependencies();
    logger.i('Dependency injection initialized successfully');
    
    // Run the app
    logger.i('Step 3: Launching Flutter application');
    runApp(const LegalRAGApp());
    logger.i('Flutter application launched successfully');
    
  } catch (e, stackTrace) {
    // Log initialization errors
    logger.e('CRITICAL: Application initialization failed', error: e, stackTrace: stackTrace);
    
    if (kDebugMode) {
      print('Initialization Error: $e');
      print('Stack Trace: $stackTrace');
    }
    
    // Show error screen if initialization fails
    logger.w('Showing error screen to user');
    runApp(InitializationErrorApp(error: e.toString()));
  }
}

/// Error app shown when initialization fails
class InitializationErrorApp extends StatelessWidget {
  final String error;
  

  
  const InitializationErrorApp({super.key, required this.error});
  
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Legal RAG México - Error',
      home: Scaffold(
        backgroundColor: const Color(0xFF003366),
        body: Center(
          child: Container(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.error_outline,
                  color: Colors.white,
                  size: 64,
                ),
                const SizedBox(height: 24),
                const Text(
                  'Initialization Error',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'The application failed to initialize properly.',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.8),
                    fontSize: 16,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                if (kDebugMode) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.black26,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: SelectableText(
                      error,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 32),
                const Text(
                  'Please check your configuration and try again.',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
