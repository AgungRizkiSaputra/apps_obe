import 'package:flutter/material.dart';
import '../../services/rps_service.dart';

class InputPertemuanPage extends StatefulWidget {
  final String rpsId;
  const InputPertemuanPage({super.key, required this.rpsId});

  @override
  State<InputPertemuanPage> createState() => _InputPertemuanPageState();
}

class _InputPertemuanPageState extends State<InputPertemuanPage> {
  final rpsService = RpsService();
  
  // --- PENYELARASAN WARNA SOLID SESUAI LOGO (TANPA GRADASI) ---
  static const Color primaryColor = Color(0xFF007AFF);
  
  bool _isLoading = true;
  List<Map<String, dynamic>> _pertemuanData = [];

  @override
  void initState() {
    super.initState();
    _initData();
  }

  // --- LOGIKA INIT DATA (UTUH 100%) ---
  Future<void> _initData() async {
    try {
      final existingData = await rpsService.getRpsDetails(widget.rpsId);
      setState(() {
        _pertemuanData = List.generate(14, (index) {
          final mingguKe = index + 1;
          final match = existingData.firstWhere(
            (element) => element['minggu_ke'] == mingguKe,
            orElse: () => {},
          );

          return {
            'rps_id': widget.rpsId,
            'minggu_ke': mingguKe,
            'materi_controller': TextEditingController(text: match['kemampuan_akhir'] ?? ''),
            'metode_controller': TextEditingController(text: match['metode_pembelajaran'] ?? ''),
            'bobot_controller': TextEditingController(text: (match['bobot_nilai'] ?? 0).toString()),
          };
        });
        _isLoading = false;
      });
    } catch (e) {
      debugPrint("Error init data: $e");
    }
  }

  // --- LOGIKA SIMPAN (UTUH DENGAN NOTIF POLESAN) ---
  Future<void> _simpanSemua() async {
    setState(() => _isLoading = true);
    try {
      List<Map<String, dynamic>> dataToSave = _pertemuanData.map((e) {
        return {
          'rps_id': e['rps_id'],
          'minggu_ke': e['minggu_ke'],
          'kemampuan_akhir': e['materi_controller'].text,
          'metode_pembelajaran': e['metode_controller'].text,
          'bobot_nilai': int.tryParse(e['bobot_controller'].text) ?? 0,
        };
      }).toList();

      await rpsService.saveRpsDetail(dataToSave);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 10),
                Text("Rencana Pertemuan Berhasil Disimpan!"),
              ],
            ),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Gagal: $e"), backgroundColor: Colors.red, behavior: SnackBarBehavior.floating),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text("Rencana Pertemuan", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        centerTitle: true,
        elevation: 0,
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : Column(
            children: [
              // Info Banner Singkat
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                color: primaryColor,
                child: const Text(
                  "Lengkapi materi dan bobot nilai untuk Minggu 1 s/d 14",
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white70, fontSize: 11),
                ),
              ),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.fromLTRB(15, 15, 15, 80), 
                  itemCount: _pertemuanData.length,
                  itemBuilder: (context, index) {
                    final item = _pertemuanData[index];
                    return _buildPertemuanCard(item);
                  },
                ),
              ),
            ],
          ),
      bottomNavigationBar: _isLoading ? null : _buildBottomAction(),
    );
  }

  // --- UI HELPER COMPONENTS ---

  Widget _buildPertemuanCard(Map<String, dynamic> item) {
    bool hasData = item['materi_controller'].text.isNotEmpty;

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
        side: BorderSide(
          color: hasData ? primaryColor.withOpacity(0.3) : Colors.grey.shade200, 
          width: 1,
        ),
      ),
      child: ExpansionTile(
        shape: const Border(), 
        leading: CircleAvatar(
          backgroundColor: hasData ? primaryColor : Colors.grey.shade300,
          child: Text(
            "${item['minggu_ke']}", 
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)
          ),
        ),
        title: Text(
          "Minggu Ke-${item['minggu_ke']}",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: hasData ? Colors.black87 : Colors.grey,
          ),
        ),
        subtitle: Text(
          item['materi_controller'].text.isEmpty 
            ? "Ketuk untuk mengisi rencana..." 
            : item['materi_controller'].text,
          maxLines: 1, 
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 12),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: Column(
              children: [
                const Divider(height: 30),
                _buildField(
                  controller: item['materi_controller'],
                  label: "Kemampuan Akhir / Materi",
                  hint: "Masukan materi pembelajaran...",
                  icon: Icons.menu_book_rounded,
                  maxLines: 3,
                ),
                const SizedBox(height: 15),
                _buildField(
                  controller: item['metode_controller'],
                  label: "Metode Pembelajaran",
                  hint: "Contoh: Ceramah, Diskusi, Praktikum",
                  icon: Icons.psychology_rounded,
                ),
                const SizedBox(height: 15),
                _buildField(
                  controller: item['bobot_controller'],
                  label: "Bobot Nilai (%)",
                  hint: "0",
                  icon: Icons.percent_rounded,
                  isNumber: true,
                ),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    int maxLines = 1,
    bool isNumber = false,
  }) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: isNumber ? TextInputType.number : TextInputType.text,
      onChanged: (val) => setState(() {}), 
      style: const TextStyle(fontSize: 14),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, size: 20, color: primaryColor),
        filled: true,
        fillColor: Colors.grey.shade50,
        labelStyle: const TextStyle(fontSize: 13),
        contentPadding: const EdgeInsets.symmetric(vertical: 15, horizontal: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade200),
        ),
      ),
    );
  }

  Widget _buildBottomAction() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, -5))
        ],
      ),
      child: SizedBox(
        width: double.infinity,
        height: 55,
        child: ElevatedButton.icon(
          onPressed: _simpanSemua,
          icon: const Icon(Icons.save_rounded, color: Colors.white),
          label: const Text("SIMPAN SEMUA PERTEMUAN", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 1)),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green.shade600,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
            elevation: 2,
          ),
        ),
      ),
    );
  }
}