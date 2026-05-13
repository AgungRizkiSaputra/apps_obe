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
  
  Map<String, TextEditingController> _weightControllers = {};
  
  List<Map<String, dynamic>> listCpl = [];
  List<String> selectedCplIds = [];
  List<String> standarCplIds = []; 
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    _fetchCplDanStandar();
  }

  @override
  void dispose() {
    _cpmkController.dispose();
    _weightControllers.forEach((_, controller) => controller.dispose());
    super.dispose();
  }

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
          // Inisialisasi controller untuk CPL standar dengan nilai awal 0
          for (var id in selectedCplIds) {
            _weightControllers[id] = TextEditingController(text: "0");
          }
        }
      });
    } catch (e) {
      debugPrint("Error fetch data: $e");
    } finally {
      setState(() => isLoading = false);
    }
  }

  double _calculateTotalWeight() {
    double total = 0;
    _weightControllers.forEach((_, controller) {
      total += double.tryParse(controller.text) ?? 0;
    });
    return total;
  }

  Future<void> _simpanMapping() async {
    // 1. Validasi Input Dasar
    if (_cpmkController.text.isEmpty || selectedCplIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Isi CPMK dan pilih minimal 1 CPL!")),
      );
      return;
    }

    // 2. Validasi Total Bobot (Harus 100%)
    double total = _calculateTotalWeight();
    if (total != 100) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Total bobot harus pas 100%! (Sekarang: $total%)"),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => isLoading = true);
    try {
      final rpsId = widget.rpsData['id'].toString();

      // --- LOGIKA MENGAMBIL NILAI DARI TEXTFIELD ---
      List<Map<String, dynamic>> mappingData = selectedCplIds.map((id) {
        // Ambil angka dari controller, default ke 0 jika gagal parse
        int bobotInput = int.tryParse(_weightControllers[id]?.text ?? "0") ?? 0;
        return {
          'cpl_id': id,
          'bobot': bobotInput,
        };
      }).toList();

      if (widget.isRevision) {
        await _rpsService.deleteExistingMapping(rpsId);
      }

      // 3. Simpan ke Database
      await _rpsService.saveMappingWithWeights(
        rpsId: rpsId,
        deskripsi: _cpmkController.text.trim(),
        mappingData: mappingData, 
      );

      if (widget.isRevision) {
        await _rpsService.tandaiRevisiSelesai(rpsId);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Mapping OBE Berhasil Disimpan!"), backgroundColor: Colors.green),
        );
        Navigator.pop(context); // Kembali setelah berhasil
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    double currentTotal = _calculateTotalWeight();

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isRevision ? "Revisi Mapping OBE" : "Mapping CPMK ke CPL"),
        backgroundColor: widget.isRevision ? Colors.orange : Colors.blue.shade800,
        foregroundColor: Colors.white,
      ),
      body: isLoading && listCpl.isEmpty 
        ? const Center(child: CircularProgressIndicator())
        : SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Indikator Progress Bobot
            Container(
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                color: currentTotal == 100 ? Colors.green.shade50 : Colors.red.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: currentTotal == 100 ? Colors.green : Colors.red),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text("Total Bobot Terisi:", style: TextStyle(fontWeight: FontWeight.bold)),
                  Text("${currentTotal.toInt()} / 100%", 
                    style: TextStyle(
                      fontSize: 18, 
                      fontWeight: FontWeight.bold, 
                      color: currentTotal == 100 ? Colors.green : Colors.red
                    )
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            const Text("1. Input Deskripsi CPMK:", style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            TextField(
              controller: _cpmkController,
              maxLines: 3,
              decoration: const InputDecoration(border: OutlineInputBorder(), hintText: "Misal: Mahasiswa mampu memahami konsep dasar..."),
            ),
            const SizedBox(height: 20),
            const Text("2. Pilih CPL & Tentukan Bobot:", style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            ...listCpl.map((cpl) {
              final String cplId = cpl['id'].toString();
              final bool isSelected = selectedCplIds.contains(cplId);
              
              return Card(
                margin: const EdgeInsets.only(bottom: 10),
                shape: RoundedRectangleBorder(
                  side: BorderSide(color: isSelected ? Colors.blue : Colors.transparent),
                  borderRadius: BorderRadius.circular(8)
                ),
                child: Column(
                  children: [
                    CheckboxListTile(
                      title: Text(cpl['kode_cpl'] ?? '-', style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text(cpl['deskripsi'] ?? '-'),
                      value: isSelected,
                      onChanged: (val) {
                        setState(() {
                          if (val == true) {
                            selectedCplIds.add(cplId);
                            _weightControllers[cplId] = TextEditingController(text: "0");
                          } else {
                            selectedCplIds.remove(cplId);
                            _weightControllers[cplId]?.dispose();
                            _weightControllers.remove(cplId);
                          }
                        });
                      },
                    ),
                    if (isSelected)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 15),
                        child: TextField(
                          controller: _weightControllers[cplId],
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: "Masukkan Bobot Untuk CPL Ini (%)",
                            prefixIcon: Icon(Icons.percent, size: 16),
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                          onChanged: (_) => setState(() {}), // Update indikator total
                        ),
                      ),
                  ],
                ),
              );
            }),
            const SizedBox(height: 30),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: currentTotal == 100 ? Colors.green : Colors.grey,
                  foregroundColor: Colors.white,
                ),
                onPressed: isLoading ? null : _simpanMapping,
                child: Text(isLoading ? "MENYIMPAN..." : "SIMPAN MAPPING OBE"),
              ),
            ),
          ],
        ),
      ),
    );
  }
}