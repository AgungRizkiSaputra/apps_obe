import 'package:flutter/material.dart';
import '../../services/rps_service.dart';

class ManageDosenPage extends StatefulWidget {
  const ManageDosenPage({super.key});

  @override
  State<ManageDosenPage> createState() => _ManageDosenPageState();
}

class _ManageDosenPageState extends State<ManageDosenPage> {
  final rpsService = RpsService();
  final primaryColor = Colors.indigo.shade900;
  String _searchQuery = "";
  bool _isRegistering = false;

  // Controller untuk Form Tambah Dosen
  final _namaController = TextEditingController();
  final _emailController = TextEditingController();
  final _passController = TextEditingController();

  @override
  void dispose() {
    _namaController.dispose();
    _emailController.dispose();
    _passController.dispose();
    super.dispose();
  }

  // --- POLESAN NOTIFIKASI ---
  void _showCustomNotif(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  // --- UI DIALOG TAMBAH DOSEN (LOGIKA UTUH) ---
  void _showAddDosenDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              Icon(Icons.person_add_rounded, color: primaryColor),
              const SizedBox(width: 10),
              const Text("Daftarkan Dosen", style: TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  "Akun ini akan didaftarkan sebagai Dosen Pengampu RPS di aplikasi ini.",
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: _namaController,
                  decoration: InputDecoration(
                    labelText: "Nama Lengkap & Gelar",
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    prefixIcon: const Icon(Icons.badge_outlined),
                    filled: true,
                    fillColor: Colors.grey.shade50,
                  ),
                ),
                const SizedBox(height: 15),
                TextField(
                  controller: _emailController,
                  decoration: InputDecoration(
                    labelText: "Email Institusi",
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    prefixIcon: const Icon(Icons.email_outlined),
                    filled: true,
                    fillColor: Colors.grey.shade50,
                  ),
                ),
                const SizedBox(height: 15),
                TextField(
                  controller: _passController,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: "Password Default",
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    prefixIcon: const Icon(Icons.lock_outline),
                    helperText: "Minimal 6 karakter",
                    filled: true,
                    fillColor: Colors.grey.shade50,
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                _namaController.clear();
                _emailController.clear();
                _passController.clear();
                Navigator.pop(context);
              },
              child: const Text("Batal"),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: _isRegistering ? null : () async {
                if (_namaController.text.isEmpty || _emailController.text.isEmpty || _passController.text.length < 6) {
                  _showCustomNotif("Lengkapi data dengan benar!", Colors.orange);
                  return;
                }

                setModalState(() => _isRegistering = true);
                try {
                  await rpsService.tambahDosenBaru(
                    email: _emailController.text.trim(),
                    password: _passController.text.trim(),
                    nama: _namaController.text.trim(),
                  );
                  
                  if (mounted) {
                    Navigator.pop(context);
                    _showCustomNotif("Dosen Berhasil Didaftarkan!", Colors.green);
                    _namaController.clear();
                    _emailController.clear();
                    _passController.clear();
                    setState(() {}); 
                  }
                } catch (e) {
                  if (mounted) _showCustomNotif("Gagal: $e", Colors.red);
                } finally {
                  setModalState(() => _isRegistering = false);
                }
              },
              child: _isRegistering 
                ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) 
                : const Text("Daftarkan"),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text("Data Dosen Pengampu", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      body: Column(
        children: [
          // --- POLESAN SEARCH BAR AREA ---
          Container(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 30),
            decoration: BoxDecoration(
              color: primaryColor,
              borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(30), bottomRight: Radius.circular(30)),
            ),
            child: Container(
              height: 55,
              padding: const EdgeInsets.symmetric(horizontal: 15),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(15),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 5))],
              ),
              child: TextField(
                onChanged: (val) => setState(() => _searchQuery = val.toLowerCase()),
                decoration: InputDecoration(
                  hintText: "Cari nama dosen...",
                  hintStyle: const TextStyle(color: Colors.grey, fontSize: 14),
                  border: InputBorder.none,
                  icon: Icon(Icons.search_rounded, color: primaryColor),
                ),
              ),
            ),
          ),
          
          // --- LIST DATA DOSEN ---
          Expanded(
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: rpsService.getAllDosen(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) return Center(child: Text("Error: ${snapshot.error}"));

                final listDosen = snapshot.data ?? [];
                final filteredList = listDosen.where((dosen) {
                  final nama = (dosen['nama'] ?? '').toString().toLowerCase();
                  return nama.contains(_searchQuery);
                }).toList();

                if (filteredList.isEmpty) return _buildEmptyState();

                return RefreshIndicator(
                  onRefresh: () async => setState(() {}),
                  child: ListView.builder(
                    padding: const EdgeInsets.all(20),
                    itemCount: filteredList.length,
                    itemBuilder: (context, index) {
                      final dosen = filteredList[index];
                      return _buildDosenCard(dosen);
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddDosenDialog,
        backgroundColor: primaryColor,
        elevation: 4,
        icon: const Icon(Icons.person_add_alt_1_rounded, color: Colors.white),
        label: const Text("TAMBAH DOSEN", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 1)),
      ),
    );
  }

  // --- UI COMPONENT HELPERS ---

  Widget _buildDosenCard(Map<String, dynamic> dosen) {
    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))],
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(15),
        leading: CircleAvatar(
          radius: 25,
          backgroundColor: primaryColor.withOpacity(0.1),
          child: Icon(Icons.person_rounded, color: primaryColor, size: 30),
        ),
        title: Text(
          dosen['nama'] ?? 'Tanpa Nama', 
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 5),
            Row(
              children: [
                const Icon(Icons.email_outlined, size: 14, color: Colors.grey),
                const SizedBox(width: 5),
                Text(dosen['email'] ?? '-', style: const TextStyle(fontSize: 12, color: Colors.grey)),
              ],
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Colors.blue.shade100),
              ),
              child: const Text("DOSEN PENGAMPU", style: TextStyle(color: Colors.blue, fontSize: 9, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.person_search_rounded, size: 80, color: Colors.grey.shade200),
          const SizedBox(height: 10),
          const Text("Dosen tidak ditemukan.", style: TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }
}