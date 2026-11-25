import 'dart:async';
import 'package:flutter/material.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const AlRowadSchoolApp());
}

// ============================================================================
// 1. النماذج والأنواع (Models & Enums)
// ============================================================================

enum UserRole {
  admin('مدير النظام', 'الإحصائيات والتعاميم والجدول والكتب', Icons.admin_panel_settings_rounded),
  teacher('معلم', 'الحضور والدرجات والواجبات', Icons.cast_for_education_rounded),
  studentParent('طالب / ولي أمر', 'الجدول والواجبات والتقييمات والإشعارات', Icons.family_restroom_rounded);

  final String label;
  final String subtitle;
  final IconData icon;
  const UserRole(this.label, this.subtitle, this.icon);
}

enum StageCategory {
  kg('رياض الأطفال (KG1 - KG2)', 'رياض الأطفال', Color(0xFFEC4899), Icons.child_care_rounded),
  primary('المرحلة الابتدائية (1 - 6)', 'الابتدائية', Color(0xFF0EA5E9), Icons.menu_book_rounded),
  prep('المرحلة الإعدادية (1 - 3)', 'الإعدادية', Color(0xFF6366F1), Icons.science_rounded);

  final String label;
  final String shortLabel;
  final Color color;
  final IconData icon;
  const StageCategory(this.label, this.shortLabel, this.color, this.icon);
}

enum GradeLevel {
  kg1('حضانة - المستوى الأول (KG1)', 'KG1', StageCategory.kg),
  kg2('حضانة - المستوى الثاني (KG2)', 'KG2', StageCategory.kg),
  p1('الصف الأول الابتدائي', '1 ابتدائي', StageCategory.primary),
  p2('الصف الثاني الابتدائي', '2 ابتدائي', StageCategory.primary),
  p3('الصف الثالث الابتدائي', '3 ابتدائي', StageCategory.primary),
  p4('الصف الرابع الابتدائي', '4 ابتدائي', StageCategory.primary),
  p5('الصف الخامس الابتدائي', '5 ابتدائي', StageCategory.primary),
  p6('الصف السادس الابتدائي', '6 ابتدائي', StageCategory.primary),
  prep1('الصف الأول الإعدادي', '1 إعدادي', StageCategory.prep),
  prep2('الصف الثاني الإعدادي', '2 إعدادي', StageCategory.prep),
  prep3('الصف الثالث الإعدادي', '3 إعدادي', StageCategory.prep);

  final String label;
  final String shortLabel;
  final StageCategory category;
  const GradeLevel(this.label, this.shortLabel, this.category);

  static List<GradeLevel> byCategory(StageCategory cat) =>
      GradeLevel.values.where((g) => g.category == cat).toList();
}

enum AttendanceStatus {
  present('حاضر', Color(0xFF10B981), Icons.check_circle_rounded),
  absent('غائب', Color(0xFFEF4444), Icons.cancel_rounded),
  late('متأخر', Color(0xFFF59E0B), Icons.access_time_filled_rounded);

  final String label;
  final Color color;
  final IconData icon;
  const AttendanceStatus(this.label, this.color, this.icon);
}

class StudentRecord {
  final String id;
  final String name;
  final GradeLevel grade;
  final String parentPhone;
  AttendanceStatus attendance;
  StudentRecord({
    required this.id,
    required this.name,
    required this.grade,
    required this.parentPhone,
    this.attendance = AttendanceStatus.present,
  });
}

class AnnouncementItem {
  final String id, title, body, author, dateLabel;
  final StageCategory? targetStage;
  final bool isUrgent;
  bool isRead;
  AnnouncementItem({
    required this.id,
    required this.title,
    required this.body,
    required this.targetStage,
    required this.author,
    required this.dateLabel,
    this.isUrgent = false,
    this.isRead = false,
  });
}

class ScheduleSlot {
  final String id, day, timeRange, subject, teacherName, classroom;
  final GradeLevel grade;
  final int period;
  ScheduleSlot({
    required this.id,
    required this.grade,
    required this.day,
    required this.period,
    required this.timeRange,
    required this.subject,
    required this.teacherName,
    required this.classroom,
  });
}

class HomeworkItem {
  final String id, subject, title, details, dueDate, teacherName;
  final GradeLevel grade;
  bool isCompleted;
  HomeworkItem({
    required this.id,
    required this.grade,
    required this.subject,
    required this.title,
    required this.details,
    required this.dueDate,
    required this.teacherName,
    this.isCompleted = false,
  });
}

class GradeEvaluation {
  final String id, studentName, subject, examTitle, skillEvaluation, teacherNote;
  final GradeLevel grade;
  final double score, maxScore;
  GradeEvaluation({
    required this.id,
    required this.studentName,
    required this.grade,
    required this.subject,
    required this.examTitle,
    required this.score,
    required this.maxScore,
    required this.skillEvaluation,
    required this.teacherNote,
  });
}

class SchoolResource {
  final String id, title, resourceType, linkOrFile, addedAt;
  final StageCategory stage;
  final GradeLevel? grade;
  SchoolResource({
    required this.id,
    required this.title,
    required this.resourceType,
    required this.stage,
    this.grade,
    required this.linkOrFile,
    required this.addedAt,
  });
}

// ============================================================================
// 2. إدارة الحالة المركزية (Reactive Local State Management)
// ============================================================================

class AlRowadAppState extends ChangeNotifier {
  UserRole? _currentRole;
  StageCategory _selectedStage = StageCategory.primary;
  GradeLevel _selectedGrade = GradeLevel.p4;
  String _userName = 'جنى محمد السيد';

  UserRole? get currentRole => _currentRole;
  StageCategory get selectedStage => _selectedStage;
  GradeLevel get selectedGrade => _selectedGrade;
  String get userName => _userName;

  static const List<String> weekDays = ['الأحد', 'الإثنين', 'الثلاثاء', 'الأربعاء', 'الخميس'];
  final int totalTeachersCount = 68;
  final int activeClassesCount = 34;

  final List<StudentRecord> _students = [
    StudentRecord(id: 's1', name: 'أنس كريم محمد', grade: GradeLevel.kg1, parentPhone: '01011223344'),
    StudentRecord(id: 's2', name: 'ليان أحمد حسن', grade: GradeLevel.kg1, parentPhone: '01022334455'),
    StudentRecord(id: 's3', name: 'ياسين محمود علي', grade: GradeLevel.kg2, parentPhone: '01033445566'),
    StudentRecord(id: 's4', name: 'مريم مصطفى سعيد', grade: GradeLevel.kg2, parentPhone: '01044556677', attendance: AttendanceStatus.late),
    StudentRecord(id: 's5', name: 'يوسف طارق إبراهيم', grade: GradeLevel.p1, parentPhone: '01112233445'),
    StudentRecord(id: 's6', name: 'سلمى خالد عبدالله', grade: GradeLevel.p2, parentPhone: '01122334456'),
    StudentRecord(id: 's7', name: 'عمر وليد فؤاد', grade: GradeLevel.p3, parentPhone: '01133445567'),
    StudentRecord(id: 's8', name: 'جنى محمد السيد', grade: GradeLevel.p4, parentPhone: '01099887766'),
    StudentRecord(id: 's9', name: 'آدم حسام الدين', grade: GradeLevel.p4, parentPhone: '01088776655'),
    StudentRecord(id: 's10', name: 'حبيبة أشرف كمال', grade: GradeLevel.p4, parentPhone: '01077665544', attendance: AttendanceStatus.absent),
    StudentRecord(id: 's11', name: 'رقية عمرو فتحي', grade: GradeLevel.p5, parentPhone: '01211223344'),
    StudentRecord(id: 's12', name: 'زياد أيمن جمال', grade: GradeLevel.p6, parentPhone: '01222334455'),
    StudentRecord(id: 's13', name: 'معاذ ياسر نبيل', grade: GradeLevel.prep1, parentPhone: '01511223344'),
    StudentRecord(id: 's14', name: 'نور الهدى سامح', grade: GradeLevel.prep2, parentPhone: '01522334455'),
    StudentRecord(id: 's15', name: 'عبدالرحمن هاني صلاح', grade: GradeLevel.prep3, parentPhone: '01533445566'),
    StudentRecord(id: 's16', name: 'ملك تامر يوسف', grade: GradeLevel.prep3, parentPhone: '01544556677', attendance: AttendanceStatus.late),
  ];

