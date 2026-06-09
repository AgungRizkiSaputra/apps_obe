import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/rps_service.dart';

class MappingPage extends StatefulWidget {
  final Map<String, dynamic> rpsData;
  final bool isRevision;

  const MappingPage({super.key, required this.rpsData, this.isRevision = false});

  @override
  State<MappingPage> createState() => _MappingPageState();
}

class _MappingPageState extends State<MappingPage> {
  final _rpsService = RpsService();
  final _supabase = Supabase.instance.client;
  final _cpmkController = TextEditingController();
  
  // --- PENYELARASAN WARNA SOLID SESUAI LOGO (TANPA GRADASI) ---
  static const Color primaryColor = Color(0xFF007AFF);
  
  // --- PERSENAN DIHAPUS: Weight controllers tidak digunakan lagi karena dospem minta tanpa persenan ---
  List<Map<String, dynamic>> listCpl = [];
  List<String> selectedCplIds = [];
  List<String> standarCplIds = []; 
  bool isLoading = false;

  List<Map<String, dynamic>> listMasterCpmk = [];
  String? selectedMasterCpmkId;
  String? selectedKodeCpmk; 

  @override
  void initState() {
    super.initState();
    _fetchCplDanStandar();
    _fetchMasterCpmkProdi(); 
  }

  @override
  void dispose() {
    _cpmkController.dispose();
    super.dispose();
  }

  // --- LOGIKA FETCH DATA MASTER CPMK PRODI (UTUH 100%) ---
  Future<void> _fetchMasterCpmkProdi() async {
    try {
      final String mkId = widget.rpsData['mata_kuliah_id'].toString();
      final response = await _supabase
          .from('master_cpmk')
          .select('*')
          .eq('mata_kuliah_id', mkId)
          .order('kode_cpmk', ascending: true);
          
      if (mounted) {
        setState(() {
          listMasterCpmk = List<Map<String, dynamic>>.from(response);
        });
      }
    } catch (e) {
      debugPrint("Error mengambil master CPMK prodi: $e");
    }
  }

  // --- LOGIKA FETCH DATA CPL (UTUH 100%) ---
  Future<void> _fetchCplDanStandar() async {
    setState(() => isLoading = true);
    try {
      final data = await _supabase.from('cpl').select().order('kode_cpl', ascending: true);
      final String mkId = widget.rpsData['mata_kuliah_id'].toString();
      final standarData = await _rpsService.getStandarCplIds(mkId);

      setState(() {
        listCpl = List<Map<String, dynamic>>.from(data);
        standarCplIds = standarData;

        if (!widget.isRevision) {
          selectedCplIds = List<String>.from(standarCplIds);
        }
      });
    } catch (e) {
      debugPrint("Error fetch data: $e");
    } finally {
      setState(() => isLoading = false);
    }
  }

