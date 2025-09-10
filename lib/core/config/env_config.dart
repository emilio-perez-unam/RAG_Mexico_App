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
  
  /// Check if running on HTTPS (for GitHub Pages)
  bool get _isHttps {
    if (kIsWeb) {
      final currentUrl = Uri.base.toString();
      return currentUrl.startsWith('https://');
    }
    return false;
  }

  // ============================================
  // SUPABASE CONFIGURATION
  // ============================================
  String get supabaseUrl {
    // Use CORS proxy when running on HTTPS (GitHub Pages)
    if (_isHttps) {
      return 'https://corsproxy.io/?http://5.161.120.86:8000';
    }
    return 'http://5.161.120.86:8000';
  }
  
  String get supabaseAnonKey => 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJyb2xlIjoiYW5vbiIsImlzcyI6InN1cGFiYXNlIiwiaWF0IjoxNzU3NDQxNTQ3LCJleHAiOjIwNzI4MDE1NDd9.yMsImS7M2UL_9T1a375Lsvu9hGWADaX4dj4xIIfreno';
  String get supabaseServiceKey => 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InhjdmJua2xqZGZqYXNkZmFzZGZhc2RmIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTY0NTQ0NjQwMCwiZXhwIjoxOTYxMDIyNDAwfQ.9v_bVZVwvxMNgEzxLR8PbPj8zTBqp7wy0OHgHIF9eH8';

  // ============================================
  // DATABASE CONFIGURATION
  // ============================================
  String get databaseHost => '5.161.120.86';
  int get databasePort => 6543;
  String get databaseName => 'postgres';
  String get databaseUser => 'postgres';
  String get databasePassword => '4b502d71c56fd186a811608c81ff61c7df6a26ea638fd79ed423dc1a8a2cb302';

  // Connection URLs
  String get databasePooledUrl => 'postgresql://postgres:4b502d71c56fd186a811608c81ff61c7df6a26ea638fd79ed423dc1a8a2cb302@5.161.120.86:6543/postgres';
  String get databaseDirectUrl => 'postgresql://postgres:4b502d71c56fd186a811608c81ff61c7df6a26ea638fd79ed423dc1a8a2cb302@5.161.120.86:5432/postgres';

  // ============================================
  // API ENDPOINTS
  // ============================================
  String get apiBaseUrl {
    // Use CORS proxy when running on HTTPS (GitHub Pages)
    if (_isHttps) {
      return 'https://corsproxy.io/?http://5.161.120.86:8000';
    }
    return 'http://5.161.120.86:8000';
  }
  
  String get restApiUrl => '$apiBaseUrl/rest/v1/';
  String get authApiUrl => '$apiBaseUrl/auth/v1/';
  String get storageApiUrl => '$apiBaseUrl/storage/v1/';
  String get realtimeApiUrl => '$apiBaseUrl/realtime/v1/';
  String get functionsApiUrl => '$apiBaseUrl/functions/v1/';

  // ============================================
  // AI/LLM CONFIGURATION
  // ============================================
  String get deepSeekApiKey => 'your_deepseek_api_key_here';
  String get deepSeekModel => 'deepseek-chat';
  String get openRouterApiKey => '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';
  String get openRouterBaseUrl => 'https://openrouter.ai/api/v1';
  String get openRouterModel => 'qwen/qwen3-235b-a22b-thinking-2507';

  // OpenAI Configuration (for embeddings)
  String get openAIApiKey => 'your_openai_api_key_here';
  String get embeddingModel => 'text-embedding-3-small';
  int get embeddingDimension => 1536;

  // ============================================
  // VECTOR DATABASE CONFIGURATION
  // ============================================
  String get vectorStoreType => 'supabase';
  String get vectorCollectionName => 'document_embeddings';
  double get vectorSimilarityThreshold => 0.7;
  int get vectorMatchCount => 10;

  // Milvus Configuration (keeping for potential future use)
  String get milvusHost => 'your_milvus_host';
  int get milvusPort => 19530;
  String get milvusCollection => 'legal_documents_mexico';
  String get milvusUsername => '';
  String get milvusPassword => '';

  // ============================================
  // STORAGE CONFIGURATION
  // ============================================
  String get storageBucketName => 'legal-documents';
  int get storageMaxFileSize => 52428800;
  List<String> get allowedFileTypes => ['pdf', 'docx', 'txt', 'md'];

  // ============================================
  // APPLICATION CONFIGURATION
  // ============================================
  String get appEnv => 'development';
  String get appName => 'LegalTracking RAG System';
  String get appVersion => '1.0.0';
  int get appPort => 3000;

  // API Configuration
  int get apiTimeout => 30000;
  int get maxRetries => 3;
  int get rateLimitRequests => 100;
  int get rateLimitWindow => 60000;

  // Logging
  bool get enableLogging => true;
  String get logLevel => 'info';
  bool get logToFile => true;
  String get logFilePath => '/var/log/legaltracking/app.log';

  // ============================================
  // SECURITY CONFIGURATION
  // ============================================
  String get jwtSecret => '729a0aedea81dea8ffb29e3ce6af8e6c60ee8c264470bdeee86f557738838f1f';
  String get sessionSecret => 'your_session_secret_here';
  List<String> get corsOrigins => ['http://localhost:3000', 'http://5.161.120.86:3000'];
  bool get secureCookies => false;

  // ============================================
  // FEATURE FLAGS
  // ============================================
  bool get enableChatHistory => true;
  bool get enableDocumentUpload => true;
  bool get enableVectorSearch => true;
  bool get enablePremiumFeatures => false;
  bool get enableUserAuthentication => true;
  bool get enableRAGSystem => true;
  bool get enableDocumentOCR => false;
  bool get enableMultiLanguage => true;
  bool get enableAnalytics => true;

  // ============================================
  // RAG SYSTEM CONFIGURATION
  // ============================================
  int get chunkSize => 1000;
  int get chunkOverlap => 200;
  int get minChunkSize => 100;

  // Retrieval Configuration
  int get retrievalTopK => 5;
  bool get rerankEnabled => false;
  bool get hybridSearchEnabled => false;

  // Response Generation
  int get maxContextLength => 4000;
  int get maxResponseLength => 2000;
  double get temperature => 0.7;
  bool get streamingEnabled => true;

  // ============================================
  // HELPER METHODS
  // ============================================
  bool get isDevelopment => appEnv == 'development';
  bool get isProduction => appEnv == 'production';
  bool get isStaging => appEnv == 'staging';

  /// Check if using Supabase vector store
  bool get isUsingSupabaseVectors => vectorStoreType == 'supabase';

  /// Check if Milvus credentials are configured
  bool get hasMilvusAuth => milvusUsername.isNotEmpty && milvusPassword.isNotEmpty;

  /// Check if AI services are configured
  bool get hasAIConfiguration => 
      deepSeekApiKey.isNotEmpty || 
      openRouterApiKey.isNotEmpty || 
      openAIApiKey.isNotEmpty;

  /// Check if database is properly configured
  bool get hasDatabaseConfiguration => 
      databaseHost.isNotEmpty && databasePassword.isNotEmpty;

  /// Get the appropriate database URL based on environment
  String get databaseUrl => isProduction ? databasePooledUrl : databaseDirectUrl;

  /// Get all configured API endpoints as a map
  Map<String, String> get apiEndpoints => {
        'base': apiBaseUrl,
        'rest': restApiUrl,
        'auth': authApiUrl,
        'storage': storageApiUrl,
        'realtime': realtimeApiUrl,
        'functions': functionsApiUrl,
      };

  /// Log current configuration (for debugging, excludes sensitive data)
  void logConfiguration() {
    if (!enableLogging) return;

    print('=== LegalTracking Configuration ===');
    print('Environment: $appEnv');
    print('Supabase URL: $supabaseUrl');
    print('Database Host: $databaseHost:$databasePort');
    print('Vector Store: $vectorStoreType');
    print('Features Enabled:');
    print('  - Chat History: $enableChatHistory');
    print('  - Document Upload: $enableDocumentUpload');
    print('  - RAG System: $enableRAGSystem');
    print('  - Vector Search: $enableVectorSearch');
    print('================================');
  }
}