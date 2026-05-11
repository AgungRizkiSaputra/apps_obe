import 'package:flutter/material.dart';
import 'package:rps_obe_app/pages/kaprodi/manage_cpl_page.dart';
import 'package:rps_obe_app/pages/kaprodi/set_standar_mapping_page.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/rps_service.dart';
import '../shared/detail_rps_page.dart';
import '../auth/login_page.dart'; // Import LoginPage
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
  final user = Supabase.instance.client.auth.currentUser;
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

  Future<void> _handleLogout() async {
    await Supabase.instance.client.auth.signOut();
    if (mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const LoginPage()),
        (route) => false,
      );
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
    final primaryColor = Colors.blue.shade800;

    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      // APPBAR IDENTIK DENGAN DASHBOARD DOSEN
      appBar: AppBar(
        backgroundColor: primaryColor,
        elevation: 0,
        toolbarHeight: 70,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Selamat Datang, Kaprodi", style: TextStyle(fontSize: 12, color: Colors.white70)),
            Text(
              user?.userMetadata?['nama'] ?? "Admin Prodi",
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
            onPressed: _handleLogout,
            tooltip: "Keluar Akun",
          ),
        ],
      ),
      drawer: _buildDrawer(context),
      body: RefreshIndicator(
        onRefresh: () async => _refreshData(),
        child: ListView(
          children: [
            // AKSEN BIRU MELENGKUNG DI BAWAH APPBAR
            Container(
              height: 20,
              decoration: BoxDecoration(
                color: primaryColor,
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(25),
                  bottomRight: Radius.circular(25),
                ),
              ),
            ),

            // 1. GRAFIK MONITORING
            _buildChartSection(),

            // 2. STAT CARDS
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
              padding: EdgeInsets.fromLTRB(20, 25, 20, 10),
              child: Text("Daftar RPS Masuk", 
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ),

            // 3. DAFTAR RPS
            FutureBuilder<List<Map<String, dynamic>>>(
              future: _reviewFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: Padding(
                    padding: EdgeInsets.all(40.0),
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
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 15),
                  itemCount: listReview.length,
                  itemBuilder: (context, index) {
                    final rps = listReview[index];
                    final status = rps['status'] ?? '';
                    final statusColor = _getStatusColor(status);

                    return Card(
                      elevation: 1,
                      margin: const EdgeInsets.symmetric(vertical: 6),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                      child: ListTile(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => DetailRpsPage(rpsId: rps['id'].toString(), isKaprodi: true)),
                          ).then((_) => _refreshData());
                        },
                        leading: CircleAvatar(
                          backgroundColor: statusColor.withOpacity(0.1),
                          child: Icon(Icons.description, color: statusColor, size: 20),
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
                            _buildSmallStatusChip(status, statusColor),
                          ],
                        ),
                        trailing: const Icon(Icons.arrow_forward_ios, size: 12, color: Colors.grey),
                      ),
                    );
                  },
                );
              },
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  // --- WIDGET KECIL UNTUK LABEL STATUS ---
  Widget _buildSmallStatusChip(String status, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        _getStatusLabel(status),
        style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.bold),
      ),
    );
  }

  // --- STAT CARD HELPER ---
  Widget _buildStatCard(String label, String count, Color color) {
    return Expanded(
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.shade200)),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            children: [
              Text(count, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: color)),
              const SizedBox(height: 4),
              Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }

  // --- PIE CHART MONITORING ---
  Widget _buildChartSection() {
    double total = ((_stats['approved'] ?? 0) + (_stats['pending'] ?? 0) + (_stats['revisi'] ?? 0)).toDouble();
    
    return Container(
      height: 200,
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10)],
      ),
      child: Row(
        children: [
          Expanded(
            child: total == 0 
            ? const Center(child: Text("Belum ada data", style: TextStyle(fontSize: 12)))
            : PieChart(
                PieChartData(
                  sectionsSpace: 2,
                  centerSpaceRadius: 35,
                  sections: [
                    PieChartSectionData(color: Colors.green, value: (_stats['approved'] ?? 0).toDouble(), title: '', radius: 45),
                    PieChartSectionData(color: Colors.orange, value: (_stats['pending'] ?? 0).toDouble(), title: '', radius: 45),
                    PieChartSectionData(color: Colors.red, value: (_stats['revisi'] ?? 0).toDouble(), title: '', radius: 45),
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
              _buildLegend(Colors.orange, "Menunggu"),
              const SizedBox(height: 8),
              _buildLegend(Colors.red, "Revisi"),
              const Divider(height: 20),
              Text("Total: ${total.toInt()}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildLegend(Color color, String text) {
    return Row(
      children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 8),
        Text(text, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500)),
      ],
    );
  }

  // --- DRAWER MENU ADMIN ---
  Widget _buildDrawer(BuildContext context) {
    return Drawer(
      child: Column(
        children: [
          UserAccountsDrawerHeader(
            decoration: BoxDecoration(color: Colors.blue.shade800),
            currentAccountPicture: const CircleAvatar(
              backgroundColor: Colors.white,
              child: Icon(Icons.admin_panel_settings, color: Colors.blue, size: 40),
            ),
            accountName: Text(user?.userMetadata?['nama'] ?? "Kaprodi"),
            accountEmail: Text(user?.email ?? ""),
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
}