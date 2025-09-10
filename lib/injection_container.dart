import 'package:get_it/get_it.dart';
import 'package:logger/logger.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:dio/dio.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hive_flutter/hive_flutter.dart';

// Core
import 'core/config/env_config.dart';
import 'core/network/network_info.dart';

// Data Sources
import 'data/datasources/remote/auth_datasource.dart';
import 'data/datasources/remote/deepseek_datasource.dart';
import 'data/datasources/remote/milvus_datasource.dart';
import 'data/datasources/remote/openrouter_datasource.dart';
import 'data/datasources/remote/document_datasource.dart';
import 'data/datasources/local/search_history_local_datasource.dart';
import 'data/datasources/local/settings_local_datasource.dart';

// Repositories
import 'data/repositories/auth_repository_impl.dart';
import 'data/repositories/legal_search_repository_impl.dart';
import 'data/repositories/document_repository_impl.dart';
import 'data/repositories/settings_repository_impl.dart';
import 'domain/repositories/auth_repository.dart';
import 'domain/repositories/legal_search_repository.dart';
import 'domain/repositories/document_repository.dart';
import 'domain/repositories/settings_repository.dart';

// Use Cases
import 'domain/usecases/search_legal_documents.dart';
import 'domain/usecases/get_document_details.dart';
import 'domain/usecases/save_search_history.dart';
import 'domain/usecases/copy_citation.dart';
import 'domain/usecases/update_settings.dart';

// Services
import 'domain/services/legal_rag_service.dart';

// Providers
import 'presentation/providers/auth_provider.dart';
import 'presentation/providers/search_provider.dart';
import 'presentation/providers/settings_provider.dart';
import 'presentation/providers/history_provider.dart';
import 'presentation/providers/filter_provider.dart';

final GetIt sl = GetIt.instance;
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

/// Initialize all dependencies
Future<void> initializeDependencies() async {
  _logger.i('Starting dependency injection initialization');
  
  try {
    // Core
    _logger.d('Initializing core dependencies');
    await _initCore();
    _logger.d('Core dependencies initialized');
    
    // External
    _logger.d('Initializing external dependencies');
    await _initExternal();
    _logger.d('External dependencies initialized');
    
    // Data Sources
    _logger.d('Initializing data sources');
    _initDataSources();
    _logger.d('Data sources initialized');
    
    // Repositories
    _logger.d('Initializing repositories');
    _initRepositories();
    _logger.d('Repositories initialized');
    
    // Use Cases
    _logger.d('Initializing use cases');
    _initUseCases();
    _logger.d('Use cases initialized');
    
    // Services
    _logger.d('Initializing services');
    _initServices();
    _logger.d('Services initialized');
    
    // Providers
    _logger.d('Initializing providers');
    _initProviders();
    _logger.d('Providers initialized');
    
    _logger.i('Dependency injection initialization complete');
  } catch (e, stackTrace) {
    _logger.e('Failed to initialize dependencies', error: e, stackTrace: stackTrace);
    rethrow;
  }
}

/// Initialize core dependencies
Future<void> _initCore() async {
  try {
    // Environment Configuration
    _logger.d('Loading EnvConfig');
    await EnvConfig.initialize();
    sl.registerLazySingleton<EnvConfig>(() => EnvConfig.instance);
    _logger.d('EnvConfig registered');
    
    // Network Info
    _logger.d('Registering NetworkInfo');
    sl.registerLazySingleton<NetworkInfo>(() => NetworkInfoImpl());
    _logger.d('NetworkInfo registered');
  } catch (e, stackTrace) {
    _logger.e('Failed to initialize core dependencies', error: e, stackTrace: stackTrace);
    rethrow;
  }
}

/// Initialize external dependencies
Future<void> _initExternal() async {
  try {
    // Supabase
    _logger.d('Initializing Supabase with URL: ${EnvConfig.instance.supabaseUrl}');
    
    // Debug: Print exact configuration being used
    print('===== SUPABASE INITIALIZATION =====');
    print('URL from ENV: ${EnvConfig.instance.supabaseUrl}');
    print('Anon Key from ENV: ${EnvConfig.instance.supabaseAnonKey.substring(0, 20)}...');
    print('===================================');
    
    await Supabase.initialize(
      url: EnvConfig.instance.supabaseUrl,
      anonKey: EnvConfig.instance.supabaseAnonKey,
    );
    sl.registerLazySingleton<SupabaseClient>(() => Supabase.instance.client);
    _logger.i('Supabase initialized and registered');
  
    // HTTP Clients
    _logger.d('Registering HTTP client');
    sl.registerLazySingleton<http.Client>(() => http.Client());
    _logger.d('HTTP client registered');
    
    // Dio
    _logger.d('Configuring Dio with timeout: ${EnvConfig.instance.apiTimeout}ms');
    final dio = Dio(BaseOptions(
      connectTimeout: Duration(milliseconds: EnvConfig.instance.apiTimeout),
      receiveTimeout: Duration(milliseconds: EnvConfig.instance.apiTimeout),
      sendTimeout: Duration(milliseconds: EnvConfig.instance.apiTimeout),
    ));
    
    // Add interceptors for logging if enabled
    if (EnvConfig.instance.enableLogging) {
      _logger.d('Adding Dio logging interceptor');
      dio.interceptors.add(LogInterceptor(
        requestBody: true,
        responseBody: true,
        error: true,
      ));
    }
    
    sl.registerLazySingleton<Dio>(() => dio);
    _logger.d('Dio configured and registered');
  
    // Shared Preferences
    _logger.d('Initializing SharedPreferences');
    final sharedPreferences = await SharedPreferences.getInstance();
    sl.registerLazySingleton<SharedPreferences>(() => sharedPreferences);
    _logger.d('SharedPreferences initialized and registered');
    
    // Hive
    _logger.d('Initializing Hive');
    await Hive.initFlutter();
    _logger.d('Hive initialized');
    // Open boxes as needed
    // Example: await Hive.openBox('settings');
    // Example: await Hive.openBox('search_history');
  } catch (e, stackTrace) {
    _logger.e('Failed to initialize external dependencies', error: e, stackTrace: stackTrace);
    rethrow;
  }
}

