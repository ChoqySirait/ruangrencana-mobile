import 'package:flutter/foundation.dart';
import 'package:ruangrencana/core/errors/app_failure.dart';
import 'package:ruangrencana/core/utils/academic_calculator.dart';
import 'package:ruangrencana/features/academic/grades/data/repositories/academic_repository.dart';
import 'package:ruangrencana/features/academic/terms/data/models/academic_term_item.dart';

/// Draf representasi rentang skor untuk formulir konfigurasi skala nilai.
class GradingScaleRangeDraft {
  GradingScaleRangeDraft({
    this.id,
    required this.letter,
    required this.gradePoint,
    required this.minScore,
    required this.maxScore,
  });

  final int? id;
  String letter;
  double gradePoint;
  double minScore;
  double maxScore;

  GradeScaleRule toRule() => GradeScaleRule(
    letter: letter.trim(),
    gradePoint: gradePoint,
    minScore: minScore,
    maxScore: maxScore,
  );

  GradingScaleRangeDraft copyWith({
    int? id,
    String? letter,
    double? gradePoint,
    double? minScore,
    double? maxScore,
  }) {
    return GradingScaleRangeDraft(
      id: id ?? this.id,
      letter: letter ?? this.letter,
      gradePoint: gradePoint ?? this.gradePoint,
      minScore: minScore ?? this.minScore,
      maxScore: maxScore ?? this.maxScore,
    );
  }
}

/// ViewModel untuk membuat atau mengubah konfigurasi skala konversi nilai universitas.
class GradingScaleFormViewModel extends ChangeNotifier {
  GradingScaleFormViewModel({
    required this.repository,
    this.scaleId,
    this.onSaved,
  }) {
    _init();
  }

  final AcademicRepository repository;
  final int? scaleId;
  final AsyncCallback? onSaved;

  String _name = '';
  bool _isDefault = false;
  final List<GradingScaleRangeDraft> _ranges = [];
  bool _isLoading = false;
  String? _errorMessage;
  List<AcademicTermItem> _affectedTerms = const [];

  String get name => _name;
  bool get isDefault => _isDefault;
  List<GradingScaleRangeDraft> get ranges => List.unmodifiable(_ranges);
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  List<AcademicTermItem> get affectedTerms => _affectedTerms;
  bool get isEditing => scaleId != null;

  List<GradeScaleRule> get currentRules =>
      _ranges.map((r) => r.toRule()).toList(growable: false);

  GradingScaleValidationResult get validationResult =>
      AcademicCalculator.validateGradingScale(currentRules);

  bool get isValid => validationResult.isValid;

  Future<void> _init() async {
    if (scaleId != null) {
      final existing = repository.getGradingScaleById(scaleId!);
      if (existing != null) {
        _name = existing.name;
        _isDefault = existing.isDefault;
        _ranges.clear();
        for (final r in existing.ranges) {
          _ranges.add(
            GradingScaleRangeDraft(
              id: r.id,
              letter: r.letterGrade,
              gradePoint: r.gradePoint,
              minScore: r.minimumScore,
              maxScore: r.maximumScore,
            ),
          );
        }
      }
      try {
        _affectedTerms = await repository.getTermsUsingScale(scaleId!);
      } catch (_) {
        _affectedTerms = const [];
      }
    } else {
      // Default ke preset Standar 4.00 jika skala baru
      applyPreset('standard_plus_minus');
      _name = 'Skala Baru';
    }
    notifyListeners();
  }

  void setName(String val) {
    _name = val;
    notifyListeners();
  }

  void setIsDefault(bool val) {
    _isDefault = val;
    notifyListeners();
  }

  void addRange() {
    // Sisipkan rentang baru di akhir atau batas bawah
    double newMin = 0.0;
    double newMax = 44.99;
    if (_ranges.isNotEmpty) {
      final last = _ranges.last;
      newMin = (last.minScore - 10.0).clamp(0.0, 100.0);
      newMax = (last.minScore - 0.01).clamp(0.0, 100.0);
    }
    _ranges.add(
      GradingScaleRangeDraft(
        letter: '?',
        gradePoint: 0.0,
        minScore: newMin,
        maxScore: newMax,
      ),
    );
    notifyListeners();
  }

  void updateRange(
    int index, {
    String? letter,
    double? gradePoint,
    double? minScore,
    double? maxScore,
  }) {
    if (index >= 0 && index < _ranges.length) {
      final curr = _ranges[index];
      _ranges[index] = curr.copyWith(
        letter: letter,
        gradePoint: gradePoint,
        minScore: minScore,
        maxScore: maxScore,
      );
      notifyListeners();
    }
  }

  void removeRange(int index) {
    if (index >= 0 && index < _ranges.length) {
      _ranges.removeAt(index);
      notifyListeners();
    }
  }

