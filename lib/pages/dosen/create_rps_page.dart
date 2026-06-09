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
  
  // --- KONTROLLER BAWAAN AWAL ---
  final bahanKajianController = TextEditingController();
  
  // --- KONTROLLER BARU TAMBAHAN UNTUK LENGKAPI FITUR POIN 1 ---
  final metodeBelajarController = TextEditingController(
    text: "Problem Based Learning (PBL), Kuliah Teori Kelas, Diskusi Kasus Kelompok, dan Praktikum Terapan Laboratorium."
  );
  final referensiController = TextEditingController(
    text: "1. Kurose, J.F. & Ross, K.W. (2022). Computer Networking: A Top-Down Approach (8th ed.). Pearson.\n2. Lammle, T. (2022). CompTIA Network+ Study Guide (5th ed.). Sybex."
  );
  final prasyaratController = TextEditingController(
    text: "KB1124 Pengantar Jaringan Komputer / Algoritma Lanjutan"
  );
  final ambangBatasController = TextEditingController(
    text: "Ambang Batas Kelulusan Minimal Mahasiswa: Skor Minimal Kelulusan 60 (Grade C)."
  );
  
  String selectedSemester = "Ganjil";
  bool isLoading = false;
  List<Map<String, dynamic>> listMk = [];

  @override
  void initState() {
    super.initState();
    _fetchMataKuliah();
  }

  // --- DISPOSE SEMUA KONTROLLER BIAR TIDAK MEMORY LEAK ---
  @override
  void dispose() {
    tahunController.dispose();
    bahanKajianController.dispose();
    metodeBelajarController.dispose();
    referensiController.dispose();
    prasyaratController.dispose();
    ambangBatasController.dispose();
    super.dispose();
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

  // --- LOGIKA VALIDASI (UTUH 100% + CHECK KELENGKAPAN FIELD BARU) ---
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
    if (bahanKajianController.text.trim().isEmpty) {
      _showCustomNotif("Bahan Kajian / Pokok Bahasan wajib diisi!", Colors.orange);
      return false;
    }
    // Validasi field tambahan biar dosen diingatkan jika sengaja dikosongkan
    if (metodeBelajarController.text.trim().isEmpty || 
        referensiController.text.trim().isEmpty || 
        ambangBatasController.text.trim().isEmpty) {
      _showCustomNotif("Lengkapi seluruh instrumen data dasar OBE!", Colors.orange);
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

  // --- LOGIKA SIMPAN (UTUH 100% & KINI MENYALURKAN EMBER DATA POIN 1 KE SERVICE) ---
  Future<void> _handleSimpanRps() async {
    if (!_isInputValid()) return;
    setState(() => isLoading = true);
    try {
      final userId = _supabase.auth.currentUser!.id;
      
      // Mengirimkan parameter data tambahan baru ke rpsService
      final result = await _rpsService.createRps(
        mkId: selectedMkId!,
        dosenId: userId,
        tahunAjaran: tahunController.text.trim(),
        semester: selectedSemester,
        bahanKajian: bahanKajianController.text.trim(),
        metodePembelajaran: metodeBelajarController.text.trim(), // --- INSTRUMEN BARU POIN 1 ---
        daftarReferensi: referensiController.text.trim(),
        mkPrasyarat: prasyaratController.text.trim(),
        ambangBatas: ambangBatasController.text.trim(),
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
                      const SizedBox(height: 25),
                      
                      _buildLabel("Bahan Kajian / Materi Pembelajaran", Icons.assignment_outlined),
                      const SizedBox(height: 10),
                      _buildTextFieldBahanKajian(),
                      const SizedBox(height: 25),

                      // --- FORM BARU 1: METODE PEMBELAJARAN ---
                      _buildLabel("Metode / Model Pembelajaran", Icons.gavel_outlined),
                      const SizedBox(height: 10),
                      _buildCustomTextField(metodeBelajarController, "Masukkan model (PBL/PjBL)...", 2),
                      const SizedBox(height: 25),

                      // --- FORM BARU 2: DAFTAR REFERENSI BUKU ---
                      _buildLabel("Daftar Referensi / Pustaka Utama", Icons.menu_book_outlined),
                      const SizedBox(height: 10),
                      _buildCustomTextField(referensiController, "1. Judul Buku Utama\n2. Judul Buku Pendukung", 3),
                      const SizedBox(height: 25),

                      // --- FORM BARU 3: MATA KULIAH PRASYARAT ---
                      _buildLabel("Mata Kuliah Prasyarat (Jika Ada)", Icons.lock_open_outlined),
                      const SizedBox(height: 10),
                      _buildCustomTextField(prasyaratController, "Contoh: Lulus Jaringan Komputer Dasar", 1),
                      const SizedBox(height: 25),

                      // --- FORM BARU 4: AMBANG BATAS KELULUSAN ---
                      _buildLabel("Ambang Batas Kelulusan Nilai", Icons.speed_outlined),
                      const SizedBox(height: 10),
                      _buildCustomTextField(ambangBatasController, "Masukkan kriteria kelulusan...", 2),
                      const SizedBox(height: 25),

                      // --- FITUR BARU POIN 2: LOCK BOBOT EVALUASI PENILAIAN 100% (READ ONLY) ---
                      _buildLabel("Komponen & Bobot Penilaian (Otomatis Terkunci prodi)", Icons.analytics_outlined),
                      const SizedBox(height: 10),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(15),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.blue.shade200),
                        ),
                        child: const Text(
                          "1. Partisipasi (Kehadiran): 10%\n"
                          "2. Unjuk Kerja (Perilaku): 5%\n"
                          "3. Observasi (Tugas Mandiri / Kelompok): 20%\n"
                          "4. Tes Lisan (Formatif / Kuis): 10%\n"
                          "5. Tes Tulis (UTS): 25%\n"
                          "6. Tes Tulis (UAS): 30%\n"
                          "Status Akumulasi: 100% MATCH (Terkunci Sesuai Aturan Mutu)",
                          style: TextStyle(fontSize: 13, color: Color(0xFF007AFF), fontWeight: FontWeight.w600, height: 1.5),
                        ),
                      ),
                      
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

  Widget _buildTextFieldBahanKajian() {
    return TextField(
      controller: bahanKajianController,
      maxLines: 4,
      keyboardType: TextInputType.multiline,
      decoration: InputDecoration(
        hintText: "Contoh:\n1. Review Arsitektur Cloud\n2. Kontainerisasi (Docker)",
        hintStyle: const TextStyle(fontSize: 13, color: Colors.grey),
        contentPadding: const EdgeInsets.all(15),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade200)),
        filled: true,
        fillColor: Colors.grey.shade50,
      ),
    );
  }

  // --- COMPONENT REUSABLE TEXTFIELD TAMBAHAN BARU UNTUK INSTRUMEN OBE ---
  Widget _buildCustomTextField(TextEditingController controller, String hint, int lines) {
    return TextField(
      controller: controller,
      maxLines: lines,
      keyboardType: lines > 1 ? TextInputType.multiline : TextInputType.text,
      style: const TextStyle(fontSize: 14),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(fontSize: 13, color: Colors.grey),
        contentPadding: const EdgeInsets.all(15),
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