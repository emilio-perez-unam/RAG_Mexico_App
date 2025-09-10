import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';
import 'package:legal_rag_mexico/core/config/env_config.dart';

/// Authentication datasource for Supabase Auth
abstract class AuthDatasource {
  /// Current user
  User? get currentUser;
  
  /// Current session
  Session? get currentSession;
  
  /// Auth state changes stream
  Stream<AuthState> get authStateChanges;
  
  /// Sign up with email and password
  Future<AuthResponse> signUp({
    required String email,
    required String password,
    Map<String, dynamic>? metadata,
  });
  
  /// Sign in with email and password
  Future<AuthResponse> signIn({
    required String email,
    required String password,
  });
  
  /// Sign in with OAuth provider
  Future<bool> signInWithProvider(OAuthProvider provider);
  
  /// Sign out
  Future<void> signOut();
  
  /// Reset password
  Future<void> resetPassword(String email);
  
  /// Update user
  Future<UserResponse> updateUser({
    String? email,
    String? password,
    Map<String, dynamic>? metadata,
  });
  
  /// Verify OTP
  Future<AuthResponse> verifyOTP({
    required String token,
    required OtpType type,
    String? email,
    String? phone,
  });
  
  /// Refresh session
  Future<AuthResponse> refreshSession();
  
  /// Set session
  Future<void> setSession(String refreshToken);
}

/// Implementation of AuthDatasource using Supabase
class AuthDatasourceImpl implements AuthDatasource {
  final SupabaseClient _supabaseClient;
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
  
  AuthDatasourceImpl({required SupabaseClient supabaseClient})
      : _supabaseClient = supabaseClient {
    _logger.i('AuthDatasourceImpl initialized');
  }
  
  @override
  User? get currentUser {
    final user = _supabaseClient.auth.currentUser;
    _logger.d('Getting current user: ${user?.email ?? 'null'}');
    return user;
  }
  
  @override
  Session? get currentSession {
    final session = _supabaseClient.auth.currentSession;
    _logger.d('Getting current session: ${session != null ? 'exists' : 'null'}');
    return session;
  }
  
  @override
  Stream<AuthState> get authStateChanges {
    _logger.d('Setting up auth state change listener');
    return _supabaseClient.auth.onAuthStateChange.map((authState) {
      _logger.i('Auth state changed: ${authState.event}, User: ${authState.session?.user.email ?? 'null'}');
      return authState;
    });
  }
  
  @override
  Future<AuthResponse> signUp({
    required String email,
    required String password,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      _logger.i('Datasource: Attempting sign up for $email');
      _logger.d('Metadata: $metadata');
      
      final response = await _supabaseClient.auth.signUp(
        email: email,
        password: password,
        data: metadata,
      );
      
      _logger.d('Sign up response received');
      _logger.d('Response user: ${response.user?.email ?? 'null'}');
      
      if (response.user == null) {
        _logger.w('Sign up response has null user');
        throw const AuthException('Sign up failed: No user returned');
      }
      
      _logger.i('Datasource: Sign up successful for ${response.user!.email}');
      return response;
    } on AuthException catch (e, stackTrace) {
      _logger.e('AuthException during sign up: ${e.message}', error: e, stackTrace: stackTrace);
      debugPrint('Sign up error: ${e.message}');
      rethrow;
    } catch (e, stackTrace) {
      _logger.e('Unexpected sign up error', error: e, stackTrace: stackTrace);
      debugPrint('Unexpected sign up error: $e');
      throw AuthException('Sign up failed: $e');
    }
  }
  
