import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart'; 
import 'package:signature/signature.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/rps_service.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final rpsService = RpsService();
  final user = Supabase.instance.client.auth.currentUser;
  final primaryColor = Colors.indigo.shade900;
  
  final TextEditingController _namaController = TextEditingController();
  final SignatureController _sigController = SignatureController(
    penStrokeWidth: 3, 
    penColor: Colors.indigo.shade900, 
    exportBackgroundColor: Colors.white,
  );

  bool _isLoading = false;
  Uint8List? _webImage; 
  String? _avatarUrl;

  @override
  void initState() {
    super.initState();
    _namaController.text = user?.userMetadata?['nama'] ?? "";
    _avatarUrl = user?.userMetadata?['avatar_url'];
  }

  @override
  void dispose() {
    _namaController.dispose();
    _sigController.dispose();
    super.dispose();
  }

  // --- LOGIKA UPLOAD FOTO PROFIL (UTUH) ---
  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery, imageQuality: 50);
    if (image != null) {
      final bytes = await image.readAsBytes();
      final extension = image.name.split('.').last;
      setState(() => _webImage = bytes);
      _handleUpdateAvatar(bytes, extension);
    }
  }

  Future<void> _handleUpdateAvatar(Uint8List bytes, String ext) async {
    setState(() => _isLoading = true);
    try {
      final newUrl = await rpsService.uploadAvatar(user!.id, bytes, ext);
      setState(() => _avatarUrl = newUrl);
      if (mounted) _showCustomNotif("Foto profil berhasil diperbarui!", Colors.green);
    } catch (e) {
      if (mounted) _showCustomNotif("Error: $e", Colors.red);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // --- LOGIKA UPDATE NAMA (UTUH) ---
  Future<void> _handleUpdateProfile() async {
    if (_namaController.text.isEmpty) return;
    setState(() => _isLoading = true);
    try {
      await rpsService.updateProfile(user!.id, _namaController.text);
      if (mounted) _showCustomNotif("Nama berhasil diperbarui!", Colors.green);
    } catch (e) {
      if (mounted) _showCustomNotif("Error: $e", Colors.red);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // --- FUNGSI GANTI PASSWORD (UTUH) ---
  void _showChangePasswordDialog() {
    final passController = TextEditingController();
    showDialog(context: context, builder: (context) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Text("Ganti Password", style: TextStyle(fontWeight: FontWeight.bold)),
      content: TextField(
        controller: passController, 
        obscureText: true, 
        decoration: InputDecoration(
          hintText: "Password baru (min 6 karakter)", 
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)), 
          prefixIcon: const Icon(Icons.lock_outline),
          filled: true,
          fillColor: Colors.grey.shade50,
        )
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text("Batal")),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: primaryColor, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
          onPressed: () async {
            if (passController.text.length < 6) { 
              _showCustomNotif("Min 6 karakter", Colors.orange);
              return; 
            }
            try { 
              await rpsService.changePassword(passController.text); 
              if (mounted) { 
                Navigator.pop(context); 
                _showCustomNotif("Password berhasil diganti!", Colors.green);
              }
            } catch (e) { if (mounted) _showCustomNotif("Error: $e", Colors.red); }
        }, child: const Text("Update", style: TextStyle(color: Colors.white))),
      ],
    ));
  }

  // --- LOGIKA SIMPAN TANDA TANGAN (UTUH) ---
  Future<void> _saveSignature() async {
    if (_sigController.isEmpty) return;
    setState(() => _isLoading = true);
    try {
      final Uint8List? data = await _sigController.toPngBytes();
      if (data != null) {
        await rpsService.uploadSignature(user!.id, data);
        if (mounted) _showCustomNotif("Tanda tangan berhasil disimpan!", Colors.green);
      }
    } catch (e) {
      if (mounted) _showCustomNotif("Error: $e", Colors.red);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // --- HELPER NOTIF (KONSISTEN) ---
  void _showCustomNotif(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: const TextStyle(fontWeight: FontWeight.bold)),
      backgroundColor: color,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text("Profil Saya", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // --- HEADER BACKGROUND ---
            Container(
              height: 100,
              width: double.infinity,
              decoration: BoxDecoration(
                color: primaryColor,
                borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(40), bottomRight: Radius.circular(40)),
              ),
              child: Text(user?.email ?? "-", textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70, fontSize: 13)),
            ),

            // --- AVATAR SECTION ---
            Transform.translate(
              offset: const Offset(0, -50),
              child: Stack(
                alignment: Alignment.bottomRight,
                children: [
                  Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle, 
                      border: Border.all(color: Colors.white, width: 5), 
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 15)]
                    ),
                    child: CircleAvatar(
                      radius: 60,
                      backgroundColor: Colors.grey.shade200,
                      backgroundImage: _webImage != null
                          ? MemoryImage(_webImage!) as ImageProvider
                          : (_avatarUrl != null ? NetworkImage(_avatarUrl!) : null),
                      child: (_webImage == null && _avatarUrl == null)
                          ? Icon(Icons.person, size: 70, color: Colors.grey.shade400)
                          : null,
                    ),
                  ),
                  InkWell(
                    onTap: _pickImage,
                    child: CircleAvatar(
                      radius: 18, 
                      backgroundColor: primaryColor, 
                      child: const Icon(Icons.camera_alt, size: 18, color: Colors.white)
                    ),
                  ),
                ],
              ),
            ),
            
            // --- CARDS ---
            _buildSectionCard(
              title: "Biodata Dosen",
              icon: Icons.person_pin_rounded,
              child: Column(
                children: [
                  TextField(
                    controller: _namaController,
                    decoration: InputDecoration(
                      labelText: "Nama Lengkap & Gelar",
                      prefixIcon: Icon(Icons.badge_outlined, color: primaryColor),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
                      filled: true,
                      fillColor: Colors.grey.shade50,
                    ),
                  ),
                  const SizedBox(height: 15),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor, 
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
                      ),
                      onPressed: _isLoading ? null : _handleUpdateProfile,
                      child: const Text("SIMPAN PERUBAHAN NAMA", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                    ),
                  ),
                ],
              ),
            ),

            _buildSectionCard(
              title: "Keamanan",
              icon: Icons.verified_user_rounded,
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(backgroundColor: Colors.orange.shade50, child: const Icon(Icons.key_rounded, color: Colors.orange)),
                title: const Text("Kata Sandi", style: TextStyle(fontWeight: FontWeight.bold)),
                subtitle: const Text("Ganti password akun secara berkala"),
                trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                onTap: _showChangePasswordDialog,
              ),
            ),

            _buildSectionCard(
              title: "Tanda Tangan Digital",
              icon: Icons.draw_rounded,
              child: Column(
                children: [
                  const Text("Tanda tangan ini akan muncul otomatis di dokumen PDF RPS yang telah disetujui.", 
                    style: TextStyle(fontSize: 11, color: Colors.grey, fontStyle: FontStyle.italic), textAlign: TextAlign.center),
                  const SizedBox(height: 15),
                  Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade200), 
                      borderRadius: BorderRadius.circular(15), 
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(15),
                      child: Signature(controller: _sigController, height: 180, backgroundColor: Colors.white),
                    ),
                  ),
                  const SizedBox(height: 15),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.red, 
                            side: const BorderSide(color: Colors.red),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
                          ),
                          onPressed: () => _sigController.clear(),
                          child: const Text("Hapus"),
                        ),
                      ),
                      const SizedBox(width: 15),
                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green.shade700, 
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
                          ),
                          onPressed: _isLoading ? null : _saveSignature,
                          child: Text(_isLoading ? "..." : "Simpan TTD", style: const TextStyle(color: Colors.white)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionCard({required String title, required IconData icon, required Widget child}) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 5))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: primaryColor, size: 20),
              const SizedBox(width: 10),
              Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
            ],
          ),
          const Divider(height: 30),
          child,
        ],
      ),
    );
  }
}