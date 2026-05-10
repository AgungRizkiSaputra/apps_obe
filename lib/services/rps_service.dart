import 'package:supabase_flutter/supabase_flutter.dart';

class RpsService {
  final supabase = Supabase.instance.client;

  // 1. Ambil daftar RPS untuk Dosen
  Future<List<Map<String, dynamic>>> getRpsByDosen(String dosenId) async {
    try {
      final response = await supabase
          .from('rps')
          .select('*, mata_kuliah(nama_mk, kode_mk, sks)') 
          .eq('dosen_id', dosenId)
          .order('created_at', ascending: false);
      
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      throw 'Gagal mengambil data RPS: $e';
    }
  }

  // 2. Ambil daftar RPS untuk Kaprodi 
  // Di rps_service.dart
Future<List<Map<String, dynamic>>> getRpsForKaprodi() async {
  try {
    final response = await supabase
        .from('rps')
        .select('*, mata_kuliah(nama_mk), users(nama)') 
        .neq('status', 'draft') 
        // Urutkan berdasarkan status secara manual di aplikasi atau 
        // urutkan berdasarkan created_at terbaru
        .order('created_at', ascending: false);
    
    // Tips: Kamu bisa sortir di Flutter agar 'waiting_approval' selalu di index 0
    List<Map<String, dynamic>> list = List<Map<String, dynamic>>.from(response);
    list.sort((a, b) {
      if (a['status'].contains('waiting') && !b['status'].contains('waiting')) return -1;
      if (!a['status'].contains('waiting') && b['status'].contains('waiting')) return 1;
      return 0;
    });
    
    return list;
  } catch (e) {
    throw 'Gagal mengambil data review: $e';
  }
}

  // 3. Logika Buat RPS Baru 
  Future<Map<String, dynamic>> createRps({
    required String mkId,
    required String dosenId,
    required String tahunAjaran,
    required String semester,
  }) async {
    try {
      final response = await supabase.from('rps').insert({
        'mata_kuliah_id': mkId,
        'dosen_id': dosenId,
        'tahun_ajaran': tahunAjaran,
        'semester': semester,
        'status': 'draft', 
      }).select('*, mata_kuliah(nama_mk)').single();

      return response;
    } catch (e) {
      throw 'Gagal membuat RPS baru: $e';
    }
  }

  // 4. Update Status 
  Future<void> updateStatusRps(String rpsId, String statusBaru, {String? catatan}) async {
    try {
      String statusFinal = statusBaru;
      
      if (statusBaru == 'waiting_approval') {
        final currentData = await supabase.from('rps').select('status').eq('id', rpsId).single();
        if (currentData['status'] == 'revisi_selesai') {
          statusFinal = 'waiting_approval_revision';
        }
      }

      final Map<String, dynamic> updateData = {'status': statusFinal};
      if (catatan != null) updateData['catatan'] = catatan;

      await supabase.from('rps').update(updateData).eq('id', rpsId);
    } catch (e) {
      throw 'Gagal memperbarui status: $e';
    }
  }

  // 5. Fungsi untuk menyimpan CPMK dan Mapping CPL-nya
  Future<void> saveMapping({
    required String rpsId,
    required String deskripsi, 
    required List<String> selectedCplIds,
  }) async {
    try {
      final cpmkResponse = await supabase.from('cpmk').insert({
        'rps_id': rpsId,
        'deskripsi': deskripsi, 
      }).select().single();

      final String cpmkId = cpmkResponse['id'];

      final List<Map<String, dynamic>> mappingData = selectedCplIds.map((cplId) => {
        'rps_id': rpsId,
        'cpmk_id': cpmkId,
        'cpl_id': cplId,
      }).toList();

      await supabase.from('mapping_cpl_cpmk').insert(mappingData);
    } catch (e) {
      throw 'Gagal menyimpan mapping: $e';
    }
  }

  // 6. Ambil detail lengkap 1 RPS (Termasuk CPMK dan CPL-nya)
  Future<Map<String, dynamic>> getRpsDetail(String rpsId) async {
    try {
      final response = await supabase
          .from('rps')
          .select('''
            *, 
            mata_kuliah(*), 
            users(nama), 
            cpmk(
              *,
              mapping_cpl_cpmk(
                cpl(kode_cpl, deskripsi)
              )
            )
          ''') 
          .eq('id', rpsId)
          .single();
      return response;
    } catch (e) {
      throw 'Gagal mengambil detail RPS: $e';
    }
  }

  // 7. Fungsi untuk menghapus mapping lama
  Future<void> deleteExistingMapping(String rpsId) async {
    try {
      await supabase.from('mapping_cpl_cpmk').delete().eq('rps_id', rpsId);
      await supabase.from('cpmk').delete().eq('rps_id', rpsId);
    } catch (e) {
      throw 'Gagal membersihkan data lama: $e';
    }
  }

  // 8. Tandai Revisi Selesai
  Future<void> tandaiRevisiSelesai(String rpsId) async {
    try {
      await supabase
          .from('rps')
          .update({'status': 'revisi_selesai'})
          .eq('id', rpsId);
    } catch (e) {
      throw 'Gagal memperbarui status revisi: $e';
    }
  }

  // 9. Fungsi untuk menghapus RPS secara tunggal
  Future<void> deleteRps(String rpsId) async {
    try {
      await supabase.from('mapping_cpl_cpmk').delete().eq('rps_id', rpsId);
      await supabase.from('cpmk').delete().eq('rps_id', rpsId);
      await supabase.from('rps').delete().eq('id', rpsId);
    } catch (e) {
      throw 'Gagal menghapus RPS: $e';
    }
  }

