import 'package:flutter/material.dart';
import '../../services/rps_service.dart';

class ManageMkPage extends StatefulWidget {
  const ManageMkPage({super.key});

  @override
  State<ManageMkPage> createState() => _ManageMkPageState();
}

class _ManageMkPageState extends State<ManageMkPage> {
  final rpsService = RpsService();
  final primaryColor = Colors.indigo.shade900;
  
  // Controller untuk form input (TIDAK DIUBAH)
  final _kodeController = TextEditingController();
  final _namaController = TextEditingController();
  final _sksController = TextEditingController();
  final _semesterController = TextEditingController();

  // Fungsi Refresh Data (TIDAK DIUBAH)
  void _refresh() => setState(() {});

  // --- LOGIKA VALIDASI INPUT (TETAP UTUH) ---
  bool _isValid() {
    if (_kodeController.text.trim().isEmpty || _namaController.text.trim().isEmpty) {
      _showWarning("Kode dan Nama MK wajib diisi!");
      return false;
    }
    int? sks = int.tryParse(_sksController.text);
    int? semester = int.tryParse(_semesterController.text);
    if (sks == null || sks <= 0 || sks > 8) {
      _showWarning("SKS harus berupa angka antara 1 - 8!");
      return false;
    }
    if (semester == null || semester <= 0 || semester > 14) {
      _showWarning("Semester harus berupa angka logis (1 - 14)!");
      return false;
    }
    return true;
  }

  void _showWarning(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg), 
        backgroundColor: Colors.orange, 
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      )
    );
  }

  // --- FUNGSI TAMBAH DATA (LOGIKA UTUH) ---
  void _showAddDialog() {
    _clearControllers();
    showDialog(
      context: context,
      builder: (context) => _buildMkDialog(
        title: "Tambah Mata Kuliah",
        buttonText: "Simpan",
        onPressed: () async {
          if (!_isValid()) return;
          try {
            await rpsService.addMataKuliah(
              _kodeController.text.trim(),
              _namaController.text.trim(),
              int.parse(_sksController.text),
              int.parse(_semesterController.text),
            );
            _handleSuccess("Berhasil menambah mata kuliah");
          } catch (e) {
            _handleError(e);
          }
        },
      ),
    );
  }

  // --- FUNGSI EDIT DATA (LOGIKA UTUH) ---
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
          if (!_isValid()) return;
          try {
            await rpsService.updateMataKuliah(
              mk['id'],
              _kodeController.text.trim(),
              _namaController.text.trim(),
              int.parse(_sksController.text),
              int.parse(_semesterController.text),
            );
            _handleSuccess("Berhasil memperbarui mata kuliah");
          } catch (e) {
            _handleError(e);
          }
        },
      ),
    );
  }

  // --- WIDGET DIALOG REUSABLE (UI DIPOLEH) ---
  Widget _buildMkDialog({required String title, required String buttonText, required VoidCallback onPressed}) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildDialogField(_kodeController, "Kode MK", Icons.qr_code, "Contoh: MK001"),
            const SizedBox(height: 15),
            _buildDialogField(_namaController, "Nama Mata Kuliah", Icons.book, ""),
            const SizedBox(height: 15),
            Row(
              children: [
                Expanded(child: _buildDialogField(_sksController, "SKS", Icons.analytics, "", isNumber: true)),
                const SizedBox(width: 15),
                Expanded(child: _buildDialogField(_semesterController, "Sem.", Icons.calendar_view_day, "", isNumber: true)),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text("Batal")),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: primaryColor,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))
          ),
          onPressed: onPressed, 
          child: Text(buttonText)
        ),
      ],
    );
  }

  Widget _buildDialogField(TextEditingController controller, String label, IconData icon, String hint, {bool isNumber = false}) {
    return TextField(
      controller: controller,
      keyboardType: isNumber ? TextInputType.number : TextInputType.text,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, size: 20),
        filled: true,
        fillColor: Colors.grey.shade50,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
      ),
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.green, behavior: SnackBarBehavior.floating)
      );
      _refresh();
    }
  }

  void _handleError(Object e) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Gagal: $e"), backgroundColor: Colors.red, behavior: SnackBarBehavior.floating),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text("Data Mata Kuliah", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        centerTitle: true,
        elevation: 0,
      ),
      body: Column(
        children: [
          // Aksen Header
          Container(
            height: 20,
            width: double.infinity,
            decoration: BoxDecoration(
              color: primaryColor,
              borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(30), bottomRight: Radius.circular(30)),
            ),
          ),
          Expanded(
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: rpsService.getAllMataKuliah(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
                if (snapshot.hasError) return Center(child: Text("Error: ${snapshot.error}"));
                
                final listMk = snapshot.data ?? [];
                if (listMk.isEmpty) return const Center(child: Text("Belum ada data mata kuliah."));

                return ListView.builder(
                  padding: const EdgeInsets.all(15),
                  itemCount: listMk.length,
                  itemBuilder: (context, index) {
                    final mk = listMk[index];
                    return _buildMkCard(mk);
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddDialog, 
        backgroundColor: primaryColor,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text("TAMBAH MK", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildMkCard(Map<String, dynamic> mk) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))],
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
        leading: CircleAvatar(
          radius: 25,
          backgroundColor: primaryColor.withOpacity(0.1),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(mk['sks']?.toString() ?? '0', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: primaryColor)),
              const Text("SKS", style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
        title: Text(mk['nama_mk'] ?? 'Tanpa Nama', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 5),
          child: Text("Kode: ${mk['kode_mk'] ?? '-'}  •  Semester: ${mk['semester'] ?? '-'}", style: const TextStyle(fontSize: 12)),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(icon: Icon(Icons.edit_outlined, color: Colors.blue.shade700, size: 22), onPressed: () => _showEditDialog(mk)),
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 22),
              onPressed: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    title: const Text("Hapus MK?"),
                    content: const Text("Data MK tidak bisa dihapus jika sedang digunakan di RPS aktif."),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Batal")),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                        onPressed: () => Navigator.pop(context, true), 
                        child: const Text("Hapus", style: TextStyle(color: Colors.white))
                      ),
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
  }
}