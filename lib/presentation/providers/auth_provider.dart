import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../data/datasources/remote/auth_datasource.dart';
import '../../domain/repositories/auth_repository.dart';

/// Authentication state enum
enum AuthStatus {
  initial,
  authenticated,
  unauthenticated,
  loading,
  error,
}

/// Authentication provider for managing auth state
class AuthProvider extends ChangeNotifier {
  final AuthRepository _authRepository;
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
  
  AuthStatus _status = AuthStatus.initial;
  User? _user;
  Session? _session;
  String? _errorMessage;
  
  AuthProvider({required AuthRepository authRepository})
      : _authRepository = authRepository {
    _logger.i('AuthProvider initialized');
    _initialize();
  }
  
  // Getters
  AuthStatus get status => _status;
  User? get user => _user;
  Session? get session => _session;
  String? get errorMessage => _errorMessage;
  bool get isAuthenticated => _status == AuthStatus.authenticated;
  bool get isLoading => _status == AuthStatus.loading;
  
  /// Initialize auth state and listen to auth changes
  Future<void> _initialize() async {
    try {
      _logger.d('Initializing auth state');
      _status = AuthStatus.loading;
      notifyListeners();
      
      // Check current session
      _logger.d('Checking current session');
      final currentUser = await _authRepository.getCurrentUser();
      final currentSession = await _authRepository.getCurrentSession();
      
      if (currentUser != null && currentSession != null) {
        _logger.i('Found existing session for user: ${currentUser.email}');
        _user = currentUser;
        _session = currentSession;
        _status = AuthStatus.authenticated;
      } else {
        _logger.i('No existing session found');
        _status = AuthStatus.unauthenticated;
      }
      
      // Listen to auth state changes
      _logger.d('Setting up auth state listener');
      _authRepository.authStateChanges.listen((authState) {
        _handleAuthStateChange(authState);
      });
      
      notifyListeners();
    } catch (e, stackTrace) {
      _logger.e('Failed to initialize auth', error: e, stackTrace: stackTrace);
      _handleError(e.toString());
    }
  }
  
  /// Handle auth state changes
  void _handleAuthStateChange(AuthState authState) {
    _logger.d('Auth state changed: ${authState.event}');
    
    if (authState.session != null) {
      _logger.i('User authenticated: ${authState.session!.user.email}');
      _user = authState.session!.user;
      _session = authState.session;
      _status = AuthStatus.authenticated;
      _errorMessage = null;
    } else {
      _logger.i('User unauthenticated');
      _user = null;
      _session = null;
      _status = AuthStatus.unauthenticated;
    }
    notifyListeners();
  }
  
  /// Sign up with email and password
  Future<void> signUp({
    required String email,
    required String password,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      _status = AuthStatus.loading;
      _errorMessage = null;
      notifyListeners();
      
      final response = await _authRepository.signUp(
        email: email,
        password: password,
        metadata: metadata,
      );
      
      if (response.user != null) {
        _user = response.user;
        _session = response.session;
        _status = response.session != null 
            ? AuthStatus.authenticated 
            : AuthStatus.unauthenticated;
      }
      
      notifyListeners();
    } on AuthException catch (e) {
      _handleError(e.message);
    } catch (e) {
      _handleError(e.toString());
    }
  }
  
  /// Sign in with email and password
  Future<void> signIn({
    required String email,
    required String password,
  }) async {
    try {
      _logger.i('Sign in attempt for: $email');
      _status = AuthStatus.loading;
      _errorMessage = null;
      notifyListeners();
      
      _logger.d('Calling auth repository signIn');
      final response = await _authRepository.signIn(
        email: email,
        password: password,
      );
      
      _logger.d('SignIn response received - User: ${response.user?.email}, Session: ${response.session != null}');
      
      if (response.user != null && response.session != null) {
        _logger.i('Sign in successful for: ${response.user!.email}');
        _user = response.user;
        _session = response.session;
        _status = AuthStatus.authenticated;
      } else {
        _logger.w('Sign in failed: Invalid response (user or session null)');
        throw const AuthException('Invalid credentials');
      }
      
      notifyListeners();
    } on AuthException catch (e, stackTrace) {
      _logger.e('AuthException during sign in', error: e.message, stackTrace: stackTrace);
      _handleError(e.message);
    } catch (e, stackTrace) {
      _logger.e('Unexpected error during sign in', error: e, stackTrace: stackTrace);
      _handleError(e.toString());
    }
  }
  
