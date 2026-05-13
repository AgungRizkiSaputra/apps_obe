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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Berhasil mengubah status ke $status")),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Gagal: $e"), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _showRevisiDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Catatan Revisi"),
        content: TextField(
          controller: controller,
          maxLines: 3,
          decoration: const InputDecoration(
            border: OutlineInputBorder(), 
            hintText: "Berikan masukan perbaikan untuk dosen..."
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Batal")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
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
      appBar: AppBar(
        title: const Text("Detail RPS OBE"),
        backgroundColor: Colors.blue.shade800,
        foregroundColor: Colors.white,
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
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    _buildHeader("Informasi Mata Kuliah"),
                    _buildInfoRow("Mata Kuliah", mk?['nama_mk'] ?? '-'),
                    _buildInfoRow("Kode MK", mk?['kode_mk'] ?? '-'),
                    _buildInfoRow("SKS", "${mk?['sks'] ?? '0'} SKS"),
                    _buildInfoRow("Semester", "${mk?['semester'] ?? '-'} (${data['semester'] ?? '-'})"),
                    _buildInfoRow("Dosen Pengampu", data['users']?['nama'] ?? '-'),
                    _buildInfoRow("Tahun Ajaran", data['tahun_ajaran'] ?? '-'),
                    
                    const SizedBox(height: 20),

                    if (!widget.isKaprodi)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 15),
                        child: ElevatedButton.icon(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => InputPertemuanPage(rpsId: widget.rpsId))
                            ).then((_) => _initData());
                          },
                          icon: const Icon(Icons.edit_calendar),
                          label: const Text("Atur Rencana Pertemuan (Minggu 1-14)"),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue.shade50,
                            foregroundColor: Colors.blue.shade800,
                          ),
                        ),
                      ),
                    
                    _buildHeader("Capaian Pembelajaran MK (CPMK)"),
                    
                    if (listCpmk.isEmpty)
                      const Padding(
                        padding: EdgeInsets.all(8.0),
                        child: Text("Belum ada data CPMK.", style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey)),
                      ),

                    ...listCpmk.map((c) {
                      final mapping = (c['mapping_cpl_cpmk'] as List?) ?? [];
                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 8),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(c['deskripsi'] ?? '-', style: const TextStyle(fontWeight: FontWeight.w500)),
                              if (mapping.isNotEmpty) ...[
                                const Divider(),
                                const Text("Mendukung CPL Prodi:", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey)),
                                const SizedBox(height: 5),
                                ...mapping.map((m) => Padding(
                                  padding: const EdgeInsets.only(bottom: 4),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(4)),
                                        // MENAMPILKAN BOBOT DI SINI GUNG
                                        child: Text(
                                          "${m['cpl']['kode_cpl']} (${m['bobot'] ?? 0}%)", 
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 10, color: Colors.blue)
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(child: Text(m['cpl']['deskripsi'], style: const TextStyle(fontSize: 12))),
                                    ],
                                  ),
                                )),
                              ]
                            ],
                          ),
                        ),
                      );
                    }).toList(),

                    const SizedBox(height: 20),
                    _buildHeader("Rencana Pertemuan"),
                    
                    if (listPertemuan.isEmpty)
                      const Padding(
                        padding: EdgeInsets.all(8.0),
                        child: Text("Belum ada rencana pertemuan.", style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey)),
                      )
                    else
                      ...listPertemuan.map((p) => Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: CircleAvatar(
                            radius: 15,
                            backgroundColor: Colors.blue.shade100,
                            child: Text("${p['minggu_ke']}", style: TextStyle(fontSize: 12, color: Colors.blue.shade800, fontWeight: FontWeight.bold)),
                          ),
                          title: Text(p['kemampuan_akhir'] ?? '-', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                          subtitle: Text("Metode: ${p['metode_pembelajaran'] ?? '-'}\nBobot: ${p['bobot_nilai']}%"),
                        ),
                      )).toList(),
                    
                    const SizedBox(height: 40),
                  ],
                ),
              ),
              
              if (widget.isKaprodi && (status == 'waiting_approval' || status == 'waiting_approval_revision'))
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -5))],
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _showRevisiDialog,
                          icon: const Icon(Icons.edit_note, color: Colors.orange),
                          label: const Text("Revisi", style: TextStyle(color: Colors.orange)),
                          style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.orange)),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => _updateStatus('approved'),
                          icon: const Icon(Icons.check_circle),
                          label: const Text("Setujui RPS"),
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildHeader(String title) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: Colors.blue.shade800,
        ),
      ),
    );

  Widget _buildInfoRow(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            SizedBox(width: 120, child: Text(label, style: const TextStyle(fontWeight: FontWeight.bold))),
            const Text(": "),
            Expanded(child: Text(value)),
          ],
        ),
      );
}