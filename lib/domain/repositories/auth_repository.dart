import 'package:supabase_flutter/supabase_flutter.dart';

/// Authentication repository interface
abstract class AuthRepository {
  /// Get current user
  Future<User?> getCurrentUser();
  
  /// Get current session
  Future<Session?> getCurrentSession();
  
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