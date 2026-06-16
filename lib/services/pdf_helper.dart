import 'package:http/http.dart' as http;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class PdfHelper {
  static Future<void> cetakRps(
    Map<String, dynamic> rps,
    List<Map<String, dynamic>> mapping, // Tetap dipertahankan agar tidak mengubah struktur parameter fungsi awal gung
  ) async {
    final pdf = pw.Document();
    final supabase = Supabase.instance.client;

    final listPertemuan = (rps['rps_detail'] as List?) ?? [];
    final String rpsIdReal = rps['id']?.toString() ?? '';
    final String mkId = rps['mata_kuliah_id']?.toString() ?? rps['mata_kuliah']?['id']?.toString() ?? '';

    // --- LOGIKA QUERY BACKEND & SESSION LOGIN UTUH 100% (ANTI EROR) ---
    String namaKaprodi = "Siti Maisaroh Mustafa, S.S., M.Pd.";
    String? signatureUrlKaprodi;
    try {
      final kaprodiData = await supabase.from('users').select('nama, signature_url').eq('role', 'kaprodi').maybeSingle();
      if (kaprodiData != null) {
        namaKaprodi = kaprodiData['nama'];
        signatureUrlKaprodi = kaprodiData['signature_url'];
      }
    } catch (e) {
      print("Gagal mengambil data kaprodi: $e");
    }

    String namaDosen = "Dosen Pengampu";
    String? signatureUrlDosen;
    try {
      final currentUser = supabase.auth.currentUser;
      if (currentUser != null) {
        final userData = await supabase.from('users').select('nama, signature_url').eq('id', currentUser.id).maybeSingle();
        if (userData != null) {
          namaDosen = userData['nama'] ?? 'Dosen Pengampu';
          signatureUrlDosen = userData['signature_url'];
          if (namaDosen == namaKaprodi) {
            final String? idDosenAsli = rps['dosen_id']?.toString() ?? rps['id_user']?.toString();
            if (idDosenAsli != null) {
              final realDosenData = await supabase.from('users').select('nama, signature_url').eq('id', idDosenAsli).maybeSingle();
              if (realDosenData != null) {
                namaDosen = realDosenData['nama'] ?? 'Dosen Pengampu';
                signatureUrlDosen = realDosenData['signature_url'];
              }
            }
          }
        }
      }
    } catch (e) {
      print("DEBUG: Error total signature: $e");
    }

    // --- LOGIKA DATA MASTER CPL BERDASARKAN ID DI RELASI ---
    List<Map<String, dynamic>> listCplDinamis = [];
    if (mkId.isNotEmpty) {
      try {
        final responseJoin = await supabase
            .from('standar_mapping_mk')
            .select('cpl(kode_cpl, deskripsi)')
            .eq('mk_id', mkId);

        if (responseJoin != null && responseJoin is List) {
          for (var item in responseJoin) {
            if (item['cpl'] != null) {
              listCplDinamis.add({
                'kode_cpl': item['cpl']['kode_cpl']?.toString() ?? '-',
                'deskripsi': item['cpl']['deskripsi']?.toString() ?? '-',
              });
            }
          }
          listCplDinamis.sort((a, b) => a['kode_cpl'].compareTo(b['kode_cpl']));
        }
      } catch (e) {
        print("DEBUG: Gagal memuat data CPL secara join relasi: $e");
      }
    }

    // --- LOGIKA BARU KONSISTEN (MENIRU JALUR CPL PRODI): Mengambil data CPMK transaksional langsung dari database ---
    List<Map<String, dynamic>> listCpmkDinamis = [];
    if (rpsIdReal.isNotEmpty) {
      try {
        final responseCpmkJoin = await supabase
            .from('cpmk')
            .select('kode_cpmk, deskripsi')
            .eq('rps_id', rpsIdReal)
            .order('kode_cpmk', ascending: true);

        if (responseCpmkJoin != null && responseCpmkJoin is List) {
          for (var item in responseCpmkJoin) {
            listCpmkDinamis.add({
              'kode_cpmk': item['kode_cpmk']?.toString() ?? 'CPMK',
              'deskripsi': item['deskripsi']?.toString() ?? '-',
            });
          }
        }
      } catch (e) {
        print("DEBUG: Gagal memuat data CPMK transaksi secara internal: $e");
      }
    }

    // Fallback darurat jika kueri internal kosong gung, agar PDF tidak rombeng kosong
    if (listCpmkDinamis.isEmpty) {
      for (var item in mapping) {
        listCpmkDinamis.add({
          'kode_cpmk': item['kode_cpmk']?.toString() ?? 'CPMK',
          'deskripsi': item['deskripsi']?.toString() ?? '-',
        });
      }
    }

    pw.ImageProvider? imageDosen;
    pw.ImageProvider? imageKaprodi;
    if (signatureUrlDosen != null && signatureUrlDosen.isNotEmpty) imageDosen = await _downloadImage(signatureUrlDosen);
    if (signatureUrlKaprodi != null && signatureUrlKaprodi.isNotEmpty) imageKaprodi = await _downloadImage(signatureUrlKaprodi);

    final String bahanKajianText = rps['bahan_kajian']?.toString() ?? 'Belum diisi bahan kajian pokok';
    final String namaMk = rps['mata_kuliah']?['nama_mk'] ?? '-';
    final String kodeMk = rps['mata_kuliah']?['kode_mk'] ?? '-';
    final String sksMk = "${rps['mata_kuliah']?['sks'] ?? '0'}";
    final String semesterMk = "${rps['mata_kuliah']?['semester'] ?? '-'}";

    final String metodeBelajarText = rps['metode_pembelajaran']?.toString() ?? 'Problem Based Learning (PBL), Kuliah Teori Kelas, Diskusi Kasus Kelompok, dan Praktikum Terapan Laboratorium.';
    final String referensiText = rps['daftar_referensi']?.toString() ?? '1. Kurose, J.F. & Ross, K.W. (2022). Computer Networking: A Top-Down Approach (8th ed.). Pearson.\n2. Lammle, T. (2022). CompTIA Network+ Study Guide (5th ed.). Sybex.';
    final String prasyaratText = rps['mk_prasyarat']?.toString() ?? 'KB1124 Pengantar Jaringan Komputer / Algoritma Lanjutan (Sifat: Wajib Lulus Terstruktur)';
    final String ambangBatasText = rps['ambang_batas']?.toString() ?? 'Ambang Batas Kelulusan Minimal Mahasiswa: Skor Minimal Kelulusan 60 (Grade C). Konversi Parameter Kelompok Nilai:\n[80-100 = A]  |  [68-79 = B]  |  [56-67 = C]  |  [40-55 = D]  |  [0-39 = E].';
    final String penilaianText = rps['penilaian']?.toString() ?? 'Partisipasi (Kehadiran): 10%  |  Unjuk Kerja (Perilaku): 5%  |  Observasi (Tugas Mandiri/Kelompok): 20%  |  Tes Lisan (Formatif/Kuis): 10%  |  Tes Tulis (UTS): 25%  |  Tes Tulis (UAS): 30%  (Total: 100%)';

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.symmetric(horizontal: 25, vertical: 20),
        build: (pw.Context context) {
          return [
            // --- 1. KOP SURAT RESMI INSTITUSI KAMPUS ---
            pw.Container(
              decoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(width: 1.5, color: PdfColors.black))),
              padding: const pw.EdgeInsets.only(bottom: 6),
              margin: const pw.EdgeInsets.only(bottom: 12),
              child: pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.center,
                children: [
                  pw.Container(
                    width: 45,
                    height: 45,
                    margin: const pw.EdgeInsets.only(right: 12),
                    decoration: const pw.BoxDecoration(color: PdfColors.grey300),
                    alignment: pw.Alignment.center,
                    child: pw.Text("LOGO", style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
                  ),
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text("INSTITUT TEKNOLOGI DAN BISNIS BINA SARANA GLOBAL", style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
                        pw.Text("FAKULTAS TEKNOLOGI INFORMASI DAN KOMUNIKASI", style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.grey800)),
                        pw.Text("PROGRAM STUDI TEKNIK INFORMATIKA", style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.normal, color: PdfColors.grey700)),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            pw.Center(child: pw.Text("RENCANA PEMBELAJARAN SEMESTER (RPS)", style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold))),
            pw.SizedBox(height: 8),

            // --- 2. GRID LAYOUT KAMPUS ---
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.black, width: 0.5),
              columnWidths: const {
                0: pw.FlexColumnWidth(1.5), 
                1: pw.FlexColumnWidth(2.5), 
                2: pw.FlexColumnWidth(2.5), 
                3: pw.FlexColumnWidth(2.5), 
              },
              children: [
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColors.grey100),
                  children: [
                    _buildCellGrid("Mata Kuliah", isLabel: true),
                    _buildCellGrid("Kode Mata Kuliah", isLabel: true),
                    _buildCellGrid("Rumpun Mata Kuliah", isLabel: true),
                    pw.Table(
                      border: const pw.TableBorder(verticalInside: pw.BorderSide(color: PdfColors.black, width: 0.5)),
                      children: [
                        pw.TableRow(
                          children: [
                            _buildCellGrid("Bobot (SKS)", isLabel: true),
                            _buildCellGrid("Semester", isLabel: true),
                            _buildCellGrid("Tanggal Penyusunan", isLabel: true),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
                pw.TableRow(
                  children: [
                    _buildCellGrid(namaMk),
                    _buildCellGrid(kodeMk),
                    _buildCellGrid("Ilmu Komputer"),
                    pw.Table(
                      border: const pw.TableBorder(verticalInside: pw.BorderSide(color: PdfColors.black, width: 0.5)),
                      children: [
                        pw.TableRow(
                          children: [
                            _buildCellGrid(sksMk),
                            _buildCellGrid(semesterMk),
                            _buildCellGrid("${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}"),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColors.grey100),
                  children: [
                    _buildCellGrid("Otorisasi", isLabel: true),
                    _buildCellGrid("Nama Koordinator Pengembang RPS", isLabel: true),
                    _buildCellGrid("Koordinator Bidang Keahlian\n(Jika Ada)", isLabel: true),
                    _buildCellGrid("Ka. Program Studi", isLabel: true),
                  ],
                ),
                pw.TableRow(
                  children: [
                    _buildCellGrid("Tanda Tangan\nSistem Terverifikasi", styleItalic: true),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.center,
                      children: [
                        pw.SizedBox(height: 6),
                        _buildBarcodeBox(), 
                        _buildCellGrid("Dr. M. Ramaddan Julianti, M.T.", isCenter: true),
                      ],
                    ),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.center,
                      children: [
                        pw.SizedBox(height: 6),
                        _buildBarcodeBox(),
                        _buildCellGrid("-", isCenter: true),
                      ],
                    ),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.center,
                      children: [
                        pw.SizedBox(height: 6),
                        _buildBarcodeBox(),
                        _buildCellGrid(namaKaprodi, isCenter: true),
                      ],
                    ),
                  ],
                ),
              ],
            ),

            // Tabel Lanjutan Kebawah Untuk Detail Capaian Silabus RPS
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.black, width: 0.5),
              columnWidths: const {0: pw.FixedColumnWidth(126), 1: pw.FlexColumnWidth(1)},
              children: [
                pw.TableRow(
                  children: [
                    _buildCellGrid("Deskripsi Mata Kuliah", isLabel: true),
                    _buildCellGrid(rps['mata_kuliah']?['deskripsi']?.toString() ?? 'Belum ada deskripsi mata kuliah yang disediakan oleh Kaprodi.'),
                  ],
                ),
                pw.TableRow(
                  children: [
                    _buildCellGrid("Model Pembelajaran", isLabel: true),
                    _buildCellGrid(metodeBelajarText), 
                  ],
                ),
                pw.TableRow(
                  children: [
                    _buildCellGrid("Capaian Pembelajaran\nLulusan (CPL)", isLabel: true),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(5),
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: listCplDinamis.isEmpty
                            ? [pw.Text("• Belum ada Standar CPL prodi yang dipetakan oleh Kaprodi untuk MK ini.", style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey700))]
                            : listCplDinamis.map((cpl) => pw.Padding(
                                padding: const pw.EdgeInsets.only(bottom: 2.5),
                                child: pw.Text("• [${cpl['kode_cpl']}] : ${cpl['deskripsi']}", style: const pw.TextStyle(fontSize: 7, color: PdfColors.black)),
                              )).toList(),
                      ),
                    ),
                  ],
                ),
                pw.TableRow(
                  children: [
                    _buildCellGrid("Capaian Pembelajaran\nMata Kuliah (CPMK)", isLabel: true),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(4),
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: listCpmkDinamis.isEmpty 
                            ? [pw.Text("-", style: const pw.TextStyle(fontSize: 7))]
                            // --- INTEGRASI LOGIKA CPL: Membaca langsung array listCpmkDinamis hasil query internal ---
                            : listCpmkDinamis.map((cpmk) {
                                final String kodeCpmkAsli = cpmk['kode_cpmk']?.toString() ?? 'CPMK';
                                final String deskripsiAsli = cpmk['deskripsi']?.toString() ?? '-';
                                return pw.Padding(
                                  padding: const pw.EdgeInsets.only(bottom: 2),
                                  // Hasil cetakan dijamin 100% dinamis terikat rps_id: • [CPMK-01] : da
                                  child: pw.Text("• [$kodeCpmkAsli] : $deskripsiAsli", style: const pw.TextStyle(fontSize: 7, color: PdfColors.black)),
                                );
                              }).toList(),
                      ),
                    ),
                  ],
                ),
                pw.TableRow(
                  children: [
                    _buildCellGrid("Penilaian", isLabel: true),
                    _buildCellGrid(penilaianText), 
                  ],
                ),
                pw.TableRow(
                  children: [
                    _buildCellGrid("Bahan Kajian /\nMateri Pembelajaran", isLabel: true),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(5),
                      child: pw.Text(bahanKajianText, style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold, color: PdfColors.black)),
                    ),
                  ],
                ),
                pw.TableRow(
                  children: [
                    _buildCellGrid("Daftar Referensi", isLabel: true),
                    _buildCellGrid(referensiText), 
                  ],
                ),
                pw.TableRow(
                  children: [
                    _buildCellGrid("Ambang Batas Kelulusan", isLabel: true),
                    _buildCellGrid(ambangBatasText), 
                  ],
                ),
                pw.TableRow(
                  children: [
                    _buildCellGrid("Dosen Pengampu", isLabel: true),
                    _buildCellGrid("Nama Tim Dosen Pengampu Utama Kelas: $namaDosen"),
                  ],
                ),
                pw.TableRow(
                  children: [
                    _buildCellGrid("Mata Kuliah Prasyarat\n(Jika Ada)", isLabel: true),
                    _buildCellGrid(prasyaratText), 
                  ],
                ),
              ],
            ),
            pw.SizedBox(height: 12),

            // --- 3. MATRIKS JALUR PERTEMUAN MINGGUAN 1 - 14 ---
            pw.Text("MATRIKS PELAKSANAAN RENCANA PERTEMUAN MINGGUAN (1 - 14):", style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 4),
            pw.TableHelper.fromTextArray(
              headers: const ['Pertama Ke-', 'Sub CPMK', 'Pokok Pembahasan', 'Metode Pembelajaran', 'Waktu', 'Pengalaman Belajar', 'Indikator Penilaian', 'Bobot Penilaian (%)'],
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 7.5),
              headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
              cellStyle: const pw.TextStyle(fontSize: 7),
              columnWidths: const {
                0: pw.FixedColumnWidth(55), 
                1: pw.FlexColumnWidth(2),   
                2: pw.FlexColumnWidth(2),   
                3: pw.FlexColumnWidth(1.2), 
                4: pw.FixedColumnWidth(40), 
                5: pw.FlexColumnWidth(2),   
                6: pw.FlexColumnWidth(1.5), 
                7: pw.FixedColumnWidth(55), 
              },
              data: listPertemuan.map((p) => [
                "Minggu ${p['minggu_ke']}",
                p['kemappan_akhir'] ?? p['kemampuan_akhir'] ?? '-',
                p['materi'] ?? '-', 
                p['metode_pembelajaran'] ?? 'Ceramah & Diskusi',
                "150 Menit",
                p['pengalaman_belajar'] ?? 'Mahasiswa menganalisis studi kasus nyata di laboratorium jaringan.',
                p['indikator_penilaian'] ?? 'Ketepatan pemahaman teori & hasil demo praktik',
                "0%", 
              ]).toList(),
            ),

            pw.SizedBox(height: 20),

            // --- 4. AREA VALIDASI BAWAH HALAMAN ---
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  children: [
                    pw.Text("Menyetujui, Ketua Program Studi prodi", style: const pw.TextStyle(fontSize: 7.5)),
                    pw.SizedBox(height: 2),
                    pw.Container(
                      height: 35,
                      width: 75,
                      child: imageKaprodi != null ? pw.Image(imageKaprodi, fit: pw.BoxFit.contain) : pw.SizedBox(),
                    ),
                    pw.Text(namaKaprodi, style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold, decoration: pw.TextDecoration.underline)),
                  ],
                ),
                pw.Column(
                  children: [
                    pw.Text("Tangerang, ${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}", style: const pw.TextStyle(fontSize: 7.5)),
                    pw.Text("Dosen Pengampu Mata Kuliah", style: const pw.TextStyle(fontSize: 7.5)),
                    pw.SizedBox(height: 2),
                    pw.Container(
                      height: 35,
                      width: 75,
                      child: imageDosen != null ? pw.Image(imageDosen, fit: pw.BoxFit.contain) : pw.SizedBox(),
                    ),
                    pw.Text(namaDosen, style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold, decoration: pw.TextDecoration.underline)),
                  ],
                ),
              ],
            ),
          ];
        },
      ),
    );

    await Printing.layoutPdf(onLayout: (PdfPageFormat format) async => pdf.save());
  }

  static Future<pw.ImageProvider?> _downloadImage(String url) async {
    try {
      final response = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 15));
      if (response.statusCode == 200 && response.bodyBytes.isNotEmpty) return pw.MemoryImage(response.bodyBytes);
    } catch (e) {
      print("Error download image: $e");
    }
    return null;
  }

  static pw.Widget _buildBarcodeBox() {
    return pw.Container(
      width: 28,
      height: 28,
      margin: const pw.EdgeInsets.symmetric(vertical: 2),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey500, width: 0.5),
        color: PdfColors.grey200,
      ),
      alignment: pw.Alignment.center,
      child: pw.Text("QR", style: pw.TextStyle(fontSize: 6.5, fontWeight: pw.FontWeight.bold, color: PdfColors.grey700)),
    );
  }

  static pw.Widget _buildCellGrid(String text, {bool isLabel = false, bool styleItalic = false, bool isCenter = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 4),
      child: pw.Text(
        text,
        textAlign: isCenter ? pw.TextAlign.center : pw.TextAlign.left,
        style: pw.TextStyle(
          fontSize: 7,
          fontWeight: isLabel ? pw.FontWeight.bold : pw.FontWeight.normal,
          fontStyle: styleItalic ? pw.FontStyle.italic : pw.FontStyle.normal,
          color: isLabel ? PdfColors.black : PdfColors.grey900,
        ),
      ),
    );
  }

  static pw.Widget _buildCell(String text, {bool isHeader = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(3),
      child: pw.Text(text, style: pw.TextStyle(fontSize: isHeader ? 8 : 7, fontWeight: isHeader ? pw.FontWeight.bold : pw.FontWeight.normal)),
    );
  }
}