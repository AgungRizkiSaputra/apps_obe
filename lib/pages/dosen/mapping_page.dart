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
  
  List<Map<String, dynamic>> listCpl = [];
  List<String> selectedCplIds = [];
  List<String> standarCplIds = []; // Variabel baru untuk menampung standar kaprodi
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    _fetchCplDanStandar();
  }

  Future<void> _fetchCplDanStandar() async {
    setState(() => isLoading = true);
    try {
      // 1. Ambil semua CPL
      final data = await _supabase.from('cpl').select().order('kode_cpl', ascending: true);
      
      // 2. Ambil Standar CPL dari Kaprodi berdasarkan ID Mata Kuliah
      final String mkId = widget.rpsData['mata_kuliah_id'].toString();
      final standarData = await _rpsService.getStandarCplIds(mkId);

      setState(() {
        listCpl = List<Map<String, dynamic>>.from(data);
        standarCplIds = standarData;

        // 3. Jika bukan revisi (RPS baru), otomatis centang yang standar prodi
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

  Future<void> _simpanMapping() async {
    if (_cpmkController.text.isEmpty || selectedCplIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Isi CPMK dan pilih minimal 1 CPL!")),
      );
      return;
    }

    setState(() => isLoading = true);
    try {
      final rpsId = widget.rpsData['id'].toString();

      if (widget.isRevision) {
        await _rpsService.deleteExistingMapping(rpsId);
      }

      await _rpsService.saveMapping(
        rpsId: rpsId,
        deskripsi: _cpmkController.text,
        selectedCplIds: selectedCplIds,
      );

      if (widget.isRevision) {
        await _rpsService.tandaiRevisiSelesai(rpsId);
      }

      if (mounted) {
        _cpmkController.clear();
        // Reset pilihan ke standar prodi setelah simpan berhasil (untuk input butir berikutnya)
        setState(() => selectedCplIds = List<String>.from(standarCplIds));
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.isRevision 
              ? "Revisi Berhasil Disimpan! Status diperbarui." 
              : "CPMK & Mapping Berhasil Disimpan!"),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isRevision ? "Revisi Mapping OBE" : "Mapping CPMK ke CPL"),
        backgroundColor: widget.isRevision ? Colors.orange : null,
      ),
      body: isLoading && listCpl.isEmpty 
        ? const Center(child: CircularProgressIndicator())
        : SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.isRevision)
              Container(
                padding: const EdgeInsets.all(10),
                margin: const EdgeInsets.only(bottom: 15), 
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.edit_note, color: Colors.orange),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        "Mode Revisi: Simpan perubahan untuk menandai revisi telah selesai.",
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),
            Text(
              "Mata Kuliah: ${widget.rpsData['mata_kuliah']?['nama_mk'] ?? 'Mata Kuliah'}", 
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)
            ),
            const Divider(),
            const Text("1. Input Deskripsi CPMK Baru:", style: TextStyle(fontWeight: FontWeight.w500)),
            const SizedBox(height: 8),
            TextField(
              controller: _cpmkController,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText: "Contoh: Mahasiswa mampu memahami konsep...",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
            const Text("2. Pilih CPL yang Terkait (OBE):", style: TextStyle(fontWeight: FontWeight.w500)),
            const SizedBox(height: 10),
            ...listCpl.map((cpl) {
              final String cplId = cpl['id'].toString();
              final bool isStandar = standarCplIds.contains(cplId);
              
              return CheckboxListTile(
                title: Row(
                  children: [
                    Text(cpl['kode_cpl'] ?? '-'),
                    if (isStandar)
                      Container(
                        margin: const EdgeInsets.only(left: 10),
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.purple.shade50,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: Colors.purple.shade200),
                        ),
                        child: const Text(
                          "STANDAR PRODI", 
                          style: TextStyle(fontSize: 9, color: Colors.purple, fontWeight: FontWeight.bold)
                        ),
                      ),
                  ],
                ),
                subtitle: Text(cpl['deskripsi'] ?? '-'),
                value: selectedCplIds.contains(cplId),
                onChanged: (val) {
                  setState(() {
                    if (val == true) {
                      selectedCplIds.add(cplId);
                    } else {
                      selectedCplIds.remove(cplId);
                    }
                  });
                },
              );
            }),
            const SizedBox(height: 30),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: widget.isRevision ? Colors.orange : Colors.blue,
                  foregroundColor: Colors.white,
                ),
                onPressed: isLoading ? null : _simpanMapping,
                child: isLoading 
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) 
                  : Text(widget.isRevision ? "Simpan Perubahan Revisi" : "Simpan Butir CPMK"),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => Navigator.pop(context), 
                child: const Text("Selesai & Kembali ke Dashboard"),
              ),
            ),
          ],
        ),
      ),
    );
  }
}