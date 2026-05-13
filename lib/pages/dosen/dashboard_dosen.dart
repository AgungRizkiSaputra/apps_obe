import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/rps_service.dart';
import '../../services/pdf_helper.dart';
import 'create_rps_page.dart';
import '../../shared/detail_rps_page.dart';
import 'mapping_page.dart';
import 'profile_page.dart';
import '../auth/login_page.dart';

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
  String _searchQuery = "";

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

  Future<void> _handleLogout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Keluar Akun"),
        content: const Text("Apakah Anda yakin ingin keluar dari aplikasi?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Batal")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Keluar", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await Supabase.instance.client.auth.signOut();
      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const LoginPage()),
          (route) => false,
        );
      }
    }
  }

  void _confirmBulkDelete() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Hapus RPS Terpilih?"),
        content: Text("Yakin ingin menghapus ${_selectedRpsIds.length} data RPS ini?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Batal")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(context);
              try {
                await rpsService.deleteMultipleRps(_selectedRpsIds);
                setState(() {
                  _isSelectionMode = false;
                  _selectedRpsIds.clear();
                });
                _refreshData();
              } catch (e) {
                debugPrint("Error: $e");
              }
            },
            child: const Text("Hapus Semua", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _handleKirimKeKaprodi(String rpsId) async {
    try {
      await rpsService.updateStatusRps(rpsId, 'waiting_approval');
      _refreshData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("RPS berhasil dikirim untuk divalidasi Kaprodi"), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      debugPrint("Error: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        backgroundColor: Colors.blue.shade800,
        elevation: 0,
        toolbarHeight: 70,
        title: _isSelectionMode
            ? Text("${_selectedRpsIds.length} Terpilih", style: const TextStyle(color: Colors.white))
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Selamat Datang,", style: TextStyle(fontSize: 12, color: Colors.white70)),
                  Text(
                    user?.userMetadata?['nama'] ?? "Dosen Pengajar",
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                ],
              ),
        actions: [
          if (!_isSelectionMode) ...[
            PopupMenuButton<String>(
              iconColor: Colors.white,
              onSelected: (value) {
                if (value == 'pilih') setState(() => _isSelectionMode = true);
                if (value == 'profil') {
                  Navigator.push(context, MaterialPageRoute(builder: (context) => const ProfilePage())).then((_) => _refreshData());
                }
                if (value == 'logout') _handleLogout();
              },
              itemBuilder: (context) => [
                const PopupMenuItem(value: 'pilih', child: Row(children: [Icon(Icons.checklist, size: 20), SizedBox(width: 10), Text("Pilih Banyak")])),
                const PopupMenuItem(value: 'profil', child: Row(children: [Icon(Icons.fingerprint, size: 20), SizedBox(width: 10), Text("Profil & TTD")])),
                const PopupMenuItem(value: 'logout', child: Row(children: [Icon(Icons.logout, size: 20, color: Colors.red), SizedBox(width: 10), Text("Keluar Akun")])),
              ],
            ),
          ] else ...[
            IconButton(icon: const Icon(Icons.delete, color: Colors.redAccent), onPressed: _selectedRpsIds.isEmpty ? null : _confirmBulkDelete),
            IconButton(icon: const Icon(Icons.close, color: Colors.white), onPressed: () => setState(() { _isSelectionMode = false; _selectedRpsIds.clear(); })),
          ],
        ],
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(15, 5, 15, 20),
            decoration: BoxDecoration(
              color: Colors.blue.shade800,
              borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(25), bottomRight: Radius.circular(25)),
            ),
            child: Container(
              height: 50,
              padding: const EdgeInsets.symmetric(horizontal: 15),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(15),
                boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10, offset: const Offset(0, 5))],
              ),
              child: TextField(
                onChanged: (val) => setState(() => _searchQuery = val.toLowerCase()),
                decoration: const InputDecoration(
                  hintText: "Cari Mata Kuliah...",
                  border: InputBorder.none,
                  icon: Icon(Icons.search, color: Colors.blue),
                ),
              ),
            ),
          ),
          Expanded(
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: _rpsFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());

                final listRps = snapshot.data ?? [];
                final filteredList = listRps.where((rps) {
                  final namaMk = (rps['mata_kuliah']?['nama_mk'] ?? '').toString().toLowerCase();
                  return namaMk.contains(_searchQuery);
                }).toList();

                if (filteredList.isEmpty) return const Center(child: Text("Data RPS kosong."));

                return ListView.builder(
                  padding: const EdgeInsets.all(15),
                  itemCount: filteredList.length,
                  itemBuilder: (context, index) {
                    final rps = filteredList[index];
                    final String rpsId = rps['id'].toString();
                    final String status = rps['status'];
                    final bool canBeDeleted = status == 'draft' || status == 'revisi_selesai' || status == 'approved';

                    return Card(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                      elevation: 2,
                      margin: const EdgeInsets.only(bottom: 15),
                      color: _selectedRpsIds.contains(rpsId) ? Colors.blue.shade50 : Colors.white,
                      child: ListTile(
                        contentPadding: const EdgeInsets.all(10),
                        leading: _isSelectionMode
                            ? (canBeDeleted
                                ? Checkbox(value: _selectedRpsIds.contains(rpsId), onChanged: (val) => setState(() => val == true ? _selectedRpsIds.add(rpsId) : _selectedRpsIds.remove(rpsId)))
                                : const Icon(Icons.lock_outline, color: Colors.grey))
                            : null,
                        title: Text(rps['mata_kuliah']?['nama_mk'] ?? 'Mata Kuliah', style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text("Tahun: ${rps['tahun_ajaran']} | Semester: ${rps['semester']}"),
                            const SizedBox(height: 8),
                            _buildStatusChip(status),
                            if (rps['catatan'] != null && (status == 'revisi' || status == 'revisi_selesai')) _buildCatatanBox(rps),
                          ],
                        ),
                        trailing: _isSelectionMode ? null : _buildTrailingWidget(status, rpsId, rps),
                        onTap: () {
                          if (_isSelectionMode && canBeDeleted) {
                            setState(() => _selectedRpsIds.contains(rpsId) ? _selectedRpsIds.remove(rpsId) : _selectedRpsIds.add(rpsId));
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
          ),
        ],
      ),
      floatingActionButton: _isSelectionMode ? null : FloatingActionButton.extended(
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const CreateRpsPage())).then((_) => _refreshData()),
        label: const Text("Buat RPS Baru"),
        icon: const Icon(Icons.add),
        backgroundColor: Colors.blue.shade800,
      ),
    );
  }

  Widget _buildCatatanBox(Map<String, dynamic> rps) {
    return GestureDetector(
      onTap: () => showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text("Detail Catatan Revisi"),
          content: Text(rps['catatan'] ?? "-"),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text("Tutup")),
            if (rps['status'] == 'revisi')
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(builder: (context) => MappingPage(rpsData: rps, isRevision: true))).then((_) => _refreshData());
                },
                child: const Text("Perbaiki Sekarang"),
              ),
          ],
        ),
      ),
      child: Container(
        margin: const EdgeInsets.only(top: 10),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(color: Colors.orange.withOpacity(0.1), borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.orange.withOpacity(0.5))),
        child: Row(children: [
          const Icon(Icons.info_outline, color: Colors.orange, size: 16),
          const SizedBox(width: 8),
          Expanded(child: Text("Catatan: ${rps['catatan']}", maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic))),
          const Icon(Icons.open_in_new, size: 14, color: Colors.orange)
        ]),
      ),
    );
  }

  Widget _buildTrailingWidget(String status, String rpsId, Map<String, dynamic> rps) {
    if (status == 'approved') {
      return IconButton(
        icon: const Icon(Icons.print, color: Colors.green, size: 28),
        onPressed: () async {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Menyiapkan dokumen PDF..."), duration: Duration(seconds: 1)));
          try {
            // --- BAGIAN KRUSIAL GUNG ---
            // Ambil data RPS lengkap (termasuk users dan rps_detail)
            final fullRpsData = await rpsService.getRpsDetail(rpsId);
            // Ambil data mapping CPMK-CPL
            final mapping = await rpsService.getMappingFullForPdf(rpsId);
            
            // Panggil helper cetak dengan data yang sudah lengkap
            await PdfHelper.cetakRps(fullRpsData, mapping);
          } catch (e) {
            if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Gagal cetak PDF: $e"), backgroundColor: Colors.red));
          }
        },
      );
    } else if (status == 'draft' || status == 'revisi' || status == 'revisi_selesai') {
      return ElevatedButton(
        style: ElevatedButton.styleFrom(backgroundColor: status.contains('revisi') ? Colors.orange : Colors.blueAccent, foregroundColor: Colors.white),
        onPressed: () => _handleKirimKeKaprodi(rpsId),
        child: Text(status.contains('revisi') ? "Kirim Ulang" : "Kirim"),
      );
    } else if (status.contains('waiting')) {
      return const Icon(Icons.hourglass_top, color: Colors.blue);
    }
    return const SizedBox();
  }

  Widget _buildStatusChip(String status) {
    Color color;
    String label = status.toUpperCase();
    switch (status) {
      case 'approved': color = Colors.green; label = "DISETUJUI"; break;
      case 'revisi': color = Colors.orange; label = "REVISI"; break;
      case 'revisi_selesai': color = Colors.cyan; label = "REVISI DISIMPAN"; break;
      case 'waiting_approval':
      case 'waiting_approval_revision': color = Colors.blue; label = "DITINJAU"; break;
      default: color = Colors.grey; label = "DRAFT";
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(12)),
      child: Text(label, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
    );
  }
}