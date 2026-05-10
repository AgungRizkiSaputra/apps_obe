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

  void _refresh() => setState(() {});

  void _showAddDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Tambah CPL Prodi"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: _kodeController, decoration: const InputDecoration(labelText: "Kode CPL (Contoh: CPL-01)")),
            TextField(controller: _deskripsiController, decoration: const InputDecoration(labelText: "Deskripsi"), maxLines: 3),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Batal")),
          ElevatedButton(
            onPressed: () async {
              await rpsService.addCpl(_kodeController.text, _deskripsiController.text);
              _kodeController.clear();
              _deskripsiController.clear();
              if (mounted) { Navigator.pop(context); _refresh(); }
            },
            child: const Text("Simpan"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Data CPL Prodi")),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: rpsService.getAllCpl(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final listCpl = snapshot.data!;
          return ListView.builder(
            padding: const EdgeInsets.all(10),
            itemCount: listCpl.length,
            itemBuilder: (context, index) {
              final cpl = listCpl[index];
              return Card(
                child: ListTile(
                  title: Text(cpl['kode_cpl'] ?? '-', style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text(cpl['deskripsi'] ?? '-'),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () async {
                      try {
                        await rpsService.deleteCpl(cpl['id']);
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text("Berhasil menghapus CPL")),
                          );
                          _refresh();
                        }
                      } catch (e) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text("Gagal hapus CPL: $e"), 
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      }
                    },
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(onPressed: _showAddDialog, child: const Icon(Icons.add)),
    );
  }
}