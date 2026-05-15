import 'package:flutter/material.dart';
import '../services/rps_service.dart';
import '../pages/dosen/input_pertemuan_page.dart';

class DetailRpsPage extends StatefulWidget {
  final String rpsId;
  final bool isKaprodi;

  const DetailRpsPage({super.key, required this.rpsId, this.isKaprodi = false});

  @override
  State<DetailRpsPage> createState() => _DetailRpsPageState();
}

class _DetailRpsPageState extends State<DetailRpsPage> {
  final rpsService = RpsService();
  final primaryColor = Colors.indigo.shade900;
  late Future<Map<String, dynamic>> _detailFuture;

  @override
  void initState() {
    super.initState();
    _initData();
  }

  void _initData() {
    setState(() {
      _detailFuture = rpsService.getRpsDetail(widget.rpsId);
    });
  }

  // --- LOGIKA UPDATE STATUS (UTUH) ---
  Future<void> _updateStatus(String status, {String? catatan}) async {
    try {
      await rpsService.updateStatusRps(widget.rpsId, status, catatan: catatan);
      if (mounted) {
        _showCustomNotif("Berhasil mengubah status ke $status", Colors.green);
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) _showCustomNotif("Gagal: $e", Colors.red);
    }
  }

  // --- POLESAN NOTIFIKASI (KONSISTEN DENGAN HALAMAN LAIN) ---
  void _showCustomNotif(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  // --- DIALOG REVISI (UI DIPERHALUS) ---
  void _showRevisiDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("Catatan Revisi", style: TextStyle(fontWeight: FontWeight.bold)),
        content: TextField(
          controller: controller,
          maxLines: 4,
          decoration: InputDecoration(
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
            hintText: "Berikan masukan perbaikan untuk dosen...",
            filled: true,
            fillColor: Colors.grey.shade50,
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Batal")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => _updateStatus('revisi', catatan: controller.text),
            child: const Text("Kirim Revisi", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text("Detail RPS OBE", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _detailFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) return Center(child: Text("Error: ${snapshot.error}"));

          final data = snapshot.data!;
          final mk = data['mata_kuliah'];
          final listCpmk = (data['cpmk'] as List?) ?? [];
          final listPertemuan = (data['rps_detail'] as List?) ?? [];
          final status = data['status'];

          return Column(
            children: [
              // Header Aksen
              Container(height: 20, decoration: BoxDecoration(color: primaryColor, borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(30), bottomRight: Radius.circular(30)))),
              
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    // --- SECTION 1: INFO MATA KULIAH ---
                    _buildSectionHeader("Informasi Mata Kuliah", Icons.account_balance_rounded),
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10)]),
                      child: Column(
                        children: [
                          _buildNewInfoRow(Icons.book, "Mata Kuliah", mk?['nama_mk'] ?? '-'),
                          _buildNewInfoRow(Icons.qr_code, "Kode MK", mk?['kode_mk'] ?? '-'),
                          _buildNewInfoRow(Icons.analytics, "SKS", "${mk?['sks'] ?? '0'} SKS"),
                          _buildNewInfoRow(Icons.calendar_month, "Semester", "${mk?['semester'] ?? '-'} (${data['semester'] ?? '-'})"),
                          _buildNewInfoRow(Icons.person, "Dosen", data['users']?['nama'] ?? '-'),
                          _buildNewInfoRow(Icons.history_edu, "Tahun", data['tahun_ajaran'] ?? '-'),
                        ],
                      ),
                    ),
                    const SizedBox(height: 25),

                    // --- TOMBOL ATUR PERTEMUAN (DOSEN ONLY) ---
                    if (!widget.isKaprodi)
                      _buildDosenAction(context),

                    // --- SECTION 2: CPMK ---
                    _buildSectionHeader("Capaian Pembelajaran (CPMK)", Icons.verified_user_rounded),
                    if (listCpmk.isEmpty) _buildEmptyState("Belum ada data CPMK.")
                    else ...listCpmk.map((c) => _buildCpmkCard(c)),

                    const SizedBox(height: 25),

                    // --- SECTION 3: RENCANA PERTEMUAN ---
                    _buildSectionHeader("Rencana Pertemuan", Icons.view_timeline_rounded),
                    if (listPertemuan.isEmpty) _buildEmptyState("Belum ada rencana pertemuan.")
                    else ...listPertemuan.map((p) => _buildPertemuanCard(p)),
                    
                    const SizedBox(height: 40),
                  ],
                ),
              ),
              
              // --- BUTTON ACTIONS (KAPRODI ONLY) ---
              if (widget.isKaprodi && (status == 'waiting_approval' || status == 'waiting_approval_revision'))
                _buildKaprodiActions(),
            ],
          );
        },
      ),
    );
  }

  // --- UI COMPONENTS HELPERS ---

  Widget _buildSectionHeader(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(left: 5, bottom: 12),
      child: Row(
        children: [
          Icon(icon, color: primaryColor, size: 22),
          const SizedBox(width: 10),
          Text(title, style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: primaryColor)),
        ],
      ),
    );
  }

  Widget _buildNewInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.grey),
          const SizedBox(width: 12),
          SizedBox(width: 80, child: Text(label, style: const TextStyle(color: Colors.grey, fontSize: 13))),
          const Text(": ", style: TextStyle(color: Colors.grey)),
          Expanded(child: Text(value, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14))),
        ],
      ),
    );
  }

  Widget _buildDosenAction(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 25),
      child: InkWell(
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => InputPertemuanPage(rpsId: widget.rpsId))).then((_) => _initData()),
        child: Container(
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(15), border: Border.all(color: Colors.blue.shade100)),
          child: Row(
            children: [
              Icon(Icons.edit_calendar_rounded, color: primaryColor),
              const SizedBox(width: 15),
              Expanded(child: Text("Atur Rencana Pertemuan (Minggu 1-14)", style: TextStyle(color: primaryColor, fontWeight: FontWeight.bold))),
              Icon(Icons.arrow_forward_ios, size: 14, color: primaryColor),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCpmkCard(Map<String, dynamic> c) {
    final mapping = (c['mapping_cpl_cpmk'] as List?) ?? [];
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15), side: BorderSide(color: Colors.grey.shade200)),
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(c['deskripsi'] ?? '-', style: const TextStyle(fontWeight: FontWeight.w600, height: 1.4)),
            if (mapping.isNotEmpty) ...[
              const Divider(height: 25),
              const Text("Mendukung CPL Prodi:", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey)),
              const SizedBox(height: 10),
              ...mapping.map((m) => Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(10)),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(color: Colors.indigo.shade50, borderRadius: BorderRadius.circular(6)),
                      child: Text("${m['cpl']['kode_cpl']} (${m['bobot'] ?? 0}%)", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 10, color: primaryColor)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(child: Text(m['cpl']['deskripsi'], style: const TextStyle(fontSize: 12, color: Colors.black87))),
                  ],
                ),
              )),
            ]
          ],
        ),
      ),
    );
  }

  Widget _buildPertemuanCard(Map<String, dynamic> p) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15), border: Border.all(color: Colors.grey.shade100)),
      child: ListTile(
        leading: CircleAvatar(backgroundColor: primaryColor.withOpacity(0.1), child: Text("${p['minggu_ke']}", style: TextStyle(color: primaryColor, fontWeight: FontWeight.bold, fontSize: 14))),
        title: Text(p['kemampuan_akhir'] ?? '-', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
        subtitle: Text("Metode: ${p['metode_pembelajaran'] ?? '-'}\nBobot Nilai: ${p['bobot_nilai']}%", style: const TextStyle(fontSize: 12)),
      ),
    );
  }

  Widget _buildKaprodiActions() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white, boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10, offset: const Offset(0, -5))]),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: _showRevisiDialog,
              icon: const Icon(Icons.edit_note),
              label: const Text("Revisi"),
              style: OutlinedButton.styleFrom(foregroundColor: Colors.orange, side: const BorderSide(color: Colors.orange), padding: const EdgeInsets.symmetric(vertical: 15), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            ),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: ElevatedButton.icon(
              onPressed: () => _updateStatus('approved'),
              icon: const Icon(Icons.check_circle_rounded),
              label: const Text("Setujui"),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 15), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(String msg) => Padding(padding: const EdgeInsets.all(20), child: Center(child: Text(msg, style: const TextStyle(fontStyle: FontStyle.italic, color: Colors.grey))));
}