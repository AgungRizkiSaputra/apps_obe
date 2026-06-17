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
  
  // --- KOREKSI TOTAL ANTI LAYAR MERAH: Mengubah deklarasi nullable tanpa kata kunci 'late' ---
  Future<List<Map<String, dynamic>>>? _cpmkFuture;
  
  // --- FITUR TAMBAHAN PROTEKSI: Mencegah trigger klik ganda pada sistem web ---
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadMataKuliah();
    _initCpmkData(); // Inisialisasi kueri pertama kali saat halaman dibuka gung
  }

  // --- KOREKSI POIN UTAMA EDIT/HAPUS: Mengunci fungsi kueri agar bisa dipanggil ulang pasca transaksi ---
  void _initCpmkData() {
    _cpmkFuture = () async {
      final response = await rpsService.supabase
          .from('cpmk')
          .select('*, mata_kuliah(nama_mk)')
          .filter('rps_id', 'is', null) // Memastikan hanya menampilkan standar kurikulum dari Kaprodi
          .order('kode_cpmk', ascending: true);
      return List<Map<String, dynamic>>.from(response);
    }();
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

  // Pembaruan fungsi refresh agar memaksa FutureBuilder menembak ulang Supabase secara bersih gung
  void _refresh() {
    setState(() {
      _initCpmkData();
    });
  }

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
              onPressed: _isSaving ? null : () async {
                if (!_isValid()) return;
                
                setDialogState(() => _isSaving = true);
                setState(() => _isSaving = true);

                try {
                  await rpsService.supabase.from('cpmk').insert({
                    'kode_cpmk': _kodeController.text.trim(),
                    'deskripsi': _deskripsiController.text.trim(),
                    'mata_kuliah_id': _selectedMkId!,
                    'rps_id': null 
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

  // --- FITUR EDIT MODAL MASTER CPMK KAPRODI ---
  void _showEditDialog(Map<String, dynamic> cpmk) {
    final editKodeController = TextEditingController(text: cpmk['kode_cpmk']);
    final editDeskripsiController = TextEditingController(text: cpmk['deskripsi']);
    String? editSelectedMkId = cpmk['mata_kuliah_id']?.toString();
    final String cpmkId = cpmk['id'].toString();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text("Edit Master CPMK", style: TextStyle(fontWeight: FontWeight.bold)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  value: editSelectedMkId,
                  hint: const Text("Pilih Mata Kuliah"),
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.book, size: 20, color: primaryColor),
                    filled: true,
                    fillColor: Colors.grey.shade50,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  items: _listMataKuliah.map((mk) {
                    return DropdownMenuItem<String>(
                      value: mk['id'].toString(),
                      child: Text(mk['nama_mk'] ?? '-'),
                    );
                  }).toList(),
                  onChanged: (val) => setDialogState(() => editSelectedMkId = val),
                ),
                const SizedBox(height: 15),
                TextField(
                  controller: editKodeController,
                  decoration: InputDecoration(
                    labelText: "Kode CPMK",
                    prefixIcon: const Icon(Icons.qr_code, size: 20, color: primaryColor),
                    filled: true,
                    fillColor: Colors.grey.shade50,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 15),
                TextField(
                  controller: editDeskripsiController,
                  maxLines: 4,
                  decoration: InputDecoration(
                    labelText: "Deskripsi CPMK",
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
              style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, foregroundColor: Colors.white),
              onPressed: _isSaving ? null : () async {
                if (editKodeController.text.trim().isEmpty || editDeskripsiController.text.trim().isEmpty || editSelectedMkId == null) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Semua kolom wajib diisi!"), backgroundColor: Colors.orange));
                  return;
                }

                setDialogState(() => _isSaving = true);
                setState(() => _isSaving = true);

                try {
                  await rpsService.updateMasterCpmk(cpmkId, editKodeController.text.trim(), editDeskripsiController.text.trim(), editSelectedMkId!);
                  if (mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Berhasil memperbarui master CPMK"), backgroundColor: Colors.green, behavior: SnackBarBehavior.floating));
                    _refresh();
                  }
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Gagal: $e"), backgroundColor: Colors.red, behavior: SnackBarBehavior.floating));
                } finally {
                  setDialogState(() => _isSaving = false);
                  setState(() => _isSaving = false);
                }
              },
              child: Text(_isSaving ? "Memproses..." : "Perbarui"),
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
              // --- KOREKSI POIN SINKRONISASI: Menggunakan variabel future state terdaftar agar bisa di-refresh total ---
              future: _cpmkFuture,
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
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // --- FITUR EDIT MASTER CPMK ---
                            IconButton(
                              icon: const Icon(Icons.edit_note_rounded, color: Colors.orange, size: 26),
                              onPressed: () => _showEditDialog(cpmk),
                            ),
                            // --- FITUR HAPUS MASTER CPMK ---
                            IconButton(
                              icon: const Icon(Icons.delete_sweep_outlined, color: Colors.redAccent, size: 24),
                              onPressed: () async {
                                final confirm = await showDialog<bool>(
                                  context: context,
                                  builder: (context) => AlertDialog(
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                    title: const Text("Hapus Master CPMK?"),
                                    content: const Text("Data yang dihapus tidak bisa dikembalikan. Pastikan komponen ini tidak sedang digunakan dalam draf RPS Dosen."),
                                    actions: [
                                      TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Batal")),
                                      ElevatedButton(
                                        style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                                        onPressed: () => Navigator.pop(context, true), 
                                        child: const Text("Hapus", style: TextStyle(color: Colors.white))
                                      ),
                                    ],
                                  ),
                                );

                                if (confirm == true) {
                                  try {
                                    await rpsService.deleteMasterCpmk(cpmk['id'].toString());
                                    if (mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Master CPMK berhasil dihapus"), backgroundColor: Colors.green, behavior: SnackBarBehavior.floating));
                                      _refresh(); // Memaksa re-query instan gung
                                    }
                                  } catch (e) {
                                    if (mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Gagal: $e"), backgroundColor: Colors.red, behavior: SnackBarBehavior.floating));
                                    }
                                  }
                                }
                              },
                            ),
                          ],
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