  final List<AnnouncementItem> _announcements = [
    AnnouncementItem(
      id: 'a1',
      title: 'مسابقة الرواد للتميز العلمي والابتكار',
      body: 'تعلن إدارة مدرسة الرواد الخاصة عن فتح باب التسجيل في مسابقة أوائل الطلبة لجميع المراحل.',
      targetStage: null,
      author: 'إدارة المدرسة',
      dateLabel: 'اليوم - 09:30 ص',
      isUrgent: true,
    ),
    AnnouncementItem(
      id: 'a2',
      title: 'يوم الأنشطة الفنية لقسم رياض الأطفال',
      body: 'يسعدنا دعوة أطفال KG1 و KG2 ليوم الرسم وتنمية المهارات بحديقة المدرسة يوم الخميس.',
      targetStage: StageCategory.kg,
      author: 'مشرفة الحضانة',
      dateLabel: 'أمس - 01:15 م',
    ),
    AnnouncementItem(
      id: 'a3',
      title: 'جدول اختبارات شهر نوفمبر للمرحلة الابتدائية',
      body: 'تم اعتماد جدول التقييمات الشهرية للصفوف من الأول حتى السادس الابتدائي.',
      targetStage: StageCategory.primary,
      author: 'شؤون الطلاب',
      dateLabel: 'منذ يومين',
      isUrgent: true,
    ),
    AnnouncementItem(
      id: 'a4',
      title: 'مراجعات المعمل للمرحلة الإعدادية',
      body: 'تبدأ حصص التجارب العملية في العلوم لطلاب الإعدادي بداية من الأحد القادم.',
      targetStage: StageCategory.prep,
      author: 'أسرة العلوم',
      dateLabel: 'منذ 3 أيام',
    ),
  ];

  final List<ScheduleSlot> _schedule = [
    ScheduleSlot(id: 'sc1', grade: GradeLevel.kg1, day: 'الأحد', period: 1, timeRange: '08:00 - 08:45', subject: 'مهارات اللغة العربية', teacherName: 'أ. سارة مجدي', classroom: 'قاعة الفراشات'),
    ScheduleSlot(id: 'sc2', grade: GradeLevel.kg2, day: 'الأحد', period: 1, timeRange: '08:00 - 08:45', subject: 'English Phonics', teacherName: 'Ms. Rana Adel', classroom: 'قاعة النجوم'),
    ScheduleSlot(id: 'sc3', grade: GradeLevel.p4, day: 'الأحد', period: 1, timeRange: '08:00 - 08:45', subject: 'اللغة العربية', teacherName: 'أ. محمود الشاذلي', classroom: 'فصل 4/أ'),
    ScheduleSlot(id: 'sc4', grade: GradeLevel.p4, day: 'الأحد', period: 2, timeRange: '08:50 - 09:35', subject: 'الرياضيات', teacherName: 'أ. إسلام عبدالعزيز', classroom: 'فصل 4/أ'),
    ScheduleSlot(id: 'sc5', grade: GradeLevel.p4, day: 'الأحد', period: 3, timeRange: '09:50 - 10:35', subject: 'العلوم', teacherName: 'أ. هبة سليمان', classroom: 'معمل العلوم'),
    ScheduleSlot(id: 'sc6', grade: GradeLevel.p4, day: 'الإثنين', period: 1, timeRange: '08:00 - 08:45', subject: 'اللغة الإنجليزية', teacherName: 'Mr. Kareem', classroom: 'فصل 4/أ'),
    ScheduleSlot(id: 'sc7', grade: GradeLevel.p4, day: 'الثلاثاء', period: 1, timeRange: '08:00 - 08:45', subject: 'تكنولوجيا المعلومات', teacherName: 'م. عمر فاروق', classroom: 'معمل الحاسب'),
    ScheduleSlot(id: 'sc8', grade: GradeLevel.p4, day: 'الأربعاء', period: 1, timeRange: '08:00 - 08:45', subject: 'الدراسات الاجتماعية', teacherName: 'أ. أحمد زكي', classroom: 'فصل 4/أ'),
    ScheduleSlot(id: 'sc9', grade: GradeLevel.p4, day: 'الخميس', period: 1, timeRange: '08:00 - 08:45', subject: 'الرياضيات - تطبيقات', teacherName: 'أ. إسلام عبدالعزيز', classroom: 'فصل 4/أ'),
    ScheduleSlot(id: 'sc10', grade: GradeLevel.prep3, day: 'الأحد', period: 1, timeRange: '08:00 - 08:45', subject: 'الجبر وحساب المثلثات', teacherName: 'أ. خالد نصار', classroom: 'قاعة 3/أ'),
    ScheduleSlot(id: 'sc11', grade: GradeLevel.prep3, day: 'الإثنين', period: 1, timeRange: '08:00 - 08:45', subject: 'اللغة العربية - النحو', teacherName: 'أ. حسن البنا', classroom: 'قاعة 3/أ'),
  ];

  final List<HomeworkItem> _homeworks = [
    HomeworkItem(id: 'h1', grade: GradeLevel.kg1, subject: 'مهارات اللغة العربية', title: 'تلوين حرف الباء والتاء', details: 'إنجاز النشاط ص 14 في كراسة التهيئة.', dueDate: 'غداً - 08:00 ص', teacherName: 'أ. سارة مجدي'),
    HomeworkItem(id: 'h2', grade: GradeLevel.p4, subject: 'الرياضيات', title: 'تمارين القسمة المطولة', details: 'حل المسائل من 1 إلى 8 ص 42 مع خطوات الحل.', dueDate: 'غداً - 08:00 ص', teacherName: 'أ. إسلام عبدالعزيز'),
    HomeworkItem(id: 'h3', grade: GradeLevel.p4, subject: 'العلوم', title: 'التكيف في الكائنات الحية', details: 'كتابة 5 أمثلة للتكيف التركيبي والسلوكي.', dueDate: 'الخميس القادم', teacherName: 'أ. هبة سليمان', isCompleted: true),
    HomeworkItem(id: 'h4', grade: GradeLevel.prep3, subject: 'الهندسة', title: 'النسب المثلثية الأساسية', details: 'حل النموذج الثالث في كراسة التدريبات ص 19.', dueDate: 'غداً - 08:00 ص', teacherName: 'أ. خالد نصار'),
  ];

  final List<GradeEvaluation> _evaluations = [
    GradeEvaluation(id: 'g1', studentName: 'أنس كريم محمد', grade: GradeLevel.kg1, subject: 'النمو اللغوي والتواصل', examTitle: 'تقييم المهارات الشهري', score: 10, maxScore: 10, skillEvaluation: 'متقن للمهارة بامتياز 🌟', teacherNote: 'يميز الحروف والأصوات بطلاقة.'),
    GradeEvaluation(id: 'g2', studentName: 'جنى محمد السيد', grade: GradeLevel.p4, subject: 'الرياضيات', examTitle: 'اختبار شهر نوفمبر', score: 28.5, maxScore: 30, skillEvaluation: 'ممتاز', teacherNote: 'أداء دقيق ومنظم في خطوات الحل.'),
    GradeEvaluation(id: 'g3', studentName: 'جنى محمد السيد', grade: GradeLevel.p4, subject: 'اللغة العربية', examTitle: 'اختبار شهر نوفمبر', score: 27, maxScore: 30, skillEvaluation: 'ممتاز', teacherNote: 'تعبير إبداعي متميز وإملاء سليم.'),
    GradeEvaluation(id: 'g4', studentName: 'عبدالرحمن هاني صلاح', grade: GradeLevel.prep3, subject: 'الرياضيات', examTitle: 'التقييم الشهري الأول', score: 47, maxScore: 50, skillEvaluation: 'ممتاز', teacherNote: 'مستوى متفوق ومؤهل للمسابقات.'),
  ];

