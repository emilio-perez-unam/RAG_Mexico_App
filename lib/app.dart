import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:get_it/get_it.dart';
import 'package:logger/logger.dart';
import 'core/theme/app_theme.dart';
import 'core/constants/app_colors.dart';
import 'presentation/providers/auth_provider.dart';
import 'presentation/screens/auth/login_screen.dart';
import 'presentation/screens/auth/forgot_password_screen.dart';
import 'presentation/screens/chat/legal_chat_screen.dart';

class LegalRAGApp extends StatelessWidget {
  const LegalRAGApp({Key? key}) : super(key: key);
  
  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthProvider>(
          create: (_) => GetIt.instance<AuthProvider>(),
        ),
      ],
      child: MaterialApp(
        title: 'Legal RAG México',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          primaryColor: AppColors.primaryBlue,
          colorScheme: ColorScheme.fromSeed(
            seedColor: AppColors.primaryBlue,
            primary: AppColors.primaryBlue,
            secondary: const Color(0xFF006847),
          ),
          fontFamily: 'Open Sans',
          useMaterial3: true,
          appBarTheme: const AppBarTheme(
            backgroundColor: AppColors.primaryBlue,
            foregroundColor: Colors.white,
            elevation: 0,
          ),
          elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryBlue,
              foregroundColor: Colors.white,
            ),
          ),
        ),
        initialRoute: '/',
        routes: {
          '/': (context) => const AuthWrapper(),
          '/login': (context) => const LoginScreen(),
          '/forgot-password': (context) => const ForgotPasswordScreen(),
          '/chat': (context) => const LegalChatScreen(),
        },
      ),
    );
  }
}

/// Auth wrapper widget that decides which screen to show based on auth state
class AuthWrapper extends StatefulWidget {
  const AuthWrapper({Key? key}) : super(key: key);

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
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

  @override
  void initState() {
    super.initState();
    _logger.i('AuthWrapper initialized');
  }

  @override
  void dispose() {
    _logger.i('AuthWrapper disposing');
    _logger.close();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, authProvider, child) {
        _logger.d('AuthWrapper building with status: ${authProvider.status}');
        _logger.d('Current user: ${authProvider.user?.email ?? 'null'}');
        
        // Show loading while checking auth state
        if (authProvider.status == AuthStatus.initial || 
            authProvider.status == AuthStatus.loading) {
          _logger.i('Showing loading screen - Auth status: ${authProvider.status}');
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }
        
        // Show chat screen if authenticated
        if (authProvider.status == AuthStatus.authenticated) {
          _logger.i('User authenticated - Navigating to chat screen');
          _logger.i('Authenticated user: ${authProvider.user?.email}');
          return const LegalChatScreen();
        }
        
        // Show login screen if not authenticated
        _logger.i('User not authenticated - Showing login screen');
        _logger.d('Auth status: ${authProvider.status}');
        _logger.d('Error message: ${authProvider.errorMessage ?? 'none'}');
        return const LoginScreen();
      },
    );
  }
}