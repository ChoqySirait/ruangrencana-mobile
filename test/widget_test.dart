import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:ruangrencana/app/app.dart';

void main() {
  Future<void> pumpAppAtMobileViewport(
    WidgetTester tester, {
    String initialLocation = '/beranda',
  }) async {
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(RuangRencanaApp(initialLocation: initialLocation));
    await tester.pumpAndSettle();
  }

  testWidgets('Navigasi lima destinasi utama berjalan tanpa error overflow', (
    tester,
  ) async {
    await pumpAppAtMobileViewport(tester);

    // 1. Beranda
    expect(find.textContaining('Nadia'), findsOneWidget);
    expect(find.text('IPS Sementara'), findsOneWidget);
    expect(find.text('IPK Kumulatif'), findsOneWidget);
    expect(find.text('SKS Aktif'), findsOneWidget);

    // 2. Pindah ke Jadwal
    await tester.tap(
      find.descendant(
        of: find.byType(NavigationBar),
        matching: find.text('Jadwal'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Jadwal Kuliah'), findsOneWidget);

    // 3. Pindah ke Tugas & uji filter
    await tester.tap(
      find.descendant(
        of: find.byType(NavigationBar),
        matching: find.text('Tugas'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Tugas Kuliah'), findsOneWidget);
    expect(find.textContaining('Mendatang'), findsWidgets);
    expect(find.textContaining('Terlambat'), findsWidgets);
    expect(find.textContaining('Selesai'), findsWidgets);

    // 4. Pindah ke Akademik
    await tester.tap(
      find.descendant(
        of: find.byType(NavigationBar),
        matching: find.text('Akademik'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Performa Akademik'), findsOneWidget);
    expect(find.text('Simulasi Nilai & Proyeksi IPS'), findsOneWidget);

    // 5. Pindah ke Profil
    await tester.tap(
      find.descendant(
        of: find.byType(NavigationBar),
        matching: find.text('Profil'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Nadia Putri Pratama'), findsOneWidget);
    expect(find.text('Skala Konversi Nilai Kampus'), findsOneWidget);
  });

  testWidgets('Rute sekunder Simulasi Nilai dan Tambah Tugas dapat dibuka', (
    tester,
  ) async {
    await pumpAppAtMobileViewport(tester);

    // Buka Simulasi Nilai dari aksi cepat di Beranda
    await tester.tap(find.text('Simulasi Nilai'));
    await tester.pumpAndSettle();
    expect(find.text('Proyeksi IPS'), findsOneWidget);
    expect(find.text('Proyeksi IPK'), findsOneWidget);

    // Kembali ke Beranda
    await tester.pageBack();
    await tester.pumpAndSettle();

    // Buka Tambah Tugas dari aksi cepat di Beranda
    await tester.tap(find.text('Tambah Tugas'));
    await tester.pumpAndSettle();
    expect(find.text('Simpan Tugas'), findsOneWidget);
  });

  testWidgets('Rute sekunder Detail Mata Kuliah dapat dibuka dari Jadwal', (
    tester,
  ) async {
    await pumpAppAtMobileViewport(
      tester,
      initialLocation: '/mata-kuliah/mk-mob',
    );
    expect(find.text('Pemrograman Mobile'), findsOneWidget);
    expect(find.text('Komponen Penilaian'), findsOneWidget);
  });
}