  final List<SchoolResource> _resources = [
    SchoolResource(id: 'r1', title: 'كتاب تأسيس القراءة والكتابة - KG1 & KG2', resourceType: 'كتاب PDF', stage: StageCategory.kg, grade: GradeLevel.kg1, linkOrFile: 'alrowad_kg_arabic.pdf', addedAt: '12 نوفمبر'),
    SchoolResource(id: 'r2', title: 'كتاب الرياضيات التفاعلي - 4 ابتدائي', resourceType: 'كتاب PDF', stage: StageCategory.primary, grade: GradeLevel.p4, linkOrFile: 'math_grade4_term1.pdf', addedAt: '14 نوفمبر'),
    SchoolResource(id: 'r3', title: 'بنك أسئلة العلوم الشامل - الابتدائي', resourceType: 'ملخص', stage: StageCategory.primary, grade: GradeLevel.p4, linkOrFile: 'science_summary_p4.pdf', addedAt: '18 نوفمبر'),
    SchoolResource(id: 'r4', title: 'مذكرة الهندسة وحساب المثلثات - 3 إعدادي', resourceType: 'كتاب PDF', stage: StageCategory.prep, grade: GradeLevel.prep3, linkOrFile: 'prep3_geometry.pdf', addedAt: '20 نوفمبر'),
    SchoolResource(id: 'r5', title: 'بوابة الاختبارات الإلكترونية التفاعلية', resourceType: 'رابط تعليمي', stage: StageCategory.prep, grade: null, linkOrFile: 'https://edu.alrowad-school.edu.eg', addedAt: '22 نوفمبر'),
  ];

  void login({required UserRole role, required StageCategory stage, required GradeLevel grade, required String name}) {
    _currentRole = role;
    _selectedStage = stage;
    _selectedGrade = grade;
    _userName = name.trim().isEmpty ? role.label : name.trim();
    notifyListeners();
  }

  void logout() {
    _currentRole = null;
    notifyListeners();
  }

  void changeWorkingGrade(GradeLevel grade) {
    _selectedGrade = grade;
    _selectedStage = grade.category;
    notifyListeners();
  }

  Map<StageCategory, int> get studentCountByStage => {
        StageCategory.kg: 184 + _students.where((s) => s.grade.category == StageCategory.kg).length,
        StageCategory.primary: 542 + _students.where((s) => s.grade.category == StageCategory.primary).length,
        StageCategory.prep: 318 + _students.where((s) => s.grade.category == StageCategory.prep).length,
      };

  int get totalStudentsCount => studentCountByStage.values.fold(0, (a, b) => a + b);

  double get overallAttendanceRate {
    if (_students.isEmpty) return 100;
    return (_students.where((s) => s.attendance != AttendanceStatus.absent).length / _students.length) * 100;
  }

  List<StudentRecord> studentsForGrade(GradeLevel g) {
    final exact = _students.where((s) => s.grade == g).toList();
    return exact.isNotEmpty ? exact : _students.where((s) => s.grade.category == g.category).toList();
  }

  List<AnnouncementItem> get allAnnouncements => List.unmodifiable(_announcements);
  List<AnnouncementItem> announcementsForStage(StageCategory s) =>
      _announcements.where((a) => a.targetStage == null || a.targetStage == s).toList();
  int unreadCount(StageCategory s) => announcementsForStage(s).where((a) => !a.isRead).length;

  List<ScheduleSlot> scheduleFor(GradeLevel g, String day) =>
      _schedule.where((s) => s.grade == g && s.day == day).toList()..sort((a, b) => a.period.compareTo(b.period));

  List<HomeworkItem> homeworksFor(GradeLevel g) {
    final exact = _homeworks.where((h) => h.grade == g).toList();
    return exact.isNotEmpty ? exact : _homeworks.where((h) => h.grade.category == g.category).toList();
  }

  List<GradeEvaluation> evaluationsFor(GradeLevel g) {
    final exact = _evaluations.where((e) => e.grade == g).toList();
    return exact.isNotEmpty ? exact : _evaluations.where((e) => e.grade.category == g.category).toList();
  }

  List<SchoolResource> get allResources => List.unmodifiable(_resources);
  List<SchoolResource> resourcesFor(StageCategory s) => _resources.where((r) => r.stage == s).toList();

  void addAnnouncement(String title, String body, StageCategory? target, bool urgent) {
    _announcements.insert(0, AnnouncementItem(id: 'a_${DateTime.now().millisecondsSinceEpoch}', title: title, body: body, targetStage: target, author: _userName, dateLabel: 'الآن', isUrgent: urgent));
    notifyListeners();
  }

  void deleteAnnouncement(String id) {
    _announcements.removeWhere((a) => a.id == id);
    notifyListeners();
  }

  void markAllRead(StageCategory s) {
    for (final a in announcementsForStage(s)) {
      a.isRead = true;
    }
    notifyListeners();
  }

  void addScheduleSlot(GradeLevel grade, String day, int period, String time, String subject, String teacher, String room) {
    _schedule.add(ScheduleSlot(id: 'sc_${DateTime.now().millisecondsSinceEpoch}', grade: grade, day: day, period: period, timeRange: time, subject: subject, teacherName: teacher, classroom: room));
    notifyListeners();
  }

  void deleteScheduleSlot(String id) {
    _schedule.removeWhere((s) => s.id == id);
    notifyListeners();
  }

  void addResource(String title, String type, StageCategory stage, GradeLevel? grade, String link) {
    _resources.insert(0, SchoolResource(id: 'r_${DateTime.now().millisecondsSinceEpoch}', title: title, resourceType: type, stage: stage, grade: grade, linkOrFile: link, addedAt: 'اليوم'));
    notifyListeners();
  }

  void deleteResource(String id) {
    _resources.removeWhere((r) => r.id == id);
    notifyListeners();
  }

  void setAttendance(String id, AttendanceStatus status) {
    final i = _students.indexWhere((s) => s.id == id);
    if (i != -1) {
      _students[i].attendance = status;
      notifyListeners();
    }
  }

  void markAllPresent(GradeLevel g) {
    for (final s in studentsForGrade(g)) {
      s.attendance = AttendanceStatus.present;
    }
    notifyListeners();
  }

  void addHomework(GradeLevel grade, String subject, String title, String details, String due) {
    _homeworks.insert(0, HomeworkItem(id: 'h_${DateTime.now().millisecondsSinceEpoch}', grade: grade, subject: subject, title: title, details: details, dueDate: due, teacherName: _userName));
    notifyListeners();
  }

  void toggleHomework(String id) {
    final i = _homeworks.indexWhere((h) => h.id == id);
    if (i != -1) {
      _homeworks[i].isCompleted = !_homeworks[i].isCompleted;
      notifyListeners();
    }
  }

  void upsertEvaluation({String? id, required String student, required GradeLevel grade, required String subject, required String exam, required double score, required double maxScore, required String skill, required String note}) {
    if (id != null) {
      final idx = _evaluations.indexWhere((e) => e.id == id);
      if (idx != -1) {
        _evaluations[idx] = GradeEvaluation(id: id, studentName: student, grade: grade, subject: subject, examTitle: exam, score: score, maxScore: maxScore, skillEvaluation: skill, teacherNote: note);
        notifyListeners();
        return;
      }
    }
    _evaluations.insert(0, GradeEvaluation(id: 'g_${DateTime.now().millisecondsSinceEpoch}', studentName: student, grade: grade, subject: subject, examTitle: exam, score: score, maxScore: maxScore, skillEvaluation: skill, teacherNote: note));
    notifyListeners();
  }
}

