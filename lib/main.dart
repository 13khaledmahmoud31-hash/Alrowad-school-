import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:excel/excel.dart' as xl;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const AlRowadPrivateSchoolApp());
}

enum UserRole {
  admin('مدير المدرسة', 'إدارة شاملة للمدرسة والحسابات والمصروفات', Icons.admin_panel_settings_rounded, Color(0xFF1E3A8A)),
  teacher('معلم', 'الطلاب، الحضور، الواجبات، الدرجات والملفات', Icons.cast_for_education_rounded, Color(0xFF0D9488)),
  student('طالب', 'الجدول، الواجبات، الدرجات، النتائج والملفات', Icons.school_rounded, Color(0xFF0284C7)),
  parent('ولي أمر', 'متابعة الأبناء، الحضور، النتائج، المصروفات والتواصل', Icons.family_restroom_rounded, Color(0xFF7C3AED));

  final String label, subtitle;
  final IconData icon;
  final Color color;
  const UserRole(this.label, this.subtitle, this.icon, this.color);
}

enum GradeLevel {
  kg1('KG1 - المستوى الأول', 'KG1'),
  kg2('KG2 - المستوى الثاني', 'KG2'),
  p1('الأول الابتدائي', '1 ابتدائي'),
  p2('الثاني الابتدائي', '2 ابتدائي'),
  p3('الثالث الابتدائي', '3 ابتدائي'),
  p4('الرابع الابتدائي', '4 ابتدائي'),
  p5('الخامس الابتدائي', '5 ابتدائي'),
  p6('السادس الابتدائي', '6 ابتدائي'),
  prep1('الأول الإعدادي', '1 إعدادي'),
  prep2('الثاني الإعدادي', '2 إعدادي'),
  prep3('الثالث الإعدادي', '3 إعدادي');

  final String label, shortLabel;
  const GradeLevel(this.label, this.shortLabel);

  static GradeLevel parseGrade(String raw) {
    final s = raw.trim().toLowerCase();
    for (final g in GradeLevel.values) {
      if (g.name.toLowerCase() == s || g.shortLabel.toLowerCase() == s || g.label.toLowerCase().contains(s)) return g;
    }
    if (s.contains('kg1')) return GradeLevel.kg1;
    if (s.contains('kg2')) return GradeLevel.kg2;
    if (s.contains('إعدادي') || s.contains('prep')) {
      if (s.contains('3')) return GradeLevel.prep3;
      if (s.contains('2')) return GradeLevel.prep2;
      return GradeLevel.prep1;
    }
    if (s.contains('6')) return GradeLevel.p6;
    if (s.contains('5')) return GradeLevel.p5;
    if (s.contains('4')) return GradeLevel.p4;
    if (s.contains('3')) return GradeLevel.p3;
    if (s.contains('2')) return GradeLevel.p2;
    return GradeLevel.p1;
  }
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

enum NotificationType {
  absence('إشعار غياب', Icons.person_off_rounded, Color(0xFFEF4444)),
  announcement('إعلان مدرسي', Icons.campaign_rounded, Color(0xFF1E3A8A)),
  exam('موعد امتحان', Icons.event_note_rounded, Color(0xFF7C3AED)),
  result('نتيجة / درجة', Icons.grade_rounded, Color(0xFF10B981)),
  homework('واجب مدرسي', Icons.assignment_rounded, Color(0xFF0284C7)),
  fees('تنبيه مصروفات', Icons.payments_rounded, Color(0xFFF59E0B));

  final String label;
  final IconData icon;
  final Color color;
  const NotificationType(this.label, this.icon, this.color);
}

class AppUser {
  final String id;
  String name, phone, password, classroom, subject, linkedParentPhone;
  UserRole role;
  GradeLevel grade;
  AppUser({required this.id, required this.name, required this.phone, required this.password, required this.role, this.grade = GradeLevel.p4, this.classroom = 'فصل 4/أ', this.subject = 'الرياضيات', this.linkedParentPhone = ''});
}

class SchoolClass {
  final String id;
  String name, supervisorName;
  GradeLevel grade;
  int capacity;
  SchoolClass({required this.id, required this.name, required this.grade, required this.capacity, required this.supervisorName});
}

class SubjectItem {
  final String id;
  String name, teacherName;
  GradeLevel grade;
  SubjectItem({required this.id, required this.name, required this.grade, required this.teacherName});
}

class ScheduleSlot {
  final String id, day, timeRange, subject, teacherName, classroom;
  GradeLevel grade;
  int period;
  ScheduleSlot({required this.id, required this.grade, required this.day, required this.period, required this.timeRange, required this.subject, required this.teacherName, required this.classroom});
}

class ExamItem {
  final String id, title, subject, dateStr, timeStr, room;
  GradeLevel grade;
  ExamItem({required this.id, required this.title, required this.subject, required this.grade, required this.dateStr, required this.timeStr, required this.room});
}

class AttendanceEntry {
  final String id, studentId, studentName, dateStr;
  GradeLevel grade;
  AttendanceStatus status;
  AttendanceEntry({required this.id, required this.studentId, required this.studentName, required this.grade, required this.dateStr, required this.status});
}

class HomeworkItem {
  final String id, subject, title, details, dueDate, teacherName;
  GradeLevel grade;
  final Set<String> completedStudentIds;
  HomeworkItem({required this.id, required this.grade, required this.subject, required this.title, required this.details, required this.dueDate, required this.teacherName, Set<String>? completedStudentIds}) : completedStudentIds = completedStudentIds ?? {};
}

class GradeEntry {
  final String id, studentId, studentName, subject, examTitle, note;
  GradeLevel grade;
  double score, maxScore;
  GradeEntry({required this.id, required this.studentId, required this.studentName, required this.grade, required this.subject, required this.examTitle, required this.score, required this.maxScore, required this.note});
}

class FeeInvoice {
  final String id, studentId, studentName, title, dueDate;
  GradeLevel grade;
  double totalAmount, paidAmount;
  FeeInvoice({required this.id, required this.studentId, required this.studentName, required this.grade, required this.title, required this.totalAmount, required this.paidAmount, required this.dueDate});
  double get remaining => (totalAmount - paidAmount).clamp(0, totalAmount);
  bool get isFullyPaid => remaining <= 0;
}

class AnnouncementNews {
  final String id, title, body, category, author, dateLabel;
  UserRole? targetRole;
  bool isUrgent;
  AnnouncementNews({required this.id, required this.title, required this.body, required this.category, this.targetRole, required this.author, required this.dateLabel, this.isUrgent = false});
}

class SchoolNotification {
  final String id, title, body, dateLabel;
  final NotificationType type;
  String? targetPhone;
  UserRole? targetRole;
  bool isRead;
  SchoolNotification({required this.id, required this.type, required this.title, required this.body, this.targetPhone, this.targetRole, required this.dateLabel, this.isRead = false});
}

class EducationalFile {
  final String id, title, fileType, subject, urlOrName, uploadedBy, dateLabel;
  GradeLevel grade;
  EducationalFile({required this.id, required this.title, required this.fileType, required this.grade, required this.subject, required this.urlOrName, required this.uploadedBy, required this.dateLabel});
}

class SchoolMessage {
  final String id, senderName, senderPhone, recipientLabel, subject, body, dateLabel;
  String reply;
  SchoolMessage({required this.id, required this.senderName, required this.senderPhone, required this.recipientLabel, required this.subject, required this.body, this.reply = '', required this.dateLabel});
}

class SchoolState extends ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.light;
  AppUser? _currentUser;
  String _selectedParentChildId = 'u_st1';

  ThemeMode get themeMode => _themeMode;
  AppUser? get currentUser => _currentUser;
  static const List<String> weekDays = ['الأحد', 'الإثنين', 'الثلاثاء', 'الأربعاء', 'الخميس'];

  void toggleTheme() {
    _themeMode = _themeMode == ThemeMode.light ? ThemeMode.dark : ThemeMode.light;
    notifyListeners();
  }

  final List<AppUser> _users = [
    AppUser(id: 'u_admin', name: 'أ. خالد محمود (مدير المدرسة)', phone: '01129220696', password: 'khaled123', role: UserRole.admin),
    AppUser(id: 'u_t1', name: 'أ. إسلام عبدالعزيز', phone: '01010101010', password: '123456', role: UserRole.teacher, grade: GradeLevel.p4, subject: 'الرياضيات'),
    AppUser(id: 'u_t2', name: 'أ. سارة مجدي', phone: '01010101011', password: '123456', role: UserRole.teacher, grade: GradeLevel.kg2, subject: 'مهارات اللغة العربية'),
    AppUser(id: 'u_st1', name: 'جنى محمد السيد', phone: '01020202020', password: '123456', role: UserRole.student, grade: GradeLevel.p4, classroom: 'فصل 4/أ', linkedParentPhone: '01030303030'),
    AppUser(id: 'u_st2', name: 'أنس محمد السيد', phone: '01020202021', password: '123456', role: UserRole.student, grade: GradeLevel.kg2, classroom: 'قاعة النجوم', linkedParentPhone: '01030303030'),
    AppUser(id: 'u_st3', name: 'عبدالرحمن هاني صلاح', phone: '01020202022', password: '123456', role: UserRole.student, grade: GradeLevel.prep3, classroom: 'فصل 3/أ إعدادي', linkedParentPhone: '01040404040'),
    AppUser(id: 'u_p1', name: 'أ. محمد السيد (ولي الأمر)', phone: '01030303030', password: '123456', role: UserRole.parent),
  ];

  final List<SchoolClass> _classes = [
    SchoolClass(id: 'c1', name: 'قاعة النجوم - KG2', grade: GradeLevel.kg2, capacity: 22, supervisorName: 'أ. سارة مجدي'),
    SchoolClass(id: 'c2', name: 'فصل 4/أ', grade: GradeLevel.p4, capacity: 28, supervisorName: 'أ. إسلام عبدالعزيز'),
    SchoolClass(id: 'c3', name: 'فصل 3/أ إعدادي', grade: GradeLevel.prep3, capacity: 30, supervisorName: 'أ. خالد نصار'),
  ];

  final List<SubjectItem> _subjects = [
    SubjectItem(id: 'sb1', name: 'الرياضيات', grade: GradeLevel.p4, teacherName: 'أ. إسلام عبدالعزيز'),
    SubjectItem(id: 'sb2', name: 'اللغة العربية', grade: GradeLevel.p4, teacherName: 'أ. محمود الشاذلي'),
    SubjectItem(id: 'sb3', name: 'العلوم', grade: GradeLevel.p4, teacherName: 'أ. هبة سليمان'),
    SubjectItem(id: 'sb4', name: 'مهارات اللغة العربية', grade: GradeLevel.kg2, teacherName: 'أ. سارة مجدي'),
    SubjectItem(id: 'sb5', name: 'الجبر وحساب المثلثات', grade: GradeLevel.prep3, teacherName: 'أ. خالد نصار'),
  ];

