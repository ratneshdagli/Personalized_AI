import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'screens/splash_screen.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';
import 'screens/today_screen.dart';
import 'screens/feed_screen.dart';
import 'screens/task_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/onboarding_screen.dart';
import 'providers/feed_provider.dart';
import 'providers/task_provider.dart';
import 'theme.dart';
import 'services/local_storage.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await LocalStorage.init();
  runApp(const RootApp());
}

class RootApp extends StatelessWidget {
  const RootApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => FeedProvider()),
        ChangeNotifierProvider(create: (_) => TaskProvider()),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Personalized AI Feed',
        theme: RNTheme.light(),
        darkTheme: RNTheme.dark(),
        initialRoute: '/splash',
        routes: {
          '/splash': (context) => const SplashScreen(),
          '/': (context) => const HomeScreen(),
          '/onboarding': (context) => OnboardingScreen(),
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
