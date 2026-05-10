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

  // State untuk form
  String? selectedMkId;
  final tahunController = TextEditingController(text: "2025/2026");
  String selectedSemester = "Ganjil";
  bool isLoading = false;

  // List mata kuliah dari database
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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Gagal load MK: $e"), backgroundColor: Colors.red),
        );
      }
    }
  }

  // --- FITUR NOMOR 4: FUNGSI VALIDASI INPUT ---
  bool _isInputValid() {
    if (selectedMkId == null) {
      _showWarning("Silakan pilih Mata Kuliah terlebih dahulu!");
      return false;
    }
    if (tahunController.text.trim().isEmpty) {
      _showWarning("Tahun Ajaran tidak boleh kosong!");
      return false;
    }
    // Validasi format tahun (Harus ada garis miring, misal 2025/2026)
    if (!tahunController.text.contains('/')) {
      _showWarning("Format Tahun Ajaran salah! Gunakan format: 2025/2026");
      return false;
    }
    return true;
  }

  void _showWarning(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.orange),
    );
  }

  Future<void> _handleSimpanRps() async {
    // Jalankan validasi sebelum proses ke database
    if (!_isInputValid()) return;

    setState(() => isLoading = true);

    try {
      final userId = _supabase.auth.currentUser!.id;

      // 1. Simpan data RPS
      final result = await _rpsService.createRps(
        mkId: selectedMkId!,
        dosenId: userId,
        tahunAjaran: tahunController.text.trim(),
        semester: selectedSemester,
      );

      if (mounted) {
        // 2. Lanjut ke MappingPage
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => MappingPage(rpsData: result),
          ),
        );

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Draft Berhasil! Lanjut ke Mapping OBE."),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Gagal: $e"), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Buat RPS Baru")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Pilih Mata Kuliah", style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              isExpanded: true,
              hint: const Text("Klik untuk memilih..."),
              value: selectedMkId,
              items: listMk.map((mk) {
                return DropdownMenuItem<String>(
                  value: mk['id'].toString(),
                  child: Text(mk['nama_mk']),
                );
              }).toList(),
              onChanged: (val) => setState(() => selectedMkId = val),
              decoration: const InputDecoration(border: OutlineInputBorder()),
            ),
            const SizedBox(height: 20),

            const Text("Tahun Ajaran", style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            TextField(
              controller: tahunController,
              decoration: const InputDecoration(
                hintText: "Contoh: 2025/2026",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),

            const Text("Semester", style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: selectedSemester,
              items: ["Ganjil", "Genap"].map((s) {
                return DropdownMenuItem(value: s, child: Text(s));
              }).toList(),
              onChanged: (val) => setState(() => selectedSemester = val!),
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 40),

            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))
                ),
                onPressed: isLoading ? null : _handleSimpanRps,
                child: isLoading 
                  ? const SizedBox(
                      height: 20, 
                      width: 20, 
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
                    ) 
                  : const Text("Simpan Draft & Lanjut Mapping", style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}