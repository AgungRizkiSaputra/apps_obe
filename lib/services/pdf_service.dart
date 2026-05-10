import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class PdfService {
  static Future<void> generateRpsPdf(Map<String, dynamic> rpsData, List<Map<String, dynamic>> mappingData) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // HEADER
              pw.Center(
                child: pw.Text("RENCANA PEMBELAJARAN SEMESTER (RPS)",
                    style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
              ),
              pw.SizedBox(height: 20),

              // TABEL INFORMASI MK
              pw.TableHelper.fromTextArray(
                context: context,
                data: [
                  ['Mata Kuliah', rpsData['mata_kuliah']?['nama_mk'] ?? '-'],
                  ['Kode / SKS', "${rpsData['mata_kuliah']?['kode_mk']} / ${rpsData['mata_kuliah']?['sks']}"],
                  ['Semester', rpsData['semester'] ?? '-'],
                  ['Dosen Pengampu', rpsData['users']?['nama'] ?? '-'],
                ],
              ),
              pw.SizedBox(height: 20),

              // BAGIAN CPMK & CPL
              pw.Text("Capaian Pembelajaran (OBE Mapping):",
                  style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 10),

              pw.TableHelper.fromTextArray(
                context: context,
                headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                headers: ['No', 'CPMK (Deskripsi)', 'Korelasi CPL'],
                data: List.generate(mappingData.length, (index) {
                  final item = mappingData[index];
                  return [
                    (index + 1).toString(),
                    item['deskripsi_cpmk'] ?? '-',
                    // Di sini kita asumsikan mappingData sudah join dengan kode_cpl
                    item['cpl_kode'] ?? '-', 
                  ];
                }),
              ),
            ],
          );
        },
      ),
    );

    // Menampilkan Preview PDF sebelum dicetak/save
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
    );
  }
}