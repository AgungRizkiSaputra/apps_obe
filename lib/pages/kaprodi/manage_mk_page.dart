import 'package:flutter/material.dart';
import '../../services/rps_service.dart';

class ManageMkPage extends StatefulWidget {
  const ManageMkPage({super.key});

  @override
  State<ManageMkPage> createState() => _ManageMkPageState();
}

class _ManageMkPageState extends State<ManageMkPage> {
  final rpsService = RpsService();
  
  // Controller untuk form input
  final _kodeController = TextEditingController();
  final _namaController = TextEditingController();
  final _sksController = TextEditingController();
  final _semesterController = TextEditingController();

  // Fungsi Refresh Data
  void _refresh() {
    setState(() {});
  }

  // --- FUNGSI TAMBAH DATA ---
  void _showAddDialog() {
    _clearControllers();
    showDialog(
      context: context,
      builder: (context) => _buildMkDialog(
        title: "Tambah Mata Kuliah",
        buttonText: "Simpan",
        onPressed: () async {
          if (_namaController.text.isEmpty) return;
          try {
            await rpsService.addMataKuliah(
              _kodeController.text,
              _namaController.text,
              int.tryParse(_sksController.text) ?? 0,
              int.tryParse(_semesterController.text) ?? 0,
            );
            _handleSuccess("Berhasil menambah mata kuliah");
          } catch (e) {
            _handleError(e);
          }
        },
      ),
    );
  }

  // --- FUNGSI EDIT DATA ---
  void _showEditDialog(Map<String, dynamic> mk) {
    _kodeController.text = mk['kode_mk']?.toString() ?? '';
    _namaController.text = mk['nama_mk']?.toString() ?? '';
    _sksController.text = mk['sks']?.toString() ?? '0';
    _semesterController.text = mk['semester']?.toString() ?? '0';

    showDialog(
      context: context,
      builder: (context) => _buildMkDialog(
        title: "Edit Mata Kuliah",
        buttonText: "Update",
        onPressed: () async {
          if (_namaController.text.isEmpty) return;
          try {
            await rpsService.updateMataKuliah(
              mk['id'],
              _kodeController.text,
              _namaController.text,
              int.tryParse(_sksController.text) ?? 0,
              int.tryParse(_semesterController.text) ?? 0,
            );
            _handleSuccess("Berhasil memperbarui mata kuliah");
          } catch (e) {
            _handleError(e);
          }
        },
      ),
    );
  }

  // --- WIDGET DIALOG REUSABLE (Untuk Tambah & Edit) ---
  Widget _buildMkDialog({required String title, required String buttonText, required VoidCallback onPressed}) {
    return AlertDialog(
      title: Text(title),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: _kodeController, decoration: const InputDecoration(labelText: "Kode MK")),
            TextField(controller: _namaController, decoration: const InputDecoration(labelText: "Nama MK")),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _sksController, 
                    decoration: const InputDecoration(labelText: "SKS"), 
                    keyboardType: TextInputType.number
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _semesterController, 
                    decoration: const InputDecoration(labelText: "Semester"), 
                    keyboardType: TextInputType.number
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text("Batal")),
        ElevatedButton(onPressed: onPressed, child: Text(buttonText)),
      ],
    );
  }

  void _clearControllers() {
    _kodeController.clear();
    _namaController.clear();
    _sksController.clear();
    _semesterController.clear();
  }

  void _handleSuccess(String message) {
    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
      _refresh();
    }
  }

  void _handleError(Object e) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Gagal: $e"), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Data Mata Kuliah")),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: rpsService.getAllMataKuliah(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) return Center(child: Text("Error: ${snapshot.error}"));
          
          final listMk = snapshot.data ?? [];
          if (listMk.isEmpty) return const Center(child: Text("Belum ada data mata kuliah."));

          return ListView.builder(
            padding: const EdgeInsets.all(8),
            itemCount: listMk.length,
            itemBuilder: (context, index) {
              final mk = listMk[index];
              final String namaMk = mk['nama_mk']?.toString() ?? 'Tanpa Nama';
              final String kodeMk = mk['kode_mk']?.toString() ?? '- No Code -';
              final String sksMk = mk['sks']?.toString() ?? '0';
              final String semMk = mk['semester']?.toString() ?? '0';

              return Card(
                elevation: 2,
                margin: const EdgeInsets.symmetric(vertical: 4),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.blue.shade100,
                    child: Text(sksMk, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  ),
                  title: Text(namaMk, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text("Kode: $kodeMk | Semester: $semMk"),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit, color: Colors.blue),
                        onPressed: () => _showEditDialog(mk),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () async {
                          final confirm = await showDialog<bool>(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: const Text("Hapus MK?"),
                              content: const Text("Data tidak bisa dihapus jika sudah digunakan di RPS."),
                              actions: [
                                TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Batal")),
                                TextButton(onPressed: () => Navigator.pop(context, true), child: const Text("Hapus")),
                              ],
                            ),
                          );

                          if (confirm == true) {
                            try {
                              await rpsService.deleteMataKuliah(mk['id']);
                              _handleSuccess("Berhasil menghapus mata kuliah");
                            } catch (e) {
                              _handleError(e);
                            }
                          }
                        },
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddDialog,
        child: const Icon(Icons.add),
      ),
    );
  }
}