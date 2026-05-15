import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart'; 
import 'package:signature/signature.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/rps_service.dart';

class ProfileKaprodiPage extends StatefulWidget {
  const ProfileKaprodiPage({super.key});

  @override
  State<ProfileKaprodiPage> createState() => _ProfileKaprodiPageState();
}

class _ProfileKaprodiPageState extends State<ProfileKaprodiPage> {
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

  // --- LOGIKA UPLOAD FOTO (UTUH) ---
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
      if (mounted) _showNotif("Foto profil Kaprodi diperbarui!", Colors.green);
    } catch (e) {
      if (mounted) _showNotif("Error: $e", Colors.red);
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
      if (mounted) _showNotif("Nama Kaprodi berhasil diperbarui!", Colors.green);
    } catch (e) {
      if (mounted) _showNotif("Error: $e", Colors.red);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // --- FUNGSI GANTI PASSWORD (UTUH) ---
  void _showChangePasswordDialog() {
    final passController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("Ganti Password Akun", style: TextStyle(fontWeight: FontWeight.bold)),
        content: TextField(
          controller: passController,
          obscureText: true,
          decoration: InputDecoration(
            hintText: "Minimal 6 karakter",
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            prefixIcon: const Icon(Icons.lock_outline),
            filled: true,
            fillColor: Colors.grey.shade50,
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Batal")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryColor,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () async {
              if (passController.text.length < 6) {
                _showNotif("Password terlalu pendek!", Colors.orange);
                return;
              }
              try {
                await rpsService.changePassword(passController.text);
                if (mounted) {
                  Navigator.pop(context);
                  _showNotif("Password berhasil diperbarui!", Colors.green);
                }
              } catch (e) {
                if (mounted) _showNotif("Error: $e", Colors.red);
              }
            },
            child: const Text("Simpan", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // --- LOGIKA SIMPAN TTD (UTUH) ---
  Future<void> _saveSignature() async {
    if (_sigController.isEmpty) return;
    setState(() => _isLoading = true);
    try {
      final Uint8List? data = await _sigController.toPngBytes();
      if (data != null) {
        await rpsService.uploadSignature(user!.id, data);
        if (mounted) _showNotif("Tanda tangan Kaprodi disimpan!", Colors.green);
      }
    } catch (e) {
      if (mounted) _showNotif("Error: $e", Colors.red);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // --- HELPER NOTIFIKASI ---
  void _showNotif(String msg, Color color) {
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
        title: const Text("Profil Kaprodi", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // --- HEADER BG ---
            Container(
              height: 100,
              width: double.infinity,
              decoration: BoxDecoration(
                color: primaryColor,
                borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(40), bottomRight: Radius.circular(40)),
              ),
              child: Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Text("Otoritas: ${user?.email ?? "-"}", textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70, fontSize: 13)),
              ),
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
                          ? Icon(Icons.admin_panel_settings, size: 70, color: Colors.grey.shade400)
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
            
            // --- KARTU-KARTU INFORMASI ---
            _buildSectionCard(
              title: "Data Struktural",
              icon: Icons.account_balance_outlined,
              child: Column(
                children: [
                  TextField(
                    controller: _namaController,
                    decoration: InputDecoration(
                      labelText: "Nama Kaprodi & Gelar",
                      prefixIcon: Icon(Icons.person, color: primaryColor),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
                      filled: true,
                      fillColor: Colors.grey.shade50,
                    ),
                  ),
                  const SizedBox(height: 15),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor, 
                        foregroundColor: Colors.white, 
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
                      ),
                      onPressed: _isLoading ? null : _handleUpdateProfile,
                      icon: const Icon(Icons.save),
                      label: const Text("Simpan Perubahan", style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ),

            _buildSectionCard(
              title: "Keamanan Akun",
              icon: Icons.security,
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(backgroundColor: Colors.orange.shade50, child: const Icon(Icons.key_rounded, color: Colors.orange)),
                title: const Text("Ubah Kata Sandi", style: TextStyle(fontWeight: FontWeight.bold)),
                subtitle: const Text("Amankan akun Kaprodi Anda"),
                trailing: const Icon(Icons.chevron_right),
                onTap: _showChangePasswordDialog,
              ),
            ),

            _buildSectionCard(
              title: "Tanda Tangan Digital",
              icon: Icons.draw_outlined,
              child: Column(
                children: [
                  const Text("Tanda tangan ini digunakan untuk validasi akhir pada dokumen RPS OBE.", 
                    style: TextStyle(fontSize: 11, color: Colors.grey, fontStyle: FontStyle.italic), textAlign: TextAlign.center),
                  const SizedBox(height: 15),
                  Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade200), 
                      borderRadius: BorderRadius.circular(15), 
                      color: Colors.white
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
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
                          ),
                          onPressed: _isLoading ? null : _saveSignature,
                          child: Text(_isLoading ? "..." : "Simpan TTD"),
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
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 15, offset: const Offset(0, 8))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: primaryColor, size: 22),
              const SizedBox(width: 12),
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