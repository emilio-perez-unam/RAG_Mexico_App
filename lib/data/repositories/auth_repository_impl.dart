import 'package:logger/logger.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/remote/auth_datasource.dart';

/// Implementation of AuthRepository
class AuthRepositoryImpl implements AuthRepository {
  final AuthDatasource _authDatasource;
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
  
  AuthRepositoryImpl({required AuthDatasource authDatasource})
      : _authDatasource = authDatasource {
    _logger.i('AuthRepositoryImpl initialized');
  }
  
  @override
  Future<User?> getCurrentUser() async {
    _logger.d('Getting current user');
    final user = _authDatasource.currentUser;
    _logger.d('Current user: ${user?.email ?? 'null'}');
    return user;
  }
  
  @override
  Future<Session?> getCurrentSession() async {
    _logger.d('Getting current session');
    final session = _authDatasource.currentSession;
    _logger.d('Current session exists: ${session != null}');
    return session;
  }
  
  @override
  Stream<AuthState> get authStateChanges => _authDatasource.authStateChanges;
  
  @override
  Future<AuthResponse> signUp({
    required String email,
    required String password,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      _logger.i('Repository: Sign up attempt for $email');
      final response = await _authDatasource.signUp(
        email: email,
        password: password,
        metadata: metadata,
      );
      _logger.i('Repository: Sign up successful for ${response.user?.email}');
      return response;
    } catch (e, stackTrace) {
      _logger.e('Repository: Sign up failed', error: e, stackTrace: stackTrace);
      rethrow;
    }
  }
  
  @override
  Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) async {
    try {
      _logger.i('Repository: Sign in attempt for $email');
      final response = await _authDatasource.signIn(
        email: email,
        password: password,
      );
      _logger.i('Repository: Sign in response - User: ${response.user?.email}, Session: ${response.session != null}');
      return response;
    } catch (e, stackTrace) {
      _logger.e('Repository: Sign in failed', error: e, stackTrace: stackTrace);
      rethrow;
    }
  }
  
  @override
  Future<bool> signInWithProvider(OAuthProvider provider) async {
    return await _authDatasource.signInWithProvider(provider);
  }
  
  @override
  Future<void> signOut() async {
    try {
      _logger.i('Repository: Sign out requested');
      await _authDatasource.signOut();
      _logger.i('Repository: Sign out successful');
    } catch (e, stackTrace) {
      _logger.e('Repository: Sign out failed', error: e, stackTrace: stackTrace);
      rethrow;
    }
  }
  
  @override
  Future<void> resetPassword(String email) async {
    try {
      _logger.i('Repository: Password reset requested for $email');
      await _authDatasource.resetPassword(email);
      _logger.i('Repository: Password reset email sent');
    } catch (e, stackTrace) {
      _logger.e('Repository: Password reset failed', error: e, stackTrace: stackTrace);
      rethrow;
    }
  }
  
  @override
  Future<UserResponse> updateUser({
    String? email,
    String? password,
    Map<String, dynamic>? metadata,
  }) async {
    return await _authDatasource.updateUser(
      email: email,
      password: password,
      metadata: metadata,
    );
  }
  
  @override
  Future<AuthResponse> verifyOTP({
    required String token,
    required OtpType type,
    String? email,
    String? phone,
  }) async {
    return await _authDatasource.verifyOTP(
      token: token,
      type: type,
      email: email,
      phone: phone,
    );
  }
  
  @override
  Future<AuthResponse> refreshSession() async {
    try {
      _logger.d('Repository: Refreshing session');
      final response = await _authDatasource.refreshSession();
      _logger.d('Repository: Session refresh successful');
      return response;
    } catch (e, stackTrace) {
      _logger.e('Repository: Session refresh failed', error: e, stackTrace: stackTrace);
      rethrow;
    }
  }
  
  @override
  Future<void> setSession(String refreshToken) async {
    await _authDatasource.setSession(refreshToken);
  }
}