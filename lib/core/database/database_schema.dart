/// Definisi konstanta nama tabel, nama kolom, serta skrip DDL
/// untuk Skema Database SQLite RuangRencana Versi 1.
abstract final class DatabaseSchema {
  static const int version = 1;
  static const String databaseName = 'ruangrencana.db';

  // --- NAMA-NAMA TABEL ---
  static const String tableStudentProfiles = 'student_profiles';
  static const String tableAcademicTerms = 'academic_terms';
  static const String tableCourses = 'courses';
  static const String tableClassSchedules = 'class_schedules';
  static const String tableAssignments = 'assignments';
  static const String tableAssessmentComponents = 'assessment_components';
  static const String tableAssessmentScores = 'assessment_scores';
  static const String tableGradingScales = 'grading_scales';
  static const String tableGradingScaleRanges = 'grading_scale_ranges';
  static const String tableAppPreferences = 'app_preferences';

  // --- DDL SKRIP PEMBUATAN TABEL (VERSI 1) ---

  static const String createTableStudentProfiles =
      '''
    CREATE TABLE $tableStudentProfiles (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      full_name TEXT NOT NULL,
      student_number TEXT,
      study_program TEXT NOT NULL,
      institution_name TEXT NOT NULL,
      created_at TEXT NOT NULL,
      updated_at TEXT NOT NULL
    );
  ''';

  static const String createTableGradingScales =
      '''
    CREATE TABLE $tableGradingScales (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      scale_name TEXT NOT NULL,
      is_default INTEGER NOT NULL DEFAULT 0 CHECK (is_default IN (0, 1)),
      created_at TEXT NOT NULL,
      updated_at TEXT NOT NULL
    );
  ''';

  static const String createTableGradingScaleRanges =
      '''
    CREATE TABLE $tableGradingScaleRanges (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      grading_scale_id INTEGER NOT NULL REFERENCES $tableGradingScales(id) ON DELETE CASCADE,
      minimum_score REAL NOT NULL CHECK (minimum_score >= 0.0 AND minimum_score <= 100.0),
      maximum_score REAL NOT NULL CHECK (maximum_score >= 0.0 AND maximum_score <= 100.0),
      letter_grade TEXT NOT NULL,
      grade_point REAL NOT NULL CHECK (grade_point >= 0.0),
      CHECK (minimum_score <= maximum_score)
    );
  ''';

  static const String createTableAcademicTerms =
      '''
    CREATE TABLE $tableAcademicTerms (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      academic_year TEXT NOT NULL,
      semester_name TEXT NOT NULL,
      semester_number INTEGER NOT NULL CHECK (semester_number > 0),
      start_date TEXT,
      end_date TEXT,
      grading_scale_id INTEGER NOT NULL REFERENCES $tableGradingScales(id) ON DELETE RESTRICT,
      is_active INTEGER NOT NULL DEFAULT 0 CHECK (is_active IN (0, 1)),
      created_at TEXT NOT NULL,
      updated_at TEXT NOT NULL
    );
  ''';

  static const String createTableCourses =
      '''
    CREATE TABLE $tableCourses (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      academic_term_id INTEGER NOT NULL REFERENCES $tableAcademicTerms(id) ON DELETE CASCADE,
      course_code TEXT NOT NULL,
      course_name TEXT NOT NULL,
      credits INTEGER NOT NULL CHECK (credits > 0),
      lecturer_name TEXT NOT NULL DEFAULT '',
      archived_at TEXT,
      created_at TEXT NOT NULL,
      updated_at TEXT NOT NULL
    );
  ''';

  static const String createTableClassSchedules =
      '''
    CREATE TABLE $tableClassSchedules (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      course_id INTEGER NOT NULL REFERENCES $tableCourses(id) ON DELETE CASCADE,
      weekday INTEGER NOT NULL CHECK (weekday BETWEEN 1 AND 7),
      start_time TEXT NOT NULL,
      end_time TEXT NOT NULL,
      classroom TEXT NOT NULL DEFAULT '',
      created_at TEXT NOT NULL,
      updated_at TEXT NOT NULL
    );
  ''';

