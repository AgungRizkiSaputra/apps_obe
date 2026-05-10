import 'package:flutter/material.dart';
import '../../services/auth_service.dart';
import '../dosen/dashboard_dosen.dart';
import '../kaprodi/dashboard_kaprodi.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {

  final emailController = TextEditingController();
  final passwordController = TextEditingController();

  final authService = AuthService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Login"),
      ),

      body: Padding(
        padding: const EdgeInsets.all(20),

        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,

          children: [

            TextField(
              controller: emailController,
              decoration: const InputDecoration(
                labelText: 'Email',
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 20),

            TextField(
              controller: passwordController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Password',
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 20),

            SizedBox(
              width: double.infinity,

              child: ElevatedButton(
                onPressed: () async {
  try {
    // 1. Proses Login ke Auth Supabase
    final response = await authService.login(
      email: emailController.text.trim(),
      password: passwordController.text.trim(),
    );

    final user = response.user;

    if (user != null) {
      final supabase = Supabase.instance.client;

      // 2. Ambil data profil dari tabel public.users berdasarkan ID/UID
      // Menggunakan ID lebih akurat daripada email karena ID adalah Primary Key
      final data = await supabase
          .from('users')
          .select()
          .eq('id', user.id) // Pakai user.id dari hasil login
          .maybeSingle();

      if (data == null) {
        throw 'Profil pengguna tidak ditemukan di database.';
      }

      String role = data['role'] ?? '';

      // 3. Navigasi berdasarkan Role
      if (role == 'dosen') {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const DashboardDosen()),
        );
      } else if (role == 'kaprodi') {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const DashboardKaprodi()),
        );
      } else {
        throw 'Role tidak dikenali.';
      }
    }
  } catch (e) {
    // Menampilkan pesan error yang lebih jelas di SnackBar
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("Login Gagal: ${e.toString()}"),
        backgroundColor: Colors.red,
      ),
    );
  }
},

                child: const Text("Login"),
              ),
            )

          ],
        ),
      ),
    );
  }
}