import 'package:flutter/foundation.dart';
import 'package:ruangrencana/core/errors/app_failure.dart';
import 'package:ruangrencana/features/academic/grades/data/repositories/academic_repository.dart';
import 'package:ruangrencana/features/academic/scales/data/models/grading_scale_item.dart';

/// ViewModel untuk menampilkan dan mengelola profil skala konversi nilai universitas.
class GradingScalesViewModel extends ChangeNotifier {
  GradingScalesViewModel({required this.repository, this.onScalesChanged}) {
    loadScales();
  }

  final AcademicRepository repository;
  final AsyncCallback? onScalesChanged;

  List<GradingScaleItem> _scales = const [];
  GradingScaleItem? _defaultScale;
  bool _isLoading = false;
  String? _errorMessage;

  List<GradingScaleItem> get scales => _scales;
  GradingScaleItem? get defaultScale => _defaultScale;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  void loadScales() {
    _scales = repository.getAllGradingScales();
    _defaultScale = repository.getDefaultGradingScale();
    _errorMessage = null;
    notifyListeners();
  }

  Future<bool> setDefaultScale(int id) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await repository.setDefaultGradingScale(id);
      loadScales();
      if (onScalesChanged != null) await onScalesChanged!();
      return true;
    } on AppFailure catch (e) {
      _errorMessage = e.message;
      return false;
    } catch (e) {
      _errorMessage = 'Gagal menetapkan skala default: $e';
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> deleteScale(int id) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await repository.deleteGradingScale(id);
      loadScales();
      if (onScalesChanged != null) await onScalesChanged!();
      return true;
    } on AppFailure catch (e) {
      _errorMessage = e.message;
      return false;
    } catch (e) {
      _errorMessage = 'Gagal menghapus skala penilaian: $e';
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<int?> duplicateScale({
    required int sourceId,
    required String newName,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final newId = await repository.duplicateGradingScale(
        sourceScaleId: sourceId,
        newName: newName,
      );
      loadScales();
      if (onScalesChanged != null) await onScalesChanged!();
      return newId;
    } on AppFailure catch (e) {
      _errorMessage = e.message;
      return null;
    } catch (e) {
      _errorMessage = 'Gagal menduplikasi skala: $e';
      return null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