  final List<ScheduleSlot> _schedule = [
    ScheduleSlot(id: 'sc1', grade: GradeLevel.p4, day: 'الأحد', period: 1, timeRange: '08:00 - 08:45', subject: 'اللغة العربية', teacherName: 'أ. محمود الشاذلي', classroom: 'فصل 4/أ'),
    ScheduleSlot(id: 'sc2', grade: GradeLevel.p4, day: 'الأحد', period: 2, timeRange: '08:50 - 09:35', subject: 'الرياضيات', teacherName: 'أ. إسلام عبدالعزيز', classroom: 'فصل 4/أ'),
    ScheduleSlot(id: 'sc3', grade: GradeLevel.p4, day: 'الأحد', period: 3, timeRange: '09:50 - 10:35', subject: 'العلوم', teacherName: 'أ. هبة سليمان', classroom: 'معمل العلوم'),
    ScheduleSlot(id: 'sc4', grade: GradeLevel.p4, day: 'الإثنين', period: 1, timeRange: '08:00 - 08:45', subject: 'اللغة الإنجليزية', teacherName: 'Mr. Kareem', classroom: 'فصل 4/أ'),
    ScheduleSlot(id: 'sc5', grade: GradeLevel.p4, day: 'الثلاثاء', period: 1, timeRange: '08:00 - 08:45', subject: 'تكنولوجيا المعلومات', teacherName: 'م. عمر فاروق', classroom: 'معمل الحاسب'),
    ScheduleSlot(id: 'sc6', grade: GradeLevel.kg2, day: 'الأحد', period: 1, timeRange: '08:30 - 09:15', subject: 'مهارات اللغة العربية', teacherName: 'أ. سارة مجدي', classroom: 'قاعة النجوم'),
    ScheduleSlot(id: 'sc7', grade: GradeLevel.prep3, day: 'الأحد', period: 1, timeRange: '08:00 - 08:45', subject: 'الجبر وحساب المثلثات', teacherName: 'أ. خالد نصار', classroom: 'فصل 3/أ إعدادي'),
  ];

  final List<ExamItem> _exams = [
    ExamItem(id: 'ex1', title: 'اختبار شهر نوفمبر', subject: 'الرياضيات', grade: GradeLevel.p4, dateStr: 'الأحد 30 نوفمبر', timeStr: '09:00 ص', room: 'لجنة 4/أ'),
    ExamItem(id: 'ex2', title: 'اختبار شهر نوفمبر', subject: 'اللغة العربية', grade: GradeLevel.p4, dateStr: 'الإثنين 1 ديسمبر', timeStr: '09:00 ص', room: 'لجنة 4/أ'),
    ExamItem(id: 'ex3', title: 'تقييم المهارات', subject: 'مهارات اللغة العربية', grade: GradeLevel.kg2, dateStr: 'الثلاثاء 2 ديسمبر', timeStr: '10:00 ص', room: 'قاعة النجوم'),
    ExamItem(id: 'ex4', title: 'امتحان تجريبي', subject: 'الجبر وحساب المثلثات', grade: GradeLevel.prep3, dateStr: 'الأربعاء 3 ديسمبر', timeStr: '08:30 ص', room: 'القاعة الكبرى'),
  ];

  final List<AttendanceEntry> _attendance = [
    AttendanceEntry(id: 'att1', studentId: 'u_st1', studentName: 'جنى محمد السيد', grade: GradeLevel.p4, dateStr: '2026-11-25', status: AttendanceStatus.present),
    AttendanceEntry(id: 'att2', studentId: 'u_st2', studentName: 'أنس محمد السيد', grade: GradeLevel.kg2, dateStr: '2026-11-25', status: AttendanceStatus.present),
    AttendanceEntry(id: 'att3', studentId: 'u_st3', studentName: 'عبدالرحمن هاني صلاح', grade: GradeLevel.prep3, dateStr: '2026-11-25', status: AttendanceStatus.late),
  ];

  final List<HomeworkItem> _homeworks = [
    HomeworkItem(id: 'hw1', grade: GradeLevel.p4, subject: 'الرياضيات', title: 'تمارين القسمة المطولة', details: 'حل المسائل من 1 إلى 8 ص 42.', dueDate: 'غداً - 08:00 ص', teacherName: 'أ. إسلام عبدالعزيز'),
    HomeworkItem(id: 'hw2', grade: GradeLevel.p4, subject: 'العلوم', title: 'التكيف في الكائنات الحية', details: 'كتابة 5 أمثلة للتكيف التركيبي والسلوكي.', dueDate: 'الخميس القادم', teacherName: 'أ. هبة سليمان', completedStudentIds: {'u_st1'}),
    HomeworkItem(id: 'hw3', grade: GradeLevel.kg2, subject: 'مهارات اللغة العربية', title: 'كتابة حرف الجيم', details: 'نشاط كراسة التهيئة ص 18.', dueDate: 'غداً', teacherName: 'أ. سارة مجدي'),
    HomeworkItem(id: 'hw4', grade: GradeLevel.prep3, subject: 'الجبر', title: 'نموذج الاختبار الثالث', details: 'كراسة التدريبات ص 24.', dueDate: 'غداً', teacherName: 'أ. خالد نصار'),
  ];

  final List<GradeEntry> _grades = [
    GradeEntry(id: 'gr1', studentId: 'u_st1', studentName: 'جنى محمد السيد', grade: GradeLevel.p4, subject: 'الرياضيات', examTitle: 'اختبار أكتوبر', score: 29, maxScore: 30, note: 'أداء ممتاز ومنظم'),
    GradeEntry(id: 'gr2', studentId: 'u_st1', studentName: 'جنى محمد السيد', grade: GradeLevel.p4, subject: 'اللغة العربية', examTitle: 'اختبار أكتوبر', score: 27.5, maxScore: 30, note: 'تعبير إبداعي متميز'),
    GradeEntry(id: 'gr3', studentId: 'u_st1', studentName: 'جنى محمد السيد', grade: GradeLevel.p4, subject: 'العلوم', examTitle: 'اختبار أكتوبر', score: 24, maxScore: 25, note: 'مشاركة فعالة بالمعمل'),
    GradeEntry(id: 'gr4', studentId: 'u_st2', studentName: 'أنس محمد السيد', grade: GradeLevel.kg2, subject: 'مهارات اللغة', examTitle: 'تقييم المهارات', score: 10, maxScore: 10, note: 'متقن للمهارات اللغوية'),
    GradeEntry(id: 'gr5', studentId: 'u_st3', studentName: 'عبدالرحمن هاني صلاح', grade: GradeLevel.prep3, subject: 'الجبر', examTitle: 'التقييم الأول', score: 47, maxScore: 50, note: 'مستوى متفوق'),
  ];

  final List<FeeInvoice> _invoices = [
    FeeInvoice(id: 'inv1', studentId: 'u_st1', studentName: 'جنى محمد السيد', grade: GradeLevel.p4, title: 'القسط الدراسي الأول 2026', totalAmount: 9500, paidAmount: 9500, dueDate: '2026-10-15'),
    FeeInvoice(id: 'inv2', studentId: 'u_st1', studentName: 'جنى محمد السيد', grade: GradeLevel.p4, title: 'القسط الثاني + الباص', totalAmount: 8500, paidAmount: 5000, dueDate: '2026-12-05'),
    FeeInvoice(id: 'inv3', studentId: 'u_st2', studentName: 'أنس محمد السيد', grade: GradeLevel.kg2, title: 'مصروفات الفصل الأول - KG2', totalAmount: 7800, paidAmount: 4000, dueDate: '2026-12-01'),
  ];

  final List<AnnouncementNews> _announcements = [
    AnnouncementNews(id: 'an1', title: 'انطلاق مسابقة أوائل الطلبة بمدرسة الرواد', body: 'تعلن إدارة مدرسة الرواد الخاصة عن بدء التصفيات الأولى لمسابقة أوائل الطلبة الأسبوع القادم.', category: 'إعلان', author: 'إدارة المدرسة', dateLabel: 'اليوم 09:30 ص', isUrgent: true),
    AnnouncementNews(id: 'an2', title: 'فوز فريق المدرسة بالمركز الأول في المسابقة الفنية', body: 'نبارك لطلاب المرحلة الابتدائية ورياض الأطفال الفوز بالميدالية الذهبية.', category: 'خبر', author: 'الأنشطة الطلابية', dateLabel: 'أمس'),
    AnnouncementNews(id: 'an3', title: 'اجتماع مجلس الآباء والمعلمين الشهري', body: 'يسعدنا حضور أولياء الأمور يوم الخميس الساعة 11 صباحاً لمناقشة المستوى التحصيلي.', category: 'إعلان', targetRole: UserRole.parent, author: 'إدارة المدرسة', dateLabel: 'منذ يومين'),
  ];

  final List<SchoolNotification> _notifications = [
    SchoolNotification(id: 'n1', type: NotificationType.announcement, title: 'إعلان هام من الإدارة', body: 'انطلاق مسابقة أوائل الطلبة الأسبوع القادم بمسرح المدرسة.', dateLabel: 'اليوم 09:30 ص'),
    SchoolNotification(id: 'n2', type: NotificationType.exam, title: 'موعد اختبار الرياضيات', body: 'يعقد اختبار شهر نوفمبر للرياضيات يوم الأحد 30 نوفمبر الساعة 9 صباحاً.', dateLabel: 'اليوم 08:15 ص'),
    SchoolNotification(id: 'n3', type: NotificationType.homework, title: 'واجب جديد - الرياضيات', body: 'تم إضافة واجب تمارين القسمة المطولة للصف الرابع الابتدائي.', dateLabel: 'أمس'),
    SchoolNotification(id: 'n4', type: NotificationType.result, title: 'اعتماد نتائج شهر أكتوبر', body: 'تم رصد واعتماد درجات شهر أكتوبر في سجل النتائج.', dateLabel: 'منذ يومين'),
    SchoolNotification(id: 'n5', type: NotificationType.fees, title: 'تذكير بقسط المصروفات', body: 'متبقي 3,500 ج.م على القسط الثاني للطالبة جنى محمد السيد.', targetPhone: '01030303030', targetRole: UserRole.parent, dateLabel: 'منذ 3 أيام'),
  ];

  final List<EducationalFile> _files = [
    EducationalFile(id: 'f1', title: 'مذكرة التفوق في الرياضيات - 4 ابتدائي', fileType: 'PDF', grade: GradeLevel.p4, subject: 'الرياضيات', urlOrName: 'alrowad_math_p4.pdf', uploadedBy: 'أ. إسلام عبدالعزيز', dateLabel: '20 نوفمبر'),
    EducationalFile(id: 'f2', title: 'بنك أسئلة العلوم الشامل', fileType: 'ملخص', grade: GradeLevel.p4, subject: 'العلوم', urlOrName: 'science_bank_p4.pdf', uploadedBy: 'أ. هبة سليمان', dateLabel: '22 نوفمبر'),
    EducationalFile(id: 'f3', title: 'كراسة تأسيس الحروف - KG2', fileType: 'PDF', grade: GradeLevel.kg2, subject: 'مهارات اللغة', urlOrName: 'kg2_arabic_book.pdf', uploadedBy: 'أ. سارة مجدي', dateLabel: '18 نوفمبر'),
    EducationalFile(id: 'f4', title: 'مراجعة الهندسة - 3 إعدادي', fileType: 'PDF', grade: GradeLevel.prep3, subject: 'الجبر', urlOrName: 'prep3_geometry.pdf', uploadedBy: 'أ. خالد نصار', dateLabel: '23 نوفمبر'),
  ];

