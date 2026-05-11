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
    final listPertemuan = (rps['rps_detail'] as List?) ?? [];

    pw.ImageProvider? signatureImage;

    // --- DOWNLOAD TANDA TANGAN DENGAN PENANGANAN ERROR ---
    if (signatureUrl != null && signatureUrl.isNotEmpty) {
      try {
        print("Sedang mengunduh tanda tangan dari: $signatureUrl");
        final response = await http
            .get(Uri.parse(signatureUrl))
            .timeout(const Duration(seconds: 10)); // Tambahkan timeout agar tidak menunggu selamanya

        if (response.statusCode == 200) {
          final Uint8List bytes = response.bodyBytes;
          if (bytes.isNotEmpty) {
            signatureImage = pw.MemoryImage(bytes);
            print("Tanda tangan berhasil dimuat.");
          }
        } else {
          print("Gagal mengunduh gambar. Status Code: ${response.statusCode}");
        }
      } catch (e) {
        print("Terjadi kesalahan saat memuat tanda tangan: $e");
      }
    }

    // --- HALAMAN UTAMA & RENCANA MINGGUAN ---
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return [
            // 1. HEADER INFORMASI UMUM
            pw.Center(
              child: pw.Text("RENCANA PEMBELAJARAN SEMESTER (RPS)",
                  style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
            ),
            pw.SizedBox(height: 20),
            pw.Text("Mata Kuliah: ${rps['mata_kuliah']?['nama_mk']}"),
            pw.Text("Kode: ${rps['mata_kuliah']?['kode_mk']}"),
            pw.Text("Semester: ${rps['semester']}"),
            pw.Text("Tahun Ajaran: ${rps['tahun_ajaran']}"),
            pw.SizedBox(height: 20),

            // 2. TABEL CPMK
            pw.Text("Capaian Pembelajaran (CPMK):",
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 10),
            pw.TableHelper.fromTextArray(
              headers: ['No', 'Deskripsi CPMK', 'CPL Terkait'],
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
              data: mapping.map((item) {
                final index = mapping.indexOf(item) + 1;
                final cpls = (item['mapping_cpl_cpmk'] as List)
                    .map((m) => m['cpl']['kode_cpl'].toString())
                    .join(', ');
                return [index.toString(), item['deskripsi'], cpls];
              }).toList(),
            ),

            pw.SizedBox(height: 20),

            // 3. TABEL RENCANA PERTEMUAN MINGGUAN
            pw.Text("RENCANA PEMBELAJARAN MINGGUAN",
                style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 10),
            pw.TableHelper.fromTextArray(
              headers: ['Minggu', 'Kemampuan Akhir / Materi', 'Metode', 'Bobot'],
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
              cellAlignment: pw.Alignment.centerLeft,
              columnWidths: {
                0: const pw.FixedColumnWidth(40),
                1: const pw.FlexColumnWidth(3),
                2: const pw.FlexColumnWidth(2),
                3: const pw.FixedColumnWidth(40),
              },
              data: listPertemuan.isNotEmpty
                  ? listPertemuan.map((p) {
                      return [
                        p['minggu_ke'].toString(),
                        p['kemampuan_akhir'] ?? '-',
                        p['metode_pembelajaran'] ?? '-',
                        "${p['bobot_nilai']}%",
                      ];
                    }).toList()
                  : [['-', 'Belum ada data pertemuan', '-', '-']],
            ),

            pw.SizedBox(height: 30),

            // 4. TANDA TANGAN
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.end,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.center,
                  children: [
                    pw.Text("Tangerang, ${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}"),
                    pw.Text("Dosen Pengampu,"),
                    pw.SizedBox(height: 10),
                    signatureImage != null
                        ? pw.Container(
                            height: 60,
                            width: 100,
                            child: pw.Image(signatureImage),
                          )
                        : pw.SizedBox(height: 60), // Space kosong jika gambar gagal muat
                    pw.Text(namaDosen,
                        style: pw.TextStyle(
                            fontWeight: pw.FontWeight.bold,
                            decoration: pw.TextDecoration.underline)),
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
}