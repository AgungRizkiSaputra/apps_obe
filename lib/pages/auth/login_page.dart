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
  
  bool _isLoading = false;
  bool _obscureText = true;

  // --- LOGIKA LOGIN DENGAN NOTIFIKASI ERROR RAMAH USER ---
  void _handleLogin() async {
    // Validasi input kosong
    if (emailController.text.isEmpty || passwordController.text.isEmpty) {
      _showErrorSnackBar("Mohon isi email dan password terlebih dahulu!");
      return;
    }

    setState(() => _isLoading = true);
    try {
      final response = await authService.login(
        email: emailController.text.trim(),
        password: passwordController.text.trim(),
      );

      final user = response.user;

      if (user != null) {
        final supabase = Supabase.instance.client;
        final data = await supabase
            .from('users')
            .select()
            .eq('id', user.id)
            .maybeSingle();

        if (data == null) throw 'user_not_found';

        String role = data['role'] ?? '';

        if (mounted) {
          if (role == 'dosen') {
            Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const DashboardDosen()));
          } else if (role == 'kaprodi') {
            Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const DashboardKaprodi()));
          } else {
            throw 'role_not_recognized';
          }
        }
      }
    } on AuthException catch (error) {
      // Menangkap error khusus dari Supabase Auth
      String pesan = "Terjadi kesalahan saat login.";
      
      // Deteksi jenis error
      if (error.message.contains("Invalid login credentials")) {
        pesan = "Email atau Password yang Anda masukkan salah!";
      } else if (error.message.contains("network")) {
        pesan = "Koneksi internet bermasalah. Coba lagi nanti.";
      }
      
      _showErrorSnackBar(pesan);
    } catch (e) {
      // Menangkap error umum lainnya
      _showErrorSnackBar("Gagal masuk: Periksa kembali akun Anda.");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // Fungsi pembantu untuk SnackBar Merah
  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white),
            const SizedBox(width: 10),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.red.shade800,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Colors.indigo.shade900;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SingleChildScrollView(
        child: Column(
          children: [
            // --- HEADER (SESUAI TAMPILAN YANG KAMU SUKA) ---
            Container(
              width: double.infinity,
              height: MediaQuery.of(context).size.height * 0.42,
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(80)),
              ),
              child: Stack(
                children: [
                  Positioned(
                    top: -50, right: -50,
                    child: CircleAvatar(radius: 100, backgroundColor: primaryColor.withOpacity(0.05)),
                  ),
                  SafeArea(
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Image.asset('assets/images/fix.png', height: 180, fit: BoxFit.contain),
                          const SizedBox(height: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 5),
                            decoration: BoxDecoration(color: primaryColor, borderRadius: BorderRadius.circular(20)),
                            child: const Text("MANAGEMENT SYSTEM", style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 2)),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // --- FORM SECTION ---
            Padding(
              padding: const EdgeInsets.fromLTRB(30, 40, 30, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Welcome Back", style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: primaryColor, letterSpacing: -1)),
                  Text("Login to access your OBE Curriculum", style: TextStyle(color: Colors.grey.shade600, fontSize: 14)),
                  const SizedBox(height: 40),

                  _buildTextField(controller: emailController, label: "Email Address", icon: Icons.alternate_email, color: primaryColor),
                  const SizedBox(height: 20),

                  _buildTextField(
                    controller: passwordController,
                    label: "Password",
                    icon: Icons.lock_open_rounded,
                    color: primaryColor,
                    isPassword: true,
                    obscureText: _obscureText,
                    onToggle: () => setState(() => _obscureText = !_obscureText),
                  ),
                  const SizedBox(height: 40),

                  SizedBox(
                    width: double.infinity,
                    height: 60,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                        foregroundColor: Colors.white,
                        elevation: 8,
                        shadowColor: primaryColor.withOpacity(0.5),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                      ),
                      onPressed: _isLoading ? null : _handleLogin,
                      child: _isLoading
                          ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : const Text("SIGN IN", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Text("ITB BINA SARANA GLOBAL", style: TextStyle(color: Colors.grey.shade400, fontSize: 10, fontWeight: FontWeight.w600, letterSpacing: 1)),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({required TextEditingController controller, required String label, required IconData icon, required Color color, bool isPassword = false, bool obscureText = false, VoidCallback? onToggle}) {
    return Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 5))]),
      child: TextField(
        controller: controller,
        obscureText: isPassword ? obscureText : false,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(fontSize: 14, color: Colors.grey),
          prefixIcon: Icon(icon, color: color, size: 20),
          suffixIcon: isPassword ? IconButton(icon: Icon(obscureText ? Icons.visibility_off : Icons.visibility, color: Colors.grey), onPressed: onToggle) : null,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
          filled: true,
          fillColor: Colors.grey.shade50,
        ),
      ),
    );
  }
}