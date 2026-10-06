import 'package:flutter/material.dart';
import 'theme/sepia_theme.dart';
import 'views/shell_layout.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const AntigravityDistributedApp());
}

class AntigravityDistributedApp extends StatelessWidget {
  const AntigravityDistributedApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Antigravity // Distributed AI System',
      debugShowCheckedModeBanner: false,
      theme: SepiaTheme.lightTheme,
      home: const ShellLayout(),
    );
  }
}
