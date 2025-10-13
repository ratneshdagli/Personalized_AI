import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'screens/splash_screen.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';
import 'screens/today_screen.dart';
import 'screens/feed_screen.dart';
import 'screens/task_screen.dart';
import 'screens/settings_screen.dart';
import 'providers/feed_provider.dart';
import 'app.dart';

void main() {
  runApp(const RootApp());
}

class RootApp extends StatelessWidget {
  const RootApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => FeedProvider()),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Personalized AI Feed',
        theme: AppThemes.light,
        darkTheme: AppThemes.dark,
        initialRoute: '/splash',
        routes: {
          '/splash': (context) => const SplashScreen(),
          '/': (context) => const HomeScreen(),
          '/login': (context) => const LoginScreen(),
          '/today': (context) => const TodayScreen(),
          '/feed': (context) => const FeedScreen(),
          '/tasks': (context) => const TaskScreen(),
          '/settings': (context) => const SettingsScreen(),
        },
      ),
    );
  }
}
