import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

class PdfHelper {
  static Future<void> cetakRps(
    Map<String, dynamic> rps,
    List<Map<String, dynamic>> mapping,
  ) async {
    final pdf = pw.Document();
    final supabase = Supabase.instance.client;

    // --- 1. AMBIL DATA DOSEN DARI PARAMETER ---
    final listPertemuan = (rps['rps_detail'] as List?) ?? [];

    // --- 2. AMBIL DATA KAPRODI DAN DOSEN DARI DATABASE (QUERY TERPISAH) ---
    String namaKaprodi = "Ketua Program Studi";
    String? signatureUrlKaprodi;

    try {
      final kaprodiData = await supabase
          .from('users')
          .select('nama, signature_url')
          .eq('role', 'kaprodi')
          .maybeSingle();
      
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
      // CARA PALING PASTI: Ambil data dari user yang sedang login (Session)
      final currentUser = supabase.auth.currentUser;
      
      if (currentUser != null) {
        // Ambil data detail (nama & ttd) dari tabel users berdasarkan ID yang login
        final userData = await supabase
            .from('users')
            .select('nama, signature_url')
            .eq('id', currentUser.id)
            .maybeSingle();

        if (userData != null) {
          namaDosen = userData['nama'] ?? 'Dosen Pengampu';
          signatureUrlDosen = userData['signature_url'];
          print("DEBUG: Berhasil panggil data dosen login: $namaDosen");
          
          // --- MENAMBAHKAN LOGIKA BARU AGAR NAMA TIDAK TERTUKAR KETIKA KAPRODI YANG CETAK ---
          // Jika data namaDosen yang tidak sengaja terambil bernilai sama dengan namaKaprodi aktif,
          // kita alihkan untuk menarik data profile Dosen asli pemilik dokumen RPS.
          if (namaDosen == namaKaprodi) {
            final String? idDosenAsli = rps['dosen_id']?.toString() ?? rps['id_user']?.toString();
            if (idDosenAsli != null) {
              final realDosenData = await supabase
                  .from('users')
                  .select('nama, signature_url')
                  .eq('id', idDosenAsli)
                  .maybeSingle();
              if (realDosenData != null) {
                namaDosen = realDosenData['nama'] ?? 'Dosen Pengampu';
                signatureUrlDosen = realDosenData['signature_url'];
                print("DEBUG: Sukses mengalihkan nama ke Dosen Pengampu asli: $namaDosen");
              }
            }
          }
          // ------------------------------------------------------------------------------------
        }
      } else {
        // Jika tidak ada session login (jarang terjadi), fallback ke id_user rps
        final String? idDariRps = rps['id_user']?.toString();
        if (idDariRps != null) {
          final rpsOwnerData = await supabase
              .from('users')
              .select('nama, signature_url')
              .eq('id', idDariRps)
              .maybeSingle();
          if (rpsOwnerData != null) {
            namaDosen = rpsOwnerData['nama'] ?? 'Dosen Pengampu';
            signatureUrlDosen = rpsOwnerData['signature_url'];
          }
        }
      }
    } catch (e) {
      print("DEBUG: Error total pengambilan data: $e");
    }

    // --- 3. PROSES DOWNLOAD GAMBAR (LOGIKA DISAMAKAN PERSIS) ---
    pw.ImageProvider? imageDosen;
    pw.ImageProvider? imageKaprodi;

    // Download TTD Dosen
    if (signatureUrlDosen != null && signatureUrlDosen.isNotEmpty) {
      print("Mencoba download TTD Dosen: $signatureUrlDosen");
      imageDosen = await _downloadImage(signatureUrlDosen);
    }

    // Download TTD Kaprodi
    if (signatureUrlKaprodi != null && signatureUrlKaprodi.isNotEmpty) {
      print("Mencoba download TTD Kaprodi: $signatureUrlKaprodi");
      imageKaprodi = await _downloadImage(signatureUrlKaprodi);
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32), // Menggunakan const agar rendering ringan
        build: (pw.Context context) {
          return [
            // 1. HEADER JUDUL
            pw.Center(
              child: pw.Text("RENCANA PEMBELAJARAN SEMESTER (RPS)",
                  style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
            ),
            pw.SizedBox(height: 20), // Menggunakan const agar hemat RAM

            // 2. INFORMASI MATA KULIAH
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    _buildInfoRow("Mata Kuliah", rps['mata_kuliah']?['nama_mk'] ?? '-'),
                    _buildInfoRow("Kode MK", rps['mata_kuliah']?['kode_mk'] ?? '-'),
                    _buildInfoRow("SKS", "${rps['mata_kuliah']?['sks'] ?? '0'} SKS"),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    _buildInfoRow("Semester", "${rps['mata_kuliah']?['semester'] ?? '-'} (${rps['semester'] ?? '-'})"),
                    _buildInfoRow("Dosen", namaDosen),
                    _buildInfoRow("Tahun Ajaran", rps['tahun_ajaran'] ?? '-'),
                  ],
                ),
              ],
            ),
            pw.SizedBox(height: 20), // Menggunakan const agar hemat RAM

