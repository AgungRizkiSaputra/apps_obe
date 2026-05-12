import 'package:flutter/material.dart';
import '../../services/rps_service.dart';

class ManageDosenPage extends StatefulWidget {
  const ManageDosenPage({super.key});

  @override
  State<ManageDosenPage> createState() => _ManageDosenPageState();
}

class _ManageDosenPageState extends State<ManageDosenPage> {
  final rpsService = RpsService();
  String _searchQuery = "";

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: const Text("Data Dosen Pengampu"),
        backgroundColor: Colors.blue.shade800,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Column(
        children: [
          // Search Bar Area (Gaya Dashboard Dosen kamu)
          Container(
            padding: const EdgeInsets.fromLTRB(15, 5, 15, 20),
            decoration: BoxDecoration(
              color: Colors.blue.shade800,
              borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(25), bottomRight: Radius.circular(25)),
            ),
            child: Container(
              height: 50,
              padding: const EdgeInsets.symmetric(horizontal: 15),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(15),
                boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10)],
              ),
              child: TextField(
                onChanged: (val) => setState(() => _searchQuery = val.toLowerCase()),
                decoration: const InputDecoration(
                  hintText: "Cari Nama Dosen...",
                  border: InputBorder.none,
                  icon: Icon(Icons.search, color: Colors.blue),
                ),
              ),
            ),
          ),
          
          Expanded(
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: rpsService.getAllDosen(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) return Center(child: Text("Error: ${snapshot.error}"));

                final listDosen = snapshot.data ?? [];
                final filteredList = listDosen.where((dosen) {
                  final nama = (dosen['nama'] ?? '').toString().toLowerCase();
                  return nama.contains(_searchQuery);
                }).toList();

                if (filteredList.isEmpty) return const Center(child: Text("Dosen tidak ditemukan."));

                return ListView.builder(
                  padding: const EdgeInsets.all(15),
                  itemCount: filteredList.length,
                  itemBuilder: (context, index) {
                    final dosen = filteredList[index];
                    return Card(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                      elevation: 2,
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.blue.shade100,
                          child: const Icon(Icons.person, color: Colors.blue),
                        ),
                        title: Text(dosen['nama'] ?? 'Tanpa Nama', 
                            style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text(dosen['email'] ?? '-'),
                        trailing: const Badge(
                          label: Text("Dosen"), 
                          backgroundColor: Colors.orange,
                          padding: EdgeInsets.symmetric(horizontal: 8),
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
    );
  }
}