  final List<SchoolMessage> _messages = [
    SchoolMessage(id: 'm1', senderName: 'أ. محمد السيد', senderPhone: '01030303030', recipientLabel: 'إدارة المدرسة / أ. إسلام عبدالعزيز', subject: 'موعد مراجعة الرياضيات', body: 'هل توجد حصة مراجعة قبل اختبار نوفمبر؟', reply: 'نعم، يوم الأربعاء الساعة 10 صباحاً.', dateLabel: 'أمس'),
  ];

  String? login(String phone, String password) {
    final p = phone.trim(), pass = password.trim();
    if (p.isEmpty || pass.isEmpty) return 'يرجى إدخال رقم الهاتف وكلمة المرور';
    final match = _users.where((u) => u.phone == p && u.password == pass).toList();
    if (match.isEmpty) return 'رقم الهاتف أو كلمة المرور غير صحيحة';
    _currentUser = match.first;
    if (_currentUser!.role == UserRole.parent) {
      final kids = childrenOfParent(_currentUser!.phone);
      if (kids.isNotEmpty) _selectedParentChildId = kids.first.id;
    }
    notifyListeners();
    return null;
  }

  void logout() {
    _currentUser = null;
    notifyListeners();
  }

  List<AppUser> get allUsers => List.unmodifiable(_users);
  List<AppUser> usersByRole(UserRole role) => _users.where((u) => u.role == role).toList();
  List<SchoolClass> get allClasses => List.unmodifiable(_classes);
  List<SubjectItem> get allSubjects => List.unmodifiable(_subjects);
  List<ScheduleSlot> get allSchedule => List.unmodifiable(_schedule);
  List<ExamItem> get allExams => List.unmodifiable(_exams);
  List<AttendanceEntry> get allAttendance => List.unmodifiable(_attendance);
  List<HomeworkItem> get allHomeworks => List.unmodifiable(_homeworks);
  List<GradeEntry> get allGrades => List.unmodifiable(_grades);
  List<FeeInvoice> get allInvoices => List.unmodifiable(_invoices);
  List<AnnouncementNews> get allAnnouncements => List.unmodifiable(_announcements);
  List<EducationalFile> get allFiles => List.unmodifiable(_files);
  List<SchoolMessage> get allMessages => List.unmodifiable(_messages);

  List<AppUser> childrenOfParent(String parentPhone) {
    final kids = _users.where((u) => u.role == UserRole.student && u.linkedParentPhone == parentPhone).toList();
    return kids.isNotEmpty ? kids : _users.where((u) => u.role == UserRole.student).take(1).toList();
  }

  AppUser? get selectedParentChild {
    if (_currentUser == null) return null;
    final kids = childrenOfParent(_currentUser!.phone);
    if (kids.isEmpty) return null;
    return kids.firstWhere((k) => k.id == _selectedParentChildId, orElse: () => kids.first);
  }

  void selectParentChild(String studentId) {
    _selectedParentChildId = studentId;
    notifyListeners();
  }

  List<SchoolNotification> notificationsForCurrentUser() {
    final u = _currentUser;
    if (u == null) return [];
    return _notifications.where((n) {
      if (n.targetPhone != null && n.targetPhone == u.phone) return true;
      if (n.targetPhone == null && (n.targetRole == null || n.targetRole == u.role)) return true;
      return u.role == UserRole.admin;
    }).toList();
  }

  int get unreadNotificationsCount => notificationsForCurrentUser().where((n) => !n.isRead).length;

  void markNotificationsRead() {
    for (final n in notificationsForCurrentUser()) {
      n.isRead = true;
    }
    notifyListeners();
  }

  String? addUser({required String name, required String phone, required String password, required UserRole role, GradeLevel grade = GradeLevel.p4, String classroom = '', String subject = 'الرياضيات', String linkedParentPhone = ''}) {
    final cleanPhone = phone.trim();
    if (name.trim().isEmpty || cleanPhone.isEmpty || password.trim().isEmpty) return 'يرجى استكمال الاسم والهاتف وكلمة المرور';
    if (_users.any((u) => u.phone == cleanPhone)) return 'رقم الهاتف مسجل بالفعل لحساب آخر';
    final user = AppUser(id: 'u_${DateTime.now().microsecondsSinceEpoch}', name: name.trim(), phone: cleanPhone, password: password.trim(), role: role, grade: grade, classroom: classroom.trim().isEmpty ? 'فصل ${grade.shortLabel}' : classroom.trim(), subject: subject.trim().isEmpty ? 'عام' : subject.trim(), linkedParentPhone: linkedParentPhone.trim());
    _users.add(user);
    if (role == UserRole.student) {
      _attendance.add(AttendanceEntry(id: 'att_${DateTime.now().microsecondsSinceEpoch}', studentId: user.id, studentName: user.name, grade: user.grade, dateStr: '2026-11-25', status: AttendanceStatus.present));
    }
    notifyListeners();
    return null;
  }

  void deleteUser(String id) {
    if (_currentUser?.id == id) return;
    _users.removeWhere((u) => u.id == id);
    notifyListeners();
  }

  String _cellText(xl.CellValue? val) {
    if (val == null) return '';
    if (val is xl.TextCellValue) return val.value.text ?? val.value.toString();
    if (val is xl.IntCellValue) return val.value.toString();
    if (val is xl.DoubleCellValue) {
      final d = val.value;
      return d == d.roundToDouble() ? d.toInt().toString() : d.toString();
    }
    if (val is xl.BoolCellValue) return val.value.toString();
    if (val is xl.FormulaCellValue) return val.formula;
    return val.toString();
  }

  UserRole _parseRole(String raw) {
    final r = raw.trim().toLowerCase();
    if (r.contains('معلم') || r.contains('teacher')) return UserRole.teacher;
    if (r.contains('ولي') || r.contains('parent')) return UserRole.parent;
    if (r.contains('مدير') || r.contains('admin')) return UserRole.admin;
    return UserRole.student;
  }

  ({int added, int skipped}) importRows(List<List<String>> rows) {
    int added = 0, skipped = 0;
    for (int i = 0; i < rows.length; i++) {
      final c = rows[i].map((e) => e.trim()).toList();
      if (c.length < 4) continue;
      if (i == 0 && (c[0].contains('الاسم') || c[2].contains('الهاتف') || c[2].toLowerCase().contains('phone'))) continue;
      if (c[0].isEmpty || c[2].isEmpty || c[3].isEmpty) {
        skipped++;
        continue;
      }
      final role = _parseRole(c[1]);
      final grade = c.length > 4 && c[4].isNotEmpty ? GradeLevel.parseGrade(c[4]) : GradeLevel.p4;
      final extra = c.length > 5 ? c[5] : '';
      final err = addUser(name: c[0], phone: c[2], password: c[3], role: role, grade: grade, subject: role == UserRole.teacher && extra.isNotEmpty ? extra : 'عام', linkedParentPhone: role == UserRole.student ? extra : '');
      if (err == null) {
        added++;
      } else {
        skipped++;
      }
    }
    return (added: added, skipped: skipped);
  }

  ({int added, int skipped, String message}) importExcelOrCsvBytes(Uint8List bytes, String fileName) {
    try {
      if (fileName.toLowerCase().endsWith('.csv')) return importDelimitedText(utf8.decode(bytes, allowMalformed: true));
      final wb = xl.Excel.decodeBytes(bytes);
      final List<List<String>> rows = [];
      for (final name in wb.tables.keys) {
        final sheet = wb.tables[name];
        if (sheet == null) continue;
        for (final row in sheet.rows) {
          rows.add(row.map((cell) => _cellText(cell?.value)).toList());
        }
        break;
      }
      final res = importRows(rows);
      return (added: res.added, skipped: res.skipped, message: 'تمت قراءة ملف الإكسيل');
    } catch (_) {
      return (added: 0, skipped: 0, message: 'تعذر قراءة الملف، تأكد أنه بصيغة .xlsx أو .csv');
    }
  }

  ({int added, int skipped, String message}) importDelimitedText(String text) {
    final lines = text.split(RegExp(r'\r?\n')).where((l) => l.trim().isNotEmpty).toList();
    final rows = lines.map((l) => l.contains('\t') ? l.split('\t') : (l.contains(';') ? l.split(';') : l.split(','))).toList();
    final res = importRows(rows);
    return (added: res.added, skipped: res.skipped, message: 'تمت معالجة البيانات');
  }

  void addClass(String name, GradeLevel grade, int cap, String sup) {
    _classes.add(SchoolClass(id: 'c_${DateTime.now().microsecondsSinceEpoch}', name: name, grade: grade, capacity: cap, supervisorName: sup));
    notifyListeners();
  }

  void deleteClass(String id) {
    _classes.removeWhere((c) => c.id == id);
    notifyListeners();
  }

  void addSubject(String name, GradeLevel grade, String teacher) {
    _subjects.add(SubjectItem(id: 'sb_${DateTime.now().microsecondsSinceEpoch}', name: name, grade: grade, teacherName: teacher));
    notifyListeners();
  }

  void deleteSubject(String id) {
    _subjects.removeWhere((s) => s.id == id);
    notifyListeners();
  }

  void addScheduleSlot(GradeLevel grade, String day, int period, String time, String sub, String teacher, String room) {
    _schedule.add(ScheduleSlot(id: 'sc_${DateTime.now().microsecondsSinceEpoch}', grade: grade, day: day, period: period, timeRange: time, subject: sub, teacherName: teacher, classroom: room));
    notifyListeners();
  }

  void deleteScheduleSlot(String id) {
    _schedule.removeWhere((s) => s.id == id);
    notifyListeners();
  }

  void addExam(String title, String sub, GradeLevel grade, String dateStr, String timeStr, String room) {
    _exams.insert(0, ExamItem(id: 'ex_${DateTime.now().microsecondsSinceEpoch}', title: title, subject: sub, grade: grade, dateStr: dateStr, timeStr: timeStr, room: room));
    _pushNotif(NotificationType.exam, 'موعد امتحان: $sub', '$title (${grade.shortLabel}) يوم $dateStr الساعة $timeStr');
  }

  void deleteExam(String id) {
    _exams.removeWhere((e) => e.id == id);
    notifyListeners();
  }

  AttendanceStatus attendanceOf(String studentId) {
    final m = _attendance.where((a) => a.studentId == studentId).toList();
    return m.isEmpty ? AttendanceStatus.present : m.first.status;
  }

  void recordAttendance(AppUser st, AttendanceStatus status) {
    final i = _attendance.indexWhere((a) => a.studentId == st.id && a.dateStr == '2026-11-25');
    if (i != -1) {
      _attendance[i].status = status;
    } else {
      _attendance.insert(0, AttendanceEntry(id: 'att_${DateTime.now().microsecondsSinceEpoch}', studentId: st.id, studentName: st.name, grade: st.grade, dateStr: '2026-11-25', status: status));
    }
    if (status == AttendanceStatus.absent) {
      _pushNotif(NotificationType.absence, 'إشعار غياب', 'تم تسجيل (${st.name}) غائباً اليوم.', targetPhone: st.linkedParentPhone.isNotEmpty ? st.linkedParentPhone : null, targetRole: UserRole.parent);
    }
    notifyListeners();
  }