  void applyPreset(String presetKey) {
    _ranges.clear();
    switch (presetKey) {
      case 'standard_plus_minus':
        _ranges.addAll([
          GradingScaleRangeDraft(
            letter: 'A',
            gradePoint: 4.00,
            minScore: 85.0,
            maxScore: 100.0,
          ),
          GradingScaleRangeDraft(
            letter: 'A-',
            gradePoint: 3.70,
            minScore: 80.0,
            maxScore: 84.99,
          ),
          GradingScaleRangeDraft(
            letter: 'B+',
            gradePoint: 3.30,
            minScore: 75.0,
            maxScore: 79.99,
          ),
          GradingScaleRangeDraft(
            letter: 'B',
            gradePoint: 3.00,
            minScore: 70.0,
            maxScore: 74.99,
          ),
          GradingScaleRangeDraft(
            letter: 'B-',
            gradePoint: 2.70,
            minScore: 65.0,
            maxScore: 69.99,
          ),
          GradingScaleRangeDraft(
            letter: 'C+',
            gradePoint: 2.30,
            minScore: 60.0,
            maxScore: 64.99,
          ),
          GradingScaleRangeDraft(
            letter: 'C',
            gradePoint: 2.00,
            minScore: 55.0,
            maxScore: 59.99,
          ),
          GradingScaleRangeDraft(
            letter: 'D',
            gradePoint: 1.00,
            minScore: 45.0,
            maxScore: 54.99,
          ),
          GradingScaleRangeDraft(
            letter: 'E',
            gradePoint: 0.00,
            minScore: 0.0,
            maxScore: 44.99,
          ),
        ]);
        break;
      case 'simple_5':
        _ranges.addAll([
          GradingScaleRangeDraft(
            letter: 'A',
            gradePoint: 4.00,
            minScore: 85.0,
            maxScore: 100.0,
          ),
          GradingScaleRangeDraft(
            letter: 'B',
            gradePoint: 3.00,
            minScore: 70.0,
            maxScore: 84.99,
          ),
          GradingScaleRangeDraft(
            letter: 'C',
            gradePoint: 2.00,
            minScore: 55.0,
            maxScore: 69.99,
          ),
          GradingScaleRangeDraft(
            letter: 'D',
            gradePoint: 1.00,
            minScore: 40.0,
            maxScore: 54.99,
          ),
          GradingScaleRangeDraft(
            letter: 'E',
            gradePoint: 0.00,
            minScore: 0.0,
            maxScore: 39.99,
          ),
        ]);
        break;
      case 'scale_7':
        _ranges.addAll([
          GradingScaleRangeDraft(
            letter: 'A',
            gradePoint: 4.00,
            minScore: 85.0,
            maxScore: 100.0,
          ),
          GradingScaleRangeDraft(
            letter: 'AB',
            gradePoint: 3.50,
            minScore: 77.5,
            maxScore: 84.99,
          ),
          GradingScaleRangeDraft(
            letter: 'B',
            gradePoint: 3.00,
            minScore: 70.0,
            maxScore: 77.49,
          ),
          GradingScaleRangeDraft(
            letter: 'BC',
            gradePoint: 2.50,
            minScore: 62.5,
            maxScore: 69.99,
          ),
          GradingScaleRangeDraft(
            letter: 'C',
            gradePoint: 2.00,
            minScore: 55.0,
            maxScore: 62.49,
          ),
          GradingScaleRangeDraft(
            letter: 'D',
            gradePoint: 1.00,
            minScore: 40.0,
            maxScore: 54.99,
          ),
          GradingScaleRangeDraft(
            letter: 'E',
            gradePoint: 0.00,
            minScore: 0.0,
            maxScore: 39.99,
          ),
        ]);
        break;
    }
    notifyListeners();
  }

  Future<int?> save({bool saveAsNewDuplicate = false}) async {
    final validation = validationResult;
    if (!validation.isValid) {
      _errorMessage = validation.errors.first;
      notifyListeners();
      return null;
    }

    if (_name.trim().isEmpty) {
      _errorMessage = 'Nama skala penilaian tidak boleh kosong.';
      notifyListeners();
      return null;
    }

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      int resultId;
      if (isEditing && !saveAsNewDuplicate) {
        await repository.updateGradingScale(
          id: scaleId!,
          name: _name.trim(),
          isDefault: _isDefault,
          ranges: currentRules,
        );
        resultId = scaleId!;
      } else {
        final targetName = saveAsNewDuplicate
            ? '$_name (Salinan)'
            : _name.trim();
        resultId = await repository.createGradingScale(
          name: targetName,
          isDefault: _isDefault,
          initialRanges: currentRules,
        );
      }

      if (onSaved != null) await onSaved!();
      return resultId;
    } on AppFailure catch (e) {
      _errorMessage = e.message;
      return null;
    } catch (e) {
      _errorMessage = 'Gagal menyimpan konfigurasi skala nilai: $e';
      return null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
