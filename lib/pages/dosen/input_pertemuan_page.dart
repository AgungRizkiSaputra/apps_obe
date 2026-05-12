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
  bool _isLoading = true;

  // List untuk menampung controller agar data tiap minggu tidak tertukar
  List<Map<String, dynamic>> _pertemuanData = [];

  @override
  void initState() {
    super.initState();
    _initData();
  }

  Future<void> _initData() async {
    try {
      // Ambil data yang sudah ada di database
      final existingData = await rpsService.getRpsDetails(widget.rpsId);
      
      setState(() {
        // Generate 14 minggu, jika ada data lama pakai data lama, jika tidak buat baru
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
          const SnackBar(content: Text("Rencana Pertemuan Berhasil Disimpan!"), backgroundColor: Colors.green),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Gagal menyimpan: $e"), backgroundColor: Colors.red),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Rencana Pertemuan (1-14)"),
        backgroundColor: Colors.blue.shade800,
        foregroundColor: Colors.white,
        actions: [
          IconButton(onPressed: _simpanSemua, icon: const Icon(Icons.save))
        ],
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : ListView.builder(
            padding: const EdgeInsets.all(10),
            itemCount: _pertemuanData.length,
            itemBuilder: (context, index) {
              final item = _pertemuanData[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 10),
                child: ExpansionTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.blue.shade800,
                    child: Text("${item['minggu_ke']}", style: const TextStyle(color: Colors.white)),
                  ),
                  title: Text("Minggu Ke-${item['minggu_ke']}"),
                  subtitle: Text(item['materi_controller'].text.isEmpty 
                    ? "Belum diisi" 
                    : "Materi: ${item['materi_controller'].text}",
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(15.0),
                      child: Column(
                        children: [
                          TextField(
                            controller: item['materi_controller'],
                            decoration: const InputDecoration(labelText: "Kemampuan Akhir / Materi", border: OutlineInputBorder()),
                            maxLines: 2,
                          ),
                          const SizedBox(height: 10),
                          TextField(
                            controller: item['metode_controller'],
                            decoration: const InputDecoration(labelText: "Metode Pembelajaran (e.g. Ceramah, Diskusi)", border: OutlineInputBorder()),
                          ),
                          const SizedBox(height: 10),
                          TextField(
                            controller: item['bobot_controller'],
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(labelText: "Bobot Nilai (%)", border: OutlineInputBorder()),
                          ),
                        ],
                      ),
                    )
                  ],
                ),
              );
            },
          ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(10.0),
        child: ElevatedButton.icon(
          onPressed: _simpanSemua,
          icon: const Icon(Icons.save, color: Colors.white),
          label: const Text("SIMPAN RENCANA PERTEMUAN", style: TextStyle(color: Colors.white)),
          style: ElevatedButton.styleFrom(backgroundColor: Colors.green, padding: const EdgeInsets.symmetric(vertical: 15)),
        ),
      ),
    );
  }
}