import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/rps_service.dart';
import 'create_rps_page.dart';
import '../shared/detail_rps_page.dart';
import 'mapping_page.dart';

class DashboardDosen extends StatefulWidget {
  const DashboardDosen({super.key});

  @override
  State<DashboardDosen> createState() => _DashboardDosenState();
}

class _DashboardDosenState extends State<DashboardDosen> {
  final rpsService = RpsService();
  final user = Supabase.instance.client.auth.currentUser;

  late Future<List<Map<String, dynamic>>> _rpsFuture;

  bool _isSelectionMode = false;
  List<String> _selectedRpsIds = [];

  @override
  void initState() {
    super.initState();
    _refreshData();
  }

  Future<void> _refreshData() async {
    final dataBaru = rpsService.getRpsByDosen(user!.id);
    setState(() {
      _rpsFuture = dataBaru;
    });
  }

  // --- FUNGSI HAPUS SATUAN DENGAN PERINGATAN BERLAPIS ---
  Future<void> _confirmSingleDelete(Map<String, dynamic> rps) async {
    final bool isApproved = rps['status'] == 'approved';
    final String rpsId = rps['id'].toString();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isApproved ? "⚠️ PERINGATAN KERAS!" : "Hapus RPS?"),
        content: Text(isApproved 
          ? "RPS ini SUDAH DISETUJUI oleh Kaprodi. Menghapus RPS ini akan menghilangkan data kurikulum yang valid. Anda yakin?" 
          : "Yakin ingin menghapus RPS ini?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Batal")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: isApproved ? Colors.red.shade900 : Colors.red),
            onPressed: () async {
              Navigator.pop(context);
              await _executeDelete([rpsId]);
            },
            child: Text(isApproved ? "Iya, Saya Bertanggung Jawab" : "Hapus", style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // --- FUNGSI HAPUS MASSAL ---
  void _confirmBulkDelete() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Hapus RPS Terpilih?"),
        content: Text("Yakin ingin menghapus ${_selectedRpsIds.length} data RPS ini secara permanen?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Batal")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(context);
              await _executeDelete(_selectedRpsIds);
            },
            child: const Text("Hapus Semua", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // --- EKSEKUSI HAPUS KE DATABASE ---
  Future<void> _executeDelete(List<String> ids) async {
    try {
      await rpsService.deleteMultipleRps(ids);
      setState(() {
        _isSelectionMode = false;
        _selectedRpsIds.clear();
      });
      _refreshData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Data berhasil dihapus!"), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Gagal menghapus: $e"), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _handleKirimKeKaprodi(String rpsId) async {
    try {
      await rpsService.updateStatusRps(rpsId, 'waiting_approval');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("RPS Berhasil dikirim ke Kaprodi!")));
        await _refreshData();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Gagal mengirim: $e"), backgroundColor: Colors.red));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isSelectionMode ? "${_selectedRpsIds.length} Terpilih" : "Dashboard Dosen"),
        actions: [
          if (!_isSelectionMode) ...[
            PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'pilih') setState(() => _isSelectionMode = true);
              },
              itemBuilder: (context) => [const PopupMenuItem(value: 'pilih', child: Text("Pilih Banyak"))],
            ),
            IconButton(
              icon: const Icon(Icons.logout),
              onPressed: () async {
                await Supabase.instance.client.auth.signOut();
                if (mounted) Navigator.pushReplacementNamed(context, '/login');
              },
            ),
          ] else ...[
            IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: _selectedRpsIds.isEmpty ? null : _confirmBulkDelete),
            IconButton(icon: const Icon(Icons.close), onPressed: () => setState(() { _isSelectionMode = false; _selectedRpsIds.clear(); })),
          ],
        ],
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _rpsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          if (snapshot.hasError) return Center(child: Text("Error: ${snapshot.error}"));

          final listRps = snapshot.data ?? [];
          if (listRps.isEmpty) return const Center(child: Text("Belum ada RPS. Klik tombol + untuk membuat."));

          return ListView.builder(
            padding: const EdgeInsets.all(10),
            itemCount: listRps.length,
            itemBuilder: (context, index) {
              final rps = listRps[index];
              final String rpsId = rps['id'].toString();
              final String status = rps['status'];

              return Card(
                elevation: 3,
                margin: const EdgeInsets.symmetric(vertical: 8),
                color: _selectedRpsIds.contains(rpsId) ? Colors.blue.shade50 : null,
                child: ListTile(
                  onLongPress: () => setState(() { _isSelectionMode = true; _selectedRpsIds.add(rpsId); }),
                  leading: _isSelectionMode
                      ? Checkbox(
                          value: _selectedRpsIds.contains(rpsId),
                          onChanged: (val) {
                            setState(() { val == true ? _selectedRpsIds.add(rpsId) : _selectedRpsIds.remove(rpsId); });
                          },
                        )
                      : null,
                  title: Text(rps['mata_kuliah']?['nama_mk'] ?? 'Mata Kuliah', style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Tahun: ${rps['tahun_ajaran']} | Semester: ${rps['semester']}"),
                      const SizedBox(height: 8),
                      _buildStatusChip(status),
                      if (rps['catatan'] != null && (status == 'revisi' || status == 'revisi_selesai'))
                        _buildCatatanBox(rps),
                    ],
                  ),
                  trailing: _isSelectionMode 
                      ? null 
                      : Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _buildTrailingWidget(status, rpsId),
                            if (status != 'waiting_approval' && status != 'waiting_approval_revision')
                              IconButton(
                                icon: const Icon(Icons.delete_outline, color: Colors.red),
                                onPressed: () => _confirmSingleDelete(rps),
                              ),
                          ],
                        ),
                  onTap: () {
                    if (_isSelectionMode) {
                      setState(() { _selectedRpsIds.contains(rpsId) ? _selectedRpsIds.remove(rpsId) : _selectedRpsIds.add(rpsId); });
                    } else {
                      Navigator.push(context, MaterialPageRoute(builder: (context) => DetailRpsPage(rpsId: rpsId)));
                    }
                  },
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: _isSelectionMode ? null : FloatingActionButton.extended(
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const CreateRpsPage())).then((_) => _refreshData()),
        label: const Text("Buat RPS Baru"),
        icon: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildCatatanBox(Map<String, dynamic> rps) {
    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(color: Colors.orange.withOpacity(0.1), borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.orange.withOpacity(0.5))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [const Icon(Icons.info_outline, color: Colors.orange, size: 16), const SizedBox(width: 8), Expanded(child: Text("Catatan: ${rps['catatan']}", style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic)))]),
          if (!_isSelectionMode)
            TextButton.icon(
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => MappingPage(rpsData: rps, isRevision: true))).then((_) => _refreshData()),
              icon: const Icon(Icons.edit, size: 18, color: Colors.orange),
              label: const Text("Perbaiki Mapping", style: TextStyle(color: Colors.orange)),
            ),
        ],
      ),
    );
  }

  Widget _buildTrailingWidget(String status, String rpsId) {
    if (status == 'draft' || status == 'revisi' || status == 'revisi_selesai') {
      return ElevatedButton(
        style: ElevatedButton.styleFrom(backgroundColor: status.contains('revisi') ? Colors.orange : Colors.blueAccent, foregroundColor: Colors.white),
        onPressed: () => _handleKirimKeKaprodi(rpsId),
        child: Text(status.contains('revisi') ? "Kirim Ulang" : "Kirim"),
      );
    } else if (status.contains('waiting')) {
      return const Icon(Icons.hourglass_top, color: Colors.blue);
    } else if (status == 'approved') {
      return const Icon(Icons.check_circle, color: Colors.green, size: 28);
    }
    return const SizedBox();
  }

  Widget _buildStatusChip(String status) {
    Color color;
    String label = status.toUpperCase();
    switch (status) {
      case 'approved': color = Colors.green; break;
      case 'revisi': color = Colors.orange; break;
      case 'revisi_selesai': color = Colors.cyan; label = "REVISI DISIMPAN"; break;
      case 'waiting_approval': 
      case 'waiting_approval_revision': color = Colors.blue; label = "DITINJAU"; break;
      default: color = Colors.grey;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(12)),
      child: Text(label, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
    );
  }
}