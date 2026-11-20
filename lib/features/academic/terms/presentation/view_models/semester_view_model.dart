import 'package:flutter/foundation.dart';
import 'package:ruangrencana/core/errors/app_failure.dart';
import 'package:ruangrencana/features/academic/grades/data/repositories/academic_repository.dart';
import 'package:ruangrencana/features/academic/terms/data/models/academic_term_item.dart';

/// ViewModel untuk manajemen semester akademik (melihat daftar, aktivasi, tambah, edit, hapus).
class SemesterViewModel extends ChangeNotifier {
  SemesterViewModel({required this.repository, this.onActiveSemesterChanged}) {
    refresh();
  }

  final AcademicRepository repository;
  final AsyncCallback? onActiveSemesterChanged;

  List<AcademicTermItem> _semesters = const [];
  AcademicTermItem? _activeSemester;
  bool _isLoading = false;
  String? _errorMessage;

  List<AcademicTermItem> get semesters => _semesters;
  AcademicTermItem? get activeSemester => _activeSemester;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  /// Daftar semester lampau (selesai atau tidak aktif).
  List<AcademicTermItem> get historicalSemesters =>
      _semesters.where((s) => !s.isActive).toList(growable: false);

  void refresh() {
    _semesters = repository.getAllSemesters();
    _activeSemester = repository.getActiveSemester();
    _errorMessage = null;
    notifyListeners();
  }

  Future<bool> setActiveSemester(int id) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await repository.setActiveSemester(id);
      refresh();
      if (onActiveSemesterChanged != null) {
        await onActiveSemesterChanged!();
      }
      return true;
    } on AppFailure catch (e) {
      _errorMessage = e.message;
      return false;
    } catch (e) {
      _errorMessage = 'Gagal mengaktifkan semester: $e';
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<int?> createSemester({
    required String academicYear,
    required String semesterName,
    required int semesterNumber,
    DateTime? startDate,
    DateTime? endDate,
    int? gradingScaleId,
    bool makeActive = false,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final newId = await repository.createSemester(
        academicYear: academicYear,
        semesterName: semesterName,
        semesterNumber: semesterNumber,
        startDate: startDate,
        endDate: endDate,
        gradingScaleId: gradingScaleId,
        makeActive: makeActive,
      );
      refresh();
      if (makeActive && onActiveSemesterChanged != null) {
        await onActiveSemesterChanged!();
      }
      return newId;
    } on AppFailure catch (e) {
      _errorMessage = e.message;
      return null;
    } catch (e) {
      _errorMessage = 'Gagal membuat semester: $e';
      return null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> updateSemester({
    required int id,
    required String academicYear,
    required String semesterName,
    required int semesterNumber,
    DateTime? startDate,
    DateTime? endDate,
    int? gradingScaleId,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await repository.updateSemester(
        id: id,
        academicYear: academicYear,
        semesterName: semesterName,
        semesterNumber: semesterNumber,
        startDate: startDate,
        endDate: endDate,
        gradingScaleId: gradingScaleId,
      );
      refresh();
      if (onActiveSemesterChanged != null) {
        await onActiveSemesterChanged!();
      }
      return true;
    } on AppFailure catch (e) {
      _errorMessage = e.message;
      return false;
    } catch (e) {
      _errorMessage = 'Gagal memperbarui semester: $e';
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> deleteSemester(int id) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await repository.deleteSemester(id);
      refresh();
      return true;
    } on AppFailure catch (e) {
      _errorMessage = e.message;
      return false;
    } catch (e) {
      _errorMessage = 'Gagal menghapus semester: $e';
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