  void addHomework(GradeLevel grade, String sub, String title, String details, String due) {
    _homeworks.insert(0, HomeworkItem(id: 'hw_${DateTime.now().microsecondsSinceEpoch}', grade: grade, subject: sub, title: title, details: details, dueDate: due, teacherName: _currentUser?.name ?? 'المعلم'));
    _pushNotif(NotificationType.homework, 'واجب جديد: $sub', '$title (${grade.shortLabel}) - التسليم: $due');
  }

  void toggleHomeworkCompletion(String hwId, String studentId) {
    final i = _homeworks.indexWhere((h) => h.id == hwId);
    if (i != -1) {
      if (_homeworks[i].completedStudentIds.contains(studentId)) {
        _homeworks[i].completedStudentIds.remove(studentId);
      } else {
        _homeworks[i].completedStudentIds.add(studentId);
      }
      notifyListeners();
    }
  }

  void addGrade(AppUser st, String sub, String exam, double score, double maxScore, String note) {
    _grades.insert(0, GradeEntry(id: 'gr_${DateTime.now().microsecondsSinceEpoch}', studentId: st.id, studentName: st.name, grade: st.grade, subject: sub, examTitle: exam, score: score, maxScore: maxScore, note: note));
    _pushNotif(NotificationType.result, 'نتيجة جديدة: $sub', 'حصل ${st.name} على $score / $maxScore في $exam.', targetPhone: st.linkedParentPhone.isNotEmpty ? st.linkedParentPhone : null);
  }

  void addInvoice(AppUser st, String title, double total, double paid, String due) {
    _invoices.insert(0, FeeInvoice(id: 'inv_${DateTime.now().microsecondsSinceEpoch}', studentId: st.id, studentName: st.name, grade: st.grade, title: title, totalAmount: total, paidAmount: paid, dueDate: due));
    if (total > paid) {
      _pushNotif(NotificationType.fees, 'تنبيه مصروفات', 'فاتورة ($title) للطالب ${st.name} متبقي ${(total - paid).toStringAsFixed(0)} ج.م.', targetPhone: st.linkedParentPhone.isNotEmpty ? st.linkedParentPhone : null, targetRole: UserRole.parent);
    }
    notifyListeners();
  }

  void payInvoice(String id, double amount) {
    final i = _invoices.indexWhere((x) => x.id == id);
    if (i != -1) {
      _invoices[i].paidAmount = (_invoices[i].paidAmount + amount).clamp(0, _invoices[i].totalAmount);
      _pushNotif(NotificationType.fees, 'تأكيد سداد مصروفات', 'تم سداد ${amount.toStringAsFixed(0)} ج.م لـ (${_invoices[i].title}).');
      notifyListeners();
    }
  }

  void addAnnouncement(String title, String body, String cat, UserRole? target, bool urgent) {
    _announcements.insert(0, AnnouncementNews(id: 'an_${DateTime.now().microsecondsSinceEpoch}', title: title, body: body, category: cat, targetRole: target, author: _currentUser?.name ?? 'الإدارة', dateLabel: 'الآن', isUrgent: urgent));
    _pushNotif(NotificationType.announcement, '$cat: $title', body, targetRole: target);
  }

  void sendCustomNotif(NotificationType type, String title, String body, UserRole? target) => _pushNotif(type, title, body, targetRole: target);

  void _pushNotif(NotificationType type, String title, String body, {String? targetPhone, UserRole? targetRole}) {
    _notifications.insert(0, SchoolNotification(id: 'n_${DateTime.now().microsecondsSinceEpoch}', type: type, title: title, body: body, targetPhone: targetPhone, targetRole: targetRole, dateLabel: 'الآن'));
    notifyListeners();
  }

  void addFile(String title, String type, GradeLevel grade, String sub, String url) {
    _files.insert(0, EducationalFile(id: 'f_${DateTime.now().microsecondsSinceEpoch}', title: title, fileType: type, grade: grade, subject: sub, urlOrName: url, uploadedBy: _currentUser?.name ?? 'المعلم', dateLabel: 'اليوم'));
    notifyListeners();
  }

  void sendMessage(String recipient, String subject, String body) {
    final u = _currentUser;
    if (u == null) return;
    _messages.insert(0, SchoolMessage(id: 'm_${DateTime.now().microsecondsSinceEpoch}', senderName: u.name, senderPhone: u.phone, recipientLabel: recipient, subject: subject, body: body, dateLabel: 'الآن'));
    notifyListeners();
  }

  void replyMessage(String id, String reply) {
    final i = _messages.indexWhere((m) => m.id == id);
    if (i != -1) {
      _messages[i].reply = reply;
      notifyListeners();
    }
  }
}

class AppScope extends InheritedNotifier<SchoolState> {
  const AppScope({super.key, required SchoolState state, required super.child}) : super(notifier: state);
  static SchoolState of(BuildContext context) => context.dependOnInheritedWidgetOfExactType<AppScope>()!.notifier!;
}

class AlRowadPrivateSchoolApp extends StatefulWidget {
  const AlRowadPrivateSchoolApp({super.key});
  @override
  State<AlRowadPrivateSchoolApp> createState() => _AlRowadPrivateSchoolAppState();
}

class _AlRowadPrivateSchoolAppState extends State<AlRowadPrivateSchoolApp> {
  final SchoolState _state = SchoolState();
  @override
  void dispose() {
    _state.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppScope(
      state: _state,
      child: AnimatedBuilder(
        animation: _state,
        builder: (_, __) {
          final light = ColorScheme.fromSeed(seedColor: const Color(0xFF1E3A8A), secondary: const Color(0xFF0D9488), brightness: Brightness.light);
          final dark = ColorScheme.fromSeed(seedColor: const Color(0xFF3B82F6), secondary: const Color(0xFF14B8A6), brightness: Brightness.dark);
          return MaterialApp(
            debugShowCheckedModeBanner: false,
            title: 'مدرسة الرواد الخاصة',
            themeMode: _state.themeMode,
            theme: ThemeData(useMaterial3: true, colorScheme: light, scaffoldBackgroundColor: const Color(0xFFF3F6FB), appBarTheme: AppBarTheme(centerTitle: true, backgroundColor: light.primary, foregroundColor: Colors.white), inputDecorationTheme: InputDecorationTheme(filled: true, fillColor: Colors.white, border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)))),
            darkTheme: ThemeData(useMaterial3: true, colorScheme: dark, scaffoldBackgroundColor: const Color(0xFF0F172A), appBarTheme: const AppBarTheme(centerTitle: true, backgroundColor: Color(0xFF1E293B), foregroundColor: Colors.white), inputDecorationTheme: InputDecorationTheme(filled: true, fillColor: const Color(0xFF1E293B), border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)))),
            builder: (_, child) => Directionality(textDirection: TextDirection.rtl, child: child!),
            home: const _AppGate(),
          );
        },
      ),
    );
  }
}

class _AppGate extends StatefulWidget {
  const _AppGate();
  @override
  State<_AppGate> createState() => _AppGateState();
}

class _AppGateState extends State<_AppGate> {
  bool _splash = true;
  @override
  void initState() {
    super.initState();
    Timer(const Duration(milliseconds: 1700), () {
      if (mounted) setState(() => _splash = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_splash) return const _SplashScreen();
    final user = AppScope.of(context).currentUser;
    if (user == null) return const LoginScreen();
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 280),
      child: switch (user.role) {
        UserRole.admin => const AdminDashboard(key: ValueKey('admin')),
        UserRole.teacher => const TeacherDashboard(key: ValueKey('teacher')),
        UserRole.student => const StudentDashboard(key: ValueKey('student')),
        UserRole.parent => const ParentDashboard(key: ValueKey('parent')),
      },
    );
  }
}

class AlRowadLogo extends StatelessWidget {
  final double size;
  const AlRowadLogo({super.key, this.size = 82});
  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(shape: BoxShape.circle, gradient: const LinearGradient(colors: [Color(0xFF1E3A8A), Color(0xFF0D9488)]), border: Border.all(color: const Color(0xFFFBBF24), width: 3)),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Icon(Icons.school_rounded, size: size * 0.5, color: Colors.white),
          Positioned(
            bottom: size * 0.13,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(color: const Color(0xFFFBBF24), borderRadius: BorderRadius.circular(8)),
              child: Text('الرواد', style: TextStyle(fontSize: size * 0.14, fontWeight: FontWeight.w900, color: const Color(0xFF1E3A8A))),
            ),
          ),
        ],
      ),
    );
  }
}

