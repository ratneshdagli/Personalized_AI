import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_gemma/flutter_gemma.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'theme/app_theme.dart';
import 'screens/onboarding_screen.dart';
import 'screens/home_screen.dart';
import 'screens/other_screens.dart';
import 'screens/calendar_screen.dart';
import 'screens/todo_screen.dart';
import 'widgets/bottom_nav.dart';
import 'state/app_state.dart';
import 'llm/model_prompt.dart';

void main() {
  // Ensure Flutter bindings are initialized
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Flutter Gemma
  try {
    FlutterGemma.initialize(
      // Optional: Add your HuggingFace token here if needed for gated models
      // huggingFaceToken: const String.fromEnvironment('HUGGINGFACE_TOKEN'),
      maxDownloadRetries: 3,
    );
    
    // Set preferred device (optional)
    // FlutterGemma.setPreferredDevice(Device.gpu);
    
    debugPrint('Flutter Gemma initialization started');
  } catch (e, stackTrace) {
    debugPrint('Error initializing Flutter Gemma: $e');
    debugPrint('Stack trace: $stackTrace');
    // Continue with app initialization even if Gemma fails
  }
  
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AppState(),
      child: Consumer<AppState>(
        builder: (context, appState, _) {
          return MaterialApp(
            title: 'Personalized AI Companion UI',
            theme: AppTheme.light,
            darkTheme: AppTheme.dark,
            themeMode: appState.themeMode,
            home: const MyHomePage(title: 'Your Space'),
            debugShowCheckedModeBanner: false,
          );
        },
      ),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  // This widget is the home page of your application. It is stateful, meaning
  // that it has a State object (defined below) that contains fields that affect
  // how it looks.

  // This class is the configuration for the state. It holds the values (in this
  // case the title) provided by the parent (in this case the App widget) and
  // used by the build method of the State. Fields in a Widget subclass are
  // always marked "final".

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  bool _completedOnboarding = false;
  int _tab = 0; // 0: Home, 1: Todo, 2: Calendar, 3: Settings

  @override
  void initState() {
    super.initState();
    // Use addPostFrameCallback to ensure the context is available
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AppState>().init();
      // Prompt to enable on-device model if not present
      maybePromptModelDownload(context);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_completedOnboarding) {
      return Scaffold(
        body: OnboardingScreen(
          onComplete: () => setState(() => _completedOnboarding = true),
        ),
      );
    }

    final screens = <Widget>[
      const HomeScreen(),
      const TodoScreen(),
      const CalendarScreen(),
      const SettingsScreen(),
    ];

    return Scaffold(
      body: Stack(
        children: [
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            transitionBuilder: (Widget child, Animation<double> animation) {
              final bool isEntering = (child.key == ValueKey<int>(_tab));

              final slideIn = Tween<Offset>(
                begin: const Offset(1.0, 0.0),
                end: Offset.zero,
              ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic));

              final slideOut = Tween<Offset>(
                begin: Offset.zero,
                end: const Offset(-1.0, 0.0),
              ).animate(CurvedAnimation(parent: animation, curve: Curves.easeInCubic));

              if (isEntering) {
                return FadeTransition(
                  opacity: animation,
                  child: SlideTransition(position: slideIn, child: child),
                );
              } else {
                return FadeTransition(
                  opacity: Tween<double>(begin: 1.0, end: 0.0).animate(animation),
                  child: SlideTransition(position: slideOut, child: child),
                );
              }
            },
            child: KeyedSubtree(
              key: ValueKey<int>(_tab),
              child: SizedBox.expand(child: screens[_tab]),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: AppBottomNav(
              currentIndex: _tab,
              onTap: (i) => setState(() => _tab = i),
            ),
          ),
        ],
      ),
    );
  }
}