  @override
  Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) async {
    try {
      _logger.i('Datasource: Attempting sign in for $email');
      _logger.d('Calling Supabase signInWithPassword');
      
      // Debug: Print what's being sent
      print('===== SUPABASE AUTH REQUEST =====');
      print('Supabase URL: ${EnvConfig.instance.supabaseUrl}');
      print('Email being sent: $email');
      print('Password length: ${password.length} characters');
      print('Auth endpoint: ${EnvConfig.instance.supabaseUrl}/auth/v1/token?grant_type=password');
      print('================================');
      
      final response = await _supabaseClient.auth.signInWithPassword(
        email: email,
        password: password,
      );
      
      _logger.d('Supabase response received');
      _logger.d('Response user: ${response.user?.email ?? 'null'}');
      _logger.d('Response session: ${response.session != null ? 'exists' : 'null'}');
      
      if (response.user == null) {
        _logger.w('Sign in response has null user');
        throw const AuthException('Sign in failed: Invalid credentials');
      }
      
      _logger.i('Datasource: Sign in successful for ${response.user!.email}');
      return response;
    } on AuthException catch (e, stackTrace) {
      _logger.e('AuthException during sign in: ${e.message}', error: e, stackTrace: stackTrace);
      debugPrint('Sign in error: ${e.message}');
      rethrow;
    } catch (e, stackTrace) {
      _logger.e('Unexpected sign in error', error: e, stackTrace: stackTrace);
      debugPrint('Unexpected sign in error: $e');
      throw AuthException('Sign in failed: $e');
    }
  }
  
  @override
  Future<bool> signInWithProvider(OAuthProvider provider) async {
    try {
      final response = await _supabaseClient.auth.signInWithOAuth(
        provider,
        redirectTo: kIsWeb ? null : 'io.supabase.legalragmexico://login-callback/',
      );
      
      return response;
    } on AuthException catch (e) {
      debugPrint('OAuth sign in error: ${e.message}');
      rethrow;
    } catch (e) {
      debugPrint('Unexpected OAuth sign in error: $e');
      throw AuthException('OAuth sign in failed: $e');
    }
  }
  
  @override
  Future<void> signOut() async {
    try {
      _logger.i('Datasource: Attempting sign out');
      await _supabaseClient.auth.signOut();
      _logger.i('Datasource: Sign out successful');
    } on AuthException catch (e, stackTrace) {
      _logger.e('AuthException during sign out: ${e.message}', error: e, stackTrace: stackTrace);
      debugPrint('Sign out error: ${e.message}');
      rethrow;
    } catch (e, stackTrace) {
      _logger.e('Unexpected sign out error', error: e, stackTrace: stackTrace);
      debugPrint('Unexpected sign out error: $e');
      throw AuthException('Sign out failed: $e');
    }
  }
  
  @override
  Future<void> resetPassword(String email) async {
    try {
      _logger.i('Datasource: Requesting password reset for $email');
      await _supabaseClient.auth.resetPasswordForEmail(
        email,
        redirectTo: kIsWeb ? null : 'io.supabase.legalragmexico://reset-callback/',
      );
      _logger.i('Datasource: Password reset email sent successfully');
    } on AuthException catch (e, stackTrace) {
      _logger.e('AuthException during password reset: ${e.message}', error: e, stackTrace: stackTrace);
      debugPrint('Reset password error: ${e.message}');
      rethrow;
    } catch (e, stackTrace) {
      _logger.e('Unexpected password reset error', error: e, stackTrace: stackTrace);
      debugPrint('Unexpected reset password error: $e');
      throw AuthException('Reset password failed: $e');
    }
  }
  
  @override
  Future<UserResponse> updateUser({
    String? email,
    String? password,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      final response = await _supabaseClient.auth.updateUser(
        UserAttributes(
          email: email,
          password: password,
          data: metadata,
        ),
      );
      
      if (response.user == null) {
        throw const AuthException('Update user failed: No user returned');
      }
      
      return response;
    } on AuthException catch (e) {
      debugPrint('Update user error: ${e.message}');
      rethrow;
    } catch (e) {
      debugPrint('Unexpected update user error: $e');
      throw AuthException('Update user failed: $e');
    }
  }
  
  @override
  Future<AuthResponse> verifyOTP({
    required String token,
    required OtpType type,
    String? email,
    String? phone,
  }) async {
    try {
      final response = await _supabaseClient.auth.verifyOTP(
        token: token,
        type: type,
        email: email,
        phone: phone,
      );
      
      if (response.user == null) {
        throw const AuthException('OTP verification failed');
      }
      
      return response;
    } on AuthException catch (e) {
      debugPrint('OTP verification error: ${e.message}');
      rethrow;
    } catch (e) {
      debugPrint('Unexpected OTP verification error: $e');
      throw AuthException('OTP verification failed: $e');
    }
  }
  
  @override
  Future<AuthResponse> refreshSession() async {
    try {
      _logger.d('Datasource: Refreshing session');
      final response = await _supabaseClient.auth.refreshSession();
      
      if (response.session == null) {
        _logger.w('Session refresh returned null session');
        throw const AuthException('Session refresh failed');
      }
      
      _logger.d('Datasource: Session refreshed successfully');
      return response;
    } on AuthException catch (e, stackTrace) {
      _logger.e('AuthException during session refresh: ${e.message}', error: e, stackTrace: stackTrace);
      debugPrint('Session refresh error: ${e.message}');
      rethrow;
    } catch (e, stackTrace) {
      _logger.e('Unexpected session refresh error', error: e, stackTrace: stackTrace);
      debugPrint('Unexpected session refresh error: $e');
      throw AuthException('Session refresh failed: $e');
    }
  }
  
  @override
  Future<void> setSession(String refreshToken) async {
    try {
      await _supabaseClient.auth.setSession(refreshToken);
    } on AuthException catch (e) {
      debugPrint('Set session error: ${e.message}');
      rethrow;
    } catch (e) {
      debugPrint('Unexpected set session error: $e');
      throw AuthException('Set session failed: $e');
    }
  }
}

/// Auth exception wrapper for consistent error handling
class AuthExceptionWrapper {
  final String message;
  final String? code;
  final dynamic originalException;
  
  AuthExceptionWrapper({
    required this.message,
    this.code,
    this.originalException,
  });
  
  /// Check if error is due to unverified email
  bool get isEmailNotVerified => code == 'email_not_confirmed';
  
  /// Check if error is due to invalid credentials
  bool get isInvalidCredentials => code == 'invalid_credentials';
  
  /// Check if error is due to user already exists
  bool get isUserAlreadyExists => code == 'user_already_exists';
  
  /// Check if error is due to weak password
  bool get isWeakPassword => code == 'weak_password';
  
  /// Check if error is due to rate limiting
  bool get isRateLimited => code == 'rate_limit_exceeded';
  
  /// Get user-friendly error message
  String get userMessage {
    switch (code) {
      case 'email_not_confirmed':
        return 'Please verify your email address before signing in.';
      case 'invalid_credentials':
        return 'Invalid email or password. Please try again.';
      case 'user_already_exists':
        return 'An account with this email already exists.';
      case 'weak_password':
        return 'Password is too weak. Please use a stronger password.';
      case 'rate_limit_exceeded':
        return 'Too many attempts. Please try again later.';
      default:
        return message;
    }
  }
}