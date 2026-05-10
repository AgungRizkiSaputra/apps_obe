import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'pages/auth/login_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://byuhbtdcrcupfjrcyplz.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImJ5dWhidGRjcmN1cGZqcmN5cGx6Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzgwNzE2NDAsImV4cCI6MjA5MzY0NzY0MH0.FHqyHoHTXB3gzjSf5lutB4qR3rp3J969tRpQtpttiAY',
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: LoginPage(),
    );
  }
}