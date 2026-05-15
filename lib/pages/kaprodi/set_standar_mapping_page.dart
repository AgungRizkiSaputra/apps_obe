import 'package:flutter/material.dart';
import '../../services/rps_service.dart';

class SetStandarMappingPage extends StatefulWidget {
  const SetStandarMappingPage({super.key});

  @override
  State<SetStandarMappingPage> createState() => _SetStandarMappingPageState();
}

class _SetStandarMappingPageState extends State<SetStandarMappingPage> {
  final rpsService = RpsService();
  final primaryColor = Colors.indigo.shade900;
  
  List<Map<String, dynamic>> _allMk = [];
  List<String> _mkSudahSet = []; 
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  // --- LOGIKA LOAD DATA (UTUH) ---
  Future<void> _loadDashboardData() async {
    setState(() => _isLoading = true);
    try {
      final mkData = await rpsService.getAllMataKuliah();
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
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text("Standar CPL Kurikulum", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        centerTitle: true,
        elevation: 0,
      ),
      body: _isLoading 
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Header Aksen
                Container(
                  height: 20,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: primaryColor,
                    borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(30), bottomRight: Radius.circular(30)),
                  ),
                ),
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: _loadDashboardData,
                    child: ListView.builder(
                      padding: const EdgeInsets.all(20),
                      itemCount: _allMk.length,
                      itemBuilder: (context, index) {
                        final mk = _allMk[index];
                        final bool isSet = _mkSudahSet.contains(mk['id'].toString());
                        return _buildMkCard(mk, isSet);
                      },
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildMkCard(Map<String, dynamic> mk, bool isSet) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 15),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
        side: BorderSide(color: isSet ? Colors.green.shade200 : Colors.grey.shade200, width: 1.5),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        leading: CircleAvatar(
          backgroundColor: isSet ? Colors.green.shade50 : Colors.orange.shade50,
          child: Icon(
            isSet ? Icons.check_circle_rounded : Icons.info_outline_rounded,
            color: isSet ? Colors.green : Colors.orange,
          ),
        ),
        title: Text(
          mk['nama_mk'],
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 5),
          child: Text(
            isSet ? "CPL Sudah Terpasang" : "CPL Belum Ditentukan",
            style: TextStyle(
              color: isSet ? Colors.green.shade700 : Colors.orange.shade700,
              fontSize: 12,
              fontWeight: FontWeight.w500
            ),
          ),
        ),
        trailing: const Icon(Icons.chevron_right_rounded, color: Colors.grey),
        onTap: () {
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
  }
}

// --- SUB-HALAMAN: FORM UNTUK ATUR STANDAR ---
class FormMappingMk extends StatefulWidget {
  final Map<String, dynamic> mkData;
  final RpsService rpsService;

  const FormMappingMk({super.key, required this.mkData, required this.rpsService});

  @override
  State<FormMappingMk> createState() => _FormMappingMkState();
}

class _FormMappingMkState extends State<FormMappingMk> {
  final primaryColor = Colors.indigo.shade900;
  List<Map<String, dynamic>> _allCpl = [];
  List<String> _selectedCplIds = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCplData();
  }

  // --- LOGIKA LOAD CPL (UTUH) ---
  Future<void> _loadCplData() async {
    final cplData = await widget.rpsService.getAllCpl();
    final standarIds = await widget.rpsService.getStandarCplIds(widget.mkData['id'].toString());
    setState(() {
      _allCpl = cplData;
      _selectedCplIds = standarIds;
      _isLoading = false;
    });
  }

  // --- LOGIKA SAVE (UTUH) ---
  void _handleSave() async {
    setState(() => _isLoading = true);
    await widget.rpsService.saveStandarMapping(widget.mkData['id'].toString(), _selectedCplIds);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text("Berhasil Update Standar Kurikulum!"),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        )
      );
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: Text(widget.mkData['nama_mk'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        centerTitle: true,
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : Column(
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                width: double.infinity,
                color: primaryColor.withOpacity(0.05),
                child: const Text(
                  "Pilih CPL yang wajib dipenuhi oleh dosen saat membuat RPS untuk mata kuliah ini.",
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: Colors.indigo, fontStyle: FontStyle.italic),
                ),
              ),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(15),
                  itemCount: _allCpl.length,
                  itemBuilder: (context, index) {
                    final cpl = _allCpl[index];
                    final id = cpl['id'].toString();
                    final isSelected = _selectedCplIds.contains(id);
                    
                    return Card(
                      elevation: 0,
                      margin: const EdgeInsets.only(bottom: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                        side: BorderSide(color: isSelected ? primaryColor : Colors.grey.shade200),
                      ),
                      child: CheckboxListTile(
                        activeColor: primaryColor,
                        title: Text(cpl['kode_cpl'], style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text(cpl['deskripsi'], style: const TextStyle(fontSize: 12)),
                        value: isSelected,
                        onChanged: (val) {
                          setState(() {
                            val == true ? _selectedCplIds.add(id) : _selectedCplIds.remove(id);
                          });
                        },
                      ),
                    );
                  },
                ),
              ),
              _buildBottomButton(),
            ],
          ),
    );
  }

  Widget _buildBottomButton() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10, offset: const Offset(0, -5))],
      ),
      child: SizedBox(
        width: double.infinity,
        height: 55,
        child: ElevatedButton(
          onPressed: _handleSave,
          style: ElevatedButton.styleFrom(
            backgroundColor: primaryColor, 
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: const Text("SIMPAN STANDAR KURIKULUM", style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1)),
        ),
      ),
    );
  }
}