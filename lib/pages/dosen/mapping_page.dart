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
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    _fetchCpl();
  }

  Future<void> _fetchCpl() async {
    try {
      final data = await _supabase.from('cpl').select();
      setState(() {
        listCpl = List<Map<String, dynamic>>.from(data);
      });
    } catch (e) {
      debugPrint("Error fetch CPL: $e");
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

      // Jika revisi, bersihkan data lama dulu
      if (widget.isRevision) {
        await _rpsService.deleteExistingMapping(rpsId);
      }

      // Simpan data mapping baru
      await _rpsService.saveMapping(
        rpsId: rpsId,
        deskripsi: _cpmkController.text,
        selectedCplIds: selectedCplIds,
      );

      // KHUSUS REVISI: Tandai bahwa revisi konten sudah selesai dilakukan
      if (widget.isRevision) {
        await _rpsService.tandaiRevisiSelesai(rpsId);
      }

      if (mounted) {
        _cpmkController.clear();
        setState(() => selectedCplIds = []);
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
      body: SingleChildScrollView(
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
            const Text("1. Input Deskripsi CPMK Baru:"),
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
            const Text("2. Pilih CPL yang Terkait (OBE):"),
            const SizedBox(height: 10),
            ...listCpl.map((cpl) => CheckboxListTile(
                  title: Text(cpl['kode_cpl'] ?? '-'),
                  subtitle: Text(cpl['deskripsi'] ?? '-'),
                  value: selectedCplIds.contains(cpl['id'].toString()),
                  onChanged: (val) {
                    setState(() {
                      if (val == true) {
                        selectedCplIds.add(cpl['id'].toString());
                      } else {
                        selectedCplIds.remove(cpl['id'].toString());
                      }
                    });
                  },
                )),
            const SizedBox(height: 30),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: widget.isRevision ? Colors.orange : Colors.blue,
                  foregroundColor: Colors.white,
                ),
                onPressed: isLoading ? null : _simpanMapping,
                child: isLoading 
                  ? const CircularProgressIndicator(color: Colors.white) 
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