import 'package:flutter/material.dart';
import 'package:rps_obe_app/pages/kaprodi/manage_cpl_page.dart';
import 'package:rps_obe_app/pages/kaprodi/set_standar_mapping_page.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/rps_service.dart';
import '../shared/detail_rps_page.dart';
import 'manage_mk_page.dart';
import 'manage_dosen_page.dart';
import 'package:fl_chart/fl_chart.dart';

class DashboardKaprodi extends StatefulWidget {
  const DashboardKaprodi({super.key});

  @override
  State<DashboardKaprodi> createState() => _DashboardKaprodiState();
}

class _DashboardKaprodiState extends State<DashboardKaprodi> {
  final rpsService = RpsService();
  late Future<List<Map<String, dynamic>>> _reviewFuture;
  Map<String, dynamic> _stats = {'pending': 0, 'approved': 0, 'revisi': 0, 'mk': 0, 'cpl': 0};

  @override
  void initState() {
    super.initState();
    _reviewFuture = _fetchAndSortRps();
    _refreshData();
  }

  Future<List<Map<String, dynamic>>> _fetchAndSortRps() async {
    final list = await rpsService.getRpsForKaprodi();
    list.sort((a, b) {
      final sA = a['status']?.toString() ?? '';
      final sB = b['status']?.toString() ?? '';
      if (sA.contains('waiting') && !sB.contains('waiting')) return -1;
      if (!sA.contains('waiting') && b['status'].contains('waiting')) return 1;
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
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: const Text("Review RPS (Kaprodi)"),
        backgroundColor: Colors.blue.shade800,
        foregroundColor: Colors.white,
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
      drawer: _buildDrawer(context),
      // MENGGUNAKAN RefreshIndicator agar bisa tarik kebawah untuk update data
      body: RefreshIndicator(
        onRefresh: () async => _refreshData(),
        child: ListView(
          padding: const EdgeInsets.only(bottom: 30),
          children: [
            // 1. BAGIAN GRAFIK
            _buildChartSection(),

            // 2. BAGIAN STAT CARD
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  _buildStatCard("Perlu Review", _stats['pending'].toString(), Colors.blue),
                  _buildStatCard("Total MK", _stats['mk'].toString(), Colors.green),
                  _buildStatCard("Total CPL", _stats['cpl'].toString(), Colors.orange),
                ],
              ),
            ),

            const Padding(
              padding: EdgeInsets.fromLTRB(20, 20, 20, 10),
              child: Text("Daftar RPS Masuk", 
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ),

            // 3. BAGIAN DAFTAR RPS
            FutureBuilder<List<Map<String, dynamic>>>(
              future: _reviewFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: Padding(
                    padding: EdgeInsets.all(20.0),
                    child: CircularProgressIndicator(),
                  ));
                }
                
                final listReview = snapshot.data ?? [];
                if (listReview.isEmpty) {
                  return const Center(child: Padding(
                    padding: EdgeInsets.all(30.0),
                    child: Text("Belum ada RPS yang masuk."),
                  ));
                }

                return ListView.builder(
                  shrinkWrap: true, // PENTING: Agar list tahu tingginya di dalam ListView
                  physics: const NeverScrollableScrollPhysics(), // PENTING: Agar tidak bentrok scroll
                  padding: const EdgeInsets.symmetric(horizontal: 15),
                  itemCount: listReview.length,
                  itemBuilder: (context, index) {
                    final rps = listReview[index];
                    final status = rps['status'] ?? '';
                    final statusColor = _getStatusColor(status);

                    return Card(
                      elevation: 2,
                      margin: const EdgeInsets.symmetric(vertical: 6),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: ListTile(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => DetailRpsPage(rpsId: rps['id'].toString(), isKaprodi: true)),
                          ).then((_) => _refreshData());
                        },
                        leading: CircleAvatar(
                          backgroundColor: statusColor.withOpacity(0.1),
                          child: Icon(Icons.description, color: statusColor),
                        ),
                        title: Text(
                          rps['mata_kuliah']?['nama_mk'] ?? 'Mata Kuliah', 
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text("Dosen: ${rps['users']?['nama'] ?? '-'}", style: const TextStyle(fontSize: 12)),
                            const SizedBox(height: 5),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: statusColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(4),
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
          ],
        ),
      ),
    );
  }

  // --- DRAWER HELPER ---
  Widget _buildDrawer(BuildContext context) {
    return Drawer(
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
          ListTile(
            leading: const Icon(Icons.people, color: Colors.orange),
            title: const Text("Data Dosen"),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(context, MaterialPageRoute(builder: (context) => const ManageDosenPage()));
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.account_tree, color: Colors.purple),
            title: const Text("Set Standar CPL MK"),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(context, MaterialPageRoute(builder: (context) => const SetStandarMappingPage()));
            },
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

  Widget _buildChartSection() {
    double total = ((_stats['approved'] ?? 0) + (_stats['pending'] ?? 0) + (_stats['revisi'] ?? 0)).toDouble();
    
    return Container(
      height: 220,
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
      ),
      child: Row(
        children: [
          Expanded(
            child: total == 0 
            ? const Center(child: Text("Belum ada data", style: TextStyle(fontSize: 12)))
            : PieChart(
                PieChartData(
                  sectionsSpace: 2,
                  centerSpaceRadius: 40,
                  sections: [
                    PieChartSectionData(
                      color: Colors.green,
                      value: (_stats['approved'] ?? 0).toDouble(),
                      title: '${_stats['approved']}',
                      radius: 50,
                      titleStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                    PieChartSectionData(
                      color: Colors.orange,
                      value: (_stats['pending'] ?? 0).toDouble(),
                      title: '${_stats['pending']}',
                      radius: 50,
                      titleStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                    PieChartSectionData(
                      color: Colors.red,
                      value: (_stats['revisi'] ?? 0).toDouble(),
                      title: '${_stats['revisi']}',
                      radius: 50,
                      titleStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
          ),
          const SizedBox(width: 20),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildLegend(Colors.green, "Disetujui"),
              const SizedBox(height: 8),
              _buildLegend(Colors.orange, "Perlu Review"),
              const SizedBox(height: 8),
              _buildLegend(Colors.red, "Revisi"),
              const Divider(height: 20),
              Text("Total RPS: ${total.toInt()}", style: const TextStyle(fontWeight: FontWeight.bold)),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildLegend(Color color, String text) {
    return Row(
      children: [
        Container(width: 12, height: 12, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 8),
        Text(text, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
      ],
    );
  }
}