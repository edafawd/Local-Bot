import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_state.dart';
import 'screens/chat_screen.dart';

void main() {
  runApp(
    ChangeNotifierProvider(
      create: (_) => AppState(),
      child: const LocalAIApp(),
    ),
  );
}

class LocalAIApp extends StatelessWidget {
  const LocalAIApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Local AI',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: ColorScheme.dark(
          primary: const Color(0xFF7C6AF7),
          secondary: const Color(0xFF5EEAD4),
          surface: const Color(0xFF13131F),
          surfaceContainerHighest: const Color(0xFF1E1E2E),
          outline: const Color(0xFF2E2E45),
        ),
        textTheme: GoogleFonts.interTextTheme(ThemeData.dark().textTheme),
        scaffoldBackgroundColor: const Color(0xFF0D0D14),
      ),
      home: const ChatScreen(),
    );
  }
}
