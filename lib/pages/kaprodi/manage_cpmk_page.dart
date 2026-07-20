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
  String? _selectedCplId; 
  List<Map<String, dynamic>> _listMataKuliah = [];
  List<Map<String, dynamic>> _listCpl = []; 

  Future<List<Map<String, dynamic>>>? _cpmkFuture;
  bool _isSaving = false;
  String? _filterMkId;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
    _initCpmkData();
  }

  void _initCpmkData() {
    _cpmkFuture = () async {
      final response = await rpsService.supabase
          .from('cpmk')
          .select('*, mata_kuliah(nama_mk), cpl(kode_cpl)')
          .filter('rps_id', 'is', null) 
          .order('kode_cpmk', ascending: true);
      return List<Map<String, dynamic>>.from(response);
    }();
  }

  Future<void> _loadInitialData() async {
    try {
      final mkData = await rpsService.getAllMataKuliah();
      final cplData = await rpsService.getAllCpl();
      setState(() {
        _listMataKuliah = mkData;
        _listCpl = cplData;
      });
    } catch (e) {
      debugPrint("Gagal load initial data: $e");
    }
  }

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
    if (_selectedCplId == null) {
      _showWarning("Silakan pilih induk CPL Prodi Berelasi!");
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
    _selectedCplId = null; // Reset default 

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

                DropdownButtonFormField<String>(
                  value: _selectedCplId,
                  hint: const Text("Pilih CPL Prodi Berelasi"),
                  isExpanded: true,
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.star_outline_rounded, size: 20, color: primaryColor),
                    filled: true,
                    fillColor: Colors.grey.shade50,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
                  ),
                  items: _listCpl.map((cpl) {
                    return DropdownMenuItem<String>(
                      value: cpl['id'].toString(),
                      child: Text("${cpl['kode_cpl']} - ${cpl['deskripsi']}", overflow: TextOverflow.ellipsis),
                    );
                  }).toList(),
                  onChanged: (val) => setDialogState(() => _selectedCplId = val),
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
                    'cpl_id': _selectedCplId!, 
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

  void _showEditDialog(Map<String, dynamic> cpmk) {
    final editKodeController = TextEditingController(text: cpmk['kode_cpmk']);
    final editDeskripsiController = TextEditingController(text: cpmk['deskripsi']);
    String? editSelectedMkId = cpmk['mata_kuliah_id']?.toString();
    String? editSelectedCplId = cpmk['cpl_id']?.toString(); 
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

                DropdownButtonFormField<String>(
                  value: editSelectedCplId,
                  hint: const Text("Pilih CPL Prodi Berelasi"),
                  isExpanded: true,
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.star_outline_rounded, size: 20, color: primaryColor),
                    filled: true,
                    fillColor: Colors.grey.shade50,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  items: _listCpl.map((cpl) {
                    return DropdownMenuItem<String>(
                      value: cpl['id'].toString(),
                      child: Text("${cpl['kode_cpl']} - ${cpl['deskripsi']}", overflow: TextOverflow.ellipsis),
                    );
                  }).toList(),
                  onChanged: (val) => setDialogState(() => editSelectedCplId = val),
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
                if (editKodeController.text.trim().isEmpty || editDeskripsiController.text.trim().isEmpty || editSelectedMkId == null || editSelectedCplId == null) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Semua kolom termasuk CPL wajib diisi!"), backgroundColor: Colors.orange));
                  return;
                }

                setDialogState(() => _isSaving = true);
                setState(() => _isSaving = true);

                try {
                  await rpsService.updateMasterCpmk(
                    cpmkId, 
                    editKodeController.text.trim(), 
                    editDeskripsiController.text.trim(), 
                    editSelectedMkId!,
                    cplId: editSelectedCplId, 
                  );
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
          
          Padding(
            padding: const EdgeInsets.fromLTRB(15, 15, 15, 5),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(15),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))
                ],
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: DropdownButtonFormField<String>(
                value: _filterMkId,
                hint: const Text("Filter Berdasarkan Mata Kuliah", style: TextStyle(fontSize: 14, color: Colors.grey)),
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.filter_list_alt, size: 20, color: primaryColor),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(vertical: 12),
                ),
                items: [
                  const DropdownMenuItem<String>(
                    value: null,
                    child: Text("Semua Mata Kuliah (Tampilkan Semua)", style: TextStyle(fontWeight: FontWeight.bold, color: primaryColor)),
                  ),
                  ..._listMataKuliah.map((mk) {
                    return DropdownMenuItem<String>(
                      value: mk['id'].toString(),
                      child: Text(mk['nama_mk'] ?? '-', overflow: TextOverflow.ellipsis),
                    );
                  }),
                ],
                onChanged: (value) {
                  setState(() {
                    _filterMkId = value;
                  });
                },
              ),
            ),
          ),
          
          Expanded(
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: _cpmkFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
                final list = snapshot.data ?? [];
                if (list.isEmpty) return const Center(child: Text("Belum ada data master CPMK prodi."));

                final filteredList = _filterMkId == null
                    ? list
                    : list.where((element) => element['mata_kuliah_id']?.toString() == _filterMkId).toList();

                if (filteredList.isEmpty) {
                  return const Center(
                    child: Text(
                      "Tidak ada data Master CPMK untuk mata kuliah ini.",
                      style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic),
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(15),
                  itemCount: filteredList.length,
                  itemBuilder: (context, index) {
                    final cpmk = filteredList[index];
                    final String cplCode = cpmk['cpl']?['kode_cpl'] ?? 'Belum Set CPL';
                    
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
                        title: Text("${cpmk['kode_cpmk'] ?? '-'} [$cplCode] • ${cpmk['mata_kuliah']?['nama_mk'] ?? '-'}", style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(cpmk['deskripsi'] ?? '-', style: TextStyle(color: Colors.grey.shade700, fontSize: 13, height: 1.3)),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit_note_rounded, color: Colors.orange, size: 26),
                              onPressed: () => _showEditDialog(cpmk),
                            ),
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
                                      _refresh();
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