  static const String createTableAssignments =
      '''
    CREATE TABLE $tableAssignments (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      course_id INTEGER NOT NULL REFERENCES $tableCourses(id) ON DELETE CASCADE,
      title TEXT NOT NULL,
      description TEXT NOT NULL DEFAULT '',
      due_at TEXT NOT NULL,
      priority TEXT NOT NULL CHECK (priority IN ('low', 'medium', 'high')),
      status TEXT NOT NULL CHECK (status IN ('upcoming', 'overdue', 'completed')),
      completed_at TEXT,
      created_at TEXT NOT NULL,
      updated_at TEXT NOT NULL
    );
  ''';

  static const String createTableAssessmentComponents =
      '''
    CREATE TABLE $tableAssessmentComponents (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      course_id INTEGER NOT NULL REFERENCES $tableCourses(id) ON DELETE CASCADE,
      component_name TEXT NOT NULL,
      weight_percentage REAL NOT NULL CHECK (weight_percentage >= 0.0 AND weight_percentage <= 100.0),
      is_required INTEGER NOT NULL DEFAULT 1 CHECK (is_required IN (0, 1)),
      sort_order INTEGER NOT NULL DEFAULT 0,
      created_at TEXT NOT NULL,
      updated_at TEXT NOT NULL
    );
  ''';

  static const String createTableAssessmentScores =
      '''
    CREATE TABLE $tableAssessmentScores (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      assessment_component_id INTEGER NOT NULL REFERENCES $tableAssessmentComponents(id) ON DELETE CASCADE,
      score REAL NOT NULL CHECK (score >= 0.0 AND score <= 100.0),
      graded_at TEXT NOT NULL,
      notes TEXT NOT NULL DEFAULT ''
    );
  ''';

  static const String createTableAppPreferences =
      '''
    CREATE TABLE $tableAppPreferences (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      preference_key TEXT NOT NULL UNIQUE,
      preference_value TEXT NOT NULL,
      updated_at TEXT NOT NULL
    );
  ''';

  // --- DDL SKRIP INDEKS UNTUK PENGOPTIMALAN QUERY ---

  static const List<String> createIndexes = [
    'CREATE INDEX idx_academic_terms_is_active ON $tableAcademicTerms(is_active);',
    'CREATE INDEX idx_academic_terms_grading_scale ON $tableAcademicTerms(grading_scale_id);',
    'CREATE INDEX idx_courses_academic_term ON $tableCourses(academic_term_id);',
    'CREATE INDEX idx_courses_archived_at ON $tableCourses(archived_at);',
    'CREATE INDEX idx_class_schedules_course ON $tableClassSchedules(course_id);',
    'CREATE INDEX idx_class_schedules_weekday ON $tableClassSchedules(weekday);',
    'CREATE INDEX idx_assignments_course ON $tableAssignments(course_id);',
    'CREATE INDEX idx_assignments_due_at ON $tableAssignments(due_at);',
    'CREATE INDEX idx_assignments_status ON $tableAssignments(status);',
    'CREATE INDEX idx_assessment_components_course ON $tableAssessmentComponents(course_id);',
    'CREATE INDEX idx_assessment_scores_component ON $tableAssessmentScores(assessment_component_id);',
    'CREATE INDEX idx_grading_scale_ranges_scale ON $tableGradingScaleRanges(grading_scale_id);',
    'CREATE INDEX idx_app_preferences_key ON $tableAppPreferences(preference_key);',
  ];

  /// Daftar seluruh eksekusi DDL pembuatan tabel dalam urutan integritas referensial.
  static const List<String> createTableStatements = [
    createTableStudentProfiles,
    createTableGradingScales,
    createTableGradingScaleRanges,
    createTableAcademicTerms,
    createTableCourses,
    createTableClassSchedules,
    createTableAssignments,
    createTableAssessmentComponents,
    createTableAssessmentScores,
    createTableAppPreferences,
  ];
}