class AppStateScope extends InheritedNotifier<AlRowadAppState> {
  const AppStateScope({super.key, required AlRowadAppState state, required super.child}) : super(notifier: state);
  static AlRowadAppState of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppStateScope>()!.notifier!;
}

// ============================================================================
// 3. التطبيق الرئيسي والثيم (Material Design 3 & RTL)
// ============================================================================

class AlRowadSchoolApp extends StatefulWidget {
  const AlRowadSchoolApp({super.key});
  @override
  State<AlRowadSchoolApp> createState() => _AlRowadSchoolAppState();
}

class _AlRowadSchoolAppState extends State<AlRowadSchoolApp> {
  final AlRowadAppState _state = AlRowadAppState();
  @override
  void dispose() {
    _state.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const seed = Color(0xFF1E3A8A);
    final scheme = ColorScheme.fromSeed(seedColor: seed, secondary: const Color(0xFF0D9488));
    return AppStateScope(
      state: _state,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'مدرسة الرواد الخاصة',
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: scheme,
          scaffoldBackgroundColor: const Color(0xFFF4F7FC),
          appBarTheme: AppBarTheme(
            centerTitle: true,
            backgroundColor: scheme.primary,
            foregroundColor: Colors.white,
            titleTextStyle: const TextStyle(fontSize: 18.5, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          inputDecorationTheme: InputDecorationTheme(
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
          ),
        ),
        builder: (context, child) => Directionality(textDirection: TextDirection.rtl, child: child!),
        home: const _RootGate(),
      ),
    );
  }
}

class _RootGate extends StatefulWidget {
  const _RootGate();
  @override
  State<_RootGate> createState() => _RootGateState();
}

class _RootGateState extends State<_RootGate> {
  bool _splash = true;
  @override
  void initState() {
    super.initState();
    Timer(const Duration(milliseconds: 2000), () {
      if (mounted) setState(() => _splash = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_splash) return const SplashScreen();
    final role = AppStateScope.of(context).currentRole;
    if (role == null) return const LoginScreen();
    switch (role) {
      case UserRole.admin:
        return const AdminDashboard();
      case UserRole.teacher:
        return const TeacherDashboard();
      case UserRole.studentParent:
        return const StudentParentDashboard();
    }
  }
}

// ============================================================================
// 4. الشاشة الترحيبية وشعار المدرسة (Splash Screen & Logo)
// ============================================================================

class AlRowadLogoBadge extends StatelessWidget {
  final double size;
  final bool showBorder;
  const AlRowadLogoBadge({super.key, this.size = 90, this.showBorder = true});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(colors: [Color(0xFF1E3A8A), Color(0xFF0D9488)]),
        border: showBorder ? Border.all(color: const Color(0xFFFBBF24), width: 3) : null,
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Icon(Icons.school_rounded, size: size * 0.52, color: Colors.white),
          Positioned(
            bottom: size * 0.14,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
              decoration: BoxDecoration(color: const Color(0xFFFBBF24), borderRadius: BorderRadius.circular(10)),
              child: Text('الرواد', style: TextStyle(fontSize: size * 0.14, fontWeight: FontWeight.w900, color: const Color(0xFF1E3A8A))),
            ),
          ),
        ],
      ),
    );
  }
}

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(colors: [Color(0xFF0F172A), Color(0xFF1E3A8A), Color(0xFF0D9488)], begin: Alignment.topRight, end: Alignment.bottomLeft),
        ),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AlRowadLogoBadge(size: 115),
            SizedBox(height: 24),
            Text('مدرسة الرواد الخاصة', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: Colors.white)),
            SizedBox(height: 8),
            Text('من الحضانة KG1 وحتى الثالث الإعدادي', style: TextStyle(fontSize: 14, color: Color(0xFFFEF08A), fontWeight: FontWeight.w600)),
            SizedBox(height: 36),
            CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFBBF24))),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// 5. شاشة تسجيل الدخول والمصادقة متعددة الأدوار (Login Screen)
// ============================================================================

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  UserRole _role = UserRole.studentParent;
  StageCategory _stage = StageCategory.primary;
  GradeLevel _grade = GradeLevel.p4;
  final _nameCtrl = TextEditingController(text: 'جنى محمد السيد');
  final _codeCtrl = TextEditingController(text: 'RW-2026-408');

  @override
  void dispose() {
    _nameCtrl.dispose();
    _codeCtrl.dispose();
    super.dispose();
  }

  void _selectRole(UserRole r) {
    setState(() {
      _role = r;
      if (r == UserRole.admin) {
        _nameCtrl.text = 'د. خالد عبدالعزيز (المدير)';
        _codeCtrl.text = 'ADM-001';
      } else if (r == UserRole.teacher) {
        _nameCtrl.text = 'أ. إسلام عبدالعزيز';
        _codeCtrl.text = 'TCH-214';
      } else {
        _nameCtrl.text = _grade.category == StageCategory.kg ? 'أنس كريم محمد (ولي الأمر)' : (_grade.category == StageCategory.prep ? 'عبدالرحمن هاني صلاح' : 'جنى محمد السيد');
        _codeCtrl.text = 'STD-408';
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final grades = GradeLevel.byCategory(_stage);
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
              decoration: const BoxDecoration(
                gradient: LinearGradient(colors: [Color(0xFF1E3A8A), Color(0xFF2563EB)]),
                borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
              ),
              child: const Column(
                children: [
                  AlRowadLogoBadge(size: 80),
                  SizedBox(height: 12),
                  Text('بوابة مدرسة الرواد الخاصة', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Colors.white)),
                  SizedBox(height: 4),
                  Text('المنصة التعليمية الشاملة (KG1 - Prep 3)', style: TextStyle(fontSize: 13, color: Colors.white70)),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('1. اختر نوع الحساب', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  ...UserRole.values.map((r) {
                    final selected = _role == r;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(14),
                        onTap: () => _selectRole(r),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: selected ? const Color(0xFFEFF6FF) : Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: selected ? const Color(0xFF1E3A8A) : Colors.grey.shade300, width: selected ? 2 : 1),
                          ),
                          child: Row(
                            children: [
                              CircleAvatar(backgroundColor: selected ? const Color(0xFF1E3A8A) : Colors.grey.shade200, child: Icon(r.icon, color: selected ? Colors.white : Colors.grey.shade700)),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(r.label, style: const TextStyle(fontWeight: FontWeight.bold)),
                                    Text(r.subtitle, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                                  ],
                                ),
                              ),
                              Icon(selected ? Icons.check_circle_rounded : Icons.circle_outlined, color: selected ? const Color(0xFF1E3A8A) : Colors.grey),
                            ],
                          ),
                        ),
                      ),
                    );
                  }),
                  const SizedBox(height: 14),
                  const Text('2. اختر المرحلة الدراسية والصف', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: StageCategory.values.map((s) {
                      final sel = _stage == s;
                      return ChoiceChip(
                        label: Text(s.label),
                        selected: sel,
                        selectedColor: s.color,
                        labelStyle: TextStyle(fontWeight: FontWeight.bold, color: sel ? Colors.white : Colors.black87),
                        onSelected: (_) => setState(() {
                          _stage = s;
                          _grade = GradeLevel.byCategory(s).first;
                        }),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<GradeLevel>(
                    value: _grade,
                    decoration: const InputDecoration(labelText: 'الصف الدراسي', prefixIcon: Icon(Icons.class_rounded)),
                    items: grades.map((g) => DropdownMenuItem(value: g, child: Text(g.label))).toList(),
                    onChanged: (v) {
                      if (v != null) setState(() => _grade = v);
                    },
                  ),
                  const SizedBox(height: 14),
                  TextField(controller: _nameCtrl, decoration: const InputDecoration(labelText: 'الاسم الكامل', prefixIcon: Icon(Icons.person_outline))),
                  const SizedBox(height: 10),
                  TextField(controller: _codeCtrl, decoration: const InputDecoration(labelText: 'كود المستخدم / كلمة المرور', prefixIcon: Icon(Icons.lock_outline))),
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1E3A8A), foregroundColor: Colors.white),
                      onPressed: () => AppStateScope.of(context).login(role: _role, stage: _stage, grade: _grade, name: _nameCtrl.text),
                      icon: const Icon(Icons.login_rounded),
                      label: Text('دخول إلى ${_role.label}'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// 6. لوحة تحكم المدير (Admin Dashboard)
// ============================================================================

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});
  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  int _tab = 0;
  @override
  Widget build(BuildContext context) {
    final app = AppStateScope.of(context);
    final pages = [const _AdminOverviewTab(), const _AdminAnnouncementsTab(), const _AdminScheduleTab(), const _AdminResourcesTab()];
    return Scaffold(
      appBar: AppBar(
        title: const Text('لوحة تحكم الإدارة - الرواد'),
        leading: const Padding(padding: EdgeInsets.all(8), child: AlRowadLogoBadge(size: 36, showBorder: false)),
        actions: [IconButton(icon: const Icon(Icons.logout_rounded), onPressed: app.logout)],
      ),
      body: pages[_tab],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.bar_chart_rounded), label: 'الإحصائيات'),
          NavigationDestination(icon: Icon(Icons.campaign_rounded), label: 'الإعلانات'),
          NavigationDestination(icon: Icon(Icons.calendar_month_rounded), label: 'الجدول'),
          NavigationDestination(icon: Icon(Icons.picture_as_pdf_rounded), label: 'الكتب PDF'),
        ],
      ),
    );
  }
}

