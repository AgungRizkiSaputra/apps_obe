import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class PdfHelper {
  static Future<void> cetakRps(
    Map<String, dynamic> rps,
    List<Map<String, dynamic>> mapping,
  ) async {
    final pdf = pw.Document();
    final supabase = Supabase.instance.client;

    final listPertemuan = (rps['rps_detail'] as List?) ?? [];
    final String rpsIdReal = rps['id']?.toString() ?? '';
    final String mkId = rps['mata_kuliah_id']?.toString() ?? rps['mata_kuliah']?['id']?.toString() ?? '';

    // --- LOGIKA PEMBACAAN LOGO ASSET LOKAL FLUTTER WEB ---
    pw.ImageProvider? logoCampustImage;
    try {
      logoCampustImage = await imageFromAssetBundle('assets/images/logoGLOBAL.webp');
      print("SUCCESS: Logo Bina Sarana Global berhasil di-load ke PDF bundle gung!");
    } catch (e) {
      print("ERROR: Gagal memuat logo asset via bundle: $e");
    }

    String namaKaprodi = "Siti Maisaroh Mustafa, S.S., M.Pd.";
    try {
      final kaprodiData = await supabase.from('users').select('nama, signature_url').eq('role', 'kaprodi').maybeSingle();
      if (kaprodiData != null) {
        namaKaprodi = kaprodiData['nama'];
      }
    } catch (e) {
      print("Gagal mengambil data kaprodi: $e");
    }

    String namaDosen = "Dosen Pengampu";
    try {
      final currentUser = supabase.auth.currentUser;
      if (currentUser != null) {
        final userData = await supabase.from('users').select('nama, signature_url').eq('id', currentUser.id).maybeSingle();
        if (userData != null) {
          namaDosen = userData['nama'] ?? 'Dosen Pengampu';
          if (namaDosen == namaKaprodi) {
            final String? idDosenAsli = rps['dosen_id']?.toString() ?? rps['id_user']?.toString();
            if (idDosenAsli != null) {
              final realDosenData = await supabase.from('users').select('nama, signature_url').eq('id', idDosenAsli).maybeSingle();
              if (realDosenData != null) {
                namaDosen = realDosenData['nama'] ?? 'Dosen Pengampu';
              }
            }
          }
        }
      }
    } catch (e) {
      print("DEBUG: Error total signature: $e");
    }

    List<Map<String, dynamic>> listCplDinamis = [];
    if (mkId.isNotEmpty) {
      try {
        final responseJoin = await supabase
            .from('standar_mapping_mk')
            .select('cpl(kode_cpl, deskripsi)')
            .eq('mk_id', mkId);

        for (var item in responseJoin) {
          if (item['cpl'] != null) {
            listCplDinamis.add({
              'kode_cpl': item['cpl']['kode_cpl']?.toString() ?? '-',
              'deskripsi': item['cpl']['deskripsi']?.toString() ?? '-',
            });
          }
        }
        listCplDinamis.sort((a, b) => a['kode_cpl'].compareTo(b['kode_cpl']));
      } catch (e) {
        print("DEBUG: Gagal memuat data CPL secara join relasi: $e");
      }
    }

    List<Map<String, dynamic>> listCpmkDinamis = [];
    if (rpsIdReal.isNotEmpty) {
      try {
        final responseCpmkJoin = await supabase
            .from('cpmk')
            .select('kode_cpmk, deskripsi')
            .eq('rps_id', rpsIdReal)
            .order('kode_cpmk', ascending: true);

        for (var item in responseCpmkJoin) {
          listCpmkDinamis.add({
            'kode_cpmk': item['kode_cpmk']?.toString() ?? 'CPMK',
            'deskripsi': item['deskripsi']?.toString() ?? '-',
          });
        }
      } catch (e) {
        print("DEBUG: Gagal memuat data CPMK transaksi secara internal: $e");
      }
    }

    if (listCpmkDinamis.isEmpty) {
      for (var item in mapping) {
        listCpmkDinamis.add({
          'kode_cpmk': item['kode_cpmk']?.toString() ?? 'CPMK',
          'deskripsi': item['deskripsi']?.toString() ?? '-',
        });
      }
    }

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
        margin: const pw.EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        build: (pw.Context context) {
          const double pageWidth = 752;
          return [
            // --- 1. KOP SURAT RESMI INSTITUSI DENGAN INTEGRASI LOGO ASSET LOKAL ---
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
                    alignment: pw.Alignment.center,
                    child: logoCampustImage != null 
                        ? pw.Image(logoCampustImage, fit: pw.BoxFit.contain)
                        : pw.Container(
                            decoration: const pw.BoxDecoration(color: PdfColors.grey300),
                            alignment: pw.Alignment.center,
                            child: pw.Text("LOGO", style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
                          ),
                  ),
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text("INSTITUT TEKNOLOGI DAN BISNIS BINA SARANA GLOBAL", style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                        pw.Text("FAKULTAS TEKNOLOGI INFORMASI DAN KOMUNIKASI", style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.black)),
                        pw.Text("PROGRAM STUDI TEKNIK INFORMATIKA", style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.black)),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Judul Dokumen Utama
            pw.Center(child: pw.Text("RENCANA PEMBELAJARAN SEMESTER (RPS)", style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold))),
            pw.SizedBox(height: 8),

            // --- TAMENG PENGUNCI LEBAR 1: Mengunci Lebar Grid Atas Agar Tidak Lewat Batas Kanan Lembar Cetak gung ---
            pw.SizedBox(
              width: pageWidth,
              child: pw.Table(
                border: pw.TableBorder.all(color: PdfColors.black, width: 0.5),
                columnWidths: const {
                  0: pw.FlexColumnWidth(1.5), 
                  1: pw.FlexColumnWidth(2.0), 
                  2: pw.FlexColumnWidth(2.0), 
                  3: pw.FlexColumnWidth(2.8),
                },
                children: [
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(color: PdfColors.grey100),
                    children: [
                      _buildCellGrid("Mata Kuliah"),
                      _buildCellGrid("Kode Mata Kuliah"),
                      _buildCellGrid("Rumpun Mata Kuliah"),
                      pw.Table(
                        border: const pw.TableBorder(verticalInside: pw.BorderSide(color: PdfColors.black, width: 0.5)),
                        children: [
                          pw.TableRow(
                            children: [
                              _buildCellGrid("Bobot (SKS)"),
                              _buildCellGrid("Semester"),
                              _buildCellGrid("Tanggal Penyusunan"),
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
                      _buildCellGrid("Otorisasi"),
                      _buildCellGrid("Nama Koordinator Pengembang RPS"),
                      _buildCellGrid("Koordinator Bidang Keahlian\n(Jika Ada)"),
                      _buildCellGrid("Ka. Program Studi"),
                    ],
                  ),
                  pw.TableRow(
                    children: [
                      _buildCellGrid("Tanda Tangan\nSistem Terverifikasi"), 
                      // --- REVISI FITUR AGUNG: Mengisi Data Unik RPS Berbasis Enkripsi String ke dalam QR Code gung ---
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.center,
                        children: [
                          pw.SizedBox(height: 6),
                          _buildBarcodeBox("Sistem TTE Global\nKoordinator: Dr. M. Ramaddan Julianti, M.T.\nRPS ID: $rpsIdReal"), 
                          _buildCellGrid("Dr. M. Ramaddan Julianti, M.T.", isCenter: true),
                        ],
                      ),
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.center,
                        children: [
                          pw.SizedBox(height: 6),
                          _buildBarcodeBox("Sistem TTE Global\nKBK: Jaringan & Ilmu Komputer\nRPS ID: $rpsIdReal"),
                          _buildCellGrid("-", isCenter: true),
                        ],
                      ),
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.center,
                        children: [
                          pw.SizedBox(height: 6),
                          _buildBarcodeBox("Sistem TTE Global\nKaprodi: $namaKaprodi\nRPS ID: $rpsIdReal"),
                          _buildCellGrid(namaKaprodi, isCenter: true),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // --- TAMENG PENGUNCI LEBAR 2: Mengunci Lebar Detail Capaian Silabus gung ---
            pw.SizedBox(
              width: pageWidth,
              child: pw.Table(
                border: pw.TableBorder.all(color: PdfColors.black, width: 0.5),
                columnWidths: const {
                  0: pw.FixedColumnWidth(136.2), 
                  1: pw.FlexColumnWidth(1.0),
                },
                children: [
                  pw.TableRow(
                    children: [
                      _buildCellGrid("Deskripsi Mata Kuliah"),
                      _buildCellGrid(rps['mata_kuliah']?['deskripsi']?.toString() ?? 'Belum ada deskripsi mata kuliah yang disediakan oleh Kaprodi.'),
                    ],
                  ),
                  pw.TableRow(
                    children: [
                      _buildCellGrid("Model Pembelajaran"),
                      _buildCellGrid(metodeBelajarText), 
                    ],
                  ),
                  pw.TableRow(
                    children: [
                      _buildCellGrid("Capaian Pembelajaran\nLulusan (CPL)"),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(5),
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: listCplDinamis.isEmpty
                              ? [pw.Text("Belum ada Standar CPL prodi yang dipetakan oleh Kaprodi untuk MK ini.", style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey900))]
                              : listCplDinamis.map((cpl) => pw.Padding(
                                  padding: const pw.EdgeInsets.only(bottom: 2.5),
                                  child: pw.Text("[${cpl['kode_cpl']}] : ${cpl['deskripsi']}", style: const pw.TextStyle(fontSize: 7, color: PdfColors.black)),
                                )).toList(),
                        ),
                      ),
                    ],
                  ),
                  pw.TableRow(
                    children: [
                      _buildCellGrid("Capaian Pembelajaran\nMata Kuliah (CPMK)"),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(4),
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: listCpmkDinamis.isEmpty 
                              ? [pw.Text("-", style: const pw.TextStyle(fontSize: 7))]
                              : listCpmkDinamis.map((cpmk) {
                                  final String kodeCpmkAsli = cpmk['kode_cpmk']?.toString() ?? 'CPMK';
                                  final String deskripsiAsli = cpmk['deskripsi']?.toString() ?? '-';
                                  return pw.Padding(
                                    padding: const pw.EdgeInsets.only(bottom: 2),
                                    child: pw.Text("[$kodeCpmkAsli] : $deskripsiAsli", style: const pw.TextStyle(fontSize: 7, color: PdfColors.black)),
                                  );
                                }).toList(),
                        ),
                      ),
                    ],
                  ),
                  pw.TableRow(
                    children: [
                      _buildCellGrid("Penilaian"),
                      _buildCellGrid(penilaianText), 
                    ],
                  ),
                  pw.TableRow(
                    children: [
                      _buildCellGrid("Bahan Kajian /\nMateri Pembelajaran"),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(5),
                        child: pw.Text(bahanKajianText, style: const pw.TextStyle(fontSize: 7, color: PdfColors.black)),
                    ),
                  ],
                ),
                pw.TableRow(
                  children: [
                    _buildCellGrid("Daftar Referensi"),
                    _buildCellGrid(referensiText), 
                  ],
                ),
                pw.TableRow(
                  children: [
                    _buildCellGrid("Ambang Batas Kelulusan"),
                    _buildCellGrid(ambangBatasText), 
                  ],
                ),
                pw.TableRow(
                  children: [
                    _buildCellGrid("Dosen Pengampu"),
                    _buildCellGrid("$namaDosen"),
                  ],
                ),
                pw.TableRow(
                  children: [
                    _buildCellGrid("Mata Kuliah Prasyarat\n(Jika Ada)"),
                    _buildCellGrid(prasyaratText), 
                  ],
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 12),

          // Header Tabel Mingguan
          pw.Text("MATRIKS PELAKSANAAN RENCANA PERTEMUAN MINGGUAN (1 - 14):", style: pw.TextStyle(fontSize: 7, color: PdfColors.black, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 4),
          
          // --- TAMENG PENGUNCI LEBAR 3 ---
          pw.SizedBox(
            width: pageWidth,
            child: pw.TableHelper.fromTextArray(
              headers: const ['Pertemuan Ke-', 'Sub CPMK', 'Pokok Pembahasan', 'Metode Pembelajaran', 'Waktu', 'Pengalaman Belajar', 'Indikator Penilaian', 'Bobot Penilaian (%)'],
              headerStyle: pw.TextStyle(fontSize: 7, color: PdfColors.black, fontWeight: pw.FontWeight.bold),
              headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
              cellStyle: const pw.TextStyle(fontSize: 6.5),
              columnWidths: const {
                0: pw.FixedColumnWidth(55), 
                1: pw.FlexColumnWidth(1.5),   
                2: pw.FlexColumnWidth(1.5),   
                3: pw.FlexColumnWidth(1.1), 
                4: pw.FixedColumnWidth(35), 
                5: pw.FlexColumnWidth(1.5),   
                6: pw.FlexColumnWidth(1.4), 
                7: pw.FixedColumnWidth(35), 
              },
              data: listPertemuan.map((p) => [
                "Minggu ${p['minggu_ke']}",
                p['sub_cpmk'] ?? '-', 
                p['pokok_pembahasan'] ?? '-', 
                p['metode_pembelajaran'] ?? 'Ceramah & Diskusi',
                p['waktu'] ?? '150 Menit', 
                p['pengalaman_belajar'] ?? 'Mahasiswa menganalisis studi kasus nyata di laboratorium jaringan.',
                p['indikator_penilaian'] ?? 'Ketepatan pemahaman teori & hasil demo praktik',
                "${p['bobot_nilai'] ?? 0}%", 
              ]).toList(),
            ),
          ),

          pw.SizedBox(height: 16),

          pw.Text("PENILAIAN DENGAN RUBRIK", style: pw.TextStyle(fontSize: 7, color: PdfColors.black, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 4),
          pw.Row(
          children: [
            pw.Flexible(
              flex: 0,
              child: pw.Table(
                border: pw.TableBorder.all(
                  color: PdfColors.black,
                  width: 0.5,
                ),
                defaultColumnWidth: const pw.IntrinsicColumnWidth(),
                children: [
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(color: PdfColors.grey100),
                    children: [
                      _buildCellGrid(
                        "Jenjang (Grade)",
                        isBold: true,
                        isCenter: true,
                      ),
                      _buildCellGrid(
                        "Angka (Skor)",
                        isBold: true,
                        isCenter: true,
                      ),
                      _buildCellGrid(
                        "Deskripsi Perilaku (Indikator)",
                        isBold: true,
                        isCenter: true,
                      ),
                    ],
                  ),
                  pw.TableRow(
                    children: [
                      _buildCellGrid("Sangat kurang"),
                      _buildCellGrid("0 - 20"),
                      _buildCellGrid("Laporan tidak ditulis sesuai intruksi tugas."),
                    ],
                  ),
                  pw.TableRow(
                    children: [
                      _buildCellGrid("Kurang"),
                      _buildCellGrid("21 - 40"),
                      _buildCellGrid("Laporan ditulis sesuai intruksi tugas namun tidak lengkap."),
                    ],
                  ),
                  pw.TableRow(
                    children: [
                      _buildCellGrid("Cukup"),
                      _buildCellGrid("41 - 60"),
                      _buildCellGrid("Laporan ditulis sesuai intruksi tugas secara lengkap dan tidak rapi."),
                    ],
                  ),
                  pw.TableRow(
                    children: [
                      _buildCellGrid("Baik"),
                      _buildCellGrid("61 - 80"),
                      _buildCellGrid("Laporan ditulis sesuai intruksi tugas secara lengkap dan rapi."),
                    ],
                  ),
                  pw.TableRow(
                    children: [
                      _buildCellGrid("Sangat Baik"),
                      _buildCellGrid("81 - 100"),
                      _buildCellGrid("Laporan ditulis sesuai intruksi tugas secara lengkap, rapi dan memiliki muatan kreativitas ide."),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),

          pw.SizedBox(height: 16),

          pw.Text("PENENTUAN NILAI AKHIR", style: pw.TextStyle(fontSize: 7, color: PdfColors.black, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 4),
          pw.SizedBox(
            width: 250,
            child: pw.Table(
              border: pw.TableBorder.all(),
              columnWidths: const {
                0: pw.FixedColumnWidth(180),
                1: pw.FixedColumnWidth(70),
              },
              children: [
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(color: PdfColors.grey100),
                    children: [
                      _buildCellGrid(
                        "Nilai Skor Mata Kuliah",
                        isBold: true,
                        isCenter: true,
                      ),
                      _buildCellGrid(
                        "Nilai Mata Kuliah (Grade)",
                        isBold: true,
                        isCenter: true,
                      ),
                    ],
                  ),
                  pw.TableRow(
                    children: [
                      _buildCellGrid("80 <= NA <= 100"),
                      _buildCellGrid("A"),
                    ],
                  ),
                  pw.TableRow(
                    children: [
                      _buildCellGrid("68 <= NA <= 79"),
                      _buildCellGrid("B"),
                    ],
                  ),
                  pw.TableRow(
                    children: [
                      _buildCellGrid("56 <= NA <= 67"),
                      _buildCellGrid("C"),
                    ],
                  ),
                  pw.TableRow(
                    children: [
                      _buildCellGrid("40 <= NA <= 55"),
                      _buildCellGrid("D"),
                    ],
                  ),
                  pw.TableRow(
                    children: [
                      _buildCellGrid("0 <= NA <= 39"),
                      _buildCellGrid("E"),
                    ],
                  ),
                ],
            ),
          )
          ];
        },
      ),
    );

    try {
      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async {
          return pdf.save();
        },
      );
    } catch (e, s) {
      print("ERROR PDF: $e");
      print(s);
      rethrow;
    }
  }

  // =========================================================================
  // --- KOREKSI TOTAL BARCODE BOX GUNG: Mengubah Placeholder Menjadi QR Code Asli Scannable ---
  // =========================================================================
  static pw.Widget _buildBarcodeBox(String data) {
    return pw.Container(
      width: 32,
      height: 32,
      margin: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.BarcodeWidget(
        barcode: pw.Barcode.qrCode(), // Memanggil konstruktor mesin QR asli gung!
        data: data,                   // Memasukkan teks verifikasi kurikulum prodi
        width: 32,
        height: 32,
        drawText: false,              // Mematikan string mentah di bawah boks agar tidak overflow
      ),
    );
  }

  static pw.Widget _buildCellGrid(
  String text, {
  bool isCenter = false,
  bool isBold = false,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 4),
      child: pw.Text(
        text,
        textAlign: isCenter ? pw.TextAlign.center : pw.TextAlign.left,
        style: pw.TextStyle(
          fontSize: 7,
          color: PdfColors.black,
          fontWeight:
              isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
        ),
      ),
    );
  }
}