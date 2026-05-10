import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class PdfHelper {
  static Future<void> cetakRps(Map<String, dynamic> rps, List<Map<String, dynamic>> mapping) async {
    final pdf = pw.Document();

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
              pw.Text("Capaian Pembelajaran (CPMK):", style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 10),
              
              // Tabel Mapping
              pw.TableHelper.fromTextArray(
                headers: ['No', 'Deskripsi CPMK', 'CPL Terkait'],
                data: mapping.map((item) {
                  final index = mapping.indexOf(item) + 1;
                  // Mengambil semua kode CPL yang di-mapping ke CPMK ini
                  final cpls = (item['mapping_cpl_cpmk'] as List)
                      .map((m) => m['cpl']['kode_cpl'].toString())
                      .join(', ');
                  
                  return [index.toString(), item['deskripsi'], cpls];
                }).toList(),
              ),
            ],
          );
        },
      ),
    );

    // Langsung munculin dialog print/save
    await Printing.layoutPdf(onLayout: (PdfPageFormat format) async => pdf.save());
  }
}