class _SplashScreen extends StatelessWidget {
  const _SplashScreen();
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(gradient: LinearGradient(colors: [Color(0xFF0F172A), Color(0xFF1E3A8A), Color(0xFF0D9488)], begin: Alignment.topRight, end: Alignment.bottomLeft)),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AlRowadLogo(size: 110),
            SizedBox(height: 20),
            Text('مدرسة الرواد الخاصة', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: Colors.white)),
            Text('Al Rowad Private School', style: TextStyle(fontSize: 14, color: Color(0xFFFEF08A), fontWeight: FontWeight.w600)),
            SizedBox(height: 32),
            CircularProgressIndicator(valueColor: AlwaysStoppedAnimation(Color(0xFFFBBF24))),
          ],
        ),
      ),
    );
  }
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _phoneCtrl = TextEditingController(text: '01129220696');
  final _passCtrl = TextEditingController(text: 'khaled123');
  bool _obscure = true, _loading = false;
  String? _error;

  @override
  void dispose() {
    _phoneCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    await Future.delayed(const Duration(milliseconds: 300));
    if (!mounted) return;
    final err = AppScope.of(context).login(_phoneCtrl.text, _passCtrl.text);
    setState(() {
      _loading = false;
      _error = err;
    });
  }

  void _fill(String p, String pass) => setState(() {
        _phoneCtrl.text = p;
        _passCtrl.text = pass;
        _error = null;
      });

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 500),
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                Container(
                  padding: const EdgeInsets.fromLTRB(18, 12, 18, 24),
                  decoration: const BoxDecoration(gradient: LinearGradient(colors: [Color(0xFF1E3A8A), Color(0xFF0D9488)]), borderRadius: BorderRadius.vertical(bottom: Radius.circular(28))),
                  child: Column(
                    children: [
                      Align(alignment: Alignment.centerLeft, child: IconButton(icon: Icon(app.themeMode == ThemeMode.dark ? Icons.light_mode : Icons.dark_mode, color: Colors.white), onPressed: app.toggleTheme)),
                      const AlRowadLogo(size: 84),
                      const SizedBox(height: 10),
                      const Text('مدرسة الرواد الخاصة', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Colors.white)),
                      const Text('Al Rowad Private School', style: TextStyle(fontSize: 13, color: Color(0xFFFEF08A))),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('تسجيل الدخول', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 14),
                      TextField(controller: _phoneCtrl, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'رقم الهاتف', prefixIcon: Icon(Icons.phone_android_rounded))),
                      const SizedBox(height: 12),
                      TextField(controller: _passCtrl, obscureText: _obscure, decoration: InputDecoration(labelText: 'كلمة المرور', prefixIcon: const Icon(Icons.lock_rounded), suffixIcon: IconButton(icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility), onPressed: () => setState(() => _obscure = !_obscure)))),
                      if (_error != null) ...[
                        const SizedBox(height: 10),
                        Container(width: double.infinity, padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: Colors.red.withAlpha(28), borderRadius: BorderRadius.circular(12)), child: Text(_error!, style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold))),
                      ],
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1E3A8A), foregroundColor: Colors.white),
                          onPressed: _loading ? null : _submit,
                          icon: _loading ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.login_rounded),
                          label: Text(_loading ? 'جاري الدخول...' : 'دخول إلى النظام'),
                        ),
                      ),
                      const SizedBox(height: 18),
                      const Text('دخول سريع للحسابات التجريبية:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          ActionChip(label: const Text('المدير (01129220696)'), onPressed: () => _fill('01129220696', 'khaled123')),
                          ActionChip(label: const Text('معلم (01010101010)'), onPressed: () => _fill('01010101010', '123456')),
                          ActionChip(label: const Text('طالب (01020202020)'), onPressed: () => _fill('01020202020', '123456')),
                          ActionChip(label: const Text('ولي أمر (01030303030)'), onPressed: () => _fill('01030303030', '123456')),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _UnifiedHomeTab extends StatelessWidget {
  final ValueChanged<int> onNavigateTab;
  final List<({String title, IconData icon, Color color, int tab})> shortcuts;
  const _UnifiedHomeTab({required this.onNavigateTab, required this.shortcuts});

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final user = app.currentUser!;
    final grade = user.role == UserRole.parent ? (app.selectedParentChild?.grade ?? GradeLevel.p4) : user.grade;
    final todaySlots = app.allSchedule.where((s) => (user.role == UserRole.admin || s.grade == grade) && s.day == 'الأحد').toList();
    final exams = app.allExams.where((e) => user.role == UserRole.admin || e.grade == grade).toList();
    final notifs = app.notificationsForCurrentUser().take(3).toList();

    return ListView(
      padding: const EdgeInsets.all(14),
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(gradient: LinearGradient(colors: [user.role.color, const Color(0xFF0D9488)]), borderRadius: BorderRadius.circular(20)),
          child: Row(
            children: [
              const AlRowadLogo(size: 58),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('مدرسة الرواد الخاصة', style: TextStyle(color: Color(0xFFFEF08A), fontSize: 12, fontWeight: FontWeight.bold)),
                    Text('مرحباً، ${user.name}', style: const TextStyle(color: Colors.white, fontSize: 16.5, fontWeight: FontWeight.w900)),
                    Text(user.role.label, style: const TextStyle(color: Colors.white70, fontSize: 12.5)),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        const Text('اختصارات الخدمات المهمة', style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
          childAspectRatio: 2.3,
          children: shortcuts.map((sc) => InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: () => onNavigateTab(sc.tab),
                child: Card(
                  margin: EdgeInsets.zero,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: Row(
                      children: [
                        CircleAvatar(radius: 17, backgroundColor: sc.color.withAlpha(30), child: Icon(sc.icon, color: sc.color, size: 19)),
                        const SizedBox(width: 8),
                        Expanded(child: Text(sc.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5))),
                      ],
                    ),
                  ),
                ),
              )).toList(),
        ),
        const SizedBox(height: 16),
        const Text('جدول اليوم', style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        if (todaySlots.isEmpty)
          const Card(child: Padding(padding: EdgeInsets.all(12), child: Text('لا توجد حصص لليوم')))
        else
          SizedBox(
            height: 92,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: todaySlots.length,
              itemBuilder: (_, i) {
                final s = todaySlots[i];
                return Container(
                  width: 185,
                  margin: const EdgeInsets.only(left: 8),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: Theme.of(context).cardColor, borderRadius: BorderRadius.circular(14), border: Border.all(color: Colors.grey.withAlpha(55))),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('${s.subject} (${s.grade.shortLabel})', style: const TextStyle(fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis),
                      Text(s.teacherName, style: TextStyle(fontSize: 12, color: Theme.of(context).hintColor), overflow: TextOverflow.ellipsis),
                      Text('${s.timeRange} • ${s.classroom}', style: const TextStyle(fontSize: 11, color: Color(0xFF0D9488), fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis),
                    ],
                  ),
                );
              },
            ),
          ),
        const SizedBox(height: 16),
        const Text('مواعيد الامتحانات', style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.bold)),
        ...exams.take(3).map((e) => Card(child: ListTile(leading: const Icon(Icons.event_note, color: Color(0xFF7C3AED)), title: Text('${e.subject} - ${e.title}', style: const TextStyle(fontWeight: FontWeight.bold)), subtitle: Text('${e.grade.shortLabel} • ${e.dateStr} • ${e.timeStr}')))),
        const SizedBox(height: 14),
        const Text('الإعلانات المدرسية وآخر الأخبار', style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.bold)),
        ...app.allAnnouncements.take(3).map((a) => Card(child: ListTile(leading: Icon(a.category == 'خبر' ? Icons.newspaper : Icons.campaign, color: const Color(0xFF1E3A8A)), title: Text('[${a.category}] ${a.title}', style: const TextStyle(fontWeight: FontWeight.bold)), subtitle: Text('${a.body}\n${a.dateLabel}')))),
        const SizedBox(height: 14),
        const Text('إشعارات المدرسة', style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.bold)),
        ...notifs.map((n) => Card(child: ListTile(leading: Icon(n.type.icon, color: n.type.color), title: Text(n.title, style: const TextStyle(fontWeight: FontWeight.bold)), subtitle: Text('${n.body} (${n.dateLabel})')))),
      ],
    );
  }
}

PreferredSizeWidget _schoolAppBar(BuildContext context, String title) {
  final app = AppScope.of(context);
  final unread = app.unreadNotificationsCount;
  return AppBar(
    title: Text(title),
    actions: [
      IconButton(icon: Badge(isLabelVisible: unread > 0, label: Text('$unread'), child: const Icon(Icons.notifications_active_rounded)), onPressed: () => _openNotifs(context)),
      IconButton(icon: Icon(app.themeMode == ThemeMode.dark ? Icons.light_mode : Icons.dark_mode), onPressed: app.toggleTheme),
      IconButton(icon: const Icon(Icons.logout_rounded), onPressed: app.logout),
    ],
  );
}

void _openNotifs(BuildContext context) {
  final app = AppScope.of(context);
  app.markNotificationsRead();
  final list = app.notificationsForCurrentUser();
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (_) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.65,
      builder: (_, ctrl) => Column(
        children: [
          const Padding(padding: EdgeInsets.all(14), child: Text('مركز إشعارات المدرسة', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold))),
          Expanded(
            child: ListView.builder(
              controller: ctrl,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: list.length,
              itemBuilder: (_, i) {
                final n = list[i];
                return Card(child: ListTile(leading: Icon(n.type.icon, color: n.type.color), title: Text('${n.type.label}: ${n.title}', style: const TextStyle(fontWeight: FontWeight.bold)), subtitle: Text('${n.body}\n${n.dateLabel}')));
              },
            ),
          ),
        ],
      ),
    ),
  );
}
// ============================================================================
// 6. لوحة الإدارة (Admin Dashboard)
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
    final pages = [
      _UnifiedHomeTab(
        onNavigateTab: (t) => setState(() => _tab = t),
        shortcuts: const [
          (title: 'إدارة الحسابات والإكسيل', icon: Icons.group_add_rounded, color: Color(0xFF1E3A8A), tab: 1),
          (title: 'الفصول والمواد والجداول', icon: Icons.school_rounded, color: Color(0xFF0D9488), tab: 2),
          (title: 'إدارة المصروفات', icon: Icons.payments_rounded, color: Color(0xFFF59E0B), tab: 3),
          (title: 'الإحصائيات والإعلانات', icon: Icons.bar_chart_rounded, color: Color(0xFF7C3AED), tab: 4),
        ],
      ),
      const _AdminUsersTab(),
      const _AdminAcademicTab(),
      const _AdminFeesTab(),
      const _AdminReportsTab(),
    ];

    return Scaffold(
      appBar: _schoolAppBar(context, 'إدارة مدرسة الرواد'),
      body: pages[_tab],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_rounded), label: 'الرئيسية'),
          NavigationDestination(icon: Icon(Icons.people_alt_rounded), label: 'الحسابات'),
          NavigationDestination(icon: Icon(Icons.menu_book_rounded), label: 'الأكاديمي'),
          NavigationDestination(icon: Icon(Icons.payments_rounded), label: 'المصروفات'),
          NavigationDestination(icon: Icon(Icons.analytics_rounded), label: 'التقارير'),
        ],
      ),
    );
  }
}

class _AdminUsersTab extends StatefulWidget {
  const _AdminUsersTab();
  @override
  State<_AdminUsersTab> createState() => _AdminUsersTabState();
}

class _AdminUsersTabState extends State<_AdminUsersTab> {
  UserRole _roleFilter = UserRole.student;

