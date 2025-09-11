/// API Constants and Endpoints
class ApiConstants {
  // Prevent instantiation
  ApiConstants._();
  
  // API Versions
  static const String apiVersion = 'v1';
  
  // Timeouts (in milliseconds)
  static const int defaultTimeout = 30000;
  static const int uploadTimeout = 60000;
  static const int downloadTimeout = 60000;
  
  // Retry Configuration
  static const int maxRetries = 3;
  static const int retryDelay = 1000; // milliseconds
  
  // Pagination
  static const int defaultPageSize = 20;
  static const int maxPageSize = 100;
  
  // Cache Duration
  static const Duration defaultCacheDuration = Duration(hours: 1);
  static const Duration searchCacheDuration = Duration(minutes: 30);
  static const Duration documentCacheDuration = Duration(days: 7);
  
  // DeepSeek API
  static const String deepSeekBaseUrl = 'https://api.deepseek.com/v1';
  static const String deepSeekModel = 'deepseek-reasoner';
  static const double deepSeekTemperature = 0.6;
  static const int deepSeekMaxTokens = 32768;
  
  // OpenRouter API
  static const String openRouterBaseUrl = 'https://openrouter.ai/api/v1';
  static const String openRouterModel = 'qwen/qwen3-235b-a22b-thinking-2507';
  
  // Milvus Endpoints
  static const String milvusSearchEndpoint = '/search';
  static const String milvusInsertEndpoint = '/insert';
  static const String milvusDeleteEndpoint = '/delete';
  static const String milvusUpdateEndpoint = '/update';
  
  // Supabase Tables
  static const String usersTable = 'users';
  static const String searchHistoryTable = 'search_history';
  static const String documentsTable = 'documents';
  static const String savedQueriesTable = 'saved_queries';
  static const String chatSessionsTable = 'chat_sessions';
  static const String citationsTable = 'citations';
  
  // Supabase Storage Buckets
  static const String documentsBucket = 'documents';
  static const String userUploadsBucket = 'user-uploads';
  
  // Rate Limiting
  static const int requestsPerMinute = 60;
  static const int requestsPerHour = 1000;
  static const int requestsPerDay = 10000;
  
  // Vector Search Configuration
  static const int vectorDimension = 1536;
  static const int topK = 10; // Number of similar documents to retrieve
  static const double similarityThreshold = 0.7;
  
  // Legal Document Types
  static const List<String> documentTypes = [
    'codigo_civil',
    'codigo_penal',
    'codigo_comercio',
    'constitucion',
    'jurisprudencia',
    'doctrina',
    'reglamento',
    'ley_federal',
    'ley_estatal',
    'acuerdo',
    'decreto',
    'norma_oficial',
  ];
  
  // Jurisdictions
  static const List<String> jurisdictions = [
    'federal',
    'cdmx',
    'aguascalientes',
    'baja_california',
    'baja_california_sur',
    'campeche',
    'chiapas',
    'chihuahua',
    'coahuila',
    'colima',
    'durango',
    'guanajuato',
    'guerrero',
    'hidalgo',
    'jalisco',
    'mexico',
    'michoacan',
    'morelos',
    'nayarit',
    'nuevo_leon',
    'oaxaca',
    'puebla',
    'queretaro',
    'quintana_roo',
    'san_luis_potosi',
    'sinaloa',
    'sonora',
    'tabasco',
    'tamaulipas',
    'tlaxcala',
    'veracruz',
    'yucatan',
    'zacatecas',
  ];
  
  // Citation Formats
  static const List<String> citationFormats = [
    'APA',
    'MLA',
    'Chicago',
    'Harvard',
    'Legal',
    'SCJN',
  ];
  
  // Search Filters
  static const Map<String, String> searchFilters = {
    'all': 'Todos',
    'recent': 'Recientes',
    'relevant': 'M�s Relevantes',
    'cited': 'M�s Citados',
    'federal': 'Federal',
    'state': 'Estatal',
  };
  
  // Error Messages
  static const Map<String, String> errorMessages = {
    'network_error': 'Error de conexi�n. Por favor verifica tu internet.',
    'timeout_error': 'La solicitud tard� demasiado. Intenta de nuevo.',
    'server_error': 'Error del servidor. Por favor intenta m�s tarde.',
    'auth_error': 'Error de autenticaci�n. Por favor inicia sesi�n nuevamente.',
    'permission_error': 'No tienes permisos para realizar esta acci�n.',
    'validation_error': 'Por favor verifica los datos ingresados.',
    'not_found': 'No se encontr� el recurso solicitado.',
    'rate_limit': 'Has excedido el l�mite de solicitudes. Espera un momento.',
    'unknown_error': 'Ocurri� un error inesperado. Por favor intenta de nuevo.',
  };
  
  // Success Messages
  static const Map<String, String> successMessages = {
    'login_success': 'Inicio de sesi�n exitoso',
    'signup_success': 'Cuenta creada exitosamente',
    'logout_success': 'Sesi�n cerrada exitosamente',
    'password_reset': 'Enlace de restablecimiento enviado',
    'profile_updated': 'Perfil actualizado exitosamente',
    'document_saved': 'Documento guardado exitosamente',
    'query_saved': 'B�squeda guardada exitosamente',
    'citation_copied': 'Cita copiada al portapapeles',
  };
  
  // Regular Expressions
  static final RegExp emailRegex = RegExp(
    r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$',
  );
  
  static final RegExp phoneRegex = RegExp(
    r'^\+?[1-9]\d{1,14}$',
  );
  
  static final RegExp passwordRegex = RegExp(
    r'^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)(?=.*[@$!%*?&])[A-Za-z\d@$!%*?&]{8,}$',
  );
  
  // Headers
  static Map<String, String> getHeaders({String? token}) {
    final headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      'X-App-Version': '1.0.0',
    };
    
    if (token != null) {
      headers['Authorization'] = 'Bearer $token';
    }
    
    return headers;
  }
  
  // Build URL with query parameters
  static String buildUrl(String baseUrl, Map<String, dynamic> params) {
    if (params.isEmpty) return baseUrl;
    
    final queryString = params.entries
        .where((e) => e.value != null)
        .map((e) => '${e.key}=${Uri.encodeComponent(e.value.toString())}')
        .join('&');
    
    return '$baseUrl?$queryString';
  }
}