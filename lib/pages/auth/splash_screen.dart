import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:rps_obe_app/pages/auth/login_page.dart';
import 'package:rps_obe_app/pages/dosen/dashboard_dosen.dart';
import 'package:rps_obe_app/pages/kaprodi/dashboard_kaprodi.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _jalankanProsesSplash();
  }

  Future<void> _jalankanProsesSplash() async {
    // Memberikan jeda waktu splash screen tampil selama 3 detik
    await Future.delayed(const Duration(seconds: 3));

    if (!mounted) return;

    final session = Supabase.instance.client.auth.currentSession;

    if (session == null) {
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const LoginPage()),
        );
      }
    } else {
      String? role = session.user.userMetadata?['role']?.toString();

      // Jika metadata lokal kosong akibat refresh browser Chrome, todong langsung ke database publik
      if (role == null || role.trim().isEmpty) {
        try {
          final resData = await Supabase.instance.client
              .from('users')
              .select('role')
              .eq('id', session.user.id)
              .maybeSingle();
              
          if (resData != null) {
            role = resData['role']?.toString();
          }
        } catch (e) {
          debugPrint("Gagal sinkronisasi role splash: $e");
        }
      }

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => _getLandingPage(role)),
        );
      }
    }
  }

  Widget _getLandingPage(String? role) {
    if (role == 'kaprodi') {
      return const DashboardKaprodi();
    } else {
      return const DashboardDosen();
    }
  }

  @override
  Widget build(BuildContext context) {
    const Color primaryColor = Color(0xFF007AFF);

    return const Scaffold(
      backgroundColor: primaryColor,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image(
              image: AssetImage('assets/images/ICON1.png'),
              width: 170,  
              height: 170,
              fit: BoxFit.contain,
            ),
            SizedBox(height: 15), 

            // --- TEKS JUDUL UTAMA ---
            Text(
              "RPS OBE",
              style: TextStyle(
                color: Colors.white,
                fontSize: 30, 
                fontWeight: FontWeight.bold,
                letterSpacing: 2,
              ),
            ),
            SizedBox(height: 4), 

            // --- SUB-JUDUL AKADEMIK ---
            Text(
              "Manajemen Sistem RPS",
              style: TextStyle(
                color: Colors.white70,
                fontSize: 14,
                fontWeight: FontWeight.w400,
              ),
            ),
            SizedBox(height: 35), 

            // --- INDIKATOR LOADING MINIMALIS ---
            SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                strokeWidth: 2.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}