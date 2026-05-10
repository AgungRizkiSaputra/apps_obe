import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:http/http.dart' as http;

class PdfHelper {
  static Future<void> cetakRps(
    Map<String, dynamic> rps,
    List<Map<String, dynamic>> mapping,
  ) async {
    final pdf = pw.Document();

    final String? signatureUrl = rps['users']?['signature_url'];
    final String namaDosen = rps['users']?['nama'] ?? 'Dosen Pengampu';

    pw.ImageProvider? signatureImage;

    // --- DOWNLOAD GAMBAR SAJA (TIDAK USAH DIOLAH PIKSELNYA) ---
    if (signatureUrl != null && signatureUrl.isNotEmpty) {
      try {
        final response = await http.get(Uri.parse(signatureUrl));
        final Uint8List bytes = response.bodyBytes;
        signatureImage = pw.MemoryImage(bytes);
      } catch (e) {
        print("Gagal memuat tanda tangan: $e");
      }
    }

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Center(
                child: pw.Text("RENCANA PEMBELAJARAN SEMESTER (RPS)",
                    style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
              ),
              pw.SizedBox(height: 20),
              pw.Text("Mata Kuliah: ${rps['mata_kuliah']?['nama_mk']}"),
              pw.Text("Kode: ${rps['mata_kuliah']?['kode_mk']}"),
              pw.Text("Semester: ${rps['semester']}"),
              pw.Text("Tahun Ajaran: ${rps['tahun_ajaran']}"),
              pw.SizedBox(height: 20),
              pw.Text("Capaian Pembelajaran (CPMK):",
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 10),

              // TABEL MAPPING
              pw.TableHelper.fromTextArray(
                headers: ['No', 'Deskripsi CPMK', 'CPL Terkait'],
                data: mapping.map((item) {
                  final index = mapping.indexOf(item) + 1;
                  final cpls = (item['mapping_cpl_cpmk'] as List)
                      .map((m) => m['cpl']['kode_cpl'].toString())
                      .join(', ');
                  return [index.toString(), item['deskripsi'], cpls];
                }).toList(),
              ),

              pw.Spacer(),

              // TANDA TANGAN
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.end,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.center,
                    children: [
                      pw.Text("Tangerang, ${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}"),
                      pw.Text("Dosen Pengampu,"),
                      pw.SizedBox(height: 10),

                      // --- BAGIAN INI YANG PENTING GUNG ---
                      signatureImage != null
                          ? pw.Container(
                              height: 60,
                              width: 100,
                              child: pw.Image(signatureImage),
                            )
                          : pw.SizedBox(height: 60),

                      pw.Text(namaDosen,
                          style: pw.TextStyle(
                              fontWeight: pw.FontWeight.bold,
                              decoration: pw.TextDecoration.underline)),
                    ],
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );

    await Printing.layoutPdf(onLayout: (PdfPageFormat format) async => pdf.save());
  }
}