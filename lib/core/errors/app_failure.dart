/// Representasi kegagalan domain/aplikasi yang terstruktur.
///
/// Kelas ini disiapkan sebagai kontrak konsisten untuk penanganan error
/// pada ViewModel maupun implementasi Repository berbasis SQLite nantinya.
class AppFailure implements Exception {
  const AppFailure(this.message, {this.code});

  final String message;
  final String? code;

  @override
  String toString() =>
      code == null ? 'AppFailure: $message' : 'AppFailure($code): $message';
}
