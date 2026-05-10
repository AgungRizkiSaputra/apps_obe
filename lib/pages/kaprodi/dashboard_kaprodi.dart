import 'package:flutter/material.dart';
import 'package:rps_obe_app/pages/kaprodi/manage_cpl_page.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/rps_service.dart';
import '../shared/detail_rps_page.dart';
import 'manage_mk_page.dart';
import 'manage_dosen_page.dart';

class DashboardKaprodi extends StatefulWidget {
  const DashboardKaprodi({super.key});

  @override
  State<DashboardKaprodi> createState() => _DashboardKaprodiState();
}

class _DashboardKaprodiState extends State<DashboardKaprodi> {
  final rpsService = RpsService();
  late Future<List<Map<String, dynamic>>> _reviewFuture;
  Map<String, dynamic> _stats = {'pending': 0, 'mk': 0, 'cpl': 0};

  @override
  void initState() {
    super.initState();
    _reviewFuture = _fetchAndSortRps(); // Gunakan fungsi sort baru
    _refreshData();
  }

  // --- FUNGSI UNTUK AMBIL DATA & URUTKAN (PRIORITAS REVIEW) ---
  Future<List<Map<String, dynamic>>> _fetchAndSortRps() async {
    final list = await rpsService.getRpsForKaprodi();
    // Urutkan: waiting_approval paling atas, lalu approved di bawah
    list.sort((a, b) {
      final sA = a['status']?.toString() ?? '';
      final sB = b['status']?.toString() ?? '';
      if (sA.contains('waiting') && !sB.contains('waiting')) return -1;
      if (!sA.contains('waiting') && sB.contains('waiting')) return 1;
      return 0;
    });
    return list;
  }

  void _refreshData() async {
    try {
      final dataStats = await rpsService.getKaprodiStats();
      if (mounted) {
        setState(() {
          _stats = dataStats;
          _reviewFuture = _fetchAndSortRps();
        });
      }
    } catch (e) {
      debugPrint("Error refresh data: $e");
    }
  }

  // --- HELPER WARNA & LABEL STATUS ---
  Color _getStatusColor(String status) {
    if (status.contains('waiting')) return Colors.orange.shade800;
    if (status == 'approved') return Colors.green.shade700;
    if (status == 'revisi') return Colors.red;
    return Colors.blue;
  }

  String _getStatusLabel(String status) {
    if (status == 'waiting_approval') return 'PERLU REVIEW';
    if (status == 'waiting_approval_revision') return 'HASIL REVISI';
    if (status == 'approved') return 'DISETUJUI';
    return status.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Review RPS (Kaprodi)"),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await Supabase.instance.client.auth.signOut();
              if (mounted) Navigator.pushReplacementNamed(context, '/login');
            },
          )
        ],
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            const DrawerHeader(
              decoration: BoxDecoration(color: Colors.blue),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Icon(Icons.admin_panel_settings, color: Colors.white, size: 40),
                  SizedBox(height: 10),
                  Text("Menu Kaprodi", style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            ListTile(
              leading: const Icon(Icons.book, color: Colors.blue),
              title: const Text("Data Mata Kuliah"),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(builder: (context) => const ManageMkPage())).then((_) => _refreshData());
              },
            ),
            ListTile(
              leading: const Icon(Icons.assignment, color: Colors.green),
              title: const Text("Data CPL Prodi"),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(builder: (context) => const ManageCplPage())).then((_) => _refreshData());
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.people, color: Colors.orange),
              title: const Text("Data Dosen"),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(builder: (context) => const ManageDosenPage()));
              },
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.grey.shade50,
            child: Row(
              children: [
                _buildStatCard("Perlu Review", _stats['pending'].toString(), Colors.blue),
                _buildStatCard("Total MK", _stats['mk'].toString(), Colors.green),
                _buildStatCard("Total CPL", _stats['cpl'].toString(), Colors.orange),
              ],
            ),
          ),
          const Divider(height: 1),
          
          Expanded(
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: _reviewFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) return Center(child: Text("Error: ${snapshot.error}"));

                final listReview = snapshot.data ?? [];
                if (listReview.isEmpty) return const Center(child: Text("Belum ada RPS yang masuk."));

                return ListView.builder(
                  padding: const EdgeInsets.all(10),
                  itemCount: listReview.length,
                  itemBuilder: (context, index) {
                    final rps = listReview[index];
                    final status = rps['status'] ?? '';
                    final statusColor = _getStatusColor(status);

                    return Card(
                      elevation: 2,
                      margin: const EdgeInsets.symmetric(vertical: 8),
                      child: ListTile(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => DetailRpsPage(rpsId: rps['id'].toString(), isKaprodi: true)),
                          ).then((_) => _refreshData());
                        },
                        leading: CircleAvatar(
                          backgroundColor: statusColor.withOpacity(0.2),
                          child: Icon(Icons.description, color: statusColor),
                        ),
                        title: Text(
                          rps['mata_kuliah']?['nama_mk'] ?? 'Mata Kuliah', 
                          style: const TextStyle(fontWeight: FontWeight.bold)
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text("Dosen: ${rps['users']?['nama'] ?? '-'}"),
                            const SizedBox(height: 5),
                            // --- BADGE STATUS ---
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: statusColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: statusColor.withOpacity(0.5)),
                              ),
                              child: Text(
                                _getStatusLabel(status),
                                style: TextStyle(color: statusColor, fontSize: 9, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ),
                        trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String label, String count, Color color) {
    return Expanded(
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8), side: BorderSide(color: Colors.grey.shade200)),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            children: [
              Text(count, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
              const SizedBox(height: 4),
              Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }
}