  // 10. Fungsi hapus massal
    Future<void> deleteMultipleRps(List<String> rpsIds) async {
    try {
      // Karena sudah pakai ON DELETE CASCADE di SQL tadi, 
      // cukup hapus di tabel rps saja.
      await supabase.from('rps').delete().inFilter('id', rpsIds);
    } catch (e) {
      print("Detail Error: $e");
      throw 'Database menolak penghapusan: $e';
    }
  }

  // --- MANAJEMEN MATA KULIAH ---
  
  // 11. Ambil semua daftar MK
  Future<List<Map<String, dynamic>>> getAllMataKuliah() async {
    final response = await supabase
        .from('mata_kuliah')
        .select('*')
        .order('nama_mk', ascending: true);
    return List<Map<String, dynamic>>.from(response);
  }

  // Tambah MK Baru
  Future<void> addMataKuliah(String kode, String nama, int sks, int semester) async {
    await supabase.from('mata_kuliah').insert({
      'kode_mk': kode,
      'nama_mk': nama,
      'sks': sks,
      'semester': semester,
    });
  }

  // Edit Mata Kuliah
  Future<void> updateMataKuliah(dynamic id, String kode, String nama, int sks, int semester) async {
    await supabase.from('mata_kuliah').update({
      'kode_mk': kode,
      'nama_mk': nama,
      'sks': sks,
      'semester': semester,
    }).eq('id', id);
  }

  // Hapus Mata Kuliah
  Future<void> deleteMataKuliah(dynamic id) async {
    try {
      await supabase.from('mata_kuliah').delete().eq('id', id);
    } catch (e) {
      throw 'Database menolak: $e';
    }
  }

  // --- MANAJEMEN CPL ---
  
  // 12. Ambil semua daftar CPL untuk Kaprodi
  Future<List<Map<String, dynamic>>> getAllCpl() async {
    try {
      final response = await supabase
          .from('cpl')
          .select('*')
          .order('kode_cpl', ascending: true);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      throw 'Gagal mengambil data CPL: $e';
    }
  }

  // Tambah CPL Baru
  Future<void> addCpl(String kode, String deskripsi) async {
    try {
      await supabase.from('cpl').insert({
        'kode_cpl': kode,
        'deskripsi': deskripsi,
      });
    } catch (e) {
      throw 'Gagal menambah CPL: $e';
    }
  }

  // Edit CPL
  Future<void> updateCpl(dynamic id, String kode, String deskripsi) async {
    await supabase.from('cpl').update({
      'kode_cpl': kode,
      'deskripsi': deskripsi,
    }).eq('id', id);
  }

  // Hapus CPL Berdasarkan ID
  Future<void> deleteCpl(dynamic id) async {
    try {
      await supabase.from('cpl').delete().eq('id', id);
    } catch (e) {
      throw 'Gagal menghapus CPL: $e';
    }
  }

  // 13. Fungsi untuk mengambil statistik dashboard Kaprodi
  Future<Map<String, int>> getKaprodiStats() async {
    try {
      final rpsPending = await supabase
          .from('rps')
          .select()
          .or('status.eq.waiting_approval,status.eq.waiting_approval_revision');

      final totalMk = await supabase.from('mata_kuliah').select();
      final totalCpl = await supabase.from('cpl').select();

      return {
        'pending': rpsPending.length,
        'mk': totalMk.length,
        'cpl': totalCpl.length,
      };
    } catch (e) {
      return {'pending': 0, 'mk': 0, 'cpl': 0};
    }
  }

  // 14. Ambil Data Semua Dosen
  Future<List<Map<String, dynamic>>> getAllDosen() async {
    try {
      final response = await supabase
          .from('users')
          .select('*')
          .eq('role', 'dosen')
          .order('nama', ascending: true);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      throw 'Gagal mengambil data dosen: $e';
    }
  }

  // 15. Simpan standar mapping CPL untuk satu Mata Kuliah
  Future<void> saveStandarMapping(String mkId, List<String> selectedCplIds) async {
    try {
      // Hapus standar lama dulu biar nggak numpuk
      await supabase.from('standar_mapping_mk').delete().eq('mk_id', mkId);
      
      if (selectedCplIds.isNotEmpty) {
        final data = selectedCplIds.map((cplId) => {
          'mk_id': mkId,
          'cpl_id': cplId,
        }).toList();
        await supabase.from('standar_mapping_mk').insert(data);
      }
    } catch (e) {
      throw 'Gagal simpan standar mapping: $e';
    }
  }

  // 16. Ambil daftar CPL yang sudah jadi standar untuk suatu MK
  Future<List<String>> getStandarCplIds(String mkId) async {
    try {
      final response = await supabase
          .from('standar_mapping_mk')
          .select('cpl_id')
          .eq('mk_id', mkId);

      // Kita ganti logika pengecekannya biar VS Code nggak komplain "Dead Code"
      final List data = response as List? ?? [];
      
      return data.map((item) => item['cpl_id'].toString()).toList();
    } catch (e) {
      // Ganti debugPrint jadi print biasa
      print("Error getStandarCplIds: $e");
      return []; // Jika error, kembalikan list kosong
    }
  }

  // 17. Fungsi untuk mengambil detail mapping (CPMK & CPL) khusus untuk Cetak PDF
  Future<List<Map<String, dynamic>>> getMappingFullForPdf(String rpsId) async {
    try {
      // Kita ambil data dari tabel cpmk yang rps_id-nya cocok
      // Kita juga join ke tabel mapping dan cpl biar dapet KODE CPL-nya
      final response = await supabase
          .from('cpmk')
          .select('''
            id,
            deskripsi,
            mapping_cpl_cpmk (
              cpl (
                kode_cpl
              )
            )
          ''')
          .eq('rps_id', rpsId);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print("Error ambil data PDF: $e");
      return [];
    }
  }
}