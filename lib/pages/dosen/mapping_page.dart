import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/rps_service.dart';

class CpmkMappingGroup {
  String? selectedMasterCpmkId;
  String? selectedKodeCpmk;
  String deskripsiCpmk;

  CpmkMappingGroup({
    this.selectedMasterCpmkId,
    this.selectedKodeCpmk,
    this.deskripsiCpmk = '',
  });
}

class MappingPage extends StatefulWidget {
  final Map<String, dynamic> rpsData;
  final bool isRevision;
  final bool isBelumSimpanDatabase; // Kontrol penanda alur tunda gung

  const MappingPage({
    super.key, 
    required this.rpsData, 
    this.isRevision = false,
    this.isBelumSimpanDatabase = false,
  });

  @override
  State<MappingPage> createState() => _MappingPageState();
}

class _MappingPageState extends State<MappingPage> {
  final _rpsService = RpsService();
  final _supabase = Supabase.instance.client;
  
  static const Color primaryColor = Color(0xFF007AFF);
  
  List<Map<String, dynamic>> listCpl = [];
  List<String> selectedCplIds = [];
  List<String> standarCplIds = []; 
  List<Map<String, dynamic>> listMasterCpmk = [];
  bool isLoading = false;

  List<CpmkMappingGroup> mappingGroups = [];

  @override
  void initState() {
    super.initState();
    _initDataSederhana();
  }

  Future<void> _initDataSederhana() async {
    setState(() => isLoading = true);
    await _fetchMasterCpmkProdi();
    await _fetchCplDanStandar();
    setState(() => isLoading = false);
  }

