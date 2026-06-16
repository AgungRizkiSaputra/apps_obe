import 'package:flutter/material.dart';
import '../services/rps_service.dart';
import '../pages/dosen/input_pertemuan_page.dart';
import 'package:rps_obe_app/services/pdf_helper.dart';

class DetailRpsPage extends StatefulWidget {
  final String rpsId;
  final bool isKaprodi;

  const DetailRpsPage({super.key, required this.rpsId, this.isKaprodi = false});

  @override
  State<DetailRpsPage> createState() => _DetailRpsPageState();
}

class _DetailRpsPageState extends State<DetailRpsPage> {
  final rpsService = RpsService();
  
  static const Color primaryColor = Color(0xFF007AFF);
  
  // local UI state
  bool isLoading = false;
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

  Future<void> _updateStatus(String status, {String? catatan}) async {
    try {
      await rpsService.updateStatusRps(widget.rpsId, status, catatan: catatan);
      if (mounted) {
        _showCustomNotif("Berhasil mengubah status dokumen!", Colors.green);
        _initData(); 
      }
    } catch (e) {
      if (mounted) _showCustomNotif("Gagal memperbarui status: $e", Colors.red);
    }
  }

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

  void _showRevisiDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("Catatan Revisi Academic", style: TextStyle(fontWeight: FontWeight.bold)),
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
              Navigator.pop(context); 
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
                          _buildStatusInfoRow(status), 
                        ],
                      ),
                    ),
                    const SizedBox(height: 25),

                    if (!widget.isKaprodi && (status == 'draft' || status == 'revisi'))
                      _buildDosenAction(context),

                    // --- SECTION 2: INTEGRASI GABUNGAN CPL & CPMK (LAYOUT BARU) ---
                    _buildSectionHeader("Capaian Pembelajaran (CPMK & CPL)", Icons.verified_user_rounded),
                    if (listCpmk.isEmpty) 
                      _buildEmptyState("Belum ada data pemetaan OBE prodi.")
                    else 
                      _buildCombinedObeCard(listCpmk),

                    const SizedBox(height: 25),

                    // --- SECTION 3: RENCANA PERTEMUAN ---
                    _buildSectionHeader("Rencana Pertemuan", Icons.view_timeline_rounded),
                    if (listPertemuan.isEmpty) _buildEmptyState("Belum ada rencana pertemuan mingguan.")
                    else ...listPertemuan.map((p) => _buildPertemuanCard(p)),
                    
                    const SizedBox(height: 40),
                  ],
                ),
              ),
              
              _buildActionBottomContainer(data, listCpmk, status),
            ],
          );
        },
      ),
    );
  }

  // --- KARTU LAYOUT GABUNGAN BARU: Menampilkan CPL Sekali di Atas, Lalu CPMK Mengalir di Bawahnya ---
  Widget _buildCombinedObeCard(List listCpmk) {
    // Ekstraksi seluruh CPL unik dari seluruh list CPMK yang dipilih dosen gung
    final Map<String, Map<String, dynamic>> uniqueCpls = {};
    for (var cpmk in listCpmk) {
      final mappings = (cpmk['mapping_cpl_cpmk'] as List?) ?? [];
      for (var m in mappings) {
        if (m['cpl'] != null) {
          final String kodeCpl = m['cpl']['kode_cpl']?.toString() ?? '';
          if (kodeCpl.isNotEmpty && !uniqueCpls.containsKey(kodeCpl)) {
            uniqueCpls[kodeCpl] = Map<String, dynamic>.from(m['cpl']);
          }
        }
      }
    }

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15), side: BorderSide(color: Colors.grey.shade200)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. TAMPILAN KELOMPOK TARGET CPL PRODI (MUNCUL 1 KALI SAJA DI ATAS)
            const Text("Mendukung CPL Program Studi:", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 0.3)),
            const SizedBox(height: 10),
            if (uniqueCpls.isEmpty)
              const Padding(
                padding: EdgeInsets.only(left: 5, bottom: 5),
                key: ValueKey('empty_cpl'),
                child: Text("- Tidak ada relasi CPL prodi terikat -", style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: Colors.grey)),
              )
            else
              ...uniqueCpls.values.map((cpl) => Container(
                    key: ValueKey('cpl_row_${cpl['kode_cpl']}'),
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.grey.shade100)),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(color: const Color(0xFFF0F7FF), borderRadius: BorderRadius.circular(6)),
                          child: Text("${cpl['kode_cpl']}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 10, color: primaryColor)),
                        ),
                        const SizedBox(width: 12),
                        Expanded(child: Text(cpl['deskripsi'] ?? '-', style: const TextStyle(fontSize: 12, color: Colors.black87, height: 1.3))),
                      ],
                    ),
                  )),
            
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Divider(height: 1, color: Color(0xFFF5F5F5), thickness: 1.2),
            ),

            // 2. TAMPILAN KOMPONEN INDIKATOR CPMK (MENGALIR DI BAWAHNYA LANGSUNG TANPA BOKS BARU)
            const Text("Capaian Pembelajaran Mata Kuliah (CPMK):", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 0.3)),
            const SizedBox(height: 12),
            ...listCpmk.map((c) {
              final String kodeCpmkAsli = c['kode_cpmk']?.toString() ?? 'CPMK-01';
              return Padding(
                key: ValueKey('cpmk_row_${c['id']}'),
                padding: const EdgeInsets.only(bottom: 14),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(6)),
                      child: Text(kodeCpmkAsli, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 10, color: primaryColor)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(c['deskripsi'] ?? '-', style: const TextStyle(fontWeight: FontWeight.w600, height: 1.4, fontSize: 13, color: Colors.black87)),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildActionBottomContainer(Map<String, dynamic> data, List listCpmk, String status) {
    if (widget.isKaprodi && (status == 'waiting_approval' || status == 'waiting_approval_revision')) {
      return _buildKaprodiActions();
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 15),
      color: Colors.white,
      child: SafeArea(
        child: SizedBox(
          width: double.infinity,
          height: 46,
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            icon: const Icon(Icons.print_rounded, size: 18),
            label: const Text("CETAK DOKUMEN RPS (PDF)", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            onPressed: () async {
              final List<Map<String, dynamic>> cpmkFormatted = listCpmk.map<Map<String, dynamic>>((c) {
                return {
                  'kode_cpmk': c['kode_cpmk']?.toString() ?? 'CPMK',
                  'deskripsi': c['deskripsi']?.toString() ?? '-',
                };
              }).toList();

              await PdfHelper.cetakRps(data, cpmkFormatted);
            },
          ),
        ),
      ),
    );
  }

  Widget _buildVerticalLayoutDivider() {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 12),
      child: Divider(height: 1, color: Color(0xFFF5F5F5), thickness: 1.2),
    );
  }

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

  Widget _buildStatusInfoRow(String status) {
    Color statusColor = Colors.grey;
    String statusLabel = status;

    if (status == 'draft') { 
      statusColor = Colors.blue; 
      statusLabel = "Draft (Belum Dikirim)"; 
    } else if (status == 'waiting_approval' || status == 'waiting_approval_revision') { 
      statusColor = Colors.orange; 
      statusLabel = "Waiting Approval"; 
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
              onPressed: _showRevisiDialog, 
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