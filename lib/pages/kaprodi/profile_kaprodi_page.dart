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
  
  final TextEditingController _namaController = TextEditingController();
  final SignatureController _sigController = SignatureController(
    penStrokeWidth: 3, 
    penColor: Colors.blue.shade900, 
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

  // --- LOGIKA UPLOAD FOTO ---
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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Foto profil Kaprodi diperbarui!"), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // --- LOGIKA UPDATE NAMA ---
  Future<void> _handleUpdateProfile() async {
    if (_namaController.text.isEmpty) return;
    setState(() => _isLoading = true);
    try {
      await rpsService.updateProfile(user!.id, _namaController.text);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Nama Kaprodi berhasil diperbarui!"), backgroundColor: Colors.green));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // --- FUNGSI GANTI PASSWORD ---
  void _showChangePasswordDialog() {
    final passController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: const Text("Ganti Password Akun"),
        content: TextField(
          controller: passController,
          obscureText: true,
          decoration: const InputDecoration(
            hintText: "Minimal 6 karakter",
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.lock_outline),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Batal")),
          ElevatedButton(
            onPressed: () async {
              if (passController.text.length < 6) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Password terlalu pendek!")));
                return;
              }
              try {
                await rpsService.changePassword(passController.text);
                if (mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Password berhasil diperbarui!"), backgroundColor: Colors.green));
                }
              } catch (e) {
                if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
              }
            },
            child: const Text("Simpan"),
          ),
        ],
      ),
    );
  }

  // --- LOGIKA SIMPAN TTD ---
  Future<void> _saveSignature() async {
    if (_sigController.isEmpty) return;
    setState(() => _isLoading = true);
    try {
      final Uint8List? data = await _sigController.toPngBytes();
      if (data != null) {
        await rpsService.uploadSignature(user!.id, data);
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Tanda tangan Kaprodi disimpan!"), backgroundColor: Colors.green));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Colors.indigo.shade900; 

    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: const Text("Profil Kaprodi"),
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            Container(
              height: 100,
              width: double.infinity,
              decoration: BoxDecoration(
                color: primaryColor,
                borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(40), bottomRight: Radius.circular(40)),
              ),
              child: Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Text("Kaprodi: ${user?.email ?? "-"}", textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70, fontSize: 13)),
              ),
            ),

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
                    child: CircleAvatar(
                      radius: 18, 
                      backgroundColor: primaryColor, 
                      child: const Icon(Icons.camera_alt, size: 18, color: Colors.white)
                    ),
                  ),
                ],
              ),
            ),
            
            _buildSectionCard(
              title: "Data Struktural",
              icon: Icons.account_balance_outlined,
              child: Column(
                children: [
                  TextField(
                    controller: _namaController,
                    decoration: InputDecoration(
                      labelText: "Nama Kaprodi & Gelar",
                      prefixIcon: const Icon(Icons.person),
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
                leading: const Icon(Icons.password, color: Colors.orange),
                title: const Text("Ubah Kata Sandi"),
                subtitle: const Text("Amankan akun Kaprodi Anda"),
                trailing: const Icon(Icons.chevron_right),
                onTap: _showChangePasswordDialog,
              ),
            ),

            _buildSectionCard(
              title: "Tanda Tangan Kaprodi",
              icon: Icons.draw_outlined,
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
              Icon(icon, color: Colors.indigo.shade900, size: 22),
              const SizedBox(width: 12),
              Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ],
          ),
          const Divider(height: 30),
          child,
        ],
      ),
    );
  }
}