  Future<void> _fetchMasterCpmkProdi() async {
    try {
      final String mkId = widget.rpsData['mata_kuliah_id'].toString();
      final response = await _supabase
          .from('cpmk') 
          .select('*')
          .eq('mata_kuliah_id', mkId)
          .filter('rps_id', 'is', null) 
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

  Future<void> _fetchCplDanStandar() async {
    try {
      final data = await _supabase.from('cpl').select().order('kode_cpl', ascending: true);
      final String mkId = widget.rpsData['mata_kuliah_id'].toString();
      final standarData = await _rpsService.getStandarCplIds(mkId);

      if (mounted) {
        setState(() {
          listCpl = List<Map<String, dynamic>>.from(data);
          standarCplIds = standarData;

          if (!widget.isRevision) {
            selectedCplIds = List<String>.from(standarCplIds);
          }
        });
      }
    } catch (e) {
      debugPrint("Error fetch data CPL: $e");
    }
  }

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

  Future<void> _simpanMapping() async {
    if (mappingGroups.isEmpty) {
      _showCustomNotif("Silakan pilih minimal 1 Kode CPMK pada pilihan di atas.", Colors.orange);
      return;
    }

    if (selectedCplIds.isEmpty) {
      _showCustomNotif("Silakan pilih minimal 1 target CPL Program Studi.", Colors.orange);
      return;
    }

    setState(() => isLoading = true);
    try {
      // --- KOREKSI TOTAL VALIDASI POIN UTAMA AGUNG: Mendeteksi alur tunda secara pintar otomatis ---
      String rpsId = widget.rpsData['id']?.toString() ?? '';
      final bool apakahDokumenBaru = (rpsId.isEmpty || rpsId == 'null');

      if (apakahDokumenBaru) {
        final userId = _supabase.auth.currentUser!.id;
        
        final Map<String, dynamic> rpsBaru = await _rpsService.createRps(
          mkId: widget.rpsData['mata_kuliah_id'].toString(), 
          dosenId: userId,
          tahunAjaran: widget.rpsData['tahun_ajaran'].toString(),
          semester: widget.rpsData['semester'].toString(),
          bahanKajian: widget.rpsData['bahan_kajian'].toString(),
          metodePembelajaran: widget.rpsData['metode_pembelajaran'].toString(), 
          daftarReferensi: widget.rpsData['daftar_referensi'].toString(),
          mkPrasyarat: widget.rpsData['mk_prasyarat'].toString(),
          ambangBatas: widget.rpsData['ambang_batas'].toString(),
        );
        
        rpsId = rpsBaru['id'].toString();
      }

      if (widget.isRevision) {
        await _rpsService.deleteExistingMapping(rpsId);
      }

      List<Map<String, dynamic>> mappingData = selectedCplIds.map((id) {
        return {'cpl_id': id, 'bobot': 0}; 
      }).toList();

      for (var grup in mappingGroups) {
        String kodeCpmkTerverifikasi = grup.selectedKodeCpmk ?? 'CPMK';
        
        if (grup.selectedMasterCpmkId != null) {
          final masterRow = await _supabase
              .from('cpmk')
              .select('kode_cpmk')
              .eq('id', grup.selectedMasterCpmkId!)
              .single();
              
          if (masterRow['kode_cpmk'] != null) {
            kodeCpmkTerverifikasi = masterRow['kode_cpmk'].toString();
          }
        }

        // Mengunci parameter agar UUID yang dikirim terikat murni ke rpsId hasil generate database cloud gung
        final insertedCpmk = await _supabase.from('cpmk').insert({
          'rps_id': rpsId,
          'deskripsi': grup.deskripsiCpmk.trim(),
          'kode_cpmk': kodeCpmkTerverifikasi, 
          'mata_kuliah_id': widget.rpsData['mata_kuliah_id'].toString() 
        }).select('id').single();

        final String generatedCpmkId = insertedCpmk['id'].toString();

        final List<Map<String, dynamic>> finalMapping = mappingData.map((item) {
          return {
            'cpmk_id': generatedCpmkId,
            'cpl_id': item['cpl_id'],
            'bobot': item['bobot'], 
          };
        }).toList();

        await _supabase.from('mapping_cpl_cpmk').insert(finalMapping);
      }

      if (widget.isRevision) await _rpsService.tandaiRevisiSelesai(rpsId);

      mappingGroups.clear();

      if (mounted) {
        setState(() => isLoading = false);
        _showCustomNotif("Seluruh Pemetaan Multi-CPMK Berhasil Disimpan.", Colors.green);
        Navigator.pop(context); 
      }
    } catch (e) {
      if (mounted) {
        setState(() => isLoading = false);
        _showCustomNotif("Gagal menyimpan data: $e", Colors.red);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    bool isReadyToSubmit = mappingGroups.isNotEmpty && selectedCplIds.isNotEmpty;

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: Text(widget.isRevision ? "Revisi Multi-Mapping OBE" : "Mapping Multi-CPMK", style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: widget.isRevision ? Colors.orange : primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      body: isLoading && listCpl.isEmpty 
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSectionTitle("1. Pilih CPMK Mata Kuliah Kurikulum", Icons.grid_view_rounded),
                        const SizedBox(height: 12),
                        _buildMasterCpmkChipsGrid(),
                        
                        const SizedBox(height: 30),
                        
                        _buildSectionTitle("2. Hubungkan ke CPL Prodi (Ceklist Cukup 1 Saja)", Icons.checklist_rtl_rounded),
                        const SizedBox(height: 12),
                        ...listCpl.map((cpl) => _buildCplCardTunggal(cpl)),
                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                ),
                _buildBottomActionPanel(isReadyToSubmit),
              ],
            ),
    );
  }

  Widget _buildSectionTitle(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: primaryColor, size: 20),
        const SizedBox(width: 8),
        Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildMasterCpmkChipsGrid() {
    if (listMasterCpmk.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15), border: Border.all(color: Colors.grey.shade200)),
        child: const Text("⚠️ Daftar master CPMK program studi belum tersedia untuk mata kuliah ini.", style: TextStyle(color: Colors.red, fontSize: 12)),
      );
    }

    final validSelectedGroups = mappingGroups.where((grup) => 
      grup.selectedMasterCpmkId != null && 
      grup.selectedKodeCpmk != null && 
      grup.selectedKodeCpmk != 'null'
    ).toList();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.01), blurRadius: 10, offset: const Offset(0, 4))],
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Pilih Kode CPMK (Dapat memilih lebih dari satu komponen):", style: TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.w500)),
          const SizedBox(height: 12),
          
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: listMasterCpmk.map((item) {
              final String itemId = item['id'].toString();
              final bool isSelected = mappingGroups.any((element) => element.selectedMasterCpmkId == itemId);
              
              return InkWell(
                onTap: () {
                  setState(() {
                    if (isSelected) {
                      mappingGroups.removeWhere((element) => element.selectedMasterCpmkId == itemId);
                    } else {
                      mappingGroups.add(CpmkMappingGroup(
                        selectedMasterCpmkId: itemId,
                        selectedKodeCpmk: item['kode_cpmk']?.toString(),
                        deskripsiCpmk: item['deskripsi']?.toString() ?? '',
                      ));
                    }
                  });
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: isSelected ? primaryColor : Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: isSelected ? primaryColor : Colors.grey.shade300, width: 1.2),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isSelected ? Icons.check_box_rounded : Icons.check_box_outline_blank_rounded,
                        color: isSelected ? Colors.white : Colors.grey,
                        size: 16,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        item['kode_cpmk'] ?? '-',
                        style: TextStyle(
                          color: isSelected ? Colors.white : Colors.black87,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
          
          if (validSelectedGroups.isNotEmpty) ...[
            const Divider(height: 30),
            const Text("Deskripsi CPMK Terpilih:", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: primaryColor)),
            const SizedBox(height: 10),
            ...validSelectedGroups.map((grup) => Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.grey.shade200)),
                  child: Text(
                    "${grup.selectedKodeCpmk} : ${grup.deskripsiCpmk}",
                    style: const TextStyle(fontSize: 12, height: 1.4, color: Colors.black87, fontWeight: FontWeight.w500),
                  ),
                )),
          ]
        ],
      ),
    );
  }

  Widget _buildCplCardTunggal(Map<String, dynamic> cpl) {
    final String cplId = cpl['id'].toString();
    final bool isSelected = selectedCplIds.contains(cplId);
    final bool isStandar = standarCplIds.contains(cplId);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isSelected ? primaryColor : Colors.grey.shade200, width: isSelected ? 1.5 : 1),
      ),
      child: CheckboxListTile(
        activeColor: primaryColor,
        dense: true,
        title: Row(
          children: [
            Text(cpl['kode_cpl'] ?? '-', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            if (isStandar) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(4)),
                child: const Text("STANDAR", style: TextStyle(fontSize: 8, color: Colors.blue, fontWeight: FontWeight.bold)),
              )
            ]
          ],
        ),
        subtitle: Text(cpl['deskripsi'] ?? '-', style: const TextStyle(fontSize: 11), maxLines: 2, overflow: TextOverflow.ellipsis),
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
    );
  }

  Widget _buildBottomActionPanel(bool isReady) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 15),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, -4))],
      ),
      child: SafeArea(
        child: SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: isReady ? Colors.green : Colors.grey,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: (isLoading || !isReady) ? null : _simpanMapping,
            child: Text(
              isLoading ? "SEDANG MENYIMPAN DATA MASAL..." : "SIMPAN DOKUMEN MAPPING OBE",
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, letterSpacing: 0.5),
            ),
          ),
        ),
      ),
    );
  }
}