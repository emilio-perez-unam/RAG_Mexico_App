import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Environment configuration class for managing app configuration
/// Provides typed access to environment variables with validation
class EnvConfig {
  static late EnvConfig _instance;

  // Private constructor
  EnvConfig._();

  /// Initialize the environment configuration
  /// Must be called before accessing any configuration values
  static Future<void> initialize() async {
    await dotenv.load(fileName: '.env');
    _instance = EnvConfig._();
    _instance._validate();
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

  /// Validate required environment variables
  void _validate() {
    final required = [
      'SUPABASE_URL',
      'SUPABASE_ANON_KEY',
    ];

    // Check for required Supabase configuration
    for (final key in required) {
      if (!dotenv.isEveryDefined([key]) ||
          dotenv.get(key, fallback: '').isEmpty) {
        print('Warning: Environment variable $key is not configured.');
      }
    }

    // Validate URLs
    if (supabaseUrl.isNotEmpty && !Uri.tryParse(supabaseUrl)!.hasScheme) {
      print('Warning: SUPABASE_URL appears to be invalid');
    }
  }

  // ============================================
  // SUPABASE CONFIGURATION
  // ============================================
  String get supabaseUrl =>
      dotenv.get('SUPABASE_URL', fallback: 'http://5.161.120.86:8000');
  String get supabaseAnonKey => dotenv.get('SUPABASE_ANON_KEY',
      fallback:
          'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InhjdmJua2xqZGZqYXNkZmFzZGZhc2RmIiwicm9sZSI6ImFub24iLCJpYXQiOjE2NDU0NDY0MDAsImV4cCI6MTk2MTAyMjQwMH0.33m6Mkc5HU4nzuuZdVEeVDELxRVLaD8Bpvyg4THcXyE');
  String get supabaseServiceKey => dotenv.get('SUPABASE_SERVICE_ROLE_KEY',
      fallback:
          'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InhjdmJua2xqZGZqYXNkZmFzZGZhc2RmIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTY0NTQ0NjQwMCwiZXhwIjoxOTYxMDIyNDAwfQ.9v_bVZVwvxMNgEzxLR8PbPj8zTBqp7wy0OHgHIF9eH8');

  // ============================================
  // DATABASE CONFIGURATION
  // ============================================
  String get databaseHost =>
      dotenv.get('DATABASE_HOST', fallback: '5.161.120.86');
  int get databasePort =>
      int.tryParse(dotenv.get('DATABASE_PORT', fallback: '6543')) ?? 6543;
  String get databaseName => dotenv.get('DATABASE_NAME', fallback: 'postgres');
  String get databaseUser => dotenv.get('DATABASE_USER', fallback: 'postgres');
  String get databasePassword => dotenv.get('DATABASE_PASSWORD',
      fallback:
          '4b502d71c56fd186a811608c81ff61c7df6a26ea638fd79ed423dc1a8a2cb302');

  // Connection URLs
  String get databasePooledUrl => dotenv.get('DATABASE_POOLED_URL',
      fallback:
          'postgresql://postgres:4b502d71c56fd186a811608c81ff61c7df6a26ea638fd79ed423dc1a8a2cb302@5.161.120.86:6543/postgres');
  String get databaseDirectUrl => dotenv.get('DATABASE_DIRECT_URL',
      fallback:
          'postgresql://postgres:4b502d71c56fd186a811608c81ff61c7df6a26ea638fd79ed423dc1a8a2cb302@5.161.120.86:5432/postgres');

  // ============================================
  // API ENDPOINTS
  // ============================================
  String get apiBaseUrl =>
      dotenv.get('API_BASE_URL', fallback: 'http://5.161.120.86:8000');
  String get restApiUrl =>
      dotenv.get('REST_API_URL', fallback: '$apiBaseUrl/rest/v1/');
  String get authApiUrl =>
      dotenv.get('AUTH_API_URL', fallback: '$apiBaseUrl/auth/v1/');
  String get storageApiUrl =>
      dotenv.get('STORAGE_API_URL', fallback: '$apiBaseUrl/storage/v1/');
  String get realtimeApiUrl =>
      dotenv.get('REALTIME_API_URL', fallback: '$apiBaseUrl/realtime/v1/');
  String get functionsApiUrl =>
      dotenv.get('FUNCTIONS_API_URL', fallback: '$apiBaseUrl/functions/v1/');

  // ============================================
  // AI/LLM CONFIGURATION
  // ============================================
  String get deepSeekApiKey => dotenv.get('DEEPSEEK_API_KEY', fallback: '');
  String get deepSeekModel =>
      dotenv.get('DEEPSEEK_MODEL', fallback: 'deepseek-chat');
  String get openRouterApiKey => dotenv.get('OPENROUTER_API_KEY', fallback: '');
  String get openRouterBaseUrl => dotenv.get('OPENROUTER_BASE_URL',
      fallback: 'https://openrouter.ai/api/v1');
  String get openRouterModel =>
      dotenv.get('OPENROUTER_MODEL', fallback: 'deepseek/deepseek-chat');

  // OpenAI Configuration (for embeddings)
  String get openAIApiKey => dotenv.get('OPENAI_API_KEY', fallback: '');
  String get embeddingModel =>
      dotenv.get('EMBEDDING_MODEL', fallback: 'text-embedding-3-small');
  int get embeddingDimension =>
      int.tryParse(dotenv.get('EMBEDDING_DIMENSION', fallback: '1536')) ?? 1536;

  // ============================================
  // VECTOR DATABASE CONFIGURATION
  // ============================================
  String get vectorStoreType =>
      dotenv.get('VECTOR_STORE_TYPE', fallback: 'supabase');
  String get vectorCollectionName =>
      dotenv.get('VECTOR_COLLECTION_NAME', fallback: 'document_embeddings');
  double get vectorSimilarityThreshold =>
      double.tryParse(
          dotenv.get('VECTOR_SIMILARITY_THRESHOLD', fallback: '0.7')) ??
      0.7;
  int get vectorMatchCount =>
      int.tryParse(dotenv.get('VECTOR_MATCH_COUNT', fallback: '10')) ?? 10;

  // Milvus Configuration (keeping for potential future use)
  String get milvusHost => dotenv.get('MILVUS_HOST', fallback: 'localhost');
  int get milvusPort =>
      int.tryParse(dotenv.get('MILVUS_PORT', fallback: '19530')) ?? 19530;
  String get milvusCollection =>
      dotenv.get('MILVUS_COLLECTION', fallback: 'legal_documents_mexico');
  String get milvusUsername => dotenv.get('MILVUS_USERNAME', fallback: '');
  String get milvusPassword => dotenv.get('MILVUS_PASSWORD', fallback: '');

  // ============================================
  // STORAGE CONFIGURATION
  // ============================================
  String get storageBucketName =>
      dotenv.get('STORAGE_BUCKET_NAME', fallback: 'legal-documents');
  int get storageMaxFileSize =>
      int.tryParse(dotenv.get('STORAGE_MAX_FILE_SIZE', fallback: '52428800')) ??
      52428800;
  List<String> get allowedFileTypes =>
      dotenv.get('ALLOWED_FILE_TYPES', fallback: 'pdf,docx,txt,md').split(',');

  // ============================================
  // APPLICATION CONFIGURATION
  // ============================================
  String get appEnv => dotenv.get('APP_ENV', fallback: 'development');
  String get appName =>
      dotenv.get('APP_NAME', fallback: 'LegalTracking RAG System');
  String get appVersion => dotenv.get('APP_VERSION', fallback: '1.0.0');
  int get appPort =>
      int.tryParse(dotenv.get('APP_PORT', fallback: '3000')) ?? 3000;

  // API Configuration
  int get apiTimeout =>
      int.tryParse(dotenv.get('API_TIMEOUT', fallback: '30000')) ?? 30000;
  int get maxRetries =>
      int.tryParse(dotenv.get('MAX_RETRIES', fallback: '3')) ?? 3;
  int get rateLimitRequests =>
      int.tryParse(dotenv.get('RATE_LIMIT_REQUESTS', fallback: '100')) ?? 100;
  int get rateLimitWindow =>
      int.tryParse(dotenv.get('RATE_LIMIT_WINDOW', fallback: '60000')) ?? 60000;

  // Logging
  bool get enableLogging =>
      dotenv.get('ENABLE_LOGGING', fallback: 'true').toLowerCase() == 'true';
  String get logLevel => dotenv.get('LOG_LEVEL', fallback: 'info');
  bool get logToFile =>
      dotenv.get('LOG_TO_FILE', fallback: 'true').toLowerCase() == 'true';
  String get logFilePath =>
      dotenv.get('LOG_FILE_PATH', fallback: '/var/log/legaltracking/app.log');

  // ============================================
  // SECURITY CONFIGURATION
  // ============================================
  String get jwtSecret => dotenv.get('JWT_SECRET',
      fallback:
          '729a0aedea81dea8ffb29e3ce6af8e6c60ee8c264470bdeee86f557738838f1f');
  String get sessionSecret => dotenv.get('SESSION_SECRET', fallback: '');
  List<String> get corsOrigins => dotenv
      .get('CORS_ORIGIN',
          fallback: 'http://localhost:3000,http://5.161.120.86:3000')
      .split(',');
  bool get secureCookies =>
      dotenv.get('SECURE_COOKIES', fallback: 'false').toLowerCase() == 'true';

  // ============================================
  // FEATURE FLAGS
  // ============================================
  bool get enableChatHistory =>
      dotenv.get('ENABLE_CHAT_HISTORY', fallback: 'true').toLowerCase() ==
      'true';
  bool get enableDocumentUpload =>
      dotenv.get('ENABLE_DOCUMENT_UPLOAD', fallback: 'true').toLowerCase() ==
      'true';
  bool get enableVectorSearch =>
      dotenv.get('ENABLE_VECTOR_SEARCH', fallback: 'true').toLowerCase() ==
      'true';
  bool get enablePremiumFeatures =>
      dotenv.get('ENABLE_PREMIUM_FEATURES', fallback: 'false').toLowerCase() ==
      'true';
  bool get enableUserAuthentication =>
      dotenv
          .get('ENABLE_USER_AUTHENTICATION', fallback: 'true')
          .toLowerCase() ==
      'true';
  bool get enableRAGSystem =>
      dotenv.get('ENABLE_RAG_SYSTEM', fallback: 'true').toLowerCase() == 'true';
  bool get enableDocumentOCR =>
      dotenv.get('ENABLE_DOCUMENT_OCR', fallback: 'false').toLowerCase() ==
      'true';
  bool get enableMultiLanguage =>
      dotenv.get('ENABLE_MULTI_LANGUAGE', fallback: 'true').toLowerCase() ==
      'true';
  bool get enableAnalytics =>
      dotenv.get('ENABLE_ANALYTICS', fallback: 'true').toLowerCase() == 'true';

  // ============================================
  // RAG SYSTEM CONFIGURATION
  // ============================================
  int get chunkSize =>
      int.tryParse(dotenv.get('CHUNK_SIZE', fallback: '1000')) ?? 1000;
  int get chunkOverlap =>
      int.tryParse(dotenv.get('CHUNK_OVERLAP', fallback: '200')) ?? 200;
  int get minChunkSize =>
      int.tryParse(dotenv.get('MIN_CHUNK_SIZE', fallback: '100')) ?? 100;

  // Retrieval Configuration
  int get retrievalTopK =>
      int.tryParse(dotenv.get('RETRIEVAL_TOP_K', fallback: '5')) ?? 5;
  bool get rerankEnabled =>
      dotenv.get('RERANK_ENABLED', fallback: 'false').toLowerCase() == 'true';
  bool get hybridSearchEnabled =>
      dotenv.get('HYBRID_SEARCH_ENABLED', fallback: 'false').toLowerCase() ==
      'true';

  // Response Generation
  int get maxContextLength =>
      int.tryParse(dotenv.get('MAX_CONTEXT_LENGTH', fallback: '4000')) ?? 4000;
  int get maxResponseLength =>
      int.tryParse(dotenv.get('MAX_RESPONSE_LENGTH', fallback: '2000')) ?? 2000;
  double get temperature =>
      double.tryParse(dotenv.get('TEMPERATURE', fallback: '0.7')) ?? 0.7;
  bool get streamingEnabled =>
      dotenv.get('STREAMING_ENABLED', fallback: 'true').toLowerCase() == 'true';

  // ============================================
  // HELPER METHODS
  // ============================================
  bool get isDevelopment => appEnv == 'development';
  bool get isProduction => appEnv == 'production';
  bool get isStaging => appEnv == 'staging';

  /// Check if using Supabase vector store
  bool get isUsingSupabaseVectors => vectorStoreType == 'supabase';

  /// Check if Milvus credentials are configured
  bool get hasMilvusAuth =>
      milvusUsername.isNotEmpty && milvusPassword.isNotEmpty;

  /// Check if AI services are configured
  bool get hasAIConfiguration =>
      deepSeekApiKey.isNotEmpty ||
      openRouterApiKey.isNotEmpty ||
      openAIApiKey.isNotEmpty;

  /// Check if database is properly configured
  bool get hasDatabaseConfiguration =>
      databaseHost.isNotEmpty && databasePassword.isNotEmpty;

  /// Get the appropriate database URL based on environment
  String get databaseUrl =>
      isProduction ? databasePooledUrl : databaseDirectUrl;

  /// Get a custom environment variable
  String getCustom(String key, {String fallback = ''}) {
    return dotenv.get(key, fallback: fallback);
  }

  /// Check if a custom environment variable is defined
  bool isDefined(String key) {
    return dotenv.isEveryDefined([key]);
  }

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
