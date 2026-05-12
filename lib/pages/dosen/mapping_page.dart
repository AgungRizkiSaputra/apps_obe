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
  
  // Map untuk menyimpan controller bobot tiap CPL yang dipilih
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
          // Inisialisasi controller untuk CPL standar
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

  // Fungsi untuk menghitung total bobot secara real-time
  double _calculateTotalWeight() {
    double total = 0;
    _weightControllers.forEach((_, controller) {
      total += double.tryParse(controller.text) ?? 0;
    });
    return total;
  }

  Future<void> _simpanMapping() async {
    // 1. Validasi Dasar
    if (_cpmkController.text.isEmpty || selectedCplIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Isi CPMK dan pilih minimal 1 CPL!")),
      );
      return;
    }

    setState(() => isLoading = true);
    try {
      final rpsId = widget.rpsData['id'].toString();

      // --- LOGIKA PERHITUNGAN BOBOT OTOMATIS (AGAR TIDAK 0%) ---
      // Kita bagi 100 dengan jumlah CPL yang dipilih
      // Misal pilih 2 CPL, maka masing-masing 50%
      int bobotPerCpl = (100 / selectedCplIds.length).floor(); 

      // Susun data mapping lengkap dengan bobotnya
      List<Map<String, dynamic>> mappingData = selectedCplIds.map((id) => {
        'cpl_id': id,
        'bobot': bobotPerCpl,
      }).toList();

      if (widget.isRevision) {
        await _rpsService.deleteExistingMapping(rpsId);
      }

      // 2. Panggil Service dengan data yang sudah ada bobotnya
      await _rpsService.saveMappingWithWeights(
        rpsId: rpsId,
        deskripsi: _cpmkController.text.trim(),
        mappingData: mappingData, // Kirim list yang sudah ada bobotnya
      );

      // --- Lanjutan kode kamu (Tandai revisi selesai, SnackBar, dsb) ---
      if (widget.isRevision) {
        await _rpsService.tandaiRevisiSelesai(rpsId);
      }

      if (mounted) {
        _cpmkController.clear();
        setState(() => selectedCplIds = List<String>.from(standarCplIds));
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Mapping OBE Berhasil Disimpan!"), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  // ignore: unused_element
  void _showSnackBar(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: color),
    );
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
                color: currentTotal == 100 ? Colors.green.shade50 : Colors.blue.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: currentTotal == 100 ? Colors.green : Colors.blue),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text("Total Bobot Terisi:", style: TextStyle(fontWeight: FontWeight.bold)),
                  Text("$currentTotal / 100%", 
                    style: TextStyle(
                      fontSize: 18, 
                      fontWeight: FontWeight.bold, 
                      color: currentTotal == 100 ? Colors.green : Colors.blue.shade800
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
              decoration: const InputDecoration(border: OutlineInputBorder(), hintText: "Deskripsi materi..."),
            ),
            const SizedBox(height: 20),
            const Text("2. Pilih CPL & Tentukan Bobot:", style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            ...listCpl.map((cpl) {
              final String cplId = cpl['id'].toString();
              final bool isSelected = selectedCplIds.contains(cplId);
              
              return Card(
                margin: const EdgeInsets.only(bottom: 10),
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
                            labelText: "Bobot (%)",
                            prefixIcon: Icon(Icons.percent, size: 16),
                            border: OutlineInputBorder(),
                          ),
                          onChanged: (_) => setState(() {}),
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
                child: const Text("SIMPAN MAPPING OBE"),
              ),
            ),
          ],
        ),
      ),
    );
  }
}