import 'package:flutter/material.dart';
import 'package:rps_obe_app/pages/dosen/mapping_page.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/rps_service.dart';

class CreateRpsPage extends StatefulWidget {
  const CreateRpsPage({super.key});

  @override
  State<CreateRpsPage> createState() => _CreateRpsPageState();
}

class _CreateRpsPageState extends State<CreateRpsPage> {
  final _rpsService = RpsService();
  final _supabase = Supabase.instance.client;
  
  // --- PENYELARASAN WARNA SOLID SESUAI LOGO (TANPA GRADASI) ---
  static const Color primaryColor = Color(0xFF007AFF);

  String? selectedMkId;
  final tahunController = TextEditingController(text: "2025/2026");
  String selectedSemester = "Ganjil";
  bool isLoading = false;
  List<Map<String, dynamic>> listMk = [];

  @override
  void initState() {
    super.initState();
    _fetchMataKuliah();
  }

  Future<void> _fetchMataKuliah() async {
    try {
      final data = await _supabase.from('mata_kuliah').select();
      if (data.isNotEmpty) {
        setState(() {
          listMk = List<Map<String, dynamic>>.from(data);
        });
      }
    } catch (e) {
      if (mounted) _showCustomNotif("Gagal load MK: $e", Colors.red);
    }
  }

  // --- LOGIKA VALIDASI (UTUH 100%) ---
  bool _isInputValid() {
    if (selectedMkId == null) {
      _showCustomNotif("Silakan pilih Mata Kuliah!", Colors.orange);
      return false;
    }
    if (tahunController.text.trim().isEmpty) {
      _showCustomNotif("Tahun Ajaran wajib diisi!", Colors.orange);
      return false;
    }
    if (!tahunController.text.contains('/')) {
      _showCustomNotif("Format Tahun salah (2025/2026)!", Colors.orange);
      return false;
    }
    return true;
  }

  // --- POLESAN NOTIFIKASI KONSISTEN (UTUH) ---
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
            Expanded(
              child: Text(
                message,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
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

  // --- LOGIKA SIMPAN (UTUH 100%) ---
  Future<void> _handleSimpanRps() async {
    if (!_isInputValid()) return;
    setState(() => isLoading = true);
    try {
      final userId = _supabase.auth.currentUser!.id;
      final result = await _rpsService.createRps(
        mkId: selectedMkId!,
        dosenId: userId,
        tahunAjaran: tahunController.text.trim(),
        semester: selectedSemester,
      );
      if (mounted) {
        _showCustomNotif("Draft Tersimpan! Membuka Mapping OBE...", Colors.green);
        
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => MappingPage(rpsData: result)),
        );
      }
    } catch (e) {
      if (mounted) _showCustomNotif("Gagal: $e", Colors.red);
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text("Buat RPS Baru", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            Container(
              height: 60,
              width: double.infinity,
              decoration: const BoxDecoration(
                color: primaryColor,
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(30),
                  bottomRight: Radius.circular(30),
                ),
              ),
            ),
            Transform.translate(
              offset: const Offset(0, -40),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Container(
                  padding: const EdgeInsets.all(25),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 15, offset: const Offset(0, 5))
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildLabel("Mata Kuliah", Icons.book_outlined),
                      const SizedBox(height: 10),
                      _buildDropdownMk(),
                      const SizedBox(height: 25),
                      _buildLabel("Tahun Ajaran", Icons.calendar_today_outlined),
                      const SizedBox(height: 10),
                      _buildTextFieldTahun(),
                      const SizedBox(height: 25),
                      _buildLabel("Semester", Icons.layers_outlined),
                      const SizedBox(height: 10),
                      _buildDropdownSemester(),
                      const SizedBox(height: 40),
                      _buildSubmitButton(),
                    ],
                  ),
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 40),
              child: Text(
                "Langkah 1: Isi data dasar RPS sebelum masuk ke pemetaan CPMK & CPL.",
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey, fontSize: 12, fontStyle: FontStyle.italic),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- UI HELPERS ---
  Widget _buildLabel(String text, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 18, color: primaryColor),
        const SizedBox(width: 8),
        Text(text, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
      ],
    );
  }

  Widget _buildDropdownMk() {
    return DropdownButtonFormField<String>(
      isExpanded: true,
      hint: const Text("Pilih Mata Kuliah"),
      value: selectedMkId,
      items: listMk.map((mk) => DropdownMenuItem<String>(value: mk['id'].toString(), child: Text(mk['nama_mk'], overflow: TextOverflow.ellipsis))).toList(),
      onChanged: (val) => setState(() => selectedMkId = val),
      decoration: InputDecoration(
        contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 15),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade200)),
        filled: true,
        fillColor: Colors.grey.shade50,
      ),
    );
  }

  Widget _buildTextFieldTahun() {
    return TextField(
      controller: tahunController,
      decoration: InputDecoration(
        hintText: "Contoh: 2025/2026",
        contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 15),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade200)),
        filled: true,
        fillColor: Colors.grey.shade50,
      ),
    );
  }

  Widget _buildDropdownSemester() {
    return DropdownButtonFormField<String>(
      value: selectedSemester,
      items: ["Ganjil", "Genap"].map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
      onChanged: (val) => setState(() => selectedSemester = val!),
      decoration: InputDecoration(
        contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 15),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade200)),
        filled: true,
        fillColor: Colors.grey.shade50,
      ),
    );
  }

  Widget _buildSubmitButton() {
    return SizedBox(
      width: double.infinity,
      height: 55,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor, 
          foregroundColor: Colors.white, 
          elevation: 2, 
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        onPressed: isLoading ? null : _handleSimpanRps,
        child: isLoading 
          ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) 
          : const Text("SIMPAN & LANJUT MAPPING", style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1)),
      ),
    );
  }
}