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

  // --- LOGIKA FETCH DATA (UTUH 100%) ---
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

  // --- LOGIKA SIMPAN KOMPLIT (UTUH 100%) ---
  Future<void> _simpanMapping() async {
    if (_cpmkController.text.isEmpty || selectedCplIds.isEmpty) {
      _showCustomNotif("Isi CPMK dan pilih minimal 1 CPL!", Colors.orange);
      return;
    }

    double total = _calculateTotalWeight();
    if (total != 100) {
      _showCustomNotif("Total bobot harus pas 100%! (Sekarang: ${total.toInt()}%)", Colors.red);
      return;
    }

    setState(() => isLoading = true);
    try {
      final rpsId = widget.rpsData['id'].toString();
      List<Map<String, dynamic>> mappingData = selectedCplIds.map((id) {
        int bobotInput = int.tryParse(_weightControllers[id]?.text ?? "0") ?? 0;
        return {'cpl_id': id, 'bobot': bobotInput};
      }).toList();

      if (widget.isRevision) await _rpsService.deleteExistingMapping(rpsId);

      await _rpsService.saveMappingWithWeights(
        rpsId: rpsId,
        deskripsi: _cpmkController.text.trim(),
        mappingData: mappingData, 
      );

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
    double currentTotal = _calculateTotalWeight();
    bool isDone = currentTotal == 100;

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
              _buildWeightIndicator(currentTotal, isDone),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSectionTitle("1. Deskripsi CPMK", Icons.edit_note),
                      const SizedBox(height: 10),
                      _buildCpmkInput(),
                      const SizedBox(height: 30),
                      _buildSectionTitle("2. Pilih CPL & Bobot", Icons.checklist_rtl_rounded),
                      const SizedBox(height: 10),
                      ...listCpl.map((cpl) => _buildCplCard(cpl)),
                      const SizedBox(height: 30),
                      _buildSubmitButton(isDone),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
            ],
          ),
    );
  }

  // --- KOMPONEN UI HELPER ---

  Widget _buildWeightIndicator(double total, bool isDone) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("Akumulasi Bobot CPMK", style: TextStyle(fontWeight: FontWeight.w600)),
              Text("${total.toInt()}% / 100%", 
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: isDone ? Colors.green : Colors.red)),
            ],
          ),
          const SizedBox(height: 10),
          LinearProgressIndicator(
            value: total / 100,
            backgroundColor: Colors.grey.shade200,
            valueColor: AlwaysStoppedAnimation<Color>(isDone ? Colors.green : Colors.orange),
            minHeight: 8,
            borderRadius: BorderRadius.circular(10),
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

  Widget _buildCpmkInput() {
    return TextField(
      controller: _cpmkController,
      maxLines: 4,
      decoration: InputDecoration(
        hintText: "Contoh: Mahasiswa mampu mendemonstrasikan algoritma pemrograman...",
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide(color: Colors.grey.shade300)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide(color: Colors.grey.shade200)),
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
      child: Column(
        children: [
          CheckboxListTile(
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
              padding: const EdgeInsets.fromLTRB(15, 0, 15, 15),
              child: TextField(
                controller: _weightControllers[cplId],
                keyboardType: TextInputType.number,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.percent, size: 16),
                  labelText: "Bobot (%)",
                  filled: true,
                  fillColor: Colors.grey.shade50,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade300)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade200)),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSubmitButton(bool isDone) {
    return SizedBox(
      width: double.infinity,
      height: 55,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: isDone ? Colors.green : Colors.grey,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          elevation: isDone ? 3 : 0,
        ),
        onPressed: isLoading ? null : _simpanMapping,
        child: Text(
          isLoading ? "PROSES MENYIMPAN..." : "SIMPAN MAPPING OBE",
          style: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1),
        ),
      ),
    );
  }
}