import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/rps_service.dart';
import '../../services/pdf_helper.dart';
import 'create_rps_page.dart';
import '../../shared/detail_rps_page.dart';
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
  
  // --- PENYELARASAN WARNA: BIRU TERANG SOLID SESUAI LOGO (TANPA GRADASI) ---
  static const Color primaryColor = Color(0xFF007AFF);

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

  // --- LOGIKA LOGOUT (UTUH 100%) ---
  Future<void> _handleLogout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: const Text("Keluar Akun"),
        content: const Text("Apakah Anda yakin ingin keluar?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Batal")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red, 
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Keluar", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await Supabase.instance.client.auth.signOut();
      if (mounted) Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (context) => const LoginPage()), (route) => false);
    }
  }

  // --- LOGIKA DELETE (UTUH 100%) ---
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

  // --- LOGIKA KIRIM (UTUH 100% DAN SEKARANG TERKONEKSI KE TOMBOL) ---
  Future<void> _handleKirimKeKaprodi(String rpsId) async {
    try {
      await rpsService.updateStatusRps(rpsId, 'waiting_approval');
      _refreshData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("RPS berhasil dikirim untuk divalidasi Kaprodi"), 
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      debugPrint("Error: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: Column(
        children: [
          _buildHeader(),
          _buildSearchBar(),
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
                if (filteredList.isEmpty) return _buildEmptyState();
                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  itemCount: filteredList.length,
                  itemBuilder: (context, index) => _buildRpsCard(filteredList[index]),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: _isSelectionMode 
        ? null 
        : FloatingActionButton.extended(
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const CreateRpsPage())).then((_) => _refreshData()),
            label: const Text(
              "RPS BARU", 
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                letterSpacing: 1,
              )
            ),
            icon: const Icon(Icons.add_rounded, color: Colors.white),
            backgroundColor: primaryColor,
            elevation: 4,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          ),
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(25, 60, 25, 30),
      decoration: const BoxDecoration(
        color: primaryColor,
        borderRadius: BorderRadius.only(bottomLeft: Radius.circular(40), bottomRight: Radius.circular(40)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Selamat Datang,", style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 14)),
                  Text(
                    user?.userMetadata?['nama'] ?? "Dosen Pengajar",
                    style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              _buildActionMenu(),
            ],
          ),
          const SizedBox(height: 25),
          FutureBuilder<List<Map<String, dynamic>>>(
            future: _rpsFuture,
            builder: (context, snapshot) {
              final list = snapshot.data ?? [];
              final total = list.length;
              final approved = list.where((e) => e['status'] == 'approved').length;
              return Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _statsItem("Total RPS", total.toString()),
                  _statsItem("Disetujui", approved.toString()),
                  _statsItem("Draft", (total - approved).toString()),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _statsItem(String label, String value) {
    return Column(
      children: [
        Text(value, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
        Text(label, style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 12)),
      ],
    );
  }

  Widget _buildActionMenu() {
    return _isSelectionMode
        ? Row(
            children: [
              IconButton(
                icon: const Icon(Icons.delete, color: Colors.redAccent), 
                onPressed: _selectedRpsIds.isEmpty ? null : _confirmBulkDelete,
              ),
              IconButton(
                icon: const Icon(Icons.close, color: Colors.white), 
                onPressed: () => setState(() { _isSelectionMode = false; _selectedRpsIds.clear(); }),
              ),
            ],
          )
        : PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: Colors.white),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
            onSelected: (val) {
              if (val == 'pilih') setState(() => _isSelectionMode = true);
              if (val == 'profil') Navigator.push(context, MaterialPageRoute(builder: (context) => const ProfilePage())).then((_) => _refreshData());
              if (val == 'logout') _handleLogout();
            },
            itemBuilder: (context) => [
              const PopupMenuItem<String>(
                value: 'pilih', 
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.checklist), 
                  title: Text("Pilih Banyak"),
                ),
              ),
              const PopupMenuItem<String>(
                value: 'profil', 
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.person_outline), 
                  title: Text("Profil Saya"),
                ),
              ),
              const PopupMenuItem<String>(
                value: 'logout', 
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.logout, color: Colors.red), 
                  title: Text("Keluar", style: TextStyle(color: Colors.red)),
                ),
              ),
            ],
          );
  }

  Widget _buildSearchBar() {
    return Transform.translate(
      offset: const Offset(0, -25),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 25),
        padding: const EdgeInsets.symmetric(horizontal: 20),
        height: 55,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(15),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 15, offset: const Offset(0, 8))],
        ),
        child: TextField(
          onChanged: (val) => setState(() => _searchQuery = val.toLowerCase()),
          decoration: const InputDecoration(
            hintText: "Cari mata kuliah...",
            border: InputBorder.none,
            icon: Icon(Icons.search_rounded, color: primaryColor),
          ),
        ),
      ),
    );
  }

  Widget _buildRpsCard(Map<String, dynamic> rps) {
    final String rpsId = rps['id'].toString();
    final String status = rps['status'];
    final bool isSelected = _selectedRpsIds.contains(rpsId);

    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      decoration: BoxDecoration(
        color: isSelected ? const Color(0xfff0f7ff) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: isSelected ? Border.all(color: primaryColor) : null,
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.01), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(15),
        leading: CircleAvatar(
          backgroundColor: primaryColor.withOpacity(0.1), 
          child: const Icon(Icons.book_rounded, color: primaryColor),
        ),
        title: Text(rps['mata_kuliah']?['nama_mk'] ?? 'Mata Kuliah', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 5),
            Text("Semester ${rps['semester']} • TA ${rps['tahun_ajaran']}", style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
            const SizedBox(height: 10),
            _buildStatusChip(status),
          ],
        ),
        trailing: _isSelectionMode 
          ? Checkbox(value: isSelected, onChanged: (val) => setState(() => val == true ? _selectedRpsIds.add(rpsId) : _selectedRpsIds.remove(rpsId)))
          : _buildTrailingAction(status, rpsId, rps),
        onTap: () {
          if (_isSelectionMode) {
            setState(() => isSelected ? _selectedRpsIds.remove(rpsId) : _selectedRpsIds.add(rpsId));
          } else {
            Navigator.push(context, MaterialPageRoute(builder: (context) => DetailRpsPage(rpsId: rpsId)));
          }
        },
      ),
    );
  }

  Widget _buildStatusChip(String status) {
    Color color = Colors.grey;
    if (status == 'approved') color = Colors.green;
    if (status.contains('revisi')) color = Colors.orange;
    if (status.contains('waiting')) color = Colors.blue;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1), 
        borderRadius: BorderRadius.circular(8), 
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(status.replaceAll('_', ' ').toUpperCase(), style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildTrailingAction(String status, String rpsId, Map<String, dynamic> rps) {
    if (status == 'approved') {
      return IconButton(
        key: ValueKey('print_$rpsId'),
        icon: const Icon(Icons.print_rounded, color: Colors.green), 
        onPressed: () => _printPdf(rpsId, rps),
      );
    }
    if (['draft', 'revisi', 'revisi_selesai'].contains(status)) {
      return TextButton(
        key: ValueKey('kirim_$rpsId'),
        onPressed: () => _handleKirimKeKaprodi(rpsId), 
        child: const Text("KIRIM", style: TextStyle(color: primaryColor, fontWeight: FontWeight.bold)),
      );
    }
    return const Icon(Icons.hourglass_empty_rounded, color: Colors.blue, size: 20);
  }

  Widget _buildEmptyState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center, 
        children: [
          Icon(Icons.folder_open_rounded, size: 80, color: Colors.grey), 
          SizedBox(height: 10),
          Text("Belum ada data RPS", style: TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }

  // --- INDIKATOR CETAK INTERAKTIF DENGAN NOTIFIKASI BERLAPIS ---
  Future<void> _printPdf(String rpsId, Map<String, dynamic> rps) async {
    // 1. Memunculkan Dialog Loading Pemroses Data (Anti-freeze)
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(color: primaryColor),
                SizedBox(height: 15),
                Text("Menyiapkan Dokumen PDF...", style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
              ],
            ),
          ),
        ),
      ),
    );

    try {
      final fullData = await rpsService.getRpsDetail(rpsId);
      final mapping = await rpsService.getMappingFullForPdf(rpsId);
      
      if (mounted) Navigator.pop(context); // Tutup Dialog Loading

      // 2. Tembak ke fungsi cetak di PdfHelper
      await PdfHelper.cetakRps(fullData, mapping);

      // 3. Memunculkan Snackbar Notifikasi Sukses Setelah Berhasil Mengunduh/Buka
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Dokumen RPS Berhasil Didownload!"),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) { 
      if (mounted) Navigator.pop(context); // Pastikan dialog tertutup jika error
      debugPrint(e.toString()); 
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Gagal mengunduh dokumen: $e"),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }
}