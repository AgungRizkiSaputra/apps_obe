import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Import semua halaman yang dibutuhkan
import 'pages/auth/login_page.dart';
import 'pages/dosen/dashboard_dosen.dart';
import 'pages/kaprodi/dashboard_kaprodi.dart';

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
    // Ambil sesi login saat ini dari Supabase
    final session = Supabase.instance.client.auth.currentSession;

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Aplikasi RPS OBE',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      // LOGIKA AUTO-LOGIN
      // Jika session tidak null, artinya user sudah pernah login
      home: session == null 
          ? const LoginPage() 
          : _getLandingPage(session.user.userMetadata?['role']),
    );
  }

  // Fungsi untuk menentukan dashboard mana yang harus dibuka berdasarkan role
  Widget _getLandingPage(String? role) {
    if (role == 'kaprodi') {
      return const DashboardKaprodi();
    } else {
      // Default atau jika role adalah 'dosen'
      return const DashboardDosen();
    }
  }
}