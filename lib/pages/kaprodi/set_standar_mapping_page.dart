import 'package:flutter/material.dart';
import '../../services/rps_service.dart';

class SetStandarMappingPage extends StatefulWidget {
  const SetStandarMappingPage({super.key});

  @override
  State<SetStandarMappingPage> createState() => _SetStandarMappingPageState();
}

class _SetStandarMappingPageState extends State<SetStandarMappingPage> {
  final rpsService = RpsService();
  
  List<Map<String, dynamic>> _allMk = [];
  List<String> _mkSudahSet = []; // Untuk melacak mana yang sudah ada standarnya
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    setState(() => _isLoading = true);
    try {
      final mkData = await rpsService.getAllMataKuliah();
      
      // Cek satu per satu MK mana yang sudah punya data di standar_mapping_mk
      List<String> sudahSet = [];
      for (var mk in mkData) {
        final standar = await rpsService.getStandarCplIds(mk['id'].toString());
        if (standar.isNotEmpty) {
          sudahSet.add(mk['id'].toString());
        }
      }

      setState(() {
        _allMk = mkData;
        _mkSudahSet = sudahSet;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint("Error: $e");
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Standar CPL Kurikulum")),
      body: _isLoading 
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadDashboardData,
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _allMk.length,
                itemBuilder: (context, index) {
                  final mk = _allMk[index];
                  final bool isSet = _mkSudahSet.contains(mk['id'].toString());

                  return Card(
                    elevation: 2,
                    margin: const EdgeInsets.only(bottom: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                      side: BorderSide(
                        color: isSet ? Colors.green.shade200 : Colors.grey.shade300,
                        width: isSet ? 1.5 : 1
                      )
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      leading: CircleAvatar(
                        backgroundColor: isSet ? Colors.green : Colors.grey.shade200,
                        child: Icon(
                          isSet ? Icons.check : Icons.priority_high,
                          color: isSet ? Colors.white : Colors.grey,
                        ),
                      ),
                      title: Text(
                        mk['nama_mk'],
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(
                        isSet ? "Standar CPL sudah diatur" : "Belum diatur (Silakan klik)",
                        style: TextStyle(
                          color: isSet ? Colors.green.shade700 : Colors.orange.shade700,
                          fontSize: 12
                        ),
                      ),
                      trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                      onTap: () {
                        // PINDAH KE FORM PENGATURAN
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => FormMappingMk(
                              mkData: mk,
                              rpsService: rpsService,
                            ),
                          ),
                        ).then((_) => _loadDashboardData());
                      },
                    ),
                  );
                },
              ),
            ),
    );
  }
}

// --- SUB-HALAMAN: FORM UNTUK ATUR STANDAR (Biar kodenya rapi dipisah) ---
class FormMappingMk extends StatefulWidget {
  final Map<String, dynamic> mkData;
  final RpsService rpsService;

  const FormMappingMk({super.key, required this.mkData, required this.rpsService});

  @override
  State<FormMappingMk> createState() => _FormMappingMkState();
}

class _FormMappingMkState extends State<FormMappingMk> {
  List<Map<String, dynamic>> _allCpl = [];
  List<String> _selectedCplIds = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCplData();
  }

  Future<void> _loadCplData() async {
    final cplData = await widget.rpsService.getAllCpl();
    final standarIds = await widget.rpsService.getStandarCplIds(widget.mkData['id'].toString());
    setState(() {
      _allCpl = cplData;
      _selectedCplIds = standarIds;
      _isLoading = false;
    });
  }

  void _handleSave() async {
    setState(() => _isLoading = true);
    await widget.rpsService.saveStandarMapping(widget.mkData['id'].toString(), _selectedCplIds);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Berhasil Update Standar!")));
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Set: ${widget.mkData['nama_mk']}")),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : Column(
            children: [
              Expanded(
                child: ListView.builder(
                  itemCount: _allCpl.length,
                  itemBuilder: (context, index) {
                    final cpl = _allCpl[index];
                    final id = cpl['id'].toString();
                    return CheckboxListTile(
                      title: Text(cpl['kode_cpl']),
                      subtitle: Text(cpl['deskripsi']),
                      value: _selectedCplIds.contains(id),
                      onChanged: (val) {
                        setState(() {
                          val == true ? _selectedCplIds.add(id) : _selectedCplIds.remove(id);
                        });
                      },
                    );
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _handleSave,
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white),
                    child: const Text("SIMPAN PERUBAHAN"),
                  ),
                ),
              )
            ],
          ),
    );
  }
}