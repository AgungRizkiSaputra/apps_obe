import 'dart:typed_data';
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

    // 1. DATA DOSEN (PASTIKAN DIAMBIL DARI rps['users'])
    final String? signatureUrl = rps['users']?['signature_url'];
    final String namaDosen = rps['users']?['nama'] ?? 'Dosen Pengampu';
    final listPertemuan = (rps['rps_detail'] as List?) ?? [];

    // 2. DATA KAPRODI (AMBIL DARI DATABASE)
    String namaKaprodi = "Ketua Program Studi";
    String? kaprodiSigUrl;
    
    try {
      final kaprodiData = await supabase
          .from('users')
          .select('nama, signature_url')
          .eq('role', 'kaprodi')
          .maybeSingle();
      
      if (kaprodiData != null) {
        namaKaprodi = kaprodiData['nama'];
        kaprodiSigUrl = kaprodiData['signature_url'];
      }
    } catch (e) {
      print("Gagal mengambil data kaprodi: $e");
    }

    pw.ImageProvider? signatureImage; // TTD Dosen
    pw.ImageProvider? kaprodiSignatureImage; // TTD Kaprodi

    // --- DOWNLOAD TANDA TANGAN DOSEN (LOGIKA DISAMAKAN DENGAN KAPRODI) ---
    if (signatureUrl != null && signatureUrl.isNotEmpty) {
      print("Mencoba download TTD Dosen dari: $signatureUrl");
      signatureImage = await _downloadImage(signatureUrl);
    }

    // --- DOWNLOAD TANDA TANGAN KAPRODI ---
    if (kaprodiSigUrl != null && kaprodiSigUrl.isNotEmpty) {
      print("Mencoba download TTD Kaprodi dari: $kaprodiSigUrl");
      kaprodiSignatureImage = await _downloadImage(kaprodiSigUrl);
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return [
            // 1. HEADER JUDUL
            pw.Center(
              child: pw.Text("RENCANA PEMBELAJARAN SEMESTER (RPS)",
                  style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
            ),
            pw.SizedBox(height: 20),

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
            pw.SizedBox(height: 20),

            // 3. TABEL CPMK
            pw.Text("Capaian Pembelajaran (CPMK):",
                style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 8),
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.black, width: 0.5),
              columnWidths: {
                0: const pw.FixedColumnWidth(30),
                1: const pw.FlexColumnWidth(2),
                2: const pw.FlexColumnWidth(3),
              },
              children: [
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColors.grey300),
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
            pw.SizedBox(height: 20),

            // 4. TABEL RENCANA PERTEMUAN MINGGUAN
            pw.Text("RENCANA PEMBELAJARAN MINGGUAN:",
                style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 8),
            pw.TableHelper.fromTextArray(
              headers: ['Minggu', 'Kemampuan Akhir / Materi', 'Metode', 'Bobot'],
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10),
              headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
              cellStyle: const pw.TextStyle(fontSize: 9),
              columnWidths: {
                0: const pw.FixedColumnWidth(40),
                1: const pw.FlexColumnWidth(3),
                2: const pw.FlexColumnWidth(2),
                3: const pw.FixedColumnWidth(40),
              },
              data: listPertemuan.map((p) => [
                p['minggu_ke'].toString(),
                p['kemampuan_akhir'] ?? '-',
                p['metode_pembelajaran'] ?? '-',
                "${p['bobot_nilai']}%",
              ]).toList(),
            ),

            pw.SizedBox(height: 40),

            // 5. TANDA TANGAN (KAPRODI DI KIRI, DOSEN DI KANAN)
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                // KOLOM KAPRODI
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.center,
                  children: [
                    pw.Text("Menyetujui,", style: const pw.TextStyle(fontSize: 10)),
                    pw.Text("Ketua Program Studi,", style: const pw.TextStyle(fontSize: 10)),
                    pw.SizedBox(height: 5),
                    kaprodiSignatureImage != null
                        ? pw.Container(height: 50, width: 90, child: pw.Image(kaprodiSignatureImage))
                        : pw.SizedBox(height: 50),
                    pw.Text(namaKaprodi,
                        style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, decoration: pw.TextDecoration.underline)),
                  ],
                ),

                // KOLOM DOSEN (SEKARANG DISAMAKAN LOGIKANYA DENGAN KAPRODI)
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.center,
                  children: [
                    pw.Text("Tangerang, ${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}", style: const pw.TextStyle(fontSize: 10)),
                    pw.Text("Dosen Pengampu,", style: const pw.TextStyle(fontSize: 10)),
                    pw.SizedBox(height: 5),
                    signatureImage != null
                        ? pw.Container(height: 50, width: 90, child: pw.Image(signatureImage))
                        : pw.SizedBox(height: 50),
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

  // --- HELPER DOWNLOAD GAMBAR (SAMA UNTUK SEMUA ROLE) ---
  static Future<pw.ImageProvider?> _downloadImage(String url) async {
    try {
      final response = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 15));
      if (response.statusCode == 200 && response.bodyBytes.isNotEmpty) {
        return pw.MemoryImage(response.bodyBytes);
      } else {
        print("Gagal download gambar dari $url. Status: ${response.statusCode}");
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