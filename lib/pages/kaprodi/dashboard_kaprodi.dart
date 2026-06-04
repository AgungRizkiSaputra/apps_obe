import 'package:flutter/material.dart';
import 'package:rps_obe_app/pages/kaprodi/manage_cpl_page.dart';
import 'package:rps_obe_app/pages/kaprodi/set_standar_mapping_page.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/rps_service.dart';
import '../../services/pdf_helper.dart'; // --- IMPORT PDF HELPER AGAR BISA NGEPRINT ---
import '../../shared/detail_rps_page.dart';
import '../auth/login_page.dart';
import 'manage_mk_page.dart';
import 'manage_dosen_page.dart';
import 'package:fl_chart/fl_chart.dart';
import 'profile_kaprodi_page.dart'; 

class DashboardKaprodi extends StatefulWidget {
  const DashboardKaprodi({super.key});

  @override
  State<DashboardKaprodi> createState() => _DashboardKaprodiState();
}

class _DashboardKaprodiState extends State<DashboardKaprodi> {
  final rpsService = RpsService();
  final user = Supabase.instance.client.auth.currentUser;
  
  // --- WARNA KHUSUS KAPRODI: TEAL BERSIH SOLID (BEDA DENGAN DOSEN, TANPA GRADASI) ---
  static const Color primaryColor = Color(0xFF00A896); 
  
  late Future<List<Map<String, dynamic>>> _reviewFuture;
  Map<String, dynamic> _stats = {'pending': 0, 'approved': 0, 'revisi': 0, 'mk': 0, 'cpl': 0};
  
  String _searchQuery = "";

  @override
  void initState() {
    super.initState();
    _reviewFuture = _fetchAndSortRps();
    _refreshData();
  }

  // --- LOGIKA FETCH & SORT (UTUH 100%) ---
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

  // --- LOGIKA REFRESH (UTUH 100%) ---
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

  // --- LOGIKA LOGOUT (UTUH 100%) ---
  Future<void> _handleLogout() async {
    await Supabase.instance.client.auth.signOut();
    if (mounted) {
      Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (context) => const LoginPage()), (route) => false);
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

  // --- LOGIKA CETAK PDF MANDIRI KAPRODI (UTUH DENGAN EMBEDDED PDF HELPER ENGINE) ---
  Future<void> _printKaprodiPdf(String rpsId) async {
    try {
      // 1. Ambil data detail lengkap dokumen RPS master
      final fullData = await rpsService.getRpsDetail(rpsId);
      // 2. Ambil data sebaran matriks CPMK & CPL kurikulum prodi
      final mapping = await rpsService.getMappingFullForPdf(rpsId);
      // 3. Eksekusi cetak lembar fisik via layout PDF helper
      await PdfHelper.cetakRps(fullData, mapping);
    } catch (e) {
      debugPrint("Gagal memproses cetak berkas: $e");
      if (mounted) {
        _showCustomNotif("Gagal mencetak berkas PDF: $e", Colors.red);
      }
    }
  }

