import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart'; // Wajib: flutter pub add image_picker
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
  
  final TextEditingController _namaController = TextEditingController();
  final SignatureController _sigController = SignatureController(
    penStrokeWidth: 3, 
    penColor: Colors.blue.shade900, 
    exportBackgroundColor: Colors.white,
  );

  bool _isLoading = false;
  Uint8List? _webImage; // Untuk preview foto di Web
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

  // --- LOGIKA AMBIL & UPLOAD FOTO (SUPPORT WEB) ---
  Future<void> _pickImage() async {
    final picker = ImagePicker();
    // imageQuality 50 biar sizenya gak kegedean pas upload
    final XFile? image = await picker.pickImage(source: ImageSource.gallery, imageQuality: 50);

    if (image != null) {
      final bytes = await image.readAsBytes();
      final extension = image.name.split('.').last;
      
      setState(() {
        _webImage = bytes;
      });
      
      // Kirim bytes ke service
      _handleUpdateAvatar(bytes, extension);
    }
  }

  Future<void> _handleUpdateAvatar(Uint8List bytes, String ext) async {
    setState(() => _isLoading = true);
    try {
      final newUrl = await rpsService.uploadAvatar(user!.id, bytes, ext);
      setState(() {
        _avatarUrl = newUrl;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Foto profil berhasil diperbarui!"), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // --- LOGIKA UPDATE DATA & PASSWORD ---
  Future<void> _handleUpdateProfile() async {
    if (_namaController.text.isEmpty) return;
    setState(() => _isLoading = true);
    try {
      await rpsService.updateProfile(user!.id, _namaController.text);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Nama berhasil diperbarui!"), backgroundColor: Colors.green));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showChangePasswordDialog() {
    final passController = TextEditingController();
    showDialog(context: context, builder: (context) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      title: const Text("Ganti Password"),
      content: TextField(
        controller: passController, 
        obscureText: true, 
        decoration: const InputDecoration(hintText: "Password baru (min 6 karakter)", border: OutlineInputBorder())
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text("Batal")),
        ElevatedButton(onPressed: () async {
          if (passController.text.length < 6) { 
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Min 6 karakter"), backgroundColor: Colors.orange)); 
            return; 
          }
          try { 
            await rpsService.changePassword(passController.text); 
            if (mounted) { 
              Navigator.pop(context); 
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Password berhasil diganti!"), backgroundColor: Colors.green)); 
            }
          } catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red)); }
        }, child: const Text("Update")),
      ],
    ));
  }

  Future<void> _saveSignature() async {
    if (_sigController.isEmpty) return;
    setState(() => _isLoading = true);
    try {
      final Uint8List? data = await _sigController.toPngBytes();
      if (data != null) {
        await rpsService.uploadSignature(user!.id, data);
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Tanda tangan disimpan!"), backgroundColor: Colors.green));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Colors.blue.shade800;

    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: const Text("Profil Pengguna"),
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // --- HEADER BIRU ---
            Container(
              height: 100,
              width: double.infinity,
              decoration: BoxDecoration(
                color: primaryColor,
                borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(40), bottomRight: Radius.circular(40)),
              ),
              child: Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Text(user?.email ?? "-", textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70, fontSize: 13)),
              ),
            ),

            // --- FOTO PROFIL MELAYANG ---
            Transform.translate(
              offset: const Offset(0, -50),
              child: Stack(
                alignment: Alignment.bottomRight,
                children: [
                  GestureDetector(
                    onTap: _pickImage,
                    child: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle, 
                        border: Border.all(color: Colors.white, width: 5), 
                        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 15)]
                      ),
                      child: CircleAvatar(
                        radius: 60,
                        backgroundColor: Colors.white,
                        backgroundImage: _webImage != null
                            ? MemoryImage(_webImage!) as ImageProvider
                            : (_avatarUrl != null ? NetworkImage(_avatarUrl!) : null),
                        child: (_webImage == null && _avatarUrl == null)
                            ? Icon(Icons.person, size: 70, color: Colors.grey.shade400)
                            : null,
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 5,
                    right: 5,
                    child: GestureDetector(
                      onTap: _pickImage,
                      child: CircleAvatar(
                        radius: 18, 
                        backgroundColor: primaryColor, 
                        child: const Icon(Icons.camera_alt, size: 18, color: Colors.white)
                      ),
                    ),
                  ),
                ],
              ),
            ),
            
            // --- KARTU INFORMASI ---
            _buildSectionCard(
              title: "Informasi Dosen",
              icon: Icons.badge_outlined,
              child: Column(
                children: [
                  TextField(
                    controller: _namaController,
                    decoration: InputDecoration(
                      labelText: "Nama Lengkap & Gelar",
                      prefixIcon: const Icon(Icons.person_outline),
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
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))
                      ),
                      onPressed: _isLoading ? null : _handleUpdateProfile,
                      icon: const Icon(Icons.save_as_outlined),
                      label: const Text("Perbarui Nama", style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ),

            _buildSectionCard(
              title: "Privasi Akun",
              icon: Icons.security_outlined,
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(backgroundColor: Colors.orange.shade50, child: const Icon(Icons.lock_open, color: Colors.orange)),
                title: const Text("Kata Sandi", style: TextStyle(fontWeight: FontWeight.bold)),
                subtitle: const Text("Ganti password login Anda"),
                trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                onTap: _showChangePasswordDialog,
              ),
            ),

            _buildSectionCard(
              title: "E-Signature",
              icon: Icons.gesture,
              child: Column(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300), 
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
                            backgroundColor: Colors.blue.shade900, 
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
        borderRadius: BorderRadius.circular(25),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 20, offset: const Offset(0, 10))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: Colors.blue.shade800, size: 22),
              const SizedBox(width: 12),
              Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ],
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 15),
            child: Divider(height: 1),
          ),
          child,
        ],
      ),
    );
  }
}