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
  
  // --- PENYELARASAN WARNA SOLID SESUAI LOGO (TANPA GRADASI) ---
  static const Color primaryColor = Color(0xFF007AFF);
  
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

  // --- LOGIKA UPDATE STATUS: SINKRONISASI STATE AKURAT (ANTI PERBEDAAN DATA) ---
  Future<void> _updateStatus(String status, {String? catatan}) async {
    try {
      await rpsService.updateStatusRps(widget.rpsId, status, catatan: catatan);
      if (mounted) {
        _showCustomNotif("Berhasil mengubah status dokumen!", Colors.green);
        // Jangan langsung di-pop gung, refresh data local biar UI detailnya ikut berubah real-time!
        _initData(); 
      }
    } catch (e) {
      if (mounted) _showCustomNotif("Gagal memperbarui status: $e", Colors.red);
    }
  }

  // --- POLESAN NOTIFIKASI KONSISTEN (UTUH) ---
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

  // --- DIALOG REVISI (KAPRODI MENEKAN TOMBOL REVISI JIKA MEMERLUKAN PERBAIKAN) ---
  void _showRevisiDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("Catatan Revisi Akademik", style: TextStyle(fontWeight: FontWeight.bold)),
        content: TextField(
          controller: controller,
          maxLines: 4,
          decoration: InputDecoration(
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
            hintText: "Berikan masukan instrumen revisi untuk dosen pengampu...",
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
            onPressed: () {
              Navigator.pop(context); // Tutup dialognya dulu
              _updateStatus('revisi', catatan: controller.text);
            },
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
          final status = data['status'] ?? 'draft';

          return Column(
            children: [
              // Header Aksen
              Container(
                height: 20, 
                decoration: const BoxDecoration(
                  color: primaryColor, 
                  borderRadius: BorderRadius.only(bottomLeft: Radius.circular(30), bottomRight: Radius.circular(30)),
                ),
              ),
              
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    // Tampilan Banner Catatan Jika Berkas Berstatus Revisi
                    if (status == 'revisi' && data['catatan'] != null)
                      _buildCatatanRevisiBanner(data['catatan']),

                    // --- SECTION 1: INFO MATA KULIAH ---
                    _buildSectionHeader("Informasi Mata Kuliah", Icons.account_balance_rounded),
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white, 
                        borderRadius: BorderRadius.circular(20), 
                        boxShadow: [
                          BoxShadow(color: Colors.black.withOpacity(0.01), blurRadius: 10, offset: const Offset(0, 4)),
                        ],
                      ),
                      child: Column(
                        children: [
                          _buildNewInfoRow(Icons.book, "Mata Kuliah", mk?['nama_mk'] ?? '-'),
                          _buildNewInfoRow(Icons.qr_code, "Kode MK", mk?['kode_mk'] ?? '-'),
                          _buildNewInfoRow(Icons.analytics, "SKS", "${mk?['sks'] ?? '0'} SKS"),
                          _buildNewInfoRow(Icons.calendar_month, "Semester", "${mk?['semester'] ?? '-'} (${data['semester'] ?? '-'})"),
                          _buildNewInfoRow(Icons.person, "Dosen", data['users']?['nama'] ?? '-'),
                          _buildNewInfoRow(Icons.history_edu, "Tahun", data['tahun_ajaran'] ?? '-'),
                          _buildStatusInfoRow(status), // Tampilan status yang sudah diselaraskan prodi
                        ],
                      ),
                    ),
                    const SizedBox(height: 25),

                    // Tombol Aksi Input Data Rencana Mingguan Dosen
                    if (!widget.isKaprodi && (status == 'draft' || status == 'revisi'))
                      _buildDosenAction(context),

                    // --- SECTION 2: CPMK ---
                    _buildSectionHeader("Capaian Pembelajaran (CPMK)", Icons.verified_user_rounded),
                    if (listCpmk.isEmpty) _buildEmptyState("Belum ada data CPMK prodi.")
                    else ...listCpmk.map((c) => _buildCpmkCard(c)),

                    const SizedBox(height: 25),

                    // --- SECTION 3: RENCANA PERTEMUAN ---
                    _buildSectionHeader("Rencana Pertemuan", Icons.view_timeline_rounded),
                    if (listPertemuan.isEmpty) _buildEmptyState("Belum ada rencana pertemuan mingguan.")
                    else ...listPertemuan.map((p) => _buildPertemuanCard(p)),
                    
                    const SizedBox(height: 40),
                  ],
                ),
              ),
              
              // --- BUTTON ACTIONS: HANYA MUNCUL JIKA KAPRODI MEMERIKSA STATUS WAITING APPROVAL ---
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
          Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: primaryColor)),
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
          SizedBox(width: 95, child: Text(label, style: const TextStyle(color: Colors.grey, fontSize: 13))),
          const Text(": ", style: TextStyle(color: Colors.grey)),
          Expanded(child: Text(value, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14))),
        ],
      ),
    );
  }

  // --- SINKRONISASI PENAMAAN STATUS SESUAI PARAMETER AKADEMIK ---
  Widget _buildStatusInfoRow(String status) {
    Color statusColor = Colors.grey;
    String statusLabel = status;

    if (status == 'draft') { 
      statusColor = Colors.blue; 
      statusLabel = "Draft (Belum Dikirim)"; 
    } else if (status == 'waiting_approval' || status == 'waiting_approval_revision') { 
      statusColor = Colors.orange; 
      statusLabel = "Waiting Approval"; // Sesuai aturan: Baru ngirim itu waiting approval, bukan pending
    } else if (status == 'revisi') { 
      statusColor = Colors.red; 
      statusLabel = "Perlu Revisi Kaprodi"; 
    } else if (status == 'approved') { 
      statusColor = Colors.green; 
      statusLabel = "Approved (Terkunci Resmi)"; 
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          const Icon(Icons.info_outline, size: 18, color: Colors.grey),
          const SizedBox(width: 12),
          const SizedBox(width: 95, child: Text("Status Dokumen", style: TextStyle(color: Colors.grey, fontSize: 13))),
          const Text(": ", style: TextStyle(color: Colors.grey)),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(color: statusColor.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
            child: Text(statusLabel, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: statusColor)),
          ),
        ],
      ),
    );
  }

  Widget _buildCatatanRevisiBanner(String catatan) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.amber.shade50,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.amber.shade300),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.assignment_returned_rounded, color: Colors.orange, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Catatan Perbaikan Kaprodi:", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.orange)),
                const SizedBox(height: 4),
                Text(catatan, style: const TextStyle(fontSize: 12, color: Colors.black87, height: 1.4)),
              ],
            ),
          ),
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
          decoration: BoxDecoration(
            color: const Color(0xFFF0F7FF), 
            borderRadius: BorderRadius.circular(15), 
            border: Border.all(color: primaryColor.withOpacity(0.2)),
          ),
          child: const Row(
            children: [
              Icon(Icons.edit_calendar_rounded, color: primaryColor),
              SizedBox(width: 15),
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
                      decoration: BoxDecoration(color: const Color(0xFFF0F7FF), borderRadius: BorderRadius.circular(6)),
                      child: Text("${m['cpl']['kode_cpl']} (${m['bobot'] ?? 0}%)", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 10, color: primaryColor)),
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
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white, 
        borderRadius: BorderRadius.circular(15), 
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 14,
                  backgroundColor: const Color(0xFFF0F7FF), 
                  child: Text("${p['minggu_ke']}", style: const TextStyle(color: primaryColor, fontWeight: FontWeight.bold, fontSize: 12)),
                ),
                const SizedBox(width: 10),
                Text("Minggu Ke-${p['minggu_ke']}", style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: primaryColor)),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(20)),
                  child: Text("Bobot: ${p['bobot_nilai']}%", style: TextStyle(color: Colors.green.shade700, fontWeight: FontWeight.bold, fontSize: 11)),
                ),
              ],
            ),
            const Divider(height: 20, color: Color(0xFFF5F5F5)),
            
            _buildDetailFieldRow("Materi Pokok", p['kemampuan_akhir'] ?? '-'),
            const SizedBox(height: 10),
            _buildDetailFieldRow("Metode Belajar", p['metode_pembelajaran'] ?? '-'),
            const SizedBox(height: 10),
            _buildDetailFieldRow("Pengalaman", p['pengalaman_belajar'] ?? '-'),
            const SizedBox(height: 10),
            _buildDetailFieldRow("Indikator", p['indikator_penilaian'] ?? '-'),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailFieldRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 95, 
          child: Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
        ),
        const Text(": ", style: TextStyle(color: Colors.grey)),
        Expanded(
          child: Text(value, style: const TextStyle(fontSize: 12, color: Colors.black87, height: 1.3)),
        ),
      ],
    );
  }

  // --- AKSI KAPRODI: JIKA BUTUH PERBAIKAN MENEKAN TOMBOL REVISI ---
  Widget _buildKaprodiActions() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white, 
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, -5)),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: _showRevisiDialog, // Tombol revisi interaktif
              icon: const Icon(Icons.edit_note),
              label: const Text("Revisi"),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.orange, 
                side: const BorderSide(color: Colors.orange), 
                padding: const EdgeInsets.symmetric(vertical: 15), 
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: ElevatedButton.icon(
              onPressed: () => _updateStatus('approved'),
              icon: const Icon(Icons.check_circle_rounded),
              label: const Text("Setujui"),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green, 
                foregroundColor: Colors.white, 
                padding: const EdgeInsets.symmetric(vertical: 15), 
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(String msg) {
    return Padding(
      padding: const EdgeInsets.all(20), 
      child: Center(
        child: Text(msg, style: const TextStyle(fontStyle: FontStyle.italic, color: Colors.grey)),
      ),
    );
  }
}