  void _addUserSheet() {
    final name = TextEditingController();
    final phone = TextEditingController();
    final pass = TextEditingController(text: '123456');
    final extra = TextEditingController();
    UserRole role = _roleFilter;
    GradeLevel grade = GradeLevel.p4;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setM) => Padding(
          padding: EdgeInsets.fromLTRB(16, 16, 16, MediaQuery.of(ctx).viewInsets.bottom + 16),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('إضافة معلم / طالب بكلمة مرور', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                DropdownButtonFormField<UserRole>(value: role, items: UserRole.values.map((r) => DropdownMenuItem(value: r, child: Text(r.label))).toList(), onChanged: (v) { if (v != null) setM(() => role = v); }),
                const SizedBox(height: 8),
                TextField(controller: name, decoration: const InputDecoration(labelText: 'الاسم الكامل')),
                const SizedBox(height: 8),
                TextField(controller: phone, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'رقم الهاتف')),
                const SizedBox(height: 8),
                TextField(controller: pass, decoration: const InputDecoration(labelText: 'كلمة المرور')),
                if (role == UserRole.student || role == UserRole.teacher) ...[
                  const SizedBox(height: 8),
                  DropdownButtonFormField<GradeLevel>(value: grade, items: GradeLevel.values.map((g) => DropdownMenuItem(value: g, child: Text(g.label))).toList(), onChanged: (v) { if (v != null) setM(() => grade = v); }),
                  const SizedBox(height: 8),
                  TextField(controller: extra, decoration: InputDecoration(labelText: role == UserRole.teacher ? 'المادة' : 'هاتف ولي الأمر')),
                ],
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      final err = AppScope.of(context).addUser(name: name.text, phone: phone.text, password: pass.text, role: role, grade: grade, subject: role == UserRole.teacher ? extra.text : 'عام', linkedParentPhone: role == UserRole.student ? extra.text : '');
                      if (err != null) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
                        return;
                      }
                      Navigator.pop(ctx);
                      setState(() => _roleFilter = role);
                    },
                    child: const Text('حفظ الحساب'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _excelImportSheet() {
    final pasteCtrl = TextEditingController();
    const template = 'الاسم,الصفة,رقم الهاتف,كلمة المرور,الصف,هاتف ولي الأمر أو المادة\nيوسف أحمد,طالب,01055566601,pass123,4 ابتدائي,01030303030\nأ. رانيا سمير,معلم,01055566602,teach123,5 ابتدائي,العلوم';
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(16, 16, 16, MediaQuery.of(ctx).viewInsets.bottom + 16),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('إضافة الطلاب والمعلمين من Excel', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              const Text('الأعمدة: الاسم | الصفة (طالب/معلم/ولي أمر) | الهاتف | كلمة المرور | الصف | هاتف ولي الأمر أو المادة', style: TextStyle(fontSize: 12)),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0D9488), foregroundColor: Colors.white),
                  onPressed: () async {
                    try {
                      final picked = await FilePicker.pickFile(type: FileType.custom, allowedExtensions: ['xlsx', 'csv']);
                      if (picked == null) return;
                      final bytes = await picked.readAsBytes();
                      if (!context.mounted) return;
                      final res = AppScope.of(context).importExcelOrCsvBytes(bytes, picked.name);
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${res.message}: أضيف ${res.added} (تخطي ${res.skipped})')));
                    } catch (_) {
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('استخدم اللصق المباشر بالأسفل أو ملف xlsx/csv')));
                    }
                  },
                  icon: const Icon(Icons.upload_file_rounded),
                  label: const Text('رفع ملف .xlsx أو .csv'),
                ),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () {
                  Clipboard.setData(const ClipboardData(text: template));
                  pasteCtrl.text = template;
                },
                icon: const Icon(Icons.copy),
                label: const Text('تعبئة نموذج Excel جاهز للتجربة'),
              ),
              const SizedBox(height: 8),
              TextField(controller: pasteCtrl, maxLines: 4, decoration: const InputDecoration(labelText: 'أو الصق جدول الإكسيل هنا')),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    if (pasteCtrl.text.trim().isEmpty) return;
                    final res = AppScope.of(context).importDelimitedText(pasteCtrl.text);
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${res.message}: أضيف ${res.added} (تخطي ${res.skipped})')));
                  },
                  child: const Text('استيراد من النص'),
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
    final app = AppScope.of(context);
    final users = app.usersByRole(_roleFilter);
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(onPressed: _addUserSheet, icon: const Icon(Icons.person_add), label: const Text('إضافة حساب')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(10),
            child: Row(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: UserRole.values.map((r) => Padding(
                            padding: const EdgeInsets.only(left: 6),
                            child: ChoiceChip(label: Text('${r.label} (${app.usersByRole(r).length})'), selected: _roleFilter == r, onSelected: (_) => setState(() => _roleFilter = r)),
                          )).toList(),
                    ),
                  ),
                ),
                IconButton.filledTonal(tooltip: 'استيراد Excel', onPressed: _excelImportSheet, icon: const Icon(Icons.table_view_rounded)),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 80),
              itemCount: users.length,
              itemBuilder: (_, i) {
                final u = users[i];
                return Card(
                  child: ListTile(
                    leading: CircleAvatar(backgroundColor: u.role.color.withAlpha(30), child: Icon(u.role.icon, color: u.role.color)),
                    title: Text(u.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text('الهاتف: ${u.phone} • كلمة المرور: ${u.password}'),
                    trailing: u.phone == '01129220696' ? const Chip(label: Text('أساسي')) : IconButton(icon: const Icon(Icons.delete_outline, color: Colors.red), onPressed: () => app.deleteUser(u.id)),
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

class _AdminAcademicTab extends StatefulWidget {
  const _AdminAcademicTab();
  @override
  State<_AdminAcademicTab> createState() => _AdminAcademicTabState();
}

class _AdminAcademicTabState extends State<_AdminAcademicTab> {
  int _sub = 0;

  void _openAddDialog() {
    final c1 = TextEditingController();
    final c2 = TextEditingController();
    final c3 = TextEditingController(text: '09:00 ص');
    GradeLevel g = GradeLevel.p4;
    String kind = _sub == 0 ? 'فصل' : 'امتحان';
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setM) => AlertDialog(
          title: Text(_sub == 0 ? 'إضافة فصل أو مادة' : 'إضافة جدول أو امتحان'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SegmentedButton<String>(
                  segments: _sub == 0
                      ? const [ButtonSegment(value: 'فصل', label: Text('فصل')), ButtonSegment(value: 'مادة', label: Text('مادة'))]
                      : const [ButtonSegment(value: 'امتحان', label: Text('امتحان')), ButtonSegment(value: 'جدول', label: Text('جدول'))],
                  selected: {kind},
                  onSelectionChanged: (s) => setM(() => kind = s.first),
                ),
                const SizedBox(height: 8),
                TextField(controller: c1, decoration: InputDecoration(labelText: kind == 'فصل' ? 'اسم الفصل' : (kind == 'مادة' ? 'اسم المادة' : 'المادة'))),
                const SizedBox(height: 8),
                TextField(controller: c2, decoration: InputDecoration(labelText: kind == 'امتحان' ? 'التاريخ' : (kind == 'جدول' ? 'اليوم (الأحد..)' : 'المعلم / الرائد'))),
                const SizedBox(height: 8),
                DropdownButtonFormField<GradeLevel>(value: g, items: GradeLevel.values.map((e) => DropdownMenuItem(value: e, child: Text(e.shortLabel))).toList(), onChanged: (v) { if (v != null) setM(() => g = v); }),
                if (_sub == 1) ...[const SizedBox(height: 8), TextField(controller: c3, decoration: const InputDecoration(labelText: 'التوقيت'))],
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
            ElevatedButton(
              onPressed: () {
                if (c1.text.trim().isEmpty) return;
                final app = AppScope.of(context);
                if (kind == 'فصل') app.addClass(c1.text.trim(), g, 28, c2.text.trim().isEmpty ? 'هيئة التدريس' : c2.text.trim());
                if (kind == 'مادة') app.addSubject(c1.text.trim(), g, c2.text.trim().isEmpty ? 'هيئة التدريس' : c2.text.trim());
                if (kind == 'امتحان') app.addExam('اختبار', c1.text.trim(), g, c2.text.trim().isEmpty ? 'الخميس' : c2.text.trim(), c3.text.trim(), 'لجنة ${g.shortLabel}');
                if (kind == 'جدول') app.addScheduleSlot(g, c2.text.trim().isEmpty ? 'الأحد' : c2.text.trim(), 1, c3.text.trim(), c1.text.trim(), 'المعلم', 'فصل ${g.shortLabel}');
                Navigator.pop(ctx);
              },
              child: const Text('حفظ'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final students = app.usersByRole(UserRole.student);
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: _sub < 2 ? FloatingActionButton.extended(onPressed: _openAddDialog, icon: const Icon(Icons.add), label: const Text('إضافة')) : null,
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(10),
            child: SegmentedButton<int>(
              segments: const [ButtonSegment(value: 0, label: Text('الفصول والمواد')), ButtonSegment(value: 1, label: Text('الجداول والامتحانات')), ButtonSegment(value: 2, label: Text('الحضور والدرجات'))],
              selected: {_sub},
              onSelectionChanged: (s) => setState(() => _sub = s.first),
            ),
          ),
          Expanded(
            child: _sub == 0
                ? ListView(padding: const EdgeInsets.fromLTRB(12, 4, 12, 80), children: [
                    ...app.allClasses.map((c) => Card(child: ListTile(title: Text('${c.name} (${c.grade.shortLabel})'), subtitle: Text('الرائد: ${c.supervisorName}'), trailing: IconButton(icon: const Icon(Icons.delete_outline, color: Colors.red), onPressed: () => app.deleteClass(c.id))))),
                    ...app.allSubjects.map((s) => Card(child: ListTile(title: Text('${s.name} - ${s.grade.shortLabel}'), subtitle: Text('المعلم: ${s.teacherName}'), trailing: IconButton(icon: const Icon(Icons.delete_outline, color: Colors.red), onPressed: () => app.deleteSubject(s.id))))),
                  ])
                : _sub == 1
                    ? ListView(padding: const EdgeInsets.fromLTRB(12, 4, 12, 80), children: [
                        ...app.allExams.map((e) => Card(child: ListTile(title: Text('امتحان ${e.subject} (${e.grade.shortLabel})'), subtitle: Text('${e.dateStr} • ${e.timeStr}'), trailing: IconButton(icon: const Icon(Icons.delete_outline, color: Colors.red), onPressed: () => app.deleteExam(e.id))))),
                        ...app.allSchedule.map((sc) => Card(child: ListTile(title: Text('${sc.day}: ${sc.subject} (${sc.grade.shortLabel})'), subtitle: Text(sc.timeRange), trailing: IconButton(icon: const Icon(Icons.delete_outline, color: Colors.red), onPressed: () => app.deleteScheduleSlot(sc.id))))),
                      ])
                    : ListView(padding: const EdgeInsets.all(12), children: [
                        ...students.map((st) {
                          final status = app.attendanceOf(st.id);
                          return Card(child: ListTile(title: Text(st.name), trailing: DropdownButton<AttendanceStatus>(value: status, underline: const SizedBox(), items: AttendanceStatus.values.map((a) => DropdownMenuItem(value: a, child: Text(a.label, style: TextStyle(color: a.color)))).toList(), onChanged: (v) { if (v != null) app.recordAttendance(st, v); })));
                        }),
                        ...app.allGrades.map((g) => Card(child: ListTile(title: Text('${g.studentName} • ${g.subject}'), trailing: Text('${g.score}/${g.maxScore}', style: const TextStyle(fontWeight: FontWeight.bold))))),
                      ]),
          ),
        ],
      ),
    );
  }
}

class _AdminFeesTab extends StatelessWidget {
  const _AdminFeesTab();

  void _newInvoice(BuildContext context) {
    final app = AppScope.of(context);
    final students = app.usersByRole(UserRole.student);
    if (students.isEmpty) return;
    AppUser st = students.first;
    final title = TextEditingController(text: 'قسط دراسي');
    final total = TextEditingController(text: '8000');
    final paid = TextEditingController(text: '0');
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setM) => AlertDialog(
          title: const Text('إصدار فاتورة مصروفات'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<AppUser>(value: st, items: students.map((s) => DropdownMenuItem(value: s, child: Text(s.name))).toList(), onChanged: (v) { if (v != null) setM(() => st = v); }),
              const SizedBox(height: 8),
              TextField(controller: title, decoration: const InputDecoration(labelText: 'البيان')),
              const SizedBox(height: 8),
              TextField(controller: total, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'الإجمالي')),
              const SizedBox(height: 8),
              TextField(controller: paid, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'المدفوع')),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
            ElevatedButton(onPressed: () { app.addInvoice(st, title.text.trim(), double.tryParse(total.text) ?? 0, double.tryParse(paid.text) ?? 0, '2026-12-15'); Navigator.pop(ctx); }, child: const Text('حفظ')),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(onPressed: () => _newInvoice(context), icon: const Icon(Icons.add_card), label: const Text('فاتورة جديدة')),
      body: ListView.builder(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 80),
        itemCount: app.allInvoices.length,
        itemBuilder: (_, i) {
          final inv = app.allInvoices[i];
          return Card(
            child: ListTile(
              title: Text('${inv.studentName} • ${inv.title}', style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text('الإجمالي: ${inv.totalAmount.toStringAsFixed(0)} | المتبقي: ${inv.remaining.toStringAsFixed(0)} ج.م'),
              trailing: inv.isFullyPaid ? const Chip(label: Text('مسدد')) : ElevatedButton(onPressed: () => app.payInvoice(inv.id, inv.remaining), child: const Text('تحصيل')),
            ),
          );
        },
      ),
    );
  }
}

class _AdminReportsTab extends StatelessWidget {
  const _AdminReportsTab();

  void _publish(BuildContext context) {
    final t = TextEditingController();
    final b = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('نشر إعلان / إشعار عام'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: t, decoration: const InputDecoration(labelText: 'العنوان')),
            const SizedBox(height: 8),
            TextField(controller: b, maxLines: 3, decoration: const InputDecoration(labelText: 'النص')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          ElevatedButton(onPressed: () { if (t.text.trim().isNotEmpty) AppScope.of(context).addAnnouncement(t.text.trim(), b.text.trim(), 'إعلان', null, true); Navigator.pop(ctx); }, child: const Text('نشر')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    return ListView(
      padding: const EdgeInsets.all(14),
      children: [
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
          childAspectRatio: 1.8,
          children: [
            _Kpi('الطلاب', '${app.usersByRole(UserRole.student).length}', Icons.school, const Color(0xFF0284C7)),
            _Kpi('المعلمون', '${app.usersByRole(UserRole.teacher).length}', Icons.cast_for_education, const Color(0xFF0D9488)),
            _Kpi('أولياء الأمور', '${app.usersByRole(UserRole.parent).length}', Icons.family_restroom, const Color(0xFF7C3AED)),
            _Kpi('الفصول', '${app.allClasses.length}', Icons.meeting_room, const Color(0xFFF59E0B)),
          ],
        ),
        const SizedBox(height: 12),
        ElevatedButton.icon(onPressed: () => _publish(context), icon: const Icon(Icons.campaign), label: const Text('نشر إعلان وإرسال إشعار للجميع')),
        const SizedBox(height: 14),
        const Text('رسائل أولياء الأمور', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
        ...app.allMessages.map((m) => Card(
              child: ListTile(
                title: Text('${m.senderName}: ${m.subject}'),
                subtitle: Text('${m.body}\n${m.reply.isEmpty ? "بانتظار الرد" : "الرد: ${m.reply}"}'),
                trailing: IconButton(
                  icon: const Icon(Icons.reply),
                  onPressed: () {
                    final r = TextEditingController(text: m.reply);
                    showDialog(context: context, builder: (ctx) => AlertDialog(title: const Text('الرد'), content: TextField(controller: r), actions: [ElevatedButton(onPressed: () { app.replyMessage(m.id, r.text.trim()); Navigator.pop(ctx); }, child: const Text('إرسال'))]));
                  },
                ),
              ),
            )),
      ],
    );
  }
}

// ============================================================================
// 7. حساب المعلم (Teacher Dashboard)
// ============================================================================

class TeacherDashboard extends StatefulWidget {
  const TeacherDashboard({super.key});
  @override
  State<TeacherDashboard> createState() => _TeacherDashboardState();
}

class _TeacherDashboardState extends State<TeacherDashboard> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final pages = [
      _UnifiedHomeTab(
        onNavigateTab: (t) => setState(() => _tab = t),
        shortcuts: const [
          (title: 'الطلاب والحضور', icon: Icons.fact_check_rounded, color: Color(0xFF0D9488), tab: 1),
          (title: 'إضافة الواجبات', icon: Icons.assignment_rounded, color: Color(0xFF0284C7), tab: 2),
          (title: 'تسجيل الدرجات', icon: Icons.grade_rounded, color: Color(0xFF10B981), tab: 3),
          (title: 'الملفات والفصول', icon: Icons.upload_file_rounded, color: Color(0xFF7C3AED), tab: 4),
        ],
      ),
      const _TeacherAttendanceTab(),
      const _TeacherHomeworkTab(),
      const _TeacherGradeTab(),
      const _TeacherFilesTab(),
    ];

    return Scaffold(
      appBar: _schoolAppBar(context, 'بوابة المعلم - الرواد'),
      body: pages[_tab],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_rounded), label: 'الرئيسية'),
          NavigationDestination(icon: Icon(Icons.fact_check_rounded), label: 'الحضور'),
          NavigationDestination(icon: Icon(Icons.assignment_rounded), label: 'الواجبات'),
          NavigationDestination(icon: Icon(Icons.grade_rounded), label: 'الدرجات'),
          NavigationDestination(icon: Icon(Icons.folder_rounded), label: 'الملفات'),
        ],
      ),
    );
  }
}

