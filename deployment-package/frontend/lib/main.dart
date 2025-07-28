import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/auth_provider.dart';
import 'screens/splash_screen.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';
import 'screens/integrated_dashboard.dart';
import 'widgets/notification_center.dart';
import 'widgets/chat_interface.dart';
import 'services/api_service.dart';
import 'services/socket_service.dart';
import 'services/notification_service.dart';
import 'services/time_tracking_service.dart';
import 'services/chat_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize services
  await ApiService.initializeToken();

  // Initialize real-time services
  final socketService = SocketService();
  final notificationService = NotificationService();
  final timeTrackingService = TimeTrackingService();
  final chatService = ChatService();

  // Initialize services
  await Future.wait([
    notificationService.initialize(),
    chatService.initialize(),
  ]);

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
      ],
      child: MaterialApp(
        title: 'Task Management',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
          useMaterial3: true,
        ),
        initialRoute: '/',
        routes: {
          '/': (context) => const SplashScreen(),
          '/login': (context) => const LoginScreen(),
          '/home': (context) => const HomeScreen(),
          '/dashboard': (context) => const IntegratedDashboard(),
          '/notifications': (context) => const NotificationCenter(),
          '/chat': (context) => const ChatInterface(),
        },
      ),
    );
  }
}