            // 3. TABEL CPMK
            pw.Text("Capaian Pembelajaran (CPMK):",
                style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 8), // Menggunakan const agar hemat RAM
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.black, width: 0.5), // Menggunakan const
              columnWidths: const { // Menggunakan const untuk mengoptimalkan RAM widget
                0: pw.FixedColumnWidth(30),
                1: pw.FlexColumnWidth(2),
                2: pw.FlexColumnWidth(3),
              },
              children: [
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColors.grey300), // Menggunakan const
                  children: [
                    _buildCell("No", isHeader: true),
                    _buildCell("Deskripsi CPMK", isHeader: true),
                    _buildCell("CPL Terkait (Kode, Bobot, Deskripsi)", isHeader: true),
                  ],
                ),
                ...mapping.map((item) {
                  final index = mapping.indexOf(item) + 1;
                  final List mList = (item['mapping_cpl_cpmk'] as List?) ?? [];
                  return pw.TableRow(
                    children: [
                      _buildCell(index.toString()),
                      _buildCell(item['deskripsi'] ?? '-'),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(5),
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: mList.map((m) {
                            return pw.Padding(
                              padding: const pw.EdgeInsets.only(bottom: 3),
                              child: pw.Text(
                                "${m['cpl']['kode_cpl']} (${m['bobot']}%): ${m['cpl']['deskripsi']}",
                                style: const pw.TextStyle(fontSize: 8),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ],
            ),
            pw.SizedBox(height: 20), // Menggunakan const agar hemat RAM

            // 4. TABEL RENCANA PERTEMUAN MINGGUAN
            pw.Text("RENCANA PEMBELAJARAN MINGGUAN:",
                style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 8), // Menggunakan const agar hemat RAM
            pw.TableHelper.fromTextArray(
              headers: const ['Minggu', 'Kemampuan Akhir / Materi', 'Metode', 'Bobot'], // Menggunakan const
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10),
              headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300), // Menggunakan const
              cellStyle: const pw.TextStyle(fontSize: 9), // Menggunakan const
              columnWidths: const { // Menggunakan const
                0: pw.FixedColumnWidth(40),
                1: pw.FlexColumnWidth(3),
                2: pw.FlexColumnWidth(2),
                3: pw.FixedColumnWidth(40),
              },
              data: listPertemuan.map((p) => [
                p['minggu_ke'].toString(),
                p['kemampuan_akhir'] ?? '-',
                p['metode_pembelajaran'] ?? '-',
                "${p['bobot_nilai']}%",
              ]).toList(),
            ),

            pw.SizedBox(height: 40), // Menggunakan const agar hemat RAM

            // --- 5. TANDA TANGAN (POSISI SEJAJAR) ---
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // KOLOM KAPRODI (KIRI)
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.center,
                  children: [
                    pw.Text("Menyetujui,", style: pw.TextStyle(fontSize: 10)), // Menggunakan const
                    pw.Text("Ketua Program Studi,", style: pw.TextStyle(fontSize: 10)), // Menggunakan const
                    pw.SizedBox(height: 5), // Menggunakan const
                    pw.Container(
                      height: 60,
                      width: 100,
                      alignment: pw.Alignment.center,
                      child: imageKaprodi != null
                          ? pw.Image(
                              imageKaprodi,
                              fit: pw.BoxFit.contain,
                            )
                          : pw.SizedBox(), // Menggunakan const
                    ),
                    pw.Text(namaKaprodi,
                        style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, decoration: pw.TextDecoration.underline)),
                  ],
                ),

                // KOLOM DOSEN (KANAN)
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.center,
                  children: [
                    pw.Text("Tangerang, ${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}", style: const pw.TextStyle(fontSize: 10)),
                    pw.Text("Dosen Pengampu,", style: pw.TextStyle(fontSize: 10)), // Menggunakan const
                    pw.SizedBox(height: 5), // Menggunakan const
                    pw.Container(
                      height: 60,
                      width: 100,
                      alignment: pw.Alignment.center,
                      child: imageDosen != null
                          ? pw.Image(
                              imageDosen,
                              fit: pw.BoxFit.contain,
                            )
                          : pw.SizedBox(), // Menggunakan const
                    ),
                    pw.Text(namaDosen,
                        style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, decoration: pw.TextDecoration.underline)),
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

  // --- HELPER DOWNLOAD (DIGUNAKAN OLEH KEDUANYA) ---
  static Future<pw.ImageProvider?> _downloadImage(String url) async {
    try {
      final response = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 15));
      if (response.statusCode == 200 && response.bodyBytes.isNotEmpty) {
        return pw.MemoryImage(response.bodyBytes);
      } else {
        print("Gagal download image dari $url. Status: ${response.statusCode}");
      }
    } catch (e) {
      print("Error download image: $e");
    }
    return null;
  }

  static pw.Widget _buildInfoRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 4),
      child: pw.RichText(
        text: pw.TextSpan(children: [
          pw.TextSpan(text: "$label : ", style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9)),
          pw.TextSpan(text: value, style: const pw.TextStyle(fontSize: 9)),
        ]),
      ),
    );
  }

  static pw.Widget _buildCell(String text, {bool isHeader = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(5),
      child: pw.Text(text, textAlign: pw.TextAlign.left, 
          style: pw.TextStyle(fontSize: isHeader ? 10 : 9, fontWeight: isHeader ? pw.FontWeight.bold : pw.FontWeight.normal)),
    );
  }
}