  /// Sign in with OAuth provider
  Future<void> signInWithProvider(OAuthProvider provider) async {
    try {
      _status = AuthStatus.loading;
      _errorMessage = null;
      notifyListeners();
      
      final success = await _authRepository.signInWithProvider(provider);
      
      if (!success) {
        throw const AuthException('OAuth sign in failed');
      }
      
      // Auth state will be updated through the listener
    } on AuthException catch (e) {
      _handleError(e.message);
    } catch (e) {
      _handleError(e.toString());
    }
  }
  
  /// Sign out
  Future<void> signOut() async {
    try {
      _logger.i('Sign out requested');
      _status = AuthStatus.loading;
      notifyListeners();
      
      await _authRepository.signOut();
      
      _logger.i('Sign out successful');
      _user = null;
      _session = null;
      _status = AuthStatus.unauthenticated;
      _errorMessage = null;
      
      notifyListeners();
    } catch (e, stackTrace) {
      _logger.e('Sign out failed', error: e, stackTrace: stackTrace);
      _handleError(e.toString());
    }
  }
  
  /// Reset password
  Future<void> resetPassword(String email) async {
    try {
      _status = AuthStatus.loading;
      _errorMessage = null;
      notifyListeners();
      
      await _authRepository.resetPassword(email);
      
      _status = AuthStatus.unauthenticated;
      notifyListeners();
    } catch (e) {
      _handleError(e.toString());
    }
  }
  
  /// Update user profile
  Future<void> updateProfile({
    String? email,
    String? password,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      _status = AuthStatus.loading;
      _errorMessage = null;
      notifyListeners();
      
      final response = await _authRepository.updateUser(
        email: email,
        password: password,
        metadata: metadata,
      );
      
      if (response.user != null) {
        _user = response.user;
        _status = AuthStatus.authenticated;
      }
      
      notifyListeners();
    } catch (e) {
      _handleError(e.toString());
    }
  }
  
  /// Refresh session
  Future<void> refreshSession() async {
    try {
      final response = await _authRepository.refreshSession();
      
      if (response.session != null) {
        _session = response.session;
        _user = response.user;
        _status = AuthStatus.authenticated;
        notifyListeners();
      }
    } catch (e) {
      // Session refresh failed, user needs to log in again
      _status = AuthStatus.unauthenticated;
      notifyListeners();
    }
  }
  
  /// Clear error message
  void clearError() {
    _errorMessage = null;
    if (_status == AuthStatus.error) {
      _status = AuthStatus.unauthenticated;
    }
    notifyListeners();
  }
  
  /// Handle errors
  void _handleError(String message) {
    _logger.e('Auth error: $message');
    _errorMessage = message;
    _status = AuthStatus.error;
    notifyListeners();
  }
  
  /// Get user metadata
  Map<String, dynamic> get userMetadata {
    return _user?.userMetadata ?? {};
  }
  
  /// Get user full name
  String get userFullName {
    return userMetadata['full_name'] ?? 'Usuario';
  }
  
  /// Get user organization
  String? get userOrganization {
    return userMetadata['organization'];
  }
  
  /// Check if user email is verified
  bool get isEmailVerified {
    return _user?.emailConfirmedAt != null;
  }
  
  /// Check if user has completed profile
  bool get hasCompletedProfile {
    return userMetadata['full_name'] != null && 
           userMetadata['full_name'].toString().isNotEmpty;
  }
  
  @override
  void dispose() {
    _logger.i('AuthProvider disposing');
    _logger.close();
    super.dispose();
  }
}