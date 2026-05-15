import 'package:flutter/material.dart';
import '../../services/rps_service.dart';

class ManageCplPage extends StatefulWidget {
  const ManageCplPage({super.key});

  @override
  State<ManageCplPage> createState() => _ManageCplPageState();
}

class _ManageCplPageState extends State<ManageCplPage> {
  final rpsService = RpsService();
  final _kodeController = TextEditingController();
  final _deskripsiController = TextEditingController();
  final primaryColor = Colors.indigo.shade900;

  void _refresh() => setState(() {});

  // --- UI DIALOG TAMBAH (LOGIKA UTUH) ---
  void _showAddDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("Tambah CPL Prodi", style: TextStyle(fontWeight: FontWeight.bold)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _kodeController, 
                decoration: InputDecoration(
                  labelText: "Kode CPL",
                  hintText: "Contoh: CPL-01",
                  prefixIcon: const Icon(Icons.tag),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                )
              ),
              const SizedBox(height: 15),
              TextField(
                controller: _deskripsiController, 
                maxLines: 4,
                decoration: InputDecoration(
                  labelText: "Deskripsi", 
                  alignLabelWithHint: true,
                  prefixIcon: const Icon(Icons.description_outlined),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Batal")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryColor,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () async {
              if (_kodeController.text.trim().isEmpty || _deskripsiController.text.trim().isEmpty) {
                _showNotif("Kode dan Deskripsi tidak boleh kosong!", Colors.orange);
                return;
              }

              try {
                await rpsService.addCpl(_kodeController.text.trim(), _deskripsiController.text.trim());
                _kodeController.clear();
                _deskripsiController.clear();
                if (mounted) { 
                  Navigator.pop(context); 
                  _refresh(); 
                  _showNotif("Berhasil menambah CPL Prodi", Colors.green);
                }
              } catch (e) {
                if (mounted) _showNotif("Gagal: $e", Colors.red);
              }
            },
            child: const Text("Simpan", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // --- HELPER NOTIFIKASI ---
  void _showNotif(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text("Data CPL Prodi", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
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
              future: rpsService.getAllCpl(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                final listCpl = snapshot.data!;
                if (listCpl.isEmpty) return _buildEmptyState();

                return ListView.builder(
                  padding: const EdgeInsets.all(15),
                  itemCount: listCpl.length,
                  itemBuilder: (context, index) {
                    final cpl = listCpl[index];
                    return _buildCplCard(cpl, index);
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
        label: const Text("TAMBAH CPL", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildCplCard(Map<String, dynamic> cpl, int index) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        leading: CircleAvatar(
          backgroundColor: primaryColor.withValues(alpha: 0.1),
          child: Text(
            "${index + 1}",
            style: TextStyle(
              color: primaryColor,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        title: Text(
          cpl['kode_cpl'] ?? '-', 
          style: TextStyle(fontWeight: FontWeight.bold, color: primaryColor)
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 5),
          child: Text(
            cpl['deskripsi'] ?? '-',
            style: const TextStyle(fontSize: 13, height: 1.4),
          ),
        ),
        trailing: IconButton(
          icon: const Icon(Icons.delete_sweep_outlined, color: Colors.redAccent),
          onPressed: () async {
            final confirm = await showDialog<bool>(
              context: context,
              builder: (context) => AlertDialog(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                title: const Text("Hapus CPL?"),
                content: const Text("Data yang dihapus tidak bisa dikembalikan. Pastikan CPL ini tidak sedang digunakan."),
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
                await rpsService.deleteCpl(cpl['id']);
                if (mounted) { 
                  _refresh(); 
                  _showNotif("CPL berhasil dihapus", Colors.green);
                }
              } catch (e) {
                if (mounted) _showNotif("Gagal menghapus: $e", Colors.red);
              }
            }
          },
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.inbox_outlined, size: 80, color: Colors.grey.shade300),
          const SizedBox(height: 10),
          const Text("Belum ada data CPL Prodi", style: TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }
}