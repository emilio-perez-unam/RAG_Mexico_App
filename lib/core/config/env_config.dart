import 'package:flutter/foundation.dart' show kIsWeb;

/// Environment configuration class with hardcoded values
/// No dependency on .env files - suitable for GitHub Pages deployment
class EnvConfig {
  static late EnvConfig _instance;

  // Private constructor
  EnvConfig._();

  /// Initialize the environment configuration
  /// Must be called before accessing any configuration values
  static Future<void> initialize() async {
    _instance = EnvConfig._();
  }

  /// Get the singleton instance
  static EnvConfig get instance {
    try {
      return _instance;
    } catch (e) {
      throw Exception(
        'EnvConfig not initialized. Call EnvConfig.initialize() first.',
      );
    }
  }

  // ============================================
  // SUPABASE CONFIGURATION (UPDATED)
  // ============================================

  /// The new, secure URL for your Supabase backend.
  /// The CORS proxy is no longer needed.
  String get supabaseUrl =>
      'https://api.rag-leyes.generalanalyticsolutions.com';

  /// Your public anonymous key. This is safe to have in frontend code.
  String get supabaseAnonKey =>
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJyb2xlIjoiYW5vbiIsImlzcyI6InN1cGFiYXNlIiwiaWF0IjoxNzU3NDQxNTQ3LCJleHAiOjIwNzI4MDE1NDd9.yMsImS7M2UL_9T1a375Lsvu9hGWADaX4dj4xIIfreno';

  // REMOVED: supabaseServiceKey. The service key is a secret and must NEVER be in client-side code.
  // REMOVED: All direct database connection details (host, port, user, password).
  // Your Flutter app should ONLY communicate with the Supabase API, not the database directly.

  // ============================================
  // API ENDPOINTS (SIMPLIFIED)
  // ============================================
  // The Supabase client library builds these URLs automatically.
  // You can still define them here for other custom uses if needed.
  String get apiBaseUrl => supabaseUrl;
  String get restApiUrl => '$apiBaseUrl/rest/v1/';
  String get authApiUrl => '$apiBaseUrl/auth/v1/';
  String get storageApiUrl => '$apiBaseUrl/storage/v1/';
  String get realtimeApiUrl => '$apiBaseUrl/realtime/v1/';
  String get functionsApiUrl => '$apiBaseUrl/functions/v1/';

  // ============================================
  // AI/LLM CONFIGURATION
  // ============================================
  // IMPORTANT: For production, load these keys from a secure backend or use Row Level Security.
  String get deepSeekApiKey => 'your_deepseek_api_key_here';
  String get deepSeekModel => 'deepseek-chat';
  String get openRouterApiKey =>
      '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';
  String get openRouterBaseUrl => 'https://openrouter.ai/api/v1';
  String get openRouterModel => 'qwen/qwen3-235b-a22b-thinking-2507';

  String get openAIApiKey => 'your_openai_api_key_here';
  String get embeddingModel => 'text-embedding-3-small';
  int get embeddingDimension => 1536;

  // ============================================
  // VECTOR DATABASE CONFIGURATION (Client-Side Safe)
  // ============================================
  String get vectorStoreType => 'supabase';
  String get vectorCollectionName => 'document_embeddings';
  double get vectorSimilarityThreshold => 0.7;
  int get vectorMatchCount => 10;

  // ============================================
  // STORAGE CONFIGURATION (Client-Side Safe)
  // ============================================
  String get storageBucketName => 'legal-documents';
  int get storageMaxFileSize => 52428800;
  List<String> get allowedFileTypes => ['pdf', 'docx', 'txt', 'md'];

  // Other configurations can remain as they are...
  // (APPLICATION, SECURITY, FEATURE FLAGS, RAG SYSTEM, HELPERS)

  // ============================================
  // APPLICATION CONFIGURATION
  // ============================================
  String get appEnv => 'development';
  String get appName => 'LegalTracking RAG System';
  String get appVersion => '1.0.0';

  // ... (the rest of your non-sensitive configurations can go here) ...

  /// Log current configuration (for debugging, excludes sensitive data)
  void logConfiguration() {
    print('=== LegalTracking Configuration ===');
    print('Environment: $appEnv');
    print('Supabase URL: $supabaseUrl'); // Now reflects the secure URL
    print('Vector Store: $vectorStoreType');
    print('================================');
  }
}