  // --- HELPER NOTIFIKASI KONSISTEN ---
  void _showCustomNotif(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        backgroundColor: primaryColor,
        elevation: 0,
        toolbarHeight: 70,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Selamat Datang, Kaprodi", style: const TextStyle(fontSize: 12, color: Colors.white70)),
            Text(
              user?.userMetadata?['nama'] ?? "Admin Prodi",
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
            ),
          ],
        ),
      ),
      drawer: _buildDrawer(context),
      body: RefreshIndicator(
        onRefresh: () async => _refreshData(),
        child: ListView(
          children: [
            Container(
              height: 40,
              decoration: const BoxDecoration(
                color: primaryColor,
                borderRadius: BorderRadius.only(bottomLeft: Radius.circular(30), bottomRight: Radius.circular(30)),
              ),
            ),
            
            _buildChartSection(),
            
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  _buildStatCard("Review", _stats['pending'].toString(), Colors.orange),
                  _buildStatCard("Mata Kuliah", _stats['mk'].toString(), primaryColor),
                  _buildStatCard("CPL Prodi", _stats['cpl'].toString(), Colors.purple),
                ],
              ),
            ),

            _buildSearchBar(),
            
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 10, 20, 10),
              child: Row(
                children: [
                  Icon(Icons.assignment_late_rounded, size: 20, color: Colors.black54),
                  SizedBox(width: 8),
                  Text("Daftar RPS Masuk", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                ],
              ),
            ),

            FutureBuilder<List<Map<String, dynamic>>>(
              future: _reviewFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: Padding(padding: EdgeInsets.all(40.0), child: CircularProgressIndicator()));
                }
                final listReview = snapshot.data ?? [];
                
                final filteredList = listReview.where((rps) {
                  final namaMk = (rps['mata_kuliah']?['nama_mk'] ?? '').toString().toLowerCase();
                  final namaDosen = (rps['users']?['nama'] ?? '').toString().toLowerCase();
                  return namaMk.contains(_searchQuery) || namaDosen.contains(_searchQuery);
                }).toList();

                if (filteredList.isEmpty) {
                  return _buildEmptyState();
                }

                return ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: filteredList.length,
                  itemBuilder: (context, index) {
                    final rps = filteredList[index];
                    final status = rps['status'] ?? '';
                    final statusColor = _getStatusColor(status);
                    return _buildRpsListItem(rps, status, statusColor);
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

  Widget _buildSearchBar() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 20, 16, 10),
      padding: const EdgeInsets.symmetric(horizontal: 15),
      height: 50,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.01), blurRadius: 10, offset: const Offset(0, 4))],
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: TextField(
        onChanged: (val) => setState(() => _searchQuery = val.toLowerCase()),
        decoration: const InputDecoration(
          hintText: "Cari Mata Kuliah atau Dosen...",
          hintStyle: TextStyle(fontSize: 13, color: Colors.grey),
          border: InputBorder.none,
          icon: Icon(Icons.search_rounded, color: primaryColor),
        ),
      ),
    );
  }

  Widget _buildStatCard(String label, String count, Color color) {
    return Expanded(
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15), side: BorderSide(color: Colors.grey.shade100)),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 15),
          child: Column(
            children: [
              Text(count, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
              const SizedBox(height: 4),
              Text(label, textAlign: TextAlign.center, style: const TextStyle(fontSize: 9, color: Colors.grey, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildChartSection() {
    double total = ((_stats['approved'] ?? 0) + (_stats['pending'] ?? 0) + (_stats['revisi'] ?? 0)).toDouble();
    return Transform.translate(
      offset: const Offset(0, -30),
      child: Container(
        height: 180,
        margin: const EdgeInsets.symmetric(horizontal: 16),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 15, offset: const Offset(0, 5))],
        ),
        child: Row(
          children: [
            Expanded(
              child: total == 0 
              ? const Center(child: Text("Belum ada data", style: TextStyle(fontSize: 12, color: Colors.grey)))
              : PieChart(
                  PieChartData(
                    sectionsSpace: 4,
                    centerSpaceRadius: 35,
                    sections: [
                      PieChartSectionData(color: Colors.green.shade400, value: (_stats['approved'] ?? 0).toDouble(), title: '', radius: 45),
                      PieChartSectionData(color: Colors.orange.shade400, value: (_stats['pending'] ?? 0).toDouble(), title: '', radius: 45),
                      PieChartSectionData(color: Colors.red.shade400, value: (_stats['revisi'] ?? 0).toDouble(), title: '', radius: 45),
                    ],
                  ),
                ),
            ),
            const SizedBox(width: 20),
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildLegend(Colors.green.shade400, "Disetujui"),
                const SizedBox(height: 8),
                _buildLegend(Colors.orange.shade400, "Menunggu"),
                const SizedBox(height: 8),
                _buildLegend(Colors.red.shade400, "Revisi"),
                const Divider(height: 25),
                Text("Total RPS: ${total.toInt()}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              ],
            )
          ],
        ),
      ),
    );
  }

  Widget _buildLegend(Color color, String text) {
    return Row(
      children: [
        Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 8),
        Text(text, style: const TextStyle(fontSize: 11, color: Colors.black54)),
      ],
    );
  }

  Widget _buildRpsListItem(Map<String, dynamic> rps, String status, Color statusColor) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.01), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: ListTile(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => DetailRpsPage(rpsId: rps['id'].toString(), isKaprodi: true)),
          ).then((_) => _refreshData());
        },
        contentPadding: const EdgeInsets.only(left: 15, right: 5, top: 5, bottom: 5),
        leading: CircleAvatar(
          backgroundColor: statusColor.withOpacity(0.1),
          child: Icon(Icons.description_outlined, color: statusColor, size: 22),
        ),
        title: Text(
          rps['mata_kuliah']?['nama_mk'] ?? 'Mata Kuliah', 
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Oleh: ${rps['users']?['nama'] ?? '-'}", style: const TextStyle(fontSize: 12, color: Colors.grey)),
            const SizedBox(height: 8),
            // --- MENAMPILKAN ICON NOTIF REVISI DI SEBELAH CHIP STATUS ---
            Row(
              children: [
                _buildSmallStatusChip(status, statusColor),
                if (status == 'revisi' && rps['catatan'] != null)
                  const Padding(
                    padding: EdgeInsets.only(left: 8),
                    child: Icon(Icons.comment_rounded, size: 14, color: Colors.red),
                  ),
              ],
            ),
            // --- MENAMPILKAN TEKS CATATAN REVISI JIKA ADA ---
            if (status == 'revisi' && rps['catatan'] != null)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  "Catatan: ${rps['catatan']}",
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 11, color: Colors.red, fontStyle: FontStyle.italic, fontWeight: FontWeight.w500),
                ),
              ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // --- KONDISI AMAN: TOMBOL HANYA AKTIF MUNCUL UNTUK YANG APPROVED/DISETUJUI ---
            if (status == 'approved')
              IconButton(
                icon: const Icon(Icons.print_rounded, color: primaryColor, size: 22),
                tooltip: 'Cetak RPS',
                onPressed: () async {
                  _showCustomNotif("Mempersiapkan berkas PDF...", primaryColor);
                  // Jalankan fungsi cetak gabungan dari layout PdfHelper Dosen
                  await _printKaprodiPdf(rps['id'].toString());
                },
              ),
            const Icon(Icons.chevron_right_rounded, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  Widget _buildSmallStatusChip(String status, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
      child: Text(
        _getStatusLabel(status),
        style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildEmptyState() {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(40.0),
        child: Column(
          children: [
            Icon(Icons.inbox_rounded, size: 50, color: Color(0xFFD6D6D6)),
            SizedBox(height: 10),
            Text("Tidak ada antrean RPS", style: TextStyle(color: Colors.grey, fontSize: 13)),
          ],
        ),
      ),
    );
  }

  Widget _buildDrawer(BuildContext context) {
    return Drawer(
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.only(topRight: Radius.circular(30), bottomRight: Radius.circular(30))),
      child: Column(
        children: [
          UserAccountsDrawerHeader(
            decoration: const BoxDecoration(color: primaryColor),
            currentAccountPicture: Container(
              decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2)),
              child: CircleAvatar(
                backgroundColor: Colors.white,
                backgroundImage: user?.userMetadata?['avatar_url'] != null ? NetworkImage(user!.userMetadata?['avatar_url']) : null,
                child: user?.userMetadata?['avatar_url'] == null ? const Icon(Icons.admin_panel_settings, color: primaryColor, size: 40) : null,
              ),
            ),
            accountName: Text(user?.userMetadata?['nama'] ?? "Kaprodi", style: const TextStyle(fontWeight: FontWeight.bold)),
            accountEmail: Text(user?.email ?? ""),
          ),
          _buildDrawerItem(Icons.book_outlined, "Data Mata Kuliah", primaryColor, () => Navigator.push(context, MaterialPageRoute(builder: (context) => const ManageMkPage())).then((_) => _refreshData())),
          _buildDrawerItem(Icons.assignment_turned_in_outlined, "Data CPL Prodi", Colors.green, () => Navigator.push(context, MaterialPageRoute(builder: (context) => const ManageCplPage())).then((_) => _refreshData())),
          _buildDrawerItem(Icons.people_outline, "Data Dosen", Colors.orange, () => Navigator.push(context, MaterialPageRoute(builder: (context) => const ManageDosenPage()))),
          _buildDrawerItem(Icons.account_tree_outlined, "Set Standar CPL MK", Colors.purple, () => Navigator.push(context, MaterialPageRoute(builder: (context) => const SetStandarMappingPage()))),
          const Divider(),
          _buildDrawerItem(Icons.person_outline, "Profil Saya", Colors.indigo, () => Navigator.push(context, MaterialPageRoute(builder: (context) => const ProfileKaprodiPage())).then((_) => _refreshData())),
          const Spacer(),
          _buildDrawerItem(Icons.logout_rounded, "Keluar", Colors.red, _handleLogout),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildDrawerItem(IconData icon, String title, Color color, VoidCallback onTap) {
    return ListTile(
      leading: Icon(icon, color: color),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
      onTap: () {
        Navigator.pop(context);
        onTap();
      },
    );
  }
}