  // --- LOGIKA NOTIFIKASI CUSTOM (UTUH) ---
  void _showCustomNotif(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              color == Colors.green ? Icons.check_circle_outline : Icons.info_outline,
              color: Colors.white,
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(message, style: const TextStyle(fontWeight: FontWeight.w600))),
          ],
        ),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(20),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  // --- LOGIKA SIMPAN KOMPLIT (DIBERSIHKAN DARI ATURAN WAJIB 100%) ---
  Future<void> _simpanMapping() async {
    if (selectedMasterCpmkId == null || _cpmkController.text.isEmpty || selectedCplIds.isEmpty) {
      _showCustomNotif("Silakan pilih Kode CPMK dan pilih minimal 1 CPL hubungannya!", Colors.orange);
      return;
    }

    setState(() => isLoading = true);
    try {
      final rpsId = widget.rpsData['id'].toString();
      
      // Karena dospem minta tanpa persenan, bobot otomatis kita set default 0 atau null di database gung gpp aman!
      List<Map<String, dynamic>> mappingData = selectedCplIds.map((id) {
        return {'cpl_id': id, 'bobot': 0}; 
      }).toList();

      if (widget.isRevision) await _rpsService.deleteExistingMapping(rpsId);

      await _rpsService.saveMappingWithWeights(
        rpsId: rpsId,
        deskripsi: _cpmkController.text.trim(),
        mappingData: mappingData, 
      );

      try {
        await _supabase
            .from('cpmk')
            .update({
              'kode_cpmk': selectedKodeCpmk,
              'mata_kuliah_id': widget.rpsData['mata_kuliah_id'].toString()
            })
            .eq('rps_id', rpsId)
            .eq('deskripsi', _cpmkController.text.trim());
      } catch (dbErr) {
        debugPrint("Sinkronisasi kode_cpmk dilewati: $dbErr");
      }

      if (widget.isRevision) await _rpsService.tandaiRevisiSelesai(rpsId);

      if (mounted) {
        _showCustomNotif("Mapping OBE Berhasil Disimpan!", Colors.green);
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) _showCustomNotif("Gagal: $e", Colors.red);
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Tombol simpan sekarang selalu aktif hijau selama dosen sudah memilih item pilihan gung
    bool isReadyToSubmit = selectedMasterCpmkId != null && selectedCplIds.isNotEmpty;

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: Text(widget.isRevision ? "Revisi Mapping OBE" : "Mapping CPMK", style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: widget.isRevision ? Colors.orange : primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      body: isLoading && listCpl.isEmpty 
        ? const Center(child: CircularProgressIndicator())
        : Column(
            children: [
              // --- SEKARANG BERSIH: Progress bar akumulasi persenan 100% di atas sudah dihilangkan penuh ---
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSectionTitle("1. Pilih Kode & Deskripsi CPMK", Icons.bookmark_added_rounded),
                      const SizedBox(height: 12),
                      _buildCpmkDropdownInput(), 
                      const SizedBox(height: 30),
                      _buildSectionTitle("2. Hubungkan ke CPL Prodi (Ceklist)", Icons.checklist_rtl_rounded),
                      const SizedBox(height: 10),
                      ...listCpl.map((cpl) => _buildCplCard(cpl)),
                      const SizedBox(height: 30),
                      _buildSubmitButton(isReadyToSubmit),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
            ],
          ),
    );
  }

  Widget _buildSectionTitle(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: primaryColor, size: 20),
        const SizedBox(width: 8),
        Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildCpmkDropdownInput() {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.01), blurRadius: 10, offset: const Offset(0, 4))],
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          listMasterCpmk.isEmpty
              ? const Padding(
                  padding: EdgeInsets.symmetric(vertical: 10),
                  child: Text(
                    "⚠️ Kaprodi belum menginput daftar master CPMK untuk Mata Kuliah ini.",
                    style: TextStyle(color: Colors.red, fontSize: 13, fontWeight: FontWeight.w500),
                  ),
                )
              : DropdownButtonFormField<String>(
                  value: selectedMasterCpmkId,
                  hint: const Text("-- Klik Pilih Kode CPMK Kurikulum --", style: TextStyle(fontSize: 13)),
                  isExpanded: true,
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.qr_code, color: primaryColor, size: 20),
                    filled: true,
                    fillColor: Colors.grey.shade50,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade200)),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade100)),
                  ),
                  items: listMasterCpmk.map((item) {
                    return DropdownMenuItem<String>(
                      value: item['id'].toString(),
                      child: Text(
                        "${item['kode_cpmk']} : ${item['deskripsi']}",
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                    );
                  }).toList(),
                  onChanged: (value) {
                    final selectedData = listMasterCpmk.firstWhere((element) => element['id'].toString() == value);
                    setState(() {
                      selectedMasterCpmkId = value;
                      selectedKodeCpmk = selectedData['kode_cpmk']?.toString();
                      _cpmkController.text = selectedData['deskripsi']?.toString() ?? '';
                    });
                  },
                ),
          if (_cpmkController.text.isNotEmpty) ...[
            const Padding(
              padding: EdgeInsets.only(top: 15, bottom: 5),
              child: Text("Deskripsi Capaian Resmi (Kaprodi):", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.grey)),
            ),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Text(
                _cpmkController.text,
                style: const TextStyle(fontSize: 13, height: 1.4, fontWeight: FontWeight.w500, color: Colors.black87),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCplCard(Map<String, dynamic> cpl) {
    final String cplId = cpl['id'].toString();
    final bool isSelected = selectedCplIds.contains(cplId);
    final bool isStandar = standarCplIds.contains(cplId);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: isSelected ? primaryColor : Colors.transparent, width: 2),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 8, offset: const Offset(0, 4))],
      ),
      child: CheckboxListTile(
        activeColor: primaryColor,
        title: Row(
          children: [
            Text(cpl['kode_cpl'] ?? '-', style: const TextStyle(fontWeight: FontWeight.bold)),
            if (isStandar) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(5)),
                child: const Text("STANDAR", style: TextStyle(fontSize: 9, color: Colors.blue, fontWeight: FontWeight.bold)),
              )
            ]
          ],
        ),
        subtitle: Text(cpl['deskripsi'] ?? '-', style: const TextStyle(fontSize: 12)),
        value: isSelected,
        onChanged: (val) {
          setState(() {
            if (val == true) {
              selectedCplIds.add(cplId);
            } else {
              selectedCplIds.remove(cplId);
            }
          });
        },
      ),
      // --- SEKARANG BERSIH: Textfield input bobot persen (%) di bawah list tile ini sudah dihapus total ---
    );
  }

  Widget _buildSubmitButton(bool isReady) {
    return SizedBox(
      width: double.infinity,
      height: 55,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: isReady ? Colors.green : Colors.grey,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          elevation: isReady ? 3 : 0,
        ),
        onPressed: (isLoading || !isReady) ? null : _simpanMapping,
        child: Text(
          isLoading ? "PROSES MENYIMPAN..." : "SIMPAN MAPPING OBE",
          style: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1),
        ),
      ),
    );
  }
}