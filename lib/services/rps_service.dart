import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:typed_data';

class RpsService {
  final supabase = Supabase.instance.client;

  // 1. Ambil daftar RPS untuk Dosen
  Future<List<Map<String, dynamic>>> getRpsByDosen(String dosenId) async {
    final response = await supabase
        .from('rps')
        .select('''
          *,
          mata_kuliah (nama_mk, kode_mk, sks),
          users (nama, signature_url) 
        ''')
        .eq('dosen_id', dosenId)
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(response);
  }

  // 2. Ambil daftar RPS untuk Kaprodi 
  Future<List<Map<String, dynamic>>> getRpsForKaprodi() async {
    try {
      final response = await supabase
          .from('rps')
          .select('*, mata_kuliah(nama_mk), users(nama)') 
          .neq('status', 'draft') 
          .order('created_at', ascending: false);
      
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

  // 3. Logika Buat RPS Baru (AUTOMATION UPDATE: OTOMATIS MENGUNCI BOBOT PENILAIAN KOMPONEN 100%)
  Future<Map<String, dynamic>> createRps({
    required String mkId,
    required String dosenId,
    required String tahunAjaran,
    required String semester,
    String? bahanKajian,
    String? metodePembelajaran,
    String? daftarReferensi,    
    String? mkPrasyarat,        
    String? ambangBatas,        
  }) async {
    try {
      // --- NILAI STANDAR BAKU KOMPONEN PENILAIAN KAMPUS (OTOMATIS DIKUNCI 100%) ---
      const String penilaianStandarKampus = 
          "Partisipasi (Kehadiran): 10% | Unjuk Kerja (Perilaku): 5% | Observasi (Tugas Mandiri/Kelompok): 20% | Tes Lisan (Formatif/Kuis): 10% | Tes Tulis (UTS): 25% | Tes Tulis (UAS): 30% (Total Akumulasi: 100%)";

      final response = await supabase.from('rps').insert({
        'mata_kuliah_id': mkId,
        'dosen_id': dosenId,
        'tahun_ajaran': tahunAjaran,
        'semester': semester,
        'bahan_kajian': bahanKajian,
        'metode_pembelajaran': metodePembelajaran, 
        'daftar_referensi': daftarReferensi,       
        'mk_prasyarat': mkPrasyarat,               
        'ambang_batas': ambangBatas,               
        'penilaian': penilaianStandarKampus, // --- OTOMATIS MASUK KE KOLOM BARU SUPABASE ---
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

  // 5. Fungsi untuk menyimpan CPMK dan Mapping CPL-nya (Legacy)
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
                bobot, 
                cpl(kode_cpl, deskripsi)
              )
            ),
            rps_detail(*) 
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
        await supabase.from('cpmk').delete().eq('rps_id', rpsId);
        print("Data mapping OBE berhasil dibersihkan otomatis oleh Database.");
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
      await supabase.from('rps').delete().inFilter('id', rpsIds);
    } catch (e) {
      print("Detail Error: $e");
      throw 'Database menolak penghapusan: $e';
    }
  }

  // 11. Ambil semua daftar MK
  Future<List<Map<String, dynamic>>> getAllMataKuliah() async {
    try {
      final response = await supabase
          .from('mata_kuliah')
          .select('*')
          .order('nama_mk', ascending: true);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      throw 'Gagal mengambil data MK: $e';
    }
  }

  // Tambah MK Baru
  Future<void> addMataKuliah(String kode, String nama, int sks, int semester) async {
    try {
      await supabase.from('mata_kuliah').insert({
        'kode_mk': kode,
        'nama_mk': nama,
        'sks': sks,
        'semester': semester,
      });
    } catch (e) {
      throw 'Gagal menambah MK: $e';
    }
  }

  // Edit Mata Kuliah
  Future<void> updateMataKuliah(String id, String kode, String nama, int sks, int semester) async {
    try {
      await supabase.from('mata_kuliah').update({
        'kode_mk': kode,
        'nama_mk': nama,
        'sks': sks,
        'semester': semester,
      }).eq('id', id);
    } catch (e) {
      throw 'Gagal memperbarui MK: $e';
    }
  }

  // Hapus Mata Kuliah
  Future<void> deleteMataKuliah(String id) async {
    try {
      await supabase.from('mata_kuliah').delete().eq('id', id);
    } catch (e) {
      throw 'Tidak bisa menghapus MK ini karena sudah digunakan dalam data RPS.';
    }
  }

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
  Future<void> deleteCpl(String id) async {
    try {
      await supabase.from('cpl').delete().eq('id', id);
    } catch (e) {
      throw 'CPL tidak bisa dihapus karena sudah digunakan dalam mapping RPS Dosen.';
    }
  }

  // 13. Fungsi untuk mengambil statistik dashboard Kaprodi
  Future<Map<String, dynamic>> getKaprodiStats() async {
    try {
      final rpsResponse = await supabase.from('rps').select('status');
      final mkResponse = await supabase.from('mata_kuliah').select();
      final cplResponse = await supabase.from('cpl').select();

      final List allRps = List.from(rpsResponse);
      final List allMk = List.from(mkResponse);
      final List allCpl = List.from(cplResponse);

      return {
        'pending': allRps.where((r) => r['status'].toString().contains('waiting')).length,
        'approved': allRps.where((r) => r['status'] == 'approved').length,
        'revisi': allRps.where((r) => r['status'] == 'revisi' || r['status'] == 'revisi_selesai').length,
        'mk': allMk.length,
        'cpl': allCpl.length,
      };
    } catch (e) {
      print("Error Stats: $e");
      return {'pending': 0, 'approved': 0, 'revisi': 0, 'mk': 0, 'cpl': 0};
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
      final List data = response as List? ?? [];
      return data.map((item) => item['cpl_id'].toString()).toList();
    } catch (e) {
      print("Error getStandarCplIds: $e");
      return [];
    }
  }

  // 17. Fungsi untuk mengambil detail mapping (CPMK & CPL) khusus untuk Cetak PDF
  Future<List<Map<String, dynamic>>> getMappingFullForPdf(String rpsId) async {
    final res = await supabase.from('cpmk').select('''
        id, 
        deskripsi,
        mapping_cpl_cpmk ( 
          bobot, 
          cpl ( kode_cpl, deskripsi ) 
        )
      ''').eq('rps_id', rpsId);
    return List<Map<String, dynamic>>.from(res);
  }

  // 18. Fungsi untuk upload tanda tangan dan update profil user
  Future<String> uploadSignature(String userId, Uint8List imageBytes) async {
    try {
      final fileName = 'sig_$userId.png';
      await supabase.storage.from('signatures').uploadBinary(
            fileName,
            imageBytes,
            fileOptions: const FileOptions(upsert: true, contentType: 'image/png'),
          );
      final imageUrl = supabase.storage.from('signatures').getPublicUrl(fileName);
      await supabase.from('users').update({'signature_url': imageUrl}).eq('id', userId);
      return imageUrl;
    } catch (e) {
      throw "Gagal simpan tanda tangan: $e";
    }
  }

  // 19. Fungsi untuk update profil (Nama)
  Future<void> updateProfile(String userId, String newName) async {
    try {
      await supabase.auth.updateUser(UserAttributes(data: {'nama': newName}));
      await supabase.from('users').update({'nama': newName}).eq('id', userId);
    } catch (e) {
      throw "Gagal update profil: $e";
    }
  }

  // 20. Fungsi untuk ganti password
  Future<void> changePassword(String newPassword) async {
    try {
      await supabase.auth.updateUser(UserAttributes(password: newPassword));
    } catch (e) {
      throw "Gagal ganti password: $e";
    }
  }

  // 21. Fungsi untuk upload foto profil
  Future<String> uploadAvatar(String userId, Uint8List bytes, String extension) async {
    try {
      final fileName = 'avatar_$userId.$extension';
      await supabase.storage.from('avatars').uploadBinary(
            fileName,
            bytes,
            fileOptions: FileOptions(upsert: true, contentType: 'image/$extension'),
          );
      final imageUrl = supabase.storage.from('avatars').getPublicUrl(fileName);
      await supabase.auth.updateUser(UserAttributes(data: {'avatar_url': imageUrl}));
      return imageUrl;
    } catch (e) {
      throw "Gagal upload foto profil: $e";
    }
  }

  // 22. Simpan atau Update Detail Pertemuan
  Future<void> saveRpsDetail(List<Map<String, dynamic>> details) async {
    try {
      for (var item in details) {
        if (item['materi'].toString().trim().isEmpty || item['kemampuan_akhir'].toString().trim().isEmpty) {
          throw "Materi atau Kemampuan Akhir pada Minggu ke-${item['minggu_ke']} tidak boleh kosong!";
        }
      }
      await supabase.from('rps_detail').upsert(details, onConflict: 'rps_id, minggu_ke');
    } catch (e) {
      throw e.toString();
    }
  }

  // Ambil Detail Pertemuan berdasarkan rps_id
  Future<List<Map<String, dynamic>>> getRpsDetails(String rpsId) async {
    final res = await supabase
        .from('rps_detail')
        .select('*')
        .eq('rps_id', rpsId)
        .order('minggu_ke', ascending: true);
    return List<Map<String, dynamic>>.from(res);
  }

  // Fungsi hapus dosen
  Future<void> deleteDosen(String dosenId) async {
    try {
      await supabase.rpc(
        'soft_delete_dosen_by_id',
        params: {'dosen_id_input': dosenId},
      );
      
    } catch (e) {
      throw 'Gagal menghapus data dosen melalui sistem: $e';
    }
  }

  // 23. --- MAPPING CPMK & CPL DENGAN BOBOT ---
  Future<void> saveMappingWithWeights({
    required String rpsId,
    required String deskripsi,
    required List<Map<String, dynamic>> mappingData,
  }) async {
    try {
      final cpmkResponse = await supabase
          .from('cpmk')
          .insert({'rps_id': rpsId, 'deskripsi': deskripsi})
          .select().single();

      final String newCpmkId = cpmkResponse['id'].toString();

      final List<Map<String, dynamic>> finalMapping = mappingData.map((item) {
        return {
          'cpmk_id': newCpmkId,
          'cpl_id': item['cpl_id'],
          'bobot': item['bobot'], 
        };
      }).toList();

      await supabase.from('mapping_cpl_cpmk').insert(finalMapping);
    } catch (e) {
      throw 'Gagal menyimpan mapping OBE: $e';
    }
  }

  // 24. Tambahan: Fungsi dengan penamaan sesuai permintaan sebelumnya
  Future<void> saveRencanaPertemuan(List<Map<String, dynamic>> dataPertemuan) async {
    try {
      await supabase.from('rps_detail').upsert(dataPertemuan, onConflict: 'rps_id, minggu_ke');
    } catch (e) {
      throw 'Gagal memperbarui rencana: $e';
    }
  }

  // 25. Fungsi untuk menambahkan dosen baru (Admin)
  Future<void> tambahDosenBaru({
    required String email,
    required String password,
    required String nama,
  }) async {
    try {
      final AuthResponse res = await supabase.auth.signUp(
        email: email,
        password: password,
        data: {
          'nama': nama,
          'role': 'dosen',
        },
      );

      if (res.user != null) {
        await supabase.from('users').insert({
          'id': res.user!.id,
          'email': email,
          'nama': nama,
          'role': 'dosen',
        });
      }
    } catch (e) {
      throw 'Gagal mendaftarkan dosen: $e';
    }
  }
}