class _TeacherAttendanceTab extends StatelessWidget {
  const _TeacherAttendanceTab();
  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final students = app.usersByRole(UserRole.student);
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: students.length,
      itemBuilder: (_, i) {
        final st = students[i];
        final cur = app.attendanceOf(st.id);
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('${st.name} (${st.grade.shortLabel})', style: const TextStyle(fontWeight: FontWeight.bold)),
                    IconButton(
                      icon: const Icon(Icons.message_rounded, color: Color(0xFF0284C7)),
                      onPressed: () {
                        final n = TextEditingController();
                        showDialog(context: context, builder: (ctx) => AlertDialog(title: Text('ملاحظة لولي أمر ${st.name}'), content: TextField(controller: n), actions: [ElevatedButton(onPressed: () { if (n.text.trim().isNotEmpty) app.sendCustomNotif(NotificationType.announcement, 'ملاحظة معلم', n.text.trim(), UserRole.parent); Navigator.pop(ctx); }, child: const Text('إرسال'))]));
                      },
                    ),
                  ],
                ),
                Row(
                  children: AttendanceStatus.values.map((a) {
                    final sel = cur == a;
                    return Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 3),
                        child: InkWell(
                          onTap: () => app.recordAttendance(st, a),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            decoration: BoxDecoration(color: sel ? a.color : a.color.withAlpha(25), borderRadius: BorderRadius.circular(10)),
                            child: Center(child: Text(a.label, style: TextStyle(fontWeight: FontWeight.bold, color: sel ? Colors.white : a.color))),
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
    );
  }
}

class _TeacherHomeworkTab extends StatelessWidget {
  const _TeacherHomeworkTab();
  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          GradeLevel g = GradeLevel.p4;
          final sub = TextEditingController(text: 'الرياضيات');
          final title = TextEditingController();
          final det = TextEditingController();
          showDialog(
            context: context,
            builder: (ctx) => StatefulBuilder(
              builder: (ctx, setM) => AlertDialog(
                title: const Text('إضافة واجب'),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<GradeLevel>(value: g, items: GradeLevel.values.map((e) => DropdownMenuItem(value: e, child: Text(e.shortLabel))).toList(), onChanged: (v) { if (v != null) setM(() => g = v); }),
                    const SizedBox(height: 8),
                    TextField(controller: sub, decoration: const InputDecoration(labelText: 'المادة')),
                    const SizedBox(height: 8),
                    TextField(controller: title, decoration: const InputDecoration(labelText: 'العنوان')),
                    const SizedBox(height: 8),
                    TextField(controller: det, decoration: const InputDecoration(labelText: 'التفاصيل')),
                  ],
                ),
                actions: [ElevatedButton(onPressed: () { if (title.text.trim().isNotEmpty) app.addHomework(g, sub.text.trim(), title.text.trim(), det.text.trim(), 'غداً'); Navigator.pop(ctx); }, child: const Text('إرسال'))],
              ),
            ),
          );
        },
        icon: const Icon(Icons.add),
        label: const Text('إضافة واجب'),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 80),
        itemCount: app.allHomeworks.length,
        itemBuilder: (_, i) {
          final h = app.allHomeworks[i];
          return Card(child: ListTile(title: Text('${h.subject} (${h.grade.shortLabel}) - ${h.title}'), subtitle: Text('${h.details}\nالتسليم: ${h.dueDate}')));
        },
      ),
    );
  }
}

class _TeacherGradeTab extends StatelessWidget {
  const _TeacherGradeTab();
  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final students = app.usersByRole(UserRole.student);
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          if (students.isEmpty) return;
          AppUser st = students.first;
          final sub = TextEditingController(text: 'الرياضيات');
          final sc = TextEditingController(text: '28');
          final mx = TextEditingController(text: '30');
          showDialog(
            context: context,
            builder: (ctx) => StatefulBuilder(
              builder: (ctx, setM) => AlertDialog(
                title: const Text('تسجيل درجة'),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<AppUser>(value: st, items: students.map((s) => DropdownMenuItem(value: s, child: Text(s.name))).toList(), onChanged: (v) { if (v != null) setM(() => st = v); }),
                    const SizedBox(height: 8),
                    TextField(controller: sub, decoration: const InputDecoration(labelText: 'المادة')),
                    const SizedBox(height: 8),
                    Row(children: [Expanded(child: TextField(controller: sc, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'الدرجة'))), const SizedBox(width: 8), Expanded(child: TextField(controller: mx, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'من')))]),
                  ],
                ),
                actions: [ElevatedButton(onPressed: () { app.addGrade(st, sub.text.trim(), 'تقييم شهري', double.tryParse(sc.text) ?? 0, double.tryParse(mx.text) ?? 30, 'متميز'); Navigator.pop(ctx); }, child: const Text('حفظ'))],
              ),
            ),
          );
        },
        icon: const Icon(Icons.add_chart),
        label: const Text('تسجيل درجة'),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 80),
        itemCount: app.allGrades.length,
        itemBuilder: (_, i) {
          final g = app.allGrades[i];
          return Card(child: ListTile(title: Text('${g.studentName} • ${g.subject}'), subtitle: Text(g.examTitle), trailing: Chip(label: Text('${g.score}/${g.maxScore}'))));
        },
      ),
    );
  }
}

class _TeacherFilesTab extends StatelessWidget {
  const _TeacherFilesTab();
  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          final t = TextEditingController();
          final u = TextEditingController(text: 'notes.pdf');
          showDialog(context: context, builder: (ctx) => AlertDialog(title: const Text('رفع ملف تعليمي'), content: Column(mainAxisSize: MainAxisSize.min, children: [TextField(controller: t, decoration: const InputDecoration(labelText: 'العنوان')), const SizedBox(height: 8), TextField(controller: u, decoration: const InputDecoration(labelText: 'اسم الملف / الرابط'))]), actions: [ElevatedButton(onPressed: () { if (t.text.trim().isNotEmpty) app.addFile(t.text.trim(), 'PDF', GradeLevel.p4, 'الرياضيات', u.text.trim()); Navigator.pop(ctx); }, child: const Text('رفع'))]));
        },
        icon: const Icon(Icons.upload_file),
        label: const Text('رفع ملف'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 80),
        children: [
          const Text('الفصول الدراسية', style: TextStyle(fontWeight: FontWeight.bold)),
          ...app.allClasses.map((c) => Card(child: ListTile(title: Text(c.name), subtitle: Text('الرائد: ${c.supervisorName}')))),
          const SizedBox(height: 10),
          const Text('الملفات التعليمية', style: TextStyle(fontWeight: FontWeight.bold)),
          ...app.allFiles.map((f) => Card(child: ListTile(leading: const Icon(Icons.picture_as_pdf, color: Colors.red), title: Text(f.title), subtitle: Text('${f.grade.shortLabel} • ${f.urlOrName}')))),
        ],
      ),
    );
  }
}

// ============================================================================
// 8. حساب الطالب (Student Dashboard)
// ============================================================================

class StudentDashboard extends StatefulWidget {
  const StudentDashboard({super.key});
  @override
  State<StudentDashboard> createState() => _StudentDashboardState();
}

