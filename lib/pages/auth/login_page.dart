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

  // --- LOGIKA LOGIN (UTUH 100% TANPA DIUBAH) ---
  void _handleLogin() async {
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
      String pesan = "Terjadi kesalahan saat login.";
      if (error.message.contains("Invalid login credentials")) {
        pesan = "Email atau Password yang Anda masukkan salah!";
      } else if (error.message.contains("network")) {
        pesan = "Koneksi internet bermasalah. Coba lagi nanti.";
      }
      _showErrorSnackBar(pesan);
    } catch (e) {
      _showErrorSnackBar("Gagal masuk: Periksa kembali akun Anda.");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

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
        backgroundColor: Colors.red.shade700,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color(0xFF007AFF);  // Biru Terang
    const accentColor = Color(0xFF00C6FF);   // Cyan/Teal Cerah
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SingleChildScrollView(
        child: Column(
          children: [
            // --- HEADER BACKGROUND ---
            Container(
              width: double.infinity,
              height: size.height * 0.42,
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(80)),
              ),
              child: Stack(
                children: [
                  Positioned(
                    top: -50, right: -50,
                    child: CircleAvatar(radius: 100, backgroundColor: accentColor.withOpacity(0.08)),
                  ),
                  SafeArea(
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Image.asset('assets/images/ICON1.png', height: 160, fit: BoxFit.contain),
                          const SizedBox(height: 15),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 6),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [primaryColor, accentColor],
                                begin: Alignment.centerLeft,
                                end: Alignment.centerRight,
                              ),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Text(
                              "MANAGEMENT SYSTEM", 
                              style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 2),
                            ),
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
              padding: const EdgeInsets.fromLTRB(30, 35, 30, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Welcome Back", 
                    style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: primaryColor, letterSpacing: -1),
                  ),
                  Text("Login to access your OBE Curriculum", style: TextStyle(color: Colors.grey.shade600, fontSize: 14)),
                  const SizedBox(height: 35),

                  _buildTextField(controller: emailController, label: "Email Address", icon: Icons.alternate_email, activeColor: primaryColor),
                  const SizedBox(height: 20),

                  _buildTextField(
                    controller: passwordController,
                    label: "Password",
                    icon: Icons.lock_open_rounded,
                    activeColor: primaryColor,
                    isPassword: true,
                    obscureText: _obscureText,
                    onToggle: () => setState(() => _obscureText = !_obscureText),
                  ),
                  const SizedBox(height: 40),

                  // --- TOMBOL LOGIN GRADASI ---
                  SizedBox(
                    width: double.infinity,
                    height: 55,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [primaryColor, accentColor],
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                        ),
                        borderRadius: BorderRadius.circular(15),
                        boxShadow: [
                          BoxShadow(
                            color: primaryColor.withOpacity(0.3),
                            blurRadius: 12,
                            offset: const Offset(0, 6),
                          )
                        ],
                      ),
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          foregroundColor: Colors.white,
                          shadowColor: Colors.transparent,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                        ),
                        onPressed: _isLoading ? null : _handleLogin,
                        child: _isLoading
                            ? const SizedBox(height: 22, width: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                            : const Text("SIGN IN", style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, letterSpacing: 1)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 15),
            const Text(
              "ITB BINA SARANA GLOBAL", 
              style: TextStyle(color: Colors.grey, fontSize: 10, fontWeight: FontWeight.w600, letterSpacing: 1),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller, 
    required String label, 
    required IconData icon, 
    required Color activeColor, 
    bool isPassword = false, 
    bool obscureText = false, 
    VoidCallback? onToggle
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white, 
        borderRadius: BorderRadius.circular(15), 
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.01), blurRadius: 10, offset: const Offset(0, 4))
        ],
      ),
      child: TextField(
        controller: controller,
        obscureText: isPassword ? obscureText : false,
        style: const TextStyle(fontSize: 15),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(fontSize: 13, color: Colors.grey),
          prefixIcon: Icon(icon, color: activeColor, size: 20),
          suffixIcon: isPassword 
              ? IconButton(icon: Icon(obscureText ? Icons.visibility_off : Icons.visibility, color: Colors.grey, size: 20), onPressed: onToggle) 
              : null,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
          filled: true,
          fillColor: Colors.grey.shade50,
          contentPadding: const EdgeInsets.symmetric(vertical: 16),
        ),
      ),
    );
  }
}