/// Initialize data sources
void _initDataSources() {
  try {
    // Remote Data Sources
    _logger.d('Registering AuthDatasource');
    sl.registerLazySingleton<AuthDatasource>(
      () => AuthDatasourceImpl(
        supabaseClient: sl<SupabaseClient>(),
      ),
    );
    _logger.d('AuthDatasource registered');
  
    _logger.d('Registering DeepSeekDatasource');
    sl.registerLazySingleton<DeepSeekDatasource>(
      () => DeepSeekDatasource(
        apiKey: EnvConfig.instance.deepSeekApiKey,
        httpClient: sl<http.Client>(),
      ),
    );
    
    _logger.d('Registering MilvusDatasource');
    sl.registerLazySingleton<MilvusDatasource>(
      () => MilvusDatasource(
        host: EnvConfig.instance.milvusHost,
        port: EnvConfig.instance.milvusPort,
        collection: EnvConfig.instance.milvusCollection,
        username: EnvConfig.instance.milvusUsername,
        password: EnvConfig.instance.milvusPassword,
        dio: sl<Dio>(),
      ),
    );
    
    _logger.d('Registering OpenRouterDatasource');
    sl.registerLazySingleton<OpenRouterDatasource>(
      () => OpenRouterDatasource(
        apiKey: EnvConfig.instance.openRouterApiKey,
        baseUrl: EnvConfig.instance.openRouterBaseUrl,
        dio: sl<Dio>(),
      ),
    );
    
    _logger.d('Registering DocumentDatasource');
    sl.registerLazySingleton<DocumentDatasource>(
      () => DocumentDatasourceImpl(sl<SupabaseClient>()),
    );
    
    // Local Data Sources
    _logger.d('Registering local data sources');
    sl.registerLazySingleton<SearchHistoryLocalDatasource>(
      () => SearchHistoryLocalDatasourceImpl(),
    );
    
    sl.registerLazySingleton<SettingsLocalDatasource>(
      () => SettingsLocalDatasourceImpl(sl<SharedPreferences>()),
    );
    _logger.d('All data sources registered successfully');
  } catch (e, stackTrace) {
    _logger.e('Failed to initialize data sources', error: e, stackTrace: stackTrace);
    rethrow;
  }
}

/// Initialize repositories
void _initRepositories() {
  sl.registerLazySingleton<AuthRepository>(
    () => AuthRepositoryImpl(
      authDatasource: sl<AuthDatasource>(),
    ),
  );
  
  sl.registerLazySingleton<LegalSearchRepository>(
    () => LegalSearchRepositoryImpl(
      deepSeekDatasource: sl<DeepSeekDatasource>(),
      milvusDatasource: sl<MilvusDatasource>(),
      searchHistoryDatasource: sl<SearchHistoryLocalDatasource>(),
    ),
  );
  
  sl.registerLazySingleton<DocumentRepository>(
    () => DocumentRepositoryImpl(
      documentDatasource: sl<DocumentDatasource>(),
    ),
  );
  
  sl.registerLazySingleton<SettingsRepository>(
    () => SettingsRepositoryImpl(
      settingsLocalDatasource: sl<SettingsLocalDatasource>(),
    ),
  );
}

/// Initialize use cases
void _initUseCases() {
  sl.registerLazySingleton<SearchLegalDocuments>(
    () => SearchLegalDocuments(
      repository: sl<LegalSearchRepository>(),
    ),
  );
  
  sl.registerLazySingleton<GetDocumentDetails>(
    () => GetDocumentDetails(
      repository: sl<DocumentRepository>(),
    ),
  );
  
  sl.registerLazySingleton<SaveSearchHistory>(
    () => SaveSearchHistory(
      repository: sl<LegalSearchRepository>(),
    ),
  );
  
  sl.registerLazySingleton<CopyCitation>(
    () => CopyCitation(),
  );
  
  sl.registerLazySingleton<UpdateSettings>(
    () => UpdateSettings(
      repository: sl<SettingsRepository>(),
    ),
  );
}

/// Initialize services
void _initServices() {
  sl.registerLazySingleton<LegalRagService>(
    () => LegalRagService(
      apiKey: EnvConfig.instance.deepSeekApiKey,
    ),
  );
}

/// Initialize providers
void _initProviders() {
  sl.registerFactory<AuthProvider>(
    () => AuthProvider(
      authRepository: sl<AuthRepository>(),
    ),
  );
  
  sl.registerFactory<SearchProvider>(
    () => SearchProvider(
      searchLegalDocuments: sl<SearchLegalDocuments>(),
      saveSearchHistory: sl<SaveSearchHistory>(),
    ),
  );
  
  sl.registerFactory<SettingsProvider>(
    () => SettingsProvider(
      updateSettings: sl<UpdateSettings>(),
      settingsRepository: sl<SettingsRepository>(),
    ),
  );
  
  sl.registerFactory<HistoryProvider>(
    () => HistoryProvider(
      legalSearchRepository: sl<LegalSearchRepository>(),
    ),
  );
  
  sl.registerFactory<FilterProvider>(
    () => FilterProvider(),
  );
}

