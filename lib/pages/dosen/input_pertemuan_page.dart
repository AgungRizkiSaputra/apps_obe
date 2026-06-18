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

  // Pilihan Dropdown untuk Metode Pembelajaran
  final List<String> _listMetode = [
    'Ceramah',
    'Diskusi',
    'Praktikum',
    'Problem Based Learning (PBL)',
    'Project Based Learning (PjBL)',
    'Ceramah & Diskusi',
  ];

  // Pilihan Waktu Pembelajaran Baku Mutu Kampus
  final List<String> _listWaktu = [
    '50 Menit',
    '100 Menit',
    '150 Menit',
    '200 Menit',
  ];

  @override
  void initState() {
    super.initState();
    _initData();
  }

  @override
  void dispose() {
    for (var item in _pertemuanData) {
      item['materi_controller']?.dispose();
      item['bobot_controller']?.dispose();
      item['pengalaman_controller']?.dispose();
      item['indikator_controller']?.dispose();
      item['pokok_controller']?.dispose();
    }
    super.dispose();
  }

  // --- LOGIKA INIT DATA (MURNI TANPA MANIPULASI STRING - SESUAI SKEMA FISIK SUPABASE AGUNG) ---
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

          String initialMetode = match['metode_pembelajaran'] ?? 'Ceramah & Diskusi';
          if (!_listMetode.contains(initialMetode)) {
            initialMetode = 'Ceramah & Diskusi';
          }

          String initialWaktu = match['waktu'] ?? '150 Menit';
          if (!_listWaktu.contains(initialWaktu)) {
            initialWaktu = '150 Menit'; 
          }

          // Membaca bersih dari kolom fisik 'sub_cpmk' dan 'pokok_pembahasan' asli database gung
          String dbSubCpmk = match['sub_cpmk'] ?? '';
          String dbPokok = match['pokok_pembahasan'] ?? 'Pengenalan Fundamental Jaringan dan Pemetaan Topologi';

          return {
            'rps_id': widget.rpsId,
            'minggu_ke': mingguKe,
            'materi_controller': TextEditingController(text: dbSubCpmk),
            'selected_metode': initialMetode, 
            'bobot_controller': TextEditingController(text: (match['bobot_nilai'] ?? 0).toString()),
            'pengalaman_controller': TextEditingController(
              text: match['pengalaman_belajar'] ?? 'Mahasiswa menganalisis studi kasus nyata di laboratorium jaringan.'
            ),
            'indikator_controller': TextEditingController(
              text: match['indikator_penilaian'] ?? 'Ketepatan pemahaman teori & hasil demo praktik'
            ),
            'pokok_controller': TextEditingController(text: dbPokok),
            'selected_waktu': initialWaktu, 
            
            // Variabel penanda nilai default awal gung untuk kontrol warna dinamis abu-abu/hitam
            'default_materi': dbSubCpmk,
            'default_pokok': dbPokok,
            'default_pengalaman': match['pengalaman_belajar'] ?? 'Mahasiswa menganalisis studi kasus nyata di laboratorium jaringan.',
            'default_indikator': match['indikator_penilaian'] ?? 'Ketepatan pemahaman teori & hasil demo praktik',
          };
        });
        _isLoading = false;
      });
    } catch (e) {
      debugPrint("Error init data: $e");
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // --- LOGIKA SIMPAN FINAL: PAYLOAD BERSIH MENEMBAK KOLOM SUB_CPMK & POKOK_PEMBAHASAN GUNG ---
  Future<void> _simpanSemua() async {
    setState(() => _isLoading = true);
    try {
      List<Map<String, dynamic>> dataToSave = [];
      
      for (var e in _pertemuanData) {
        dataToSave.add({
          'rps_id': e['rps_id'],
          'minggu_ke': e['minggu_ke'],
          'sub_cpmk': e['materi_controller'].text, // Menembak kolom sub_cpmk asli
          'metode_pembelajaran': e['selected_metode'], 
          'bobot_nilai': int.tryParse(e['bobot_controller'].text) ?? 0,
          'pengalaman_belajar': e['pengalaman_controller'].text,
          'indikator_penilaian': e['indikator_controller'].text,
          'pokok_pembahasan': e['pokok_controller'].text, // Menembak kolom pokok_pembahasan asli
          'waktu': e['selected_waktu'], 
        });
      }

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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Gagal Menyimpan: $e"), backgroundColor: Colors.red, behavior: SnackBarBehavior.floating),
        );
      }
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
                    return _buildPertemuanCard(_pertemuanData[index]);
                  },
                ),
              ),
            ],
          ),
      bottomNavigationBar: _isLoading ? null : _buildBottomAction(),
    );
  }

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
                  hint: "Masukkan materi pembelajaran...",
                  icon: Icons.menu_book_rounded,
                  maxLines: 3,
                  isDefaultValue: item['materi_controller'].text == item['default_materi'],
                ),
                const SizedBox(height: 15),
                
                _buildField(
                  controller: item['pokok_controller'],
                  label: "Pokok Pembahasan",
                  hint: "Masukkan pokok pembahasan silabus...",
                  icon: Icons.list_alt_rounded,
                  isDefaultValue: item['pokok_controller'].text == item['default_pokok'],
                ),
                const SizedBox(height: 15),

                DropdownButtonFormField<String>(
                  value: _listMetode.contains(item['selected_metode']) ? item['selected_metode'] : _listMetode.last,
                  items: _listMetode.map((String metode) {
                    return DropdownMenuItem<String>(
                      value: metode,
                      child: Text(metode, style: const TextStyle(fontSize: 14)),
                    );
                  }).toList(),
                  onChanged: (newValue) {
                    setState(() {
                      item['selected_metode'] = newValue;
                    });
                  },
                  decoration: InputDecoration(
                    labelText: "Metode Pembelajaran",
                    prefixIcon: const Icon(Icons.psychology_rounded, size: 20, color: primaryColor),
                    filled: true,
                    fillColor: Colors.grey.shade50,
                    labelStyle: const TextStyle(fontSize: 13),
                    contentPadding: const EdgeInsets.symmetric(vertical: 15, horizontal: 12),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade200)),
                  ),
                ),
                const SizedBox(height: 15),

                DropdownButtonFormField<String>(
                  value: _listWaktu.contains(item['selected_waktu']) ? item['selected_waktu'] : _listWaktu.last,
                  items: _listWaktu.map((String waktu) {
                    return DropdownMenuItem<String>(
                      value: waktu,
                      child: Text(waktu, style: const TextStyle(fontSize: 14)),
                    );
                  }).toList(),
                  onChanged: (newValue) {
                    setState(() {
                      item['selected_waktu'] = newValue;
                    });
                  },
                  decoration: InputDecoration(
                    labelText: "Waktu Pembelajaran",
                    prefixIcon: const Icon(Icons.more_time_rounded, size: 20, color: primaryColor),
                    filled: true,
                    fillColor: Colors.grey.shade50,
                    labelStyle: const TextStyle(fontSize: 13),
                    contentPadding: const EdgeInsets.symmetric(vertical: 15, horizontal: 12),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade200)),
                  ),
                ),
                const SizedBox(height: 15),
                
                _buildField(
                  controller: item['pengalaman_controller'],
                  label: "Pengalaman Belajar Mahasiswa",
                  hint: "Aktivitas nyata mahasiswa di kelas...",
                  icon: Icons.accessibility_new_rounded,
                  maxLines: 2,
                  isDefaultValue: item['pengalaman_controller'].text == item['default_pengalaman'],
                ),
                const SizedBox(height: 15),
                _buildField(
                  controller: item['indikator_controller'],
                  label: "Indikator Penilaian Dosen",
                  hint: "Tolok ukur kriteria penilaian...",
                  icon: Icons.assignment_turned_in_rounded,
                  maxLines: 2,
                  isDefaultValue: item['indikator_controller'].text == item['default_indikator'],
                ),
                const SizedBox(height: 15),
                _buildField(
                  controller: item['bobot_controller'],
                  label: "Bobot Nilai (%)",
                  hint: "0",
                  icon: Icons.percent_rounded,
                  isNumber: true,
                  isDefaultValue: false,
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
    required bool isDefaultValue,
  }) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: isNumber ? TextInputType.number : TextInputType.text,
      onChanged: (val) {
        setState(() {}); 
      }, 
      onTap: () {
        if (isDefaultValue) {
          controller.clear();
        } else {
          controller.selection = TextSelection(
            baseOffset: 0,
            extentOffset: controller.text.length,
          );
        }
        setState(() {});
      },
      style: TextStyle(
        fontSize: 14, 
        color: isDefaultValue ? Colors.grey : Colors.black87, 
        fontWeight: isDefaultValue ? FontWeight.w500 : FontWeight.bold
      ),
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
          onPressed: _isLoading ? null : _simpanSemua,
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