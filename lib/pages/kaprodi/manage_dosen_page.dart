import 'package:flutter/material.dart';
import '../../services/rps_service.dart';

class ManageDosenPage extends StatelessWidget {
  const ManageDosenPage({super.key});

  @override
  Widget build(BuildContext context) {
    final rpsService = RpsService();
    return Scaffold(
      appBar: AppBar(title: const Text("Data Dosen")),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: rpsService.getAllDosen(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final listDosen = snapshot.data!;
          return ListView.builder(
            itemCount: listDosen.length,
            itemBuilder: (context, index) {
              final dosen = listDosen[index];
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                child: ListTile(
                  leading: const CircleAvatar(child: Icon(Icons.person)),
                  title: Text(dosen['nama'] ?? 'Tanpa Nama'),
                  subtitle: Text(dosen['email'] ?? '-'),
                  trailing: const Badge(label: Text("Dosen"), backgroundColor: Colors.orange),
                ),
              );
            },
          );
        },
      ),
    );
  }
}