class _StudentDashboardState extends State<StudentDashboard> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final st = AppScope.of(context).currentUser!;
    final pages = [
      _UnifiedHomeTab(
        onNavigateTab: (t) => setState(() => _tab = t),
        shortcuts: const [
          (title: 'الجدول والامتحانات', icon: Icons.calendar_month, color: Color(0xFF0284C7), tab: 1),
          (title: 'الواجبات والملفات', icon: Icons.assignment, color: Color(0xFF0D9488), tab: 2),
          (title: 'الدرجات والنتائج', icon: Icons.grade, color: Color(0xFF10B981), tab: 3),
          (title: 'بياناتي والحضور', icon: Icons.person, color: Color(0xFF7C3AED), tab: 4),
        ],
      ),
      _StudentScheduleView(grade: st.grade),
      _StudentHomeworkFilesView(student: st),
      _StudentResultsView(student: st),
      _StudentProfileView(student: st),
    ];

    return Scaffold(
      appBar: _schoolAppBar(context, 'الطالب • ${st.grade.shortLabel}'),
      body: pages[_tab],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_rounded), label: 'الرئيسية'),
          NavigationDestination(icon: Icon(Icons.calendar_month_rounded), label: 'الجدول'),
          NavigationDestination(icon: Icon(Icons.assignment_rounded), label: 'الواجبات'),
          NavigationDestination(icon: Icon(Icons.grade_rounded), label: 'النتائج'),
          NavigationDestination(icon: Icon(Icons.person_rounded), label: 'حسابي'),
        ],
      ),
    );
  }
}

class _StudentScheduleView extends StatefulWidget {
  final GradeLevel grade;
  const _StudentScheduleView({required this.grade});
  @override
  State<_StudentScheduleView> createState() => _StudentScheduleViewState();
}

class _StudentScheduleViewState extends State<_StudentScheduleView> {
  String _day = SchoolState.weekDays.first;
  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final slots = app.allSchedule.where((s) => s.grade == widget.grade && s.day == _day).toList();
    return ListView(
      padding: const EdgeInsets.all(14),
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(children: SchoolState.weekDays.map((d) => Padding(padding: const EdgeInsets.only(left: 6), child: ChoiceChip(label: Text(d), selected: _day == d, onSelected: (_) => setState(() => _day = d)))).toList()),
        ),
        const SizedBox(height: 8),
        ...slots.map((s) => Card(child: ListTile(leading: CircleAvatar(child: Text('${s.period}')), title: Text(s.subject), subtitle: Text('${s.teacherName} • ${s.classroom}'), trailing: Text(s.timeRange)))),
      ],
    );
  }
}

class _StudentHomeworkFilesView extends StatelessWidget {
  final AppUser student;
  const _StudentHomeworkFilesView({required this.student});
  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final hws = app.allHomeworks.where((h) => h.grade == student.grade).toList();
    final files = app.allFiles.where((f) => f.grade == student.grade).toList();
    return ListView(
      padding: const EdgeInsets.all(14),
      children: [
        const Text('الواجبات المنزلية', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15.5)),
        ...hws.map((h) {
          final done = h.completedStudentIds.contains(student.id);
          return Card(child: CheckboxListTile(value: done, onChanged: (_) => app.toggleHomeworkCompletion(h.id, student.id), title: Text('${h.subject}: ${h.title}'), subtitle: Text('${h.details} • التسليم: ${h.dueDate}')));
        }),
        const SizedBox(height: 12),
        const Text('الملفات التعليمية', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15.5)),
        ...files.map((f) => Card(child: ListTile(leading: const Icon(Icons.picture_as_pdf, color: Colors.red), title: Text(f.title), subtitle: Text(f.urlOrName), trailing: TextButton(onPressed: () => showDialog(context: context, builder: (ctx) => AlertDialog(title: Text(f.title), content: Text(f.urlOrName))), child: const Text('فتح'))))),
      ],
    );
  }
}

class _StudentResultsView extends StatelessWidget {
  final AppUser student;
  const _StudentResultsView({required this.student});
  @override
  Widget build(BuildContext context) {
    final list = AppScope.of(context).allGrades.where((g) => g.studentId == student.id || g.grade == student.grade).toList();
    double sum = 0, mx = 0;
    for (final g in list) {
      sum += g.score;
      mx += g.maxScore;
    }
    final pct = mx == 0 ? 0.0 : (sum / mx) * 100;
    return ListView(
      padding: const EdgeInsets.all(14),
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFF0D9488), Color(0xFF1E3A8A)]), borderRadius: BorderRadius.circular(18)),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('المعدل العام: ${student.name}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              CircleAvatar(backgroundColor: Colors.white, child: Text('${pct.toStringAsFixed(0)}%', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1E3A8A)))),
            ],
          ),
        ),
        const SizedBox(height: 10),
        ...list.map((g) => Card(child: ListTile(title: Text('${g.subject} (${g.examTitle})'), subtitle: Text(g.note), trailing: Chip(label: Text('${g.score}/${g.maxScore}'))))),
      ],
    );
  }
}

class _StudentProfileView extends StatelessWidget {
  final AppUser student;
  const _StudentProfileView({required this.student});
  @override
  Widget build(BuildContext context) {
    final status = AppScope.of(context).attendanceOf(student.id);
    return ListView(
      padding: const EdgeInsets.all(14),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('بيانات الطالب', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const Divider(),
                Text('الاسم: ${student.name}'),
                Text('الصف: ${student.grade.label}'),
                Text('الفصل: ${student.classroom}'),
                Text('الهاتف: ${student.phone}'),
              ],
            ),
          ),
        ),
        Card(child: ListTile(leading: Icon(status.icon, color: status.color), title: const Text('الحضور اليوم'), trailing: Text(status.label, style: TextStyle(color: status.color, fontWeight: FontWeight.bold)))),
      ],
    );
  }
}

// ============================================================================
// 9. حساب ولي الأمر (Parent Dashboard)
// ============================================================================

class ParentDashboard extends StatefulWidget {
  const ParentDashboard({super.key});
  @override
  State<ParentDashboard> createState() => _ParentDashboardState();
}

class _ParentDashboardState extends State<ParentDashboard> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final kids = app.childrenOfParent(app.currentUser!.phone);
    final active = app.selectedParentChild;

    final pages = [
      _UnifiedHomeTab(
        onNavigateTab: (t) => setState(() => _tab = t),
        shortcuts: const [
          (title: 'الأبناء والحضور والنتائج', icon: Icons.family_restroom, color: Color(0xFF7C3AED), tab: 1),
          (title: 'واجبات الابن', icon: Icons.assignment, color: Color(0xFF0284C7), tab: 2),
          (title: 'المصروفات', icon: Icons.payments, color: Color(0xFFF59E0B), tab: 3),
          (title: 'التواصل مع المدرسة', icon: Icons.chat, color: Color(0xFF0D9488), tab: 4),
        ],
      ),
      _ParentChildrenTab(kids: kids, active: active),
      if (active != null) _StudentHomeworkFilesView(student: active) else const Center(child: Text('لا يوجد أبناء')),
      _ParentFeesTab(kids: kids),
      const _ParentMessagesTab(),
    ];

    return Scaffold(
      appBar: _schoolAppBar(context, 'ولي الأمر - الرواد'),
      body: pages[_tab],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_rounded), label: 'الرئيسية'),
          NavigationDestination(icon: Icon(Icons.family_restroom_rounded), label: 'الأبناء'),
          NavigationDestination(icon: Icon(Icons.assignment_rounded), label: 'الواجبات'),
          NavigationDestination(icon: Icon(Icons.payments_rounded), label: 'المصروفات'),
          NavigationDestination(icon: Icon(Icons.chat_rounded), label: 'التواصل'),
        ],
      ),
    );
  }
}

class _ParentChildrenTab extends StatelessWidget {
  final List<AppUser> kids;
  final AppUser? active;
  const _ParentChildrenTab({required this.kids, required this.active});

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    if (active == null) return const Center(child: Text('لا يوجد أبناء مرتبطون'));
    final att = app.attendanceOf(active!.id);
    final grades = app.allGrades.where((g) => g.studentId == active!.id).toList();
    return ListView(
      padding: const EdgeInsets.all(14),
      children: [
        Wrap(spacing: 8, children: kids.map((k) => ChoiceChip(label: Text('${k.name} (${k.grade.shortLabel})'), selected: k.id == active!.id, onSelected: (_) => app.selectParentChild(k.id))).toList()),
        const SizedBox(height: 10),
        Card(child: ListTile(leading: Icon(att.icon, color: att.color), title: Text('حضور ${active!.name}'), trailing: Text(att.label, style: TextStyle(color: att.color, fontWeight: FontWeight.bold)))),
        ...grades.map((g) => Card(child: ListTile(title: Text('${g.subject} (${g.examTitle})'), subtitle: Text(g.note), trailing: Chip(label: Text('${g.score}/${g.maxScore}'))))),
      ],
    );
  }
}

class _ParentFeesTab extends StatelessWidget {
  final List<AppUser> kids;
  const _ParentFeesTab({required this.kids});
  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final ids = kids.map((k) => k.id).toSet();
    final invoices = app.allInvoices.where((i) => ids.contains(i.studentId)).toList();
    return ListView.builder(
      padding: const EdgeInsets.all(14),
      itemCount: invoices.length,
      itemBuilder: (_, i) {
        final inv = invoices[i];
        return Card(
          child: ListTile(
            title: Text('${inv.studentName} - ${inv.title}'),
            subtitle: Text('الإجمالي: ${inv.totalAmount.toStringAsFixed(0)} | المتبقي: ${inv.remaining.toStringAsFixed(0)} ج.م'),
            trailing: inv.isFullyPaid ? const Chip(label: Text('مسدد')) : ElevatedButton(onPressed: () => app.payInvoice(inv.id, inv.remaining), child: const Text('سداد')),
          ),
        );
      },
    );
  }
}

class _ParentMessagesTab extends StatelessWidget {
  const _ParentMessagesTab();
  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          final sub = TextEditingController();
          final body = TextEditingController();
          showDialog(context: context, builder: (ctx) => AlertDialog(title: const Text('تواصل مع المدرسة'), content: Column(mainAxisSize: MainAxisSize.min, children: [TextField(controller: sub, decoration: const InputDecoration(labelText: 'الموضوع')), const SizedBox(height: 8), TextField(controller: body, maxLines: 3, decoration: const InputDecoration(labelText: 'الرسالة'))]), actions: [ElevatedButton(onPressed: () { if (sub.text.trim().isNotEmpty) app.sendMessage('إدارة المدرسة', sub.text.trim(), body.text.trim()); Navigator.pop(ctx); }, child: const Text('إرسال'))]));
        },
        icon: const Icon(Icons.send),
        label: const Text('رسالة جديدة'),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 80),
        itemCount: app.allMessages.length,
        itemBuilder: (_, i) {
          final m = app.allMessages[i];
          return Card(child: ListTile(title: Text(m.subject, style: const TextStyle(fontWeight: FontWeight.bold)), subtitle: Text('${m.body}\n${m.reply.isEmpty ? "بانتظار الرد" : "الرد: ${m.reply}"}')));
        },
      ),
    );
  }
}

class _Kpi extends StatelessWidget {
  final String title, value;
  final IconData icon;
  final Color color;
  const _Kpi(this.title, this.value, this.icon, this.color);
  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(title, style: const TextStyle(fontWeight: FontWeight.w600)), Icon(icon, color: color)]),
            Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: color)),
          ],
        ),
      ),
    );
  }
}
