import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:dio/dio.dart';

/// Centralized error handling service
class ErrorHandlingService {
  static final ErrorHandlingService _instance = ErrorHandlingService._internal();
  factory ErrorHandlingService() => _instance;
  ErrorHandlingService._internal();

  /// Handle and format errors
  String handleError(dynamic error, [StackTrace? stackTrace]) {
    // Log error in debug mode
    if (kDebugMode) {
      print('Error: $error');
      if (stackTrace != null) {
        print('Stack trace: $stackTrace');
      }
    }

    // Handle different error types
    if (error is AuthException) {
      return _handleAuthError(error);
    } else if (error is PostgrestException) {
      return _handlePostgrestError(error);
    } else if (error is DioException) {
      return _handleDioError(error);
    } else if (error is FormatException) {
      return 'Formato de datos inválido. Por favor intenta de nuevo.';
    } else if (error is TypeError) {
      return 'Error de tipo de datos. Por favor contacta soporte.';
    } else if (error.toString().contains('SocketException')) {
      return 'Error de conexión. Por favor verifica tu internet.';
    } else if (error.toString().contains('TimeoutException')) {
      return 'La solicitud tardó demasiado. Intenta de nuevo.';
    } else {
      return error.toString().contains('Exception:') 
          ? error.toString().replaceAll('Exception:', '').trim()
          : 'Ocurrió un error inesperado. Por favor intenta de nuevo.';
    }
  }

  /// Handle authentication errors
  String _handleAuthError(AuthException error) {
    switch (error.message.toLowerCase()) {
      case String m when m.contains('email not confirmed'):
        return 'Por favor verifica tu correo electrónico antes de iniciar sesión.';
      case String m when m.contains('invalid login credentials'):
        return 'Credenciales inválidas. Por favor verifica tu correo y contraseña.';
      case String m when m.contains('user already registered'):
        return 'Este correo ya está registrado. Por favor inicia sesión.';
      case String m when m.contains('password'):
        return 'La contraseña debe tener al menos 8 caracteres con mayúsculas, minúsculas y números.';
      case String m when m.contains('rate limit'):
        return 'Demasiados intentos. Por favor espera unos minutos.';
      case String m when m.contains('network'):
        return 'Error de conexión. Por favor verifica tu internet.';
      default:
        return error.message;
    }
  }

  /// Handle Postgrest/Database errors
  String _handlePostgrestError(PostgrestException error) {
    switch (error.code) {
      case '23505': // Unique violation
        return 'Este registro ya existe.';
      case '23503': // Foreign key violation
        return 'Referencia inválida. El registro relacionado no existe.';
      case '23502': // Not null violation
        return 'Faltan campos requeridos.';
      case '42501': // Insufficient privilege
        return 'No tienes permisos para realizar esta acción.';
      case '42P01': // Undefined table
        return 'Tabla no encontrada. Por favor contacta soporte.';
      case '22P02': // Invalid text representation
        return 'Formato de datos inválido.';
      case 'PGRST301': // JWT expired
        return 'Tu sesión ha expirado. Por favor inicia sesión nuevamente.';
      default:
        return error.message;
    }
  }

  /// Handle DioException/Network errors
  String _handleDioError(DioException error) {
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return 'La solicitud tardó demasiado. Intenta de nuevo.';
      
      case DioExceptionType.badResponse:
        return _handleHttpError(error.response?.statusCode);
      
      case DioExceptionType.cancel:
        return 'Solicitud cancelada.';
      
      case DioExceptionType.unknown:
        if (error.message?.contains('SocketException') ?? false) {
          return 'Error de conexión. Por favor verifica tu internet.';
        }
        return 'Ocurrió un error inesperado. Por favor intenta de nuevo.';
      
      default:
        return 'Error de conexión. Por favor verifica tu internet.';
    }
  }

  /// Handle HTTP status code errors
  String _handleHttpError(int? statusCode) {
    switch (statusCode) {
      case 400:
        return 'Solicitud inválida. Por favor verifica los datos.';
      case 401:
        return 'Error de autenticación. Por favor inicia sesión nuevamente.';
      case 403:
        return 'No tienes permisos para realizar esta acción.';
      case 404:
        return 'No se encontró el recurso solicitado.';
      case 409:
        return 'Conflicto con el estado actual del recurso.';
      case 422:
        return 'Por favor verifica los datos ingresados.';
      case 429:
        return 'Has excedido el límite de solicitudes. Espera un momento.';
      case 500:
      case 502:
      case 503:
      case 504:
        return 'Error del servidor. Por favor intenta más tarde.';
      default:
        return 'Ocurrió un error inesperado. Por favor intenta de nuevo.';
    }
  }

  /// Show error as SnackBar
  void showErrorSnackBar(BuildContext context, dynamic error) {
    final message = handleError(error);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.red.shade600,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        action: SnackBarAction(
          label: 'Cerrar',
          textColor: Colors.white,
          onPressed: () {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
          },
        ),
      ),
    );
  }

  /// Show success SnackBar
  void showSuccessSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.green.shade600,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  /// Show info SnackBar
  void showInfoSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.info_outline, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.blue.shade600,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  /// Show error dialog
  Future<void> showErrorDialog(
    BuildContext context, {
    required String title,
    required String message,
    String? details,
  }) async {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.error_outline, color: Colors.red.shade700),
            const SizedBox(width: 8),
            Text(title),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(message),
            if (details != null && kDebugMode) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  details,
                  style: const TextStyle(
                    fontSize: 12,
                    fontFamily: 'monospace',
                  ),
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  /// Handle and report critical errors
  Future<void> reportCriticalError({
    required dynamic error,
    required StackTrace stackTrace,
    Map<String, dynamic>? additionalData,
  }) async {
    // Log to console in debug mode
    if (kDebugMode) {
      print('CRITICAL ERROR: $error');
      print('Stack trace: $stackTrace');
      if (additionalData != null) {
        print('Additional data: $additionalData');
      }
    }

    // In production, you would send this to a crash reporting service
    // like Sentry, Firebase Crashlytics, etc.
    // Example:
    // await Sentry.captureException(
    //   error,
    //   stackTrace: stackTrace,
    //   withScope: (scope) {
    //     if (additionalData != null) {
    //       additionalData.forEach((key, value) {
    //         scope.setExtra(key, value);
    //       });
    //     }
    //   },
    // );
  }
}

/// Extension for easy error handling on Futures
extension ErrorHandlingExtension<T> on Future<T> {
  Future<T?> handleError(BuildContext context) async {
    try {
      return await this;
    } catch (error, stackTrace) {
      ErrorHandlingService().showErrorSnackBar(context, error);
      if (kDebugMode) {
        print('Error in Future: $error');
        print('Stack trace: $stackTrace');
      }
      return null;
    }
  }
}