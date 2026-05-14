import 'package:flutter/material.dart';
import '../../services/rps_service.dart';

class ManageDosenPage extends StatefulWidget {
  const ManageDosenPage({super.key});

  @override
  State<ManageDosenPage> createState() => _ManageDosenPageState();
}

class _ManageDosenPageState extends State<ManageDosenPage> {
  final rpsService = RpsService();
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

  // --- FUNGSI UNTUK MODAL FORM TAMBAH DOSEN ---
  void _showAddDosenDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(
            children: [
              Icon(Icons.person_add_alt_1, color: Colors.blue),
              SizedBox(width: 10),
              Text("Tambah Dosen Baru"),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  "Akun ini akan didaftarkan sebagai Dosen Pengampu RPS.",
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: _namaController,
                  decoration: const InputDecoration(
                    labelText: "Nama Lengkap & Gelar",
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.badge_outlined),
                  ),
                ),
                const SizedBox(height: 15),
                TextField(
                  controller: _emailController,
                  decoration: const InputDecoration(
                    labelText: "Email Institusi",
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.email_outlined),
                  ),
                ),
                const SizedBox(height: 15),
                TextField(
                  controller: _passController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: "Password Default",
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.lock_outline),
                    helperText: "Minimal 6 karakter",
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
                backgroundColor: Colors.blue.shade800,
                foregroundColor: Colors.white,
              ),
              onPressed: _isRegistering ? null : () async {
                if (_namaController.text.isEmpty || _emailController.text.isEmpty || _passController.text.length < 6) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Lengkapi data dengan benar!")));
                  return;
                }

                setModalState(() => _isRegistering = true);
                try {
                  // Panggil fungsi pendaftaran dari service
                  await rpsService.tambahDosenBaru(
                    email: _emailController.text.trim(),
                    password: _passController.text.trim(),
                    nama: _namaController.text.trim(),
                  );
                  
                  if (mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Dosen Berhasil Didaftarkan!"), backgroundColor: Colors.green)
                    );
                    _namaController.clear();
                    _emailController.clear();
                    _passController.clear();
                    setState(() {}); // Refresh list
                  }
                } catch (e) {
                  if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Gagal: $e"), backgroundColor: Colors.red));
                } finally {
                  setModalState(() => _isRegistering = false);
                }
              },
              child: _isRegistering ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Text("Simpan"),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: const Text("Data Dosen Pengampu"),
        backgroundColor: Colors.blue.shade800,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Column(
        children: [
          // Search Bar Area
          Container(
            padding: const EdgeInsets.fromLTRB(15, 5, 15, 20),
            decoration: BoxDecoration(
              color: Colors.blue.shade800,
              borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(25), bottomRight: Radius.circular(25)),
            ),
            child: Container(
              height: 50,
              padding: const EdgeInsets.symmetric(horizontal: 15),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(15),
                boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10)],
              ),
              child: TextField(
                onChanged: (val) => setState(() => _searchQuery = val.toLowerCase()),
                decoration: const InputDecoration(
                  hintText: "Cari Nama Dosen...",
                  border: InputBorder.none,
                  icon: Icon(Icons.search, color: Colors.blue),
                ),
              ),
            ),
          ),
          
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

                if (filteredList.isEmpty) return const Center(child: Text("Dosen tidak ditemukan."));

                return RefreshIndicator(
                  onRefresh: () async => setState(() {}),
                  child: ListView.builder(
                    padding: const EdgeInsets.all(15),
                    itemCount: filteredList.length,
                    itemBuilder: (context, index) {
                      final dosen = filteredList[index];
                      return Card(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                        elevation: 2,
                        margin: const EdgeInsets.only(bottom: 12),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: Colors.blue.shade100,
                            child: const Icon(Icons.person, color: Colors.blue),
                          ),
                          title: Text(dosen['nama'] ?? 'Tanpa Nama', 
                              style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text(dosen['email'] ?? '-'),
                          trailing: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.orange.shade100,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Text("Dosen", style: TextStyle(color: Colors.orange, fontSize: 10, fontWeight: FontWeight.bold)),
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
      // --- TOMBOL TAMBAH DOSEN ---
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddDosenDialog,
        backgroundColor: Colors.blue.shade800,
        icon: const Icon(Icons.add),
        label: const Text("Tambah Dosen"),
      ),
    );
  }
}