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

  // Fungsi ambil master data MK agar dosen tinggal pilih
  Future<void> _fetchMataKuliah() async {
  try {
    final data = await _supabase.from('mata_kuliah').select();
    if (data.isNotEmpty) {
      setState(() {
        listMk = List<Map<String, dynamic>>.from(data);
      });
    }
  } catch (e) {
    // Tambahkan snackbar biar kamu tau errornya apa pas ngetes di HP/Emulator
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Gagal load MK: $e"))
    );
  }
}

  Future<void> _handleSimpanRps() async {
    if (selectedMkId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Pilih Mata Kuliah dulu!")),
      );
      return;
    }

    setState(() => isLoading = true);

    try {
      final userId = _supabase.auth.currentUser!.id;

      // 1. Simpan data RPS dan tangkap hasilnya (result)
      final result = await _rpsService.createRps(
        mkId: selectedMkId!,
        dosenId: userId,
        tahunAjaran: tahunController.text,
        semester: selectedSemester,
      );

      if (mounted) {
        // 2. Panggil MappingPage dan kirim data RPS yang baru dibuat
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => MappingPage(rpsData: result),
          ),
        );

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Draft Berhasil! Lanjut ke Mapping OBE.")),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Gagal: $e"), backgroundColor: Colors.red),
      );
    } finally {
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Buat RPS Baru")),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // Dropdown Mata Kuliah (Mengambil dari Tabel mata_kuliah)
            DropdownButtonFormField<String>(
              hint: const Text("Pilih Mata Kuliah"),
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

            TextField(
              controller: tahunController,
              decoration: const InputDecoration(
                labelText: "Tahun Ajaran",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),

            DropdownButtonFormField<String>(
              value: selectedSemester,
              items: ["Ganjil", "Genap"].map((s) {
                return DropdownMenuItem(value: s, child: Text(s));
              }).toList(),
              onChanged: (val) => setState(() => selectedSemester = val!),
              decoration: const InputDecoration(
                labelText: "Semester",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 30),

            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: isLoading ? null : _handleSimpanRps,
                child: isLoading 
                  ? const CircularProgressIndicator() 
                  : const Text("Simpan Draft & Lanjut Mapping"),
              ),
            ),
          ],
        ),
      ),
    );
  }
}