class _AdminOverviewTab extends StatelessWidget {
  const _AdminOverviewTab();
  @override
  Widget build(BuildContext context) {
    final app = AppStateScope.of(context);
    final map = app.studentCountByStage;
    final total = app.totalStudentsCount;
    final maxVal = map.values.reduce((a, b) => a > b ? a : b);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _BannerCard(title: 'مرحباً ${app.userName}', subtitle: 'إحصائيات حية لمدرسة الرواد (KG1 - Prep 3)', icon: Icons.admin_panel_settings_rounded, colors: const [Color(0xFF1E3A8A), Color(0xFF3B82F6)]),
        const SizedBox(height: 14),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          childAspectRatio: 1.5,
          children: [
            _KpiCard('إجمالي الطلاب', '$total', Icons.groups_rounded, const Color(0xFF1E3A8A)),
            _KpiCard('المعلمون', '${app.totalTeachersCount}', Icons.cast_for_education_rounded, const Color(0xFF0D9488)),
            _KpiCard('الفصول النشطة', '${app.activeClassesCount}', Icons.meeting_room_rounded, const Color(0xFFF59E0B)),
            _KpiCard('الحضور اليوم', '${app.overallAttendanceRate.toStringAsFixed(0)}%', Icons.verified_rounded, const Color(0xFF10B981)),
          ],
        ),
        const SizedBox(height: 16),
        Card(
          color: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('توزيع الطلاب حسب المرحلة', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 14),
                ...StageCategory.values.map((s) {
                  final c = map[s] ?? 0;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(s.label, style: const TextStyle(fontWeight: FontWeight.w600)),
                            Text('$c طالب', style: TextStyle(fontWeight: FontWeight.bold, color: s.color)),
                          ],
                        ),
                        const SizedBox(height: 6),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: LinearProgressIndicator(value: maxVal == 0 ? 0 : c / maxVal, minHeight: 11, backgroundColor: s.color.withAlpha(35), valueColor: AlwaysStoppedAnimation(s.color)),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _AdminAnnouncementsTab extends StatefulWidget {
  const _AdminAnnouncementsTab();
  @override
  State<_AdminAnnouncementsTab> createState() => _AdminAnnouncementsTabState();
}

class _AdminAnnouncementsTabState extends State<_AdminAnnouncementsTab> {
  StageCategory? _filter;

  void _openAdd() {
    final tCtrl = TextEditingController();
    final bCtrl = TextEditingController();
    StageCategory? target;
    bool urgent = false;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setM) => Padding(
          padding: EdgeInsets.fromLTRB(18, 18, 18, MediaQuery.of(ctx).viewInsets.bottom + 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('نشر إعلان / تعميم', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              TextField(controller: tCtrl, decoration: const InputDecoration(labelText: 'عنوان الإعلان')),
              const SizedBox(height: 10),
              TextField(controller: bCtrl, maxLines: 3, decoration: const InputDecoration(labelText: 'التفاصيل')),
              const SizedBox(height: 10),
              DropdownButtonFormField<StageCategory?>(
                value: target,
                decoration: const InputDecoration(labelText: 'المرحلة المستهدفة'),
                items: [
                  const DropdownMenuItem(value: null, child: Text('المدرسة بالكامل')),
                  ...StageCategory.values.map((s) => DropdownMenuItem(value: s, child: Text(s.label))),
                ],
                onChanged: (v) => setM(() => target = v),
              ),
              SwitchListTile(title: const Text('إعلان هام وعاجل'), value: urgent, onChanged: (v) => setM(() => urgent = v)),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    if (tCtrl.text.trim().isEmpty || bCtrl.text.trim().isEmpty) return;
                    AppStateScope.of(context).addAnnouncement(tCtrl.text.trim(), bCtrl.text.trim(), target, urgent);
                    Navigator.pop(ctx);
                  },
                  child: const Text('نشر الإعلان'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final app = AppStateScope.of(context);
    final items = _filter == null ? app.allAnnouncements : app.allAnnouncements.where((a) => a.targetStage == _filter).toList();
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(onPressed: _openAdd, icon: const Icon(Icons.add), label: const Text('نشر إعلان')),
      body: Column(
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                FilterChip(label: const Text('الكل'), selected: _filter == null, onSelected: (_) => setState(() => _filter = null)),
                const SizedBox(width: 6),
                ...StageCategory.values.map((s) => Padding(
                      padding: const EdgeInsets.only(left: 6),
                      child: FilterChip(label: Text(s.shortLabel), selected: _filter == s, onSelected: (_) => setState(() => _filter = s)),
                    )),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 80),
              itemCount: items.length,
              itemBuilder: (_, i) {
                final a = items[i];
                return Card(
                  color: Colors.white,
                  margin: const EdgeInsets.only(bottom: 10),
                  child: ListTile(
                    title: Text(a.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text('${a.targetStage?.shortLabel ?? "المدرسة بالكامل"} • ${a.dateLabel}\n${a.body}'),
                    trailing: IconButton(icon: const Icon(Icons.delete_outline, color: Colors.red), onPressed: () => app.deleteAnnouncement(a.id)),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _AdminScheduleTab extends StatefulWidget {
  const _AdminScheduleTab();
  @override
  State<_AdminScheduleTab> createState() => _AdminScheduleTabState();
}

class _AdminScheduleTabState extends State<_AdminScheduleTab> {
  GradeLevel _grade = GradeLevel.p4;
  String _day = AlRowadAppState.weekDays.first;

  void _addSlot() {
    final sub = TextEditingController();
    final tch = TextEditingController();
    final time = TextEditingController(text: '10:40 - 11:25');
    int period = 4;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('حصة جديدة (${_grade.shortLabel} - $_day)'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: sub, decoration: const InputDecoration(labelText: 'المادة')),
            const SizedBox(height: 8),
            TextField(controller: tch, decoration: const InputDecoration(labelText: 'المعلم')),
            const SizedBox(height: 8),
            TextField(controller: time, decoration: const InputDecoration(labelText: 'الوقت')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: () {
              if (sub.text.trim().isEmpty) return;
              AppStateScope.of(context).addScheduleSlot(_grade, _day, period, time.text.trim(), sub.text.trim(), tch.text.trim().isEmpty ? 'هيئة التدريس' : tch.text.trim(), 'فصل ${_grade.shortLabel}');
              Navigator.pop(ctx);
            },
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final app = AppStateScope.of(context);
    final slots = app.scheduleFor(_grade, _day);
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(onPressed: _addSlot, icon: const Icon(Icons.add), label: const Text('إضافة حصة')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(14),
            child: DropdownButtonFormField<GradeLevel>(
              value: _grade,
              decoration: const InputDecoration(labelText: 'الصف الدراسي'),
              items: GradeLevel.values.map((g) => DropdownMenuItem(value: g, child: Text(g.label))).toList(),
              onChanged: (v) {
                if (v != null) setState(() => _grade = v);
              },
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Row(
              children: AlRowadAppState.weekDays.map((d) => Padding(
                    padding: const EdgeInsets.only(left: 6),
                    child: ChoiceChip(label: Text(d), selected: _day == d, onSelected: (_) => setState(() => _day = d)),
                  )).toList(),
            ),
          ),
          Expanded(
            child: slots.isEmpty
                ? const _EmptyWidget(Icons.calendar_today, 'لا توجد حصص مسجلة لهذا اليوم')
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(14, 10, 14, 80),
                    itemCount: slots.length,
                    itemBuilder: (_, i) {
                      final s = slots[i];
                      return Card(
                        color: Colors.white,
                        child: ListTile(
                          leading: CircleAvatar(child: Text('${s.period}')),
                          title: Text(s.subject, style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text('${s.timeRange} • ${s.teacherName} • ${s.classroom}'),
                          trailing: IconButton(icon: const Icon(Icons.delete_outline, color: Colors.red), onPressed: () => app.deleteScheduleSlot(s.id)),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _AdminResourcesTab extends StatefulWidget {
  const _AdminResourcesTab();
  @override
  State<_AdminResourcesTab> createState() => _AdminResourcesTabState();
}

class _AdminResourcesTabState extends State<_AdminResourcesTab> {
  void _addFile() {
    final title = TextEditingController();
    final link = TextEditingController();
    String type = 'كتاب PDF';
    StageCategory stage = StageCategory.primary;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setM) => Padding(
          padding: EdgeInsets.fromLTRB(18, 18, 18, MediaQuery.of(ctx).viewInsets.bottom + 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('رفع كتاب PDF أو رابط تعليمي', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              TextField(controller: title, decoration: const InputDecoration(labelText: 'عنوان الملف أو الكتاب')),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                value: type,
                decoration: const InputDecoration(labelText: 'النوع'),
                items: ['كتاب PDF', 'ملخص', 'رابط تعليمي'].map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                onChanged: (v) {
                  if (v != null) setM(() => type = v);
                },
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<StageCategory>(
                value: stage,
                decoration: const InputDecoration(labelText: 'المرحلة'),
                items: StageCategory.values.map((s) => DropdownMenuItem(value: s, child: Text(s.label))).toList(),
                onChanged: (v) {
                  if (v != null) setM(() => stage = v);
                },
              ),
              const SizedBox(height: 10),
              TextField(controller: link, decoration: const InputDecoration(labelText: 'اسم ملف PDF أو الرابط')),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    if (title.text.trim().isEmpty) return;
                    AppStateScope.of(context).addResource(title.text.trim(), type, stage, GradeLevel.byCategory(stage).first, link.text.trim().isEmpty ? 'book.pdf' : link.text.trim());
                    Navigator.pop(ctx);
                  },
                  child: const Text('رفع وحفظ'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final app = AppStateScope.of(context);
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(onPressed: _addFile, icon: const Icon(Icons.upload_file), label: const Text('رفع PDF')),
      body: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
        itemCount: app.allResources.length,
        itemBuilder: (_, i) {
          final r = app.allResources[i];
          return Card(
            color: Colors.white,
            child: ListTile(
              leading: Icon(r.resourceType == 'رابط تعليمي' ? Icons.link : Icons.picture_as_pdf, color: Colors.red),
              title: Text(r.title, style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text('${r.resourceType} • ${r.stage.shortLabel}\n${r.linkOrFile}'),
              trailing: IconButton(icon: const Icon(Icons.delete_outline, color: Colors.red), onPressed: () => app.deleteResource(r.id)),
            ),
          );
        },
      ),
    );
  }
}

// ============================================================================
// 7. لوحة تحكم المعلم (Teacher Dashboard)
// ============================================================================

class TeacherDashboard extends StatefulWidget {
  const TeacherDashboard({super.key});
  @override
  State<TeacherDashboard> createState() => _TeacherDashboardState();
}

class _TeacherDashboardState extends State<TeacherDashboard> {
  int _tab = 0;

  void _switchGrade() {
    final app = AppStateScope.of(context);
    showModalBottomSheet(
      context: context,
      builder: (ctx) => ListView(
        padding: const EdgeInsets.all(14),
        children: GradeLevel.values
            .map((g) => ListTile(
                  title: Text(g.label),
                  trailing: g == app.selectedGrade ? const Icon(Icons.check_circle, color: Color(0xFF1E3A8A)) : null,
                  onTap: () {
                    app.changeWorkingGrade(g);
                    Navigator.pop(ctx);
                  },
                ))
            .toList(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final app = AppStateScope.of(context);
    final pages = [const _TeacherClassesTab(), const _TeacherAttendanceTab(), const _TeacherGradesTab(), const _TeacherHomeworkTab()];
    return Scaffold(
      appBar: AppBar(
        title: Text('المعلم • ${app.selectedGrade.shortLabel}'),
        actions: [
          IconButton(icon: const Icon(Icons.swap_horiz_rounded), onPressed: _switchGrade),
          IconButton(icon: const Icon(Icons.logout_rounded), onPressed: app.logout),
        ],
      ),
      body: pages[_tab],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.class_rounded), label: 'فصولي'),
          NavigationDestination(icon: Icon(Icons.fact_check_rounded), label: 'الحضور'),
          NavigationDestination(icon: Icon(Icons.grade_rounded), label: 'الدرجات'),
          NavigationDestination(icon: Icon(Icons.assignment_rounded), label: 'الواجبات'),
        ],
      ),
    );
  }
}

class _TeacherClassesTab extends StatelessWidget {
  const _TeacherClassesTab();
  @override
  Widget build(BuildContext context) {
    final app = AppStateScope.of(context);
    final g = app.selectedGrade;
    final subjects = g.category == StageCategory.kg
        ? ['مهارات اللغة العربية', 'الحساب الممتع', 'English Phonics', 'الأنشطة والمهارات']
        : ['اللغة العربية', 'الرياضيات', 'العلوم', 'اللغة الإنجليزية', 'الدراسات الاجتماعية'];

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _BannerCard(title: 'أهلاً ${app.userName}', subtitle: 'الصف المسند: ${g.label}', icon: g.category.icon, colors: [g.category.color, const Color(0xFF1E3A8A)]),
        const SizedBox(height: 14),
        const Text('المواد المسندة لهذه المرحلة', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        ...subjects.map((s) => Card(
              color: Colors.white,
              child: ListTile(
                leading: Icon(Icons.menu_book_rounded, color: g.category.color),
                title: Text(s, style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text(g.label),
              ),
            )),
      ],
    );
  }
}

class _TeacherAttendanceTab extends StatelessWidget {
  const _TeacherAttendanceTab();
  @override
  Widget build(BuildContext context) {
    final app = AppStateScope.of(context);
    final g = app.selectedGrade;
    final students = app.studentsForGrade(g);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => app.markAllPresent(g),
              icon: const Icon(Icons.done_all_rounded),
              label: const Text('تحضير جميع الطلاب بضغطة واحدة'),
            ),
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: students.length,
            itemBuilder: (_, i) {
              final st = students[i];
              return Card(
                color: Colors.white,
                margin: const EdgeInsets.only(bottom: 10),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(st.name, style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Row(
                        children: AttendanceStatus.values.map((status) {
                          final sel = st.attendance == status;
                          return Expanded(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 3),
                              child: InkWell(
                                onTap: () => app.setAttendance(st.id, status),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 8),
                                  decoration: BoxDecoration(color: sel ? status.color : status.color.withAlpha(25), borderRadius: BorderRadius.circular(10)),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(status.icon, size: 15, color: sel ? Colors.white : status.color),
                                      const SizedBox(width: 4),
                                      Text(status.label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: sel ? Colors.white : status.color)),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _TeacherGradesTab extends StatefulWidget {
  const _TeacherGradesTab();
  @override
  State<_TeacherGradesTab> createState() => _TeacherGradesTabState();
}

class _TeacherGradesTabState extends State<_TeacherGradesTab> {
  void _openEditor({GradeEvaluation? existing}) {
    final app = AppStateScope.of(context);
    final g = app.selectedGrade;
    final students = app.studentsForGrade(g);
    final isKg = g.category == StageCategory.kg;
    String student = existing?.studentName ?? students.first.name;
    final sub = TextEditingController(text: existing?.subject ?? (isKg ? 'المهارات اللغوية' : 'الرياضيات'));
    final exam = TextEditingController(text: existing?.examTitle ?? (isKg ? 'تقييم المهارات' : 'اختبار نوفمبر'));
    final score = TextEditingController(text: existing?.score.toString() ?? '28');
    final maxS = TextEditingController(text: existing?.maxScore.toString() ?? '30');
    final note = TextEditingController(text: existing?.teacherNote ?? 'أداء متميز داخل الفصل.');
    String kgSkill = 'متقن للمهارة بامتياز 🌟';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setM) => Padding(
          padding: EdgeInsets.fromLTRB(18, 18, 18, MediaQuery.of(ctx).viewInsets.bottom + 18),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(existing == null ? 'رصد تقييم جديد' : 'تحديث التقييم', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  value: students.any((s) => s.name == student) ? student : null,
                  decoration: const InputDecoration(labelText: 'الطالب'),
                  items: students.map((s) => DropdownMenuItem(value: s.name, child: Text(s.name))).toList(),
                  onChanged: (v) {
                    if (v != null) setM(() => student = v);
                  },
                ),
                const SizedBox(height: 8),
                TextField(controller: sub, decoration: const InputDecoration(labelText: 'المادة')),
                const SizedBox(height: 8),
                TextField(controller: exam, decoration: const InputDecoration(labelText: 'الاختبار / التقييم')),
                const SizedBox(height: 8),
                if (isKg)
                  DropdownButtonFormField<String>(
                    value: kgSkill,
                    decoration: const InputDecoration(labelText: 'التقدير المهاري'),
                    items: ['متقن للمهارة بامتياز 🌟', 'متقدم جداً 🎨', 'يحتاج متابعة 💡'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                    onChanged: (v) {
                      if (v != null) setM(() => kgSkill = v);
                    },
                  )
                else
                  Row(
                    children: [
                      Expanded(child: TextField(controller: score, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'الدرجة'))),
                      const SizedBox(width: 8),
                      Expanded(child: TextField(controller: maxS, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'من'))),
                    ],
                  ),
                const SizedBox(height: 8),
                TextField(controller: note, decoration: const InputDecoration(labelText: 'ملاحظة المعلم')),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      final sc = double.tryParse(score.text) ?? 10;
                      final mx = double.tryParse(maxS.text) ?? 10;
                      app.upsertEvaluation(id: existing?.id, student: student, grade: g, subject: sub.text.trim(), exam: exam.text.trim(), score: isKg ? 10 : sc, maxScore: isKg ? 10 : mx, skill: isKg ? kgSkill : (sc / mx >= 0.85 ? 'ممتاز' : 'جيد جداً'), note: note.text.trim());
                      Navigator.pop(ctx);
                    },
                    child: const Text('حفظ التقييم'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final app = AppStateScope.of(context);
    final list = app.evaluationsFor(app.selectedGrade);
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(onPressed: () => _openEditor(), icon: const Icon(Icons.add), label: const Text('رصد درجة')),
      body: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
        itemCount: list.length,
        itemBuilder: (_, i) {
          final e = list[i];
          final isKg = e.grade.category == StageCategory.kg;
          return Card(
            color: Colors.white,
            child: ListTile(
              title: Text('${e.studentName} • ${e.subject}', style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text('${e.examTitle} • ${isKg ? e.skillEvaluation : "${e.score}/${e.maxScore}"}\n${e.teacherNote}'),
              trailing: IconButton(icon: const Icon(Icons.edit), onPressed: () => _openEditor(existing: e)),
            ),
          );
        },
      ),
    );
  }
}

class _TeacherHomeworkTab extends StatefulWidget {
  const _TeacherHomeworkTab();
  @override
  State<_TeacherHomeworkTab> createState() => _TeacherHomeworkTabState();
}

class _TeacherHomeworkTabState extends State<_TeacherHomeworkTab> {
  void _sendHw() {
    final app = AppStateScope.of(context);
    final sub = TextEditingController();
    final title = TextEditingController();
    final details = TextEditingController();
    final due = TextEditingController(text: 'غداً - 08:00 ص');
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(18, 18, 18, MediaQuery.of(ctx).viewInsets.bottom + 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('إرسال واجب (${app.selectedGrade.shortLabel})', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            TextField(controller: sub, decoration: const InputDecoration(labelText: 'المادة')),
            const SizedBox(height: 8),
            TextField(controller: title, decoration: const InputDecoration(labelText: 'عنوان الواجب')),
            const SizedBox(height: 8),
            TextField(controller: details, maxLines: 2, decoration: const InputDecoration(labelText: 'التفاصيل')),
            const SizedBox(height: 8),
            TextField(controller: due, decoration: const InputDecoration(labelText: 'موعد التسليم')),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  if (sub.text.trim().isEmpty || title.text.trim().isEmpty) return;
                  app.addHomework(app.selectedGrade, sub.text.trim(), title.text.trim(), details.text.trim(), due.text.trim());
                  Navigator.pop(ctx);
                },
                child: const Text('إرسال الواجب'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final app = AppStateScope.of(context);
    final list = app.homeworksFor(app.selectedGrade);
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(onPressed: _sendHw, icon: const Icon(Icons.add_task), label: const Text('إرسال واجب')),
      body: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
        itemCount: list.length,
        itemBuilder: (_, i) {
          final h = list[i];
          return Card(
            color: Colors.white,
            child: ListTile(
              title: Text('${h.subject}: ${h.title}', style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text('${h.details}\nالتسليم: ${h.dueDate}'),
            ),
          );
        },
      ),
    );
  }
}

// ============================================================================
// 8. لوحة تحكم الطالب وولي الأمر (Student & Parent Dashboard)
// ============================================================================

class StudentParentDashboard extends StatefulWidget {
  const StudentParentDashboard({super.key});
  @override
  State<StudentParentDashboard> createState() => _StudentParentDashboardState();
}

class _StudentParentDashboardState extends State<StudentParentDashboard> {
  int _tab = 0;
  @override
  Widget build(BuildContext context) {
    final app = AppStateScope.of(context);
    final unread = app.unreadCount(app.selectedStage);
    final pages = [const _StudentScheduleTab(), const _StudentHomeworkTab(), const _StudentGradesTab(), const _StudentNotificationsTab()];
    return Scaffold(
      appBar: AppBar(
        title: Text('روادنا • ${app.selectedGrade.shortLabel}'),
        actions: [
          IconButton(
            icon: Badge(isLabelVisible: unread > 0, label: Text('$unread'), child: const Icon(Icons.notifications_active_rounded)),
            onPressed: () {
              setState(() => _tab = 3);
              app.markAllRead(app.selectedStage);
            },
          ),
          IconButton(icon: const Icon(Icons.logout_rounded), onPressed: app.logout),
        ],
      ),
      body: pages[_tab],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) {
          setState(() => _tab = i);
          if (i == 3) app.markAllRead(app.selectedStage);
        },
        destinations: [
          const NavigationDestination(icon: Icon(Icons.calendar_view_week_rounded), label: 'الجدول'),
          const NavigationDestination(icon: Icon(Icons.assignment_rounded), label: 'الواجبات'),
          const NavigationDestination(icon: Icon(Icons.auto_awesome_rounded), label: 'الدرجات'),
          NavigationDestination(icon: Badge(isLabelVisible: unread > 0, label: Text('$unread'), child: const Icon(Icons.notifications_rounded)), label: 'الإشعارات والكتب'),
        ],
      ),
    );
  }
}

class _StudentScheduleTab extends StatefulWidget {
  const _StudentScheduleTab();
  @override
  State<_StudentScheduleTab> createState() => _StudentScheduleTabState();
}

class _StudentScheduleTabState extends State<_StudentScheduleTab> {
  String _day = AlRowadAppState.weekDays.first;
  @override
  Widget build(BuildContext context) {
    final app = AppStateScope.of(context);
    final g = app.selectedGrade;
    final slots = app.scheduleFor(g, _day);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(14),
          child: _BannerCard(title: 'مرحباً ${app.userName}', subtitle: 'الجدول الأسبوعي • ${g.label}', icon: g.category.icon, colors: [g.category.color, const Color(0xFF1E3A8A)]),
        ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Row(
            children: AlRowadAppState.weekDays.map((d) => Padding(
                  padding: const EdgeInsets.only(left: 6),
                  child: ChoiceChip(label: Text(d), selected: _day == d, onSelected: (_) => setState(() => _day = d)),
                )).toList(),
          ),
        ),
        Expanded(
          child: slots.isEmpty
              ? const _EmptyWidget(Icons.event_available, 'لا توجد حصص مجدولة لهذا اليوم')
              : ListView.builder(
                  padding: const EdgeInsets.all(14),
                  itemCount: slots.length,
                  itemBuilder: (_, i) {
                    final s = slots[i];
                    return Card(
                      color: Colors.white,
                      child: ListTile(
                        leading: CircleAvatar(backgroundColor: g.category.color.withAlpha(30), child: Text('${s.period}', style: TextStyle(color: g.category.color, fontWeight: FontWeight.bold))),
                        title: Text(s.subject, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text('${s.teacherName} • ${s.classroom}'),
                        trailing: Text(s.timeRange, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _StudentHomeworkTab extends StatelessWidget {
  const _StudentHomeworkTab();
  @override
  Widget build(BuildContext context) {
    final app = AppStateScope.of(context);
    final items = app.homeworksFor(app.selectedGrade);
    if (items.isEmpty) return const _EmptyWidget(Icons.celebration, 'لا توجد واجبات مطلوبة حالياً');
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: items.length,
      itemBuilder: (_, i) {
        final h = items[i];
        return Card(
          color: h.isCompleted ? const Color(0xFFF0FDF4) : Colors.white,
          child: CheckboxListTile(
            value: h.isCompleted,
            onChanged: (_) => app.toggleHomework(h.id),
            title: Text('${h.subject}: ${h.title}', style: TextStyle(fontWeight: FontWeight.bold, decoration: h.isCompleted ? TextDecoration.lineThrough : null)),
            subtitle: Text('${h.details}\nالتسليم: ${h.dueDate} • ${h.teacherName}'),
          ),
        );
      },
    );
  }
}

class _StudentGradesTab extends StatelessWidget {
  const _StudentGradesTab();
  @override
  Widget build(BuildContext context) {
    final app = AppStateScope.of(context);
    final g = app.selectedGrade;
    final list = app.evaluationsFor(g);
    final isKg = g.category == StageCategory.kg;
    if (list.isEmpty) return const _EmptyWidget(Icons.grade_outlined, 'لم تُعلن تقييمات لهذا الصف بعد');

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: list.length,
      itemBuilder: (_, i) {
        final e = list[i];
        final ratio = e.maxScore == 0 ? 0.0 : (e.score / e.maxScore).clamp(0.0, 1.0);
        return Card(
          color: Colors.white,
          margin: const EdgeInsets.only(bottom: 10),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(e.subject, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    Chip(label: Text(isKg ? e.skillEvaluation : '${e.score}/${e.maxScore} (${e.skillEvaluation})'), backgroundColor: const Color(0xFFDCFCE7)),
                  ],
                ),
                Text('${e.examTitle} • ${e.studentName}', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                if (!isKg) ...[
                  const SizedBox(height: 8),
                  LinearProgressIndicator(value: ratio, minHeight: 8, borderRadius: BorderRadius.circular(6)),
                ],
                const SizedBox(height: 8),
                Text('ملاحظة المعلم: ${e.teacherNote}', style: const TextStyle(fontSize: 13)),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _StudentNotificationsTab extends StatefulWidget {
  const _StudentNotificationsTab();
  @override
  State<_StudentNotificationsTab> createState() => _StudentNotificationsTabState();
}

class _StudentNotificationsTabState extends State<_StudentNotificationsTab> {
  int _subTab = 0;
  @override
  Widget build(BuildContext context) {
    final app = AppStateScope.of(context);
    final anns = app.announcementsForStage(app.selectedStage);
    final files = app.resourcesFor(app.selectedStage);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(14),
          child: SegmentedButton<int>(
            segments: const [
              ButtonSegment(value: 0, icon: Icon(Icons.notifications_active), label: Text('الإشعارات')),
              ButtonSegment(value: 1, icon: Icon(Icons.picture_as_pdf), label: Text('الكتب والملفات PDF')),
            ],
            selected: {_subTab},
            onSelectionChanged: (s) => setState(() => _subTab = s.first),
          ),
        ),
        Expanded(
          child: _subTab == 0
              ? ListView.builder(
                  padding: const EdgeInsets.all(14),
                  itemCount: anns.length,
                  itemBuilder: (_, i) {
                    final a = anns[i];
                    return Card(
                      color: Colors.white,
                      child: ListTile(
                        leading: Icon(a.isUrgent ? Icons.priority_high_rounded : Icons.campaign_rounded, color: a.isUrgent ? Colors.red : const Color(0xFF1E3A8A)),
                        title: Text(a.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text('${a.body}\n${a.author} • ${a.dateLabel}'),
                      ),
                    );
                  },
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(14),
                  itemCount: files.length,
                  itemBuilder: (_, i) {
                    final r = files[i];
                    return Card(
                      color: Colors.white,
                      child: ListTile(
                        leading: Icon(r.resourceType == 'رابط تعليمي' ? Icons.link : Icons.picture_as_pdf, color: Colors.red),
                        title: Text(r.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text('${r.resourceType} • ${r.linkOrFile}'),
                        trailing: TextButton(
                          onPressed: () => showDialog(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: Text(r.title),
                              content: Text('الملف/الرابط:\n${r.linkOrFile}'),
                              actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إغلاق'))],
                            ),
                          ),
                          child: const Text('فتح'),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

// ============================================================================
// 9. مكونات مساعدة مشتركة (Shared UI Components)
// ============================================================================

class _BannerCard extends StatelessWidget {
  final String title, subtitle;
  final IconData icon;
  final List<Color> colors;
  const _BannerCard({required this.title, required this.subtitle, required this.icon, required this.colors});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(gradient: LinearGradient(colors: colors), borderRadius: BorderRadius.circular(18)),
      child: Row(
        children: [
          CircleAvatar(backgroundColor: Colors.white.withAlpha(45), child: Icon(icon, color: Colors.white)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 16.5, fontWeight: FontWeight.bold, color: Colors.white)),
                Text(subtitle, style: const TextStyle(fontSize: 12.5, color: Colors.white70)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _KpiCard extends StatelessWidget {
  final String title, value;
  final IconData icon;
  final Color color;
  const _KpiCard(this.title, this.value, this.icon, this.color);
  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(title, style: const TextStyle(fontWeight: FontWeight.w600)), Icon(icon, color: color)]),
            Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: color)),
          ],
        ),
      ),
    );
  }
}

class _EmptyWidget extends StatelessWidget {
  final IconData icon;
  final String text;
  const _EmptyWidget(this.icon, this.text);
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 54, color: Colors.grey.shade400),
            const SizedBox(height: 10),
            Text(text, textAlign: TextAlign.center, style: TextStyle(color: Colors.grey.shade600, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}
