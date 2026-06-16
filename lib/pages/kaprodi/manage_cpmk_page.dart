import 'package:flutter/material.dart';
import '../../services/rps_service.dart';

class ManageCpmkPage extends StatefulWidget {
  const ManageCpmkPage({super.key});

  @override
  State<ManageCpmkPage> createState() => _ManageCpmkPageState();
}

class _ManageCpmkPageState extends State<ManageCpmkPage> {
  final rpsService = RpsService();
  static const Color primaryColor = Color(0xFF00A896); // Warna Khas Kaprodi Teal Solid

  final _kodeController = TextEditingController();
  final _deskripsiController = TextEditingController();
  String? _selectedMkId;
  List<Map<String, dynamic>> _listMataKuliah = [];
  
  // --- FITUR TAMBAHAN PROTEKSI: Mencegah trigger klik ganda pada sistem web ---
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadMataKuliah();
  }

  Future<void> _loadMataKuliah() async {
    try {
      final data = await rpsService.getAllMataKuliah();
      setState(() {
        _listMataKuliah = data;
      });
    } catch (e) {
      debugPrint("Gagal load mata kuliah: $e");
    }
  }

  void _refresh() => setState(() {});

  bool _isValid() {
    if (_kodeController.text.trim().isEmpty || _deskripsiController.text.trim().isEmpty) {
      _showWarning("Kode CPMK and Deskripsi wajib diisi!");
      return false;
    }
    if (_selectedMkId == null) {
      _showWarning("Silakan pilih Mata Kuliah terlebih dahulu!");
      return false;
    }
    return true;
  }

  void _showWarning(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: Colors.orange,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  void _showAddDialog() {
    _kodeController.clear();
    _deskripsiController.clear();
    _selectedMkId = null;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text("Tambah Master CPMK", style: TextStyle(fontWeight: FontWeight.bold)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Dropdown Pilih Mata Kuliah
                DropdownButtonFormField<String>(
                  value: _selectedMkId,
                  hint: const Text("Pilih Mata Kuliah"),
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.book, size: 20, color: primaryColor),
                    filled: true,
                    fillColor: Colors.grey.shade50,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
                  ),
                  items: _listMataKuliah.map((mk) {
                    return DropdownMenuItem<String>(
                      value: mk['id'].toString(),
                      child: Text(mk['nama_mk'] ?? '-'),
                    );
                  }).toList(),
                  onChanged: (val) => setDialogState(() => _selectedMkId = val),
                ),
                const SizedBox(height: 15),
                // Input Kode CPMK
                TextField(
                  controller: _kodeController,
                  decoration: InputDecoration(
                    labelText: "Kode CPMK",
                    hintText: "Contoh: CPMK-01",
                    prefixIcon: const Icon(Icons.qr_code, size: 20, color: primaryColor),
                    filled: true,
                    fillColor: Colors.grey.shade50,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 15),
                // Input Deskripsi CPMK
                TextField(
                  controller: _deskripsiController,
                  maxLines: 4,
                  decoration: InputDecoration(
                    labelText: "Deskripsi CPMK",
                    hintText: "Tuliskan capaian pembelajaran mata kuliah...",
                    prefixIcon: const Icon(Icons.description, size: 20, color: primaryColor),
                    filled: true,
                    fillColor: Colors.grey.shade50,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text("Batal")),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: primaryColor, foregroundColor: Colors.white),
              onPressed: _isSaving ? null : () async { // Menonaktifkan tombol secara otomatis jika sistem sedang loading
                if (!_isValid()) return;
                
                setDialogState(() => _isSaving = true);
                setState(() => _isSaving = true);

                try {
                  // --- PERBAIKAN SINKRONISASI LU: Mengarahkan insert langsung ke tabel transaksi cpmk ---
                  await rpsService.supabase.from('cpmk').insert({
                    'kode_cpmk': _kodeController.text.trim(),
                    'deskripsi': _deskripsiController.text.trim(),
                    'mata_kuliah_id': _selectedMkId!,
                    'rps_id': null // Dikosongkan karena ini adalah draf standar awal dari Kaprodi
                  });

                  if (mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Berhasil menambah master CPMK"), backgroundColor: Colors.green, behavior: SnackBarBehavior.floating));
                    _refresh();
                  }
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Gagal: $e"), backgroundColor: Colors.red, behavior: SnackBarBehavior.floating));
                } finally {
                  setDialogState(() => _isSaving = false);
                  setState(() => _isSaving = false);
                }
              },
              child: Text(_isSaving ? "Menyimpan..." : "Simpan"),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text("Data Master CPMK", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        centerTitle: true,
        elevation: 0,
      ),
      body: Column(
        children: [
          Container(
            height: 20,
            decoration: const BoxDecoration(
              color: primaryColor,
              borderRadius: BorderRadius.only(bottomLeft: Radius.circular(30), bottomRight: Radius.circular(30)),
            ),
          ),
          Expanded(
            child: FutureBuilder<List<Map<String, dynamic>>>(
              // --- PERBAIKAN SINKRONISASI LU: Menembak langsung select query ke tabel cpmk dengan filter rps_id is null ---
              future: () async {
                final response = await rpsService.supabase
                    .from('cpmk')
                    .select('*, mata_kuliah(nama_mk)')
                    .filter('rps_id', 'is', null) // Memastikan hanya menampilkan standar kurikulum dari Kaprodi
                    .order('kode_cpmk', ascending: true);
                return List<Map<String, dynamic>>.from(response);
              }(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
                final list = snapshot.data ?? [];
                if (list.isEmpty) return const Center(child: Text("Belum ada data master CPMK prodi."));

                return ListView.builder(
                  padding: const EdgeInsets.all(15),
                  itemCount: list.length,
                  itemBuilder: (context, index) {
                    final cpmk = list[index];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(15),
                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.01), blurRadius: 10, offset: const Offset(0, 4))],
                        border: Border.all(color: Colors.grey.shade100),
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.all(15),
                        leading: CircleAvatar(
                          backgroundColor: primaryColor.withOpacity(0.1),
                          child: const Icon(Icons.bookmark, color: primaryColor),
                        ),
                        title: Text("${cpmk['kode_cpmk'] ?? '-'} • ${cpmk['mata_kuliah']?['nama_mk'] ?? '-'}", style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(cpmk['deskripsi'] ?? '-', style: TextStyle(color: Colors.grey.shade700, fontSize: 13, height: 1.3)),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddDialog,
        backgroundColor: primaryColor,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text("TAMBAH CPMK", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
    );
  }
}