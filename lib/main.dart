import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:excel/excel.dart' as xl;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const AlRowadPrivateSchoolApp());
}

// ============================================================================
// 1. النماذج والأنواع الأساسية مع دعم الحفظ الدائم (Models + JSON)
// ============================================================================

enum UserRole {
  admin('مدير المدرسة', Icons.admin_panel_settings_rounded, Color(0xFF1B365D)),
  teacher('معلم', Icons.cast_for_education_rounded, Color(0xFF0D9488)),
  student('طالب', Icons.school_rounded, Color(0xFF0284C7)),
  parent('ولي أمر', Icons.family_restroom_rounded, Color(0xFF6D28D9));

  final String label;
  final IconData icon;
  final Color color;
  const UserRole(this.label, this.icon, this.color);

  static UserRole fromName(String? name) =>
      UserRole.values.firstWhere((e) => e.name == name, orElse: () => UserRole.student);
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

  static GradeLevel fromName(String? name) =>
      GradeLevel.values.firstWhere((e) => e.name == name, orElse: () => GradeLevel.p4);

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

  static AttendanceStatus fromName(String? name) =>
      AttendanceStatus.values.firstWhere((e) => e.name == name, orElse: () => AttendanceStatus.present);
}

enum NotificationType {
  absence('إشعار غياب', Icons.person_off_rounded, Color(0xFFEF4444)),
  announcement('إعلان مدرسي', Icons.campaign_rounded, Color(0xFF1B365D)),
  exam('موعد امتحان', Icons.event_note_rounded, Color(0xFF6D28D9)),
  result('نتيجة / درجة', Icons.grade_rounded, Color(0xFF10B981)),
  homework('واجب مدرسي', Icons.assignment_rounded, Color(0xFF0284C7)),
  fees('تنبيه مصروفات', Icons.payments_rounded, Color(0xFFD97706));

  final String label;
  final IconData icon;
  final Color color;
  const NotificationType(this.label, this.icon, this.color);

  static NotificationType fromName(String? name) =>
      NotificationType.values.firstWhere((e) => e.name == name, orElse: () => NotificationType.announcement);
}

class AppUser {
  final String id;
  String name, phone, password, classroom, subject, linkedParentPhone, otpCode;
  UserRole role;
  GradeLevel grade;
  bool isVerified;
  bool isApproved;

  AppUser({
    required this.id,
    required this.name,
    required this.phone,
    required this.password,
    required this.role,
    this.grade = GradeLevel.p4,
    this.classroom = 'فصل 4/أ',
    this.subject = 'الرياضيات',
    this.linkedParentPhone = '',
    this.isVerified = false,
    this.isApproved = true,
    this.otpCode = '1234',
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'phone': phone,
        'password': password,
        'role': role.name,
        'grade': grade.name,
        'classroom': classroom,
        'subject': subject,
        'linkedParentPhone': linkedParentPhone,
        'isVerified': isVerified,
        'isApproved': isApproved,
        'otpCode': otpCode,
      };

  factory AppUser.fromJson(Map<String, dynamic> j) => AppUser(
        id: j['id'] ?? '',
        name: j['name'] ?? '',
        phone: j['phone'] ?? '',
        password: j['password'] ?? '',
        role: UserRole.fromName(j['role']),
        grade: GradeLevel.fromName(j['grade']),
        classroom: j['classroom'] ?? '',
        subject: j['subject'] ?? '',
        linkedParentPhone: j['linkedParentPhone'] ?? '',
        isVerified: j['isVerified'] ?? false,
        isApproved: j['isApproved'] ?? true,
        otpCode: j['otpCode'] ?? '1234',
      );
}

class SchoolClass {
  final String id;
  String name, supervisorName;
  GradeLevel grade;
  int capacity;
  SchoolClass({required this.id, required this.name, required this.grade, required this.capacity, required this.supervisorName});

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'grade': grade.name, 'capacity': capacity, 'supervisorName': supervisorName};
  factory SchoolClass.fromJson(Map<String, dynamic> j) => SchoolClass(id: j['id'], name: j['name'], grade: GradeLevel.fromName(j['grade']), capacity: j['capacity'] ?? 28, supervisorName: j['supervisorName'] ?? '');
}

class SubjectItem {
  final String id;
  String name, teacherName;
  GradeLevel grade;
  SubjectItem({required this.id, required this.name, required this.grade, required this.teacherName});

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'grade': grade.name, 'teacherName': teacherName};
  factory SubjectItem.fromJson(Map<String, dynamic> j) => SubjectItem(id: j['id'], name: j['name'], grade: GradeLevel.fromName(j['grade']), teacherName: j['teacherName'] ?? '');
}

class ScheduleSlot {
  final String id, day, timeRange, subject, teacherName, classroom;
  GradeLevel grade;
  int period;
  ScheduleSlot({required this.id, required this.grade, required this.day, required this.period, required this.timeRange, required this.subject, required this.teacherName, required this.classroom});

  Map<String, dynamic> toJson() => {'id': id, 'grade': grade.name, 'day': day, 'period': period, 'timeRange': timeRange, 'subject': subject, 'teacherName': teacherName, 'classroom': classroom};
  factory ScheduleSlot.fromJson(Map<String, dynamic> j) => ScheduleSlot(id: j['id'], grade: GradeLevel.fromName(j['grade']), day: j['day'], period: j['period'] ?? 1, timeRange: j['timeRange'], subject: j['subject'], teacherName: j['teacherName'], classroom: j['classroom']);
}

class ExamItem {
  final String id, title, subject, dateStr, timeStr, room;
  GradeLevel grade;
  ExamItem({required this.id, required this.title, required this.subject, required this.grade, required this.dateStr, required this.timeStr, required this.room});

  Map<String, dynamic> toJson() => {'id': id, 'title': title, 'subject': subject, 'grade': grade.name, 'dateStr': dateStr, 'timeStr': timeStr, 'room': room};
  factory ExamItem.fromJson(Map<String, dynamic> j) => ExamItem(id: j['id'], title: j['title'], subject: j['subject'], grade: GradeLevel.fromName(j['grade']), dateStr: j['dateStr'], timeStr: j['timeStr'], room: j['room']);
}

class AttendanceEntry {
  final String id, studentId, studentName, dateStr;
  GradeLevel grade;
  AttendanceStatus status;
  AttendanceEntry({required this.id, required this.studentId, required this.studentName, required this.grade, required this.dateStr, required this.status});

  Map<String, dynamic> toJson() => {'id': id, 'studentId': studentId, 'studentName': studentName, 'grade': grade.name, 'dateStr': dateStr, 'status': status.name};
  factory AttendanceEntry.fromJson(Map<String, dynamic> j) => AttendanceEntry(id: j['id'], studentId: j['studentId'], studentName: j['studentName'], grade: GradeLevel.fromName(j['grade']), dateStr: j['dateStr'], status: AttendanceStatus.fromName(j['status']));
}

class HomeworkItem {
  final String id, subject, title, details, dueDate, teacherName;
  GradeLevel grade;
  final Set<String> completedStudentIds;
  HomeworkItem({required this.id, required this.grade, required this.subject, required this.title, required this.details, required this.dueDate, required this.teacherName, Set<String>? completedStudentIds}) : completedStudentIds = completedStudentIds ?? {};

  Map<String, dynamic> toJson() => {'id': id, 'grade': grade.name, 'subject': subject, 'title': title, 'details': details, 'dueDate': dueDate, 'teacherName': teacherName, 'completedStudentIds': completedStudentIds.toList()};
  factory HomeworkItem.fromJson(Map<String, dynamic> j) => HomeworkItem(id: j['id'], grade: GradeLevel.fromName(j['grade']), subject: j['subject'], title: j['title'], details: j['details'], dueDate: j['dueDate'], teacherName: j['teacherName'], completedStudentIds: Set<String>.from(j['completedStudentIds'] ?? []));
}

class GradeEntry {
  final String id, studentId, studentName, subject, examTitle, note;
  GradeLevel grade;
  double score, maxScore;
  GradeEntry({required this.id, required this.studentId, required this.studentName, required this.grade, required this.subject, required this.examTitle, required this.score, required this.maxScore, required this.note});

  Map<String, dynamic> toJson() => {'id': id, 'studentId': studentId, 'studentName': studentName, 'grade': grade.name, 'subject': subject, 'examTitle': examTitle, 'score': score, 'maxScore': maxScore, 'note': note};
  factory GradeEntry.fromJson(Map<String, dynamic> j) => GradeEntry(id: j['id'], studentId: j['studentId'], studentName: j['studentName'], grade: GradeLevel.fromName(j['grade']), subject: j['subject'], examTitle: j['examTitle'], score: (j['score'] as num).toDouble(), maxScore: (j['maxScore'] as num).toDouble(), note: j['note'] ?? '');
}

class FeeInvoice {
  final String id, studentId, studentName, title, dueDate;
  GradeLevel grade;
  double totalAmount, paidAmount;
  FeeInvoice({required this.id, required this.studentId, required this.studentName, required this.grade, required this.title, required this.totalAmount, required this.paidAmount, required this.dueDate});
  double get remaining => (totalAmount - paidAmount).clamp(0, totalAmount);
  bool get isFullyPaid => remaining <= 0;

  Map<String, dynamic> toJson() => {'id': id, 'studentId': studentId, 'studentName': studentName, 'grade': grade.name, 'title': title, 'totalAmount': totalAmount, 'paidAmount': paidAmount, 'dueDate': dueDate};
  factory FeeInvoice.fromJson(Map<String, dynamic> j) => FeeInvoice(id: j['id'], studentId: j['studentId'], studentName: j['studentName'], grade: GradeLevel.fromName(j['grade']), title: j['title'], totalAmount: (j['totalAmount'] as num).toDouble(), paidAmount: (j['paidAmount'] as num).toDouble(), dueDate: j['dueDate']);
}

class AnnouncementNews {
  final String id, title, body, category, author, dateLabel;
  UserRole? targetRole;
  bool isUrgent;
  AnnouncementNews({required this.id, required this.title, required this.body, required this.category, this.targetRole, required this.author, required this.dateLabel, this.isUrgent = false});

  Map<String, dynamic> toJson() => {'id': id, 'title': title, 'body': body, 'category': category, 'targetRole': targetRole?.name, 'author': author, 'dateLabel': dateLabel, 'isUrgent': isUrgent};
  factory AnnouncementNews.fromJson(Map<String, dynamic> j) => AnnouncementNews(id: j['id'], title: j['title'], body: j['body'], category: j['category'], targetRole: j['targetRole'] == null ? null : UserRole.fromName(j['targetRole']), author: j['author'], dateLabel: j['dateLabel'], isUrgent: j['isUrgent'] ?? false);
}

class SchoolNotification {
  final String id, title, body, dateLabel;
  final NotificationType type;
  String? targetPhone;
  UserRole? targetRole;
  bool isRead;
  SchoolNotification({required this.id, required this.type, required this.title, required this.body, this.targetPhone, this.targetRole, required this.dateLabel, this.isRead = false});

  Map<String, dynamic> toJson() => {'id': id, 'type': type.name, 'title': title, 'body': body, 'targetPhone': targetPhone, 'targetRole': targetRole?.name, 'dateLabel': dateLabel, 'isRead': isRead};
  factory SchoolNotification.fromJson(Map<String, dynamic> j) => SchoolNotification(id: j['id'], type: NotificationType.fromName(j['type']), title: j['title'], body: j['body'], targetPhone: j['targetPhone'], targetRole: j['targetRole'] == null ? null : UserRole.fromName(j['targetRole']), dateLabel: j['dateLabel'], isRead: j['isRead'] ?? false);
}

class EducationalFile {
  final String id, title, fileType, subject, urlOrName, uploadedBy, dateLabel;
  GradeLevel grade;
  EducationalFile({required this.id, required this.title, required this.fileType, required this.grade, required this.subject, required this.urlOrName, required this.uploadedBy, required this.dateLabel});

  Map<String, dynamic> toJson() => {'id': id, 'title': title, 'fileType': fileType, 'grade': grade.name, 'subject': subject, 'urlOrName': urlOrName, 'uploadedBy': uploadedBy, 'dateLabel': dateLabel};
  factory EducationalFile.fromJson(Map<String, dynamic> j) => EducationalFile(id: j['id'], title: j['title'], fileType: j['fileType'], grade: GradeLevel.fromName(j['grade']), subject: j['subject'], urlOrName: j['urlOrName'], uploadedBy: j['uploadedBy'], dateLabel: j['dateLabel']);
}

class SchoolMessage {
  final String id, senderName, senderPhone, recipientLabel, subject, body, dateLabel;
  String reply;
  SchoolMessage({required this.id, required this.senderName, required this.senderPhone, required this.recipientLabel, required this.subject, required this.body, this.reply = '', required this.dateLabel});

  Map<String, dynamic> toJson() => {'id': id, 'senderName': senderName, 'senderPhone': senderPhone, 'recipientLabel': recipientLabel, 'subject': subject, 'body': body, 'reply': reply, 'dateLabel': dateLabel};
  factory SchoolMessage.fromJson(Map<String, dynamic> j) => SchoolMessage(id: j['id'], senderName: j['senderName'], senderPhone: j['senderPhone'], recipientLabel: j['recipientLabel'], subject: j['subject'], body: j['body'], reply: j['reply'] ?? '', dateLabel: j['dateLabel']);
}

// ============================================================================
// 2. إدارة الحالة والحفظ الدائم على الجهاز (SchoolState + SharedPreferencesAsync)
// ============================================================================

class SchoolState extends ChangeNotifier {
  static const String _storageKey = 'alrowad_school_db_v2';
  final SharedPreferencesAsync _prefs = SharedPreferencesAsync();
  final Random _rng = Random();

  bool _isInitialized = false;
  ThemeMode _themeMode = ThemeMode.light;
  String? _currentUserId;
  String _selectedParentChildId = '';

  bool get isInitialized => _isInitialized;
  ThemeMode get themeMode => _themeMode;
  static const List<String> weekDays = ['الأحد', 'الإثنين', 'الثلاثاء', 'الأربعاء', 'الخميس'];

  List<AppUser> _users = [];
  List<SchoolClass> _classes = [];
  List<SubjectItem> _subjects = [];
  List<ScheduleSlot> _schedule = [];
  List<ExamItem> _exams = [];
  List<AttendanceEntry> _attendance = [];
  List<HomeworkItem> _homeworks = [];
  List<GradeEntry> _grades = [];
  List<FeeInvoice> _invoices = [];
  List<AnnouncementNews> _announcements = [];
  List<SchoolNotification> _notifications = [];
  List<EducationalFile> _files = [];
  List<SchoolMessage> _messages = [];

  AppUser? get currentUser {
    if (_currentUserId == null) return null;
    final found = _users.where((u) => u.id == _currentUserId).toList();
    return found.isEmpty ? null : found.first;
  }

  Future<void> init() async {
    try {
      final raw = await _prefs.getString(_storageKey);
      if (raw != null && raw.isNotEmpty) {
        final map = jsonDecode(raw) as Map<String, dynamic>;
        _themeMode = (map['darkMode'] == true) ? ThemeMode.dark : ThemeMode.light;
        _currentUserId = map['currentUserId'];
        _selectedParentChildId = map['selectedParentChildId'] ?? '';
        _users = (map['users'] as List).map((e) => AppUser.fromJson(e)).toList();
        _classes = (map['classes'] as List).map((e) => SchoolClass.fromJson(e)).toList();
        _subjects = (map['subjects'] as List).map((e) => SubjectItem.fromJson(e)).toList();
        _schedule = (map['schedule'] as List).map((e) => ScheduleSlot.fromJson(e)).toList();
        _exams = (map['exams'] as List).map((e) => ExamItem.fromJson(e)).toList();
        _attendance = (map['attendance'] as List).map((e) => AttendanceEntry.fromJson(e)).toList();
        _homeworks = (map['homeworks'] as List).map((e) => HomeworkItem.fromJson(e)).toList();
        _grades = (map['grades'] as List).map((e) => GradeEntry.fromJson(e)).toList();
        _invoices = (map['invoices'] as List).map((e) => FeeInvoice.fromJson(e)).toList();
        _announcements = (map['announcements'] as List).map((e) => AnnouncementNews.fromJson(e)).toList();
        _notifications = (map['notifications'] as List).map((e) => SchoolNotification.fromJson(e)).toList();
        _files = (map['files'] as List).map((e) => EducationalFile.fromJson(e)).toList();
        _messages = (map['messages'] as List).map((e) => SchoolMessage.fromJson(e)).toList();
      } else {
        _seedInitialData();
        await _persist();
      }
    } catch (_) {
      _seedInitialData();
    }
    _isInitialized = true;
    notifyListeners();
  }

  void _seedInitialData() {
    _users = [
      AppUser(id: 'u_admin', name: 'أ. خالد محمود (مدير المدرسة)', phone: '01129220696', password: 'khaled123', role: UserRole.admin, isVerified: true, isApproved: true, otpCode: '0000'),
    ];
    _classes = [
      SchoolClass(id: 'c1', name: 'قاعة النجوم - KG2', grade: GradeLevel.kg2, capacity: 22, supervisorName: 'أ. سارة مجدي'),
      SchoolClass(id: 'c2', name: 'فصل 4/أ', grade: GradeLevel.p4, capacity: 28, supervisorName: 'أ. إسلام عبدالعزيز'),
      SchoolClass(id: 'c3', name: 'فصل 3/أ إعدادي', grade: GradeLevel.prep3, capacity: 30, supervisorName: 'أ. خالد نصار'),
    ];
    _subjects = [
      SubjectItem(id: 'sb1', name: 'الرياضيات', grade: GradeLevel.p4, teacherName: 'هيئة التدريس'),
      SubjectItem(id: 'sb2', name: 'اللغة العربية', grade: GradeLevel.p4, teacherName: 'هيئة التدريس'),
      SubjectItem(id: 'sb3', name: 'العلوم', grade: GradeLevel.p4, teacherName: 'هيئة التدريس'),
    ];
    _schedule = [
      ScheduleSlot(id: 'sc1', grade: GradeLevel.p4, day: 'الأحد', period: 1, timeRange: '08:00 - 08:45', subject: 'اللغة العربية', teacherName: 'هيئة التدريس', classroom: 'فصل 4/أ'),
      ScheduleSlot(id: 'sc2', grade: GradeLevel.p4, day: 'الأحد', period: 2, timeRange: '08:50 - 09:35', subject: 'الرياضيات', teacherName: 'هيئة التدريس', classroom: 'فصل 4/أ'),
    ];
    _exams = [
      ExamItem(id: 'ex1', title: 'اختبار شهر نوفمبر', subject: 'الرياضيات', grade: GradeLevel.p4, dateStr: 'الأحد 30 نوفمبر', timeStr: '09:00 ص', room: 'لجنة 4/أ'),
    ];
    _announcements = [
      AnnouncementNews(id: 'an1', title: 'أهلاً بكم في منصة مدرسة الرواد الخاصة', body: 'نظام الإدارة والمتابعة الإلكترونية لجميع المراحل الدراسية من KG1 وحتى الثالث الإعدادي.', category: 'إعلان', author: 'إدارة المدرسة', dateLabel: 'اليوم', isUrgent: true),
    ];
    _notifications = [
      SchoolNotification(id: 'n1', type: NotificationType.announcement, title: 'مرحباً بكم في النظام الجديد', body: 'تم تفعيل الحفظ التلقائي وتوثيق الحسابات برمز التحقق.', dateLabel: 'الآن'),
    ];
  }

  Future<void> _persist() async {
    final payload = jsonEncode({
      'darkMode': _themeMode == ThemeMode.dark,
      'currentUserId': _currentUserId,
      'selectedParentChildId': _selectedParentChildId,
      'users': _users.map((e) => e.toJson()).toList(),
      'classes': _classes.map((e) => e.toJson()).toList(),
      'subjects': _subjects.map((e) => e.toJson()).toList(),
      'schedule': _schedule.map((e) => e.toJson()).toList(),
      'exams': _exams.map((e) => e.toJson()).toList(),
      'attendance': _attendance.map((e) => e.toJson()).toList(),
      'homeworks': _homeworks.map((e) => e.toJson()).toList(),
      'grades': _grades.map((e) => e.toJson()).toList(),
      'invoices': _invoices.map((e) => e.toJson()).toList(),
      'announcements': _announcements.map((e) => e.toJson()).toList(),
      'notifications': _notifications.map((e) => e.toJson()).toList(),
      'files': _files.map((e) => e.toJson()).toList(),
      'messages': _messages.map((e) => e.toJson()).toList(),
    });
    await _prefs.setString(_storageKey, payload);
  }

  String _generateOtp() => (1000 + _rng.nextInt(9000)).toString();

  void toggleTheme() {
    _themeMode = _themeMode == ThemeMode.light ? ThemeMode.dark : ThemeMode.light;
    _persist();
    notifyListeners();
  }

  // تسجيل الدخول والمصادقة وتأكيد الحساب
  String? login(String phone, String password, {bool rememberSession = true}) {
    final p = phone.trim(), pass = password.trim();
    if (p.isEmpty || pass.isEmpty) return 'يرجى إدخال رقم الهاتف وكلمة المرور';
    final match = _users.where((u) => u.phone == p && u.password == pass).toList();
    if (match.isEmpty) return 'بيانات الدخول غير صحيحة. تأكد من رقم الهاتف وكلمة المرور.';
    final user = match.first;
    if (!user.isVerified) {
      user.otpCode = _generateOtp();
    }
    _currentUserId = user.id;
    if (user.role == UserRole.parent) {
      final kids = childrenOfParent(user.phone);
      if (kids.isNotEmpty) _selectedParentChildId = kids.first.id;
    }
    if (rememberSession) _persist();
    notifyListeners();
    return null;
  }

  ({String? error, AppUser? created}) registerSelf({
    required String name,
    required String phone,
    required String password,
    required UserRole role,
    required GradeLevel grade,
    String linkedParentPhone = '',
  }) {
    final p = phone.trim();
    if (name.trim().isEmpty || p.length < 8 || password.trim().length < 6) {
      return (error: 'تأكد من الاسم ورقم الهاتف الصحيح وكلمة مرور لا تقل عن 6 أحرف', created: null);
    }
    if (_users.any((u) => u.phone == p)) {
      return (error: 'رقم الهاتف مسجل بالفعل في النظام', created: null);
    }
    final user = AppUser(
      id: 'u_${DateTime.now().microsecondsSinceEpoch}',
      name: name.trim(),
      phone: p,
      password: password.trim(),
      role: role,
      grade: grade,
      classroom: 'فصل ${grade.shortLabel}',
      linkedParentPhone: linkedParentPhone.trim(),
      isVerified: false,
      isApproved: false, // حسابات التسجيل الذاتي تنتظر موافقة المدير بعد تأكيد OTP
      otpCode: _generateOtp(),
    );
    _users.add(user);
    _currentUserId = user.id;
    _persist();
    notifyListeners();
    return (error: null, created: user);
  }

  String resendOtpForCurrent() {
    final u = currentUser;
    if (u == null) return '';
    u.otpCode = _generateOtp();
    _persist();
    notifyListeners();
    return u.otpCode;
  }

  String? verifyCurrentUserOtp(String code, {String? newPassword}) {
    final u = currentUser;
    if (u == null) return 'لا توجد جلسة نشطة';
    if (code.trim() != u.otpCode) return 'رمز التحقق غير صحيح، يرجى التأكد والمحاولة مرة أخرى';
    u.isVerified = true;
    if (newPassword != null && newPassword.trim().length >= 6) {
      u.password = newPassword.trim();
    }
    _persist();
    notifyListeners();
    return null;
  }

  ({String? error, String? otp}) requestPasswordResetOtp(String phone) {
    final idx = _users.indexWhere((u) => u.phone == phone.trim());
    if (idx == -1) return (error: 'لا يوجد حساب مسجل بهذا الرقم', otp: null);
    final otp = _generateOtp();
    _users[idx].otpCode = otp;
    _persist();
    return (error: null, otp: otp);
  }

  String? completePasswordReset(String phone, String otp, String newPass) {
    final idx = _users.indexWhere((u) => u.phone == phone.trim());
    if (idx == -1) return 'الحساب غير موجود';
    if (_users[idx].otpCode != otp.trim()) return 'رمز التحقق غير صحيح';
    if (newPass.trim().length < 6) return 'كلمة المرور الجديدة يجب أن تكون 6 أحرف على الأقل';
    _users[idx].password = newPass.trim();
    _users[idx].isVerified = true;
    _persist();
    notifyListeners();
    return null;
  }

  String? changeCurrentUserPassword(String oldPass, String newPass) {
    final u = currentUser;
    if (u == null) return 'غير مسجل';
    if (u.password != oldPass.trim()) return 'كلمة المرور الحالية غير صحيحة';
    if (newPass.trim().length < 6) return 'كلمة المرور الجديدة يجب ألا تقل عن 6 أحرف';
    u.password = newPass.trim();
    _persist();
    notifyListeners();
    return null;
  }

  void approveUser(String userId) {
    final i = _users.indexWhere((u) => u.id == userId);
    if (i != -1) {
      _users[i].isApproved = true;
      _pushNotif(NotificationType.announcement, 'تم اعتماد حسابك', 'أهلاً ${_users[i].name}، تم اعتماد وتفعيل حسابك من إدارة مدرسة الرواد.', targetPhone: _users[i].phone);
      _persist();
      notifyListeners();
    }
  }

  void verifyUserByAdmin(String userId) {
    final i = _users.indexWhere((u) => u.id == userId);
    if (i != -1) {
      _users[i].isVerified = true;
      _users[i].isApproved = true;
      _persist();
      notifyListeners();
    }
  }

  void logout() {
    _currentUserId = null;
    _persist();
    notifyListeners();
  }

  // الاستعلامات
  List<AppUser> get allUsers => List.unmodifiable(_users);
  List<AppUser> usersByRole(UserRole role) => _users.where((u) => u.role == role).toList();
  List<AppUser> get pendingUsers => _users.where((u) => !u.isApproved || !u.isVerified).toList();
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

  List<AppUser> childrenOfParent(String parentPhone) =>
      _users.where((u) => u.role == UserRole.student && u.linkedParentPhone == parentPhone).toList();

  AppUser? get selectedParentChild {
    final u = currentUser;
    if (u == null) return null;
    final kids = childrenOfParent(u.phone);
    if (kids.isEmpty) return null;
    return kids.firstWhere((k) => k.id == _selectedParentChildId, orElse: () => kids.first);
  }

  void selectParentChild(String studentId) {
    _selectedParentChildId = studentId;
    _persist();
    notifyListeners();
  }

  List<SchoolNotification> notificationsForCurrentUser() {
    final u = currentUser;
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
    _persist();
    notifyListeners();
  }

  // إضافة وحذف المستخدمين واستيراد Excel
  String? addUserByAdmin({
    required String name,
    required String phone,
    required String password,
    required UserRole role,
    GradeLevel grade = GradeLevel.p4,
    String classroom = '',
    String subject = 'الرياضيات',
    String linkedParentPhone = '',
  }) {
    final cleanPhone = phone.trim();
    if (name.trim().isEmpty || cleanPhone.isEmpty || password.trim().isEmpty) return 'يرجى استكمال الاسم والهاتف وكلمة المرور';
    if (_users.any((u) => u.phone == cleanPhone)) return 'رقم الهاتف مسجل بالفعل';
    final user = AppUser(
      id: 'u_${DateTime.now().microsecondsSinceEpoch}',
      name: name.trim(),
      phone: cleanPhone,
      password: password.trim(),
      role: role,
      grade: grade,
      classroom: classroom.trim().isEmpty ? 'فصل ${grade.shortLabel}' : classroom.trim(),
      subject: subject.trim().isEmpty ? 'عام' : subject.trim(),
      linkedParentPhone: linkedParentPhone.trim(),
      isVerified: false, // يُطلب من المستخدم تأكيد حسابه برمز OTP في أول دخول
      isApproved: true,
      otpCode: _generateOtp(),
    );
    _users.add(user);
    if (role == UserRole.student) {
      _attendance.add(AttendanceEntry(id: 'att_${DateTime.now().microsecondsSinceEpoch}', studentId: user.id, studentName: user.name, grade: user.grade, dateStr: '2026-11-25', status: AttendanceStatus.present));
    }
    _persist();
    notifyListeners();
    return null;
  }

  void deleteUser(String id) {
    if (_currentUserId == id) return;
    _users.removeWhere((u) => u.id == id);
    _persist();
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
      final err = addUserByAdmin(name: c[0], phone: c[2], password: c[3], role: role, grade: grade, subject: role == UserRole.teacher && extra.isNotEmpty ? extra : 'عام', linkedParentPhone: role == UserRole.student ? extra : '');
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

  // العمليات الأكاديمية والمالية (تُحفظ فوراً على الجهاز)
  void addClass(String name, GradeLevel grade, int cap, String sup) {
    _classes.add(SchoolClass(id: 'c_${DateTime.now().microsecondsSinceEpoch}', name: name, grade: grade, capacity: cap, supervisorName: sup));
    _persist();
    notifyListeners();
  }

  void deleteClass(String id) {
    _classes.removeWhere((c) => c.id == id);
    _persist();
    notifyListeners();
  }

  void addSubject(String name, GradeLevel grade, String teacher) {
    _subjects.add(SubjectItem(id: 'sb_${DateTime.now().microsecondsSinceEpoch}', name: name, grade: grade, teacherName: teacher));
    _persist();
    notifyListeners();
  }

  void deleteSubject(String id) {
    _subjects.removeWhere((s) => s.id == id);
    _persist();
    notifyListeners();
  }

  void addScheduleSlot(GradeLevel grade, String day, int period, String time, String sub, String teacher, String room) {
    _schedule.add(ScheduleSlot(id: 'sc_${DateTime.now().microsecondsSinceEpoch}', grade: grade, day: day, period: period, timeRange: time, subject: sub, teacherName: teacher, classroom: room));
    _persist();
    notifyListeners();
  }

  void deleteScheduleSlot(String id) {
    _schedule.removeWhere((s) => s.id == id);
    _persist();
    notifyListeners();
  }

  void addExam(String title, String sub, GradeLevel grade, String dateStr, String timeStr, String room) {
    _exams.insert(0, ExamItem(id: 'ex_${DateTime.now().microsecondsSinceEpoch}', title: title, subject: sub, grade: grade, dateStr: dateStr, timeStr: timeStr, room: room));
    _pushNotif(NotificationType.exam, 'موعد امتحان: $sub', '$title (${grade.shortLabel}) يوم $dateStr الساعة $timeStr');
  }

  void deleteExam(String id) {
    _exams.removeWhere((e) => e.id == id);
    _persist();
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
    } else {
      _persist();
      notifyListeners();
    }
  }

  void addHomework(GradeLevel grade, String sub, String title, String details, String due) {
    _homeworks.insert(0, HomeworkItem(id: 'hw_${DateTime.now().microsecondsSinceEpoch}', grade: grade, subject: sub, title: title, details: details, dueDate: due, teacherName: currentUser?.name ?? 'المعلم'));
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
      _persist();
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
    } else {
      _persist();
      notifyListeners();
    }
  }

  void payInvoice(String id, double amount) {
    final i = _invoices.indexWhere((x) => x.id == id);
    if (i != -1) {
      _invoices[i].paidAmount = (_invoices[i].paidAmount + amount).clamp(0, _invoices[i].totalAmount);
      _pushNotif(NotificationType.fees, 'تأكيد سداد مصروفات', 'تم سداد ${amount.toStringAsFixed(0)} ج.م لـ (${_invoices[i].title}).');
    }
  }

  void addAnnouncement(String title, String body, String cat, UserRole? target, bool urgent) {
    _announcements.insert(0, AnnouncementNews(id: 'an_${DateTime.now().microsecondsSinceEpoch}', title: title, body: body, category: cat, targetRole: target, author: currentUser?.name ?? 'الإدارة', dateLabel: 'الآن', isUrgent: urgent));
    _pushNotif(NotificationType.announcement, '$cat: $title', body, targetRole: target);
  }

  void sendCustomNotif(NotificationType type, String title, String body, UserRole? target) => _pushNotif(type, title, body, targetRole: target);

  void _pushNotif(NotificationType type, String title, String body, {String? targetPhone, UserRole? targetRole}) {
    _notifications.insert(0, SchoolNotification(id: 'n_${DateTime.now().microsecondsSinceEpoch}', type: type, title: title, body: body, targetPhone: targetPhone, targetRole: targetRole, dateLabel: 'الآن'));
    _persist();
    notifyListeners();
  }

  void addFile(String title, String type, GradeLevel grade, String sub, String url) {
    _files.insert(0, EducationalFile(id: 'f_${DateTime.now().microsecondsSinceEpoch}', title: title, fileType: type, grade: grade, subject: sub, urlOrName: url, uploadedBy: currentUser?.name ?? 'المعلم', dateLabel: 'اليوم'));
    _persist();
    notifyListeners();
  }

  void sendMessage(String recipient, String subject, String body) {
    final u = currentUser;
    if (u == null) return;
    _messages.insert(0, SchoolMessage(id: 'm_${DateTime.now().microsecondsSinceEpoch}', senderName: u.name, senderPhone: u.phone, recipientLabel: recipient, subject: subject, body: body, dateLabel: 'الآن'));
    _persist();
    notifyListeners();
  }

  void replyMessage(String id, String reply) {
    final i = _messages.indexWhere((m) => m.id == id);
    if (i != -1) {
      _messages[i].reply = reply;
      _persist();
      notifyListeners();
    }
  }
}

class AppScope extends InheritedNotifier<SchoolState> {
  const AppScope({super.key, required SchoolState state, required super.child}) : super(notifier: state);
  static SchoolState of(BuildContext context) => context.dependOnInheritedWidgetOfExactType<AppScope>()!.notifier!;
}

// ============================================================================
// 3. التطبيق الرئيسي وبوابة التوجيه والتحقق (App, Splash, Auth & OTP)
// ============================================================================

class AlRowadPrivateSchoolApp extends StatefulWidget {
  const AlRowadPrivateSchoolApp({super.key});
  @override
  State<AlRowadPrivateSchoolApp> createState() => _AlRowadPrivateSchoolAppState();
}

class _AlRowadPrivateSchoolAppState extends State<AlRowadPrivateSchoolApp> {
  final SchoolState _state = SchoolState();

  @override
  void initState() {
    super.initState();
    _state.init();
  }

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
          final light = ColorScheme.fromSeed(seedColor: const Color(0xFF1B365D), secondary: const Color(0xFF0D9488), tertiary: const Color(0xFFD97706), brightness: Brightness.light);
          final dark = ColorScheme.fromSeed(seedColor: const Color(0xFF3B82F6), secondary: const Color(0xFF14B8A6), tertiary: const Color(0xFFF59E0B), brightness: Brightness.dark);
          return MaterialApp(
            debugShowCheckedModeBanner: false,
            title: 'مدرسة الرواد الخاصة',
            themeMode: _state.themeMode,
            theme: ThemeData(
              useMaterial3: true,
              colorScheme: light,
              scaffoldBackgroundColor: const Color(0xFFF5F7FA),
              appBarTheme: const AppBarTheme(centerTitle: true, elevation: 0, backgroundColor: Color(0xFF1B365D), foregroundColor: Colors.white),
              inputDecorationTheme: InputDecorationTheme(
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
              ),
            ),
            darkTheme: ThemeData(
              useMaterial3: true,
              colorScheme: dark,
              scaffoldBackgroundColor: const Color(0xFF0B1120),
              appBarTheme: const AppBarTheme(centerTitle: true, elevation: 0, backgroundColor: Color(0xFF111827), foregroundColor: Colors.white),
              inputDecorationTheme: InputDecorationTheme(filled: true, fillColor: const Color(0xFF1E293B), border: OutlineInputBorder(borderRadius: BorderRadius.circular(14))),
            ),
            builder: (_, child) => Directionality(textDirection: TextDirection.rtl, child: child!),
            home: const _AppGate(),
          );
        },
      ),
    );
  }
}

class _AppGate extends StatelessWidget {
  const _AppGate();
  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    if (!app.isInitialized) return const _SplashScreen();
    final user = app.currentUser;
    if (user == null) return const LoginScreen();
    if (!user.isVerified) return const OtpVerificationScreen();
    if (!user.isApproved) return const PendingApprovalScreen();

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
  const AlRowadLogo({super.key, this.size = 76});
  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(colors: [Color(0xFF1B365D), Color(0xFF0D9488)]),
        border: Border.all(color: const Color(0xFFF59E0B), width: 2.5),
        boxShadow: [BoxShadow(color: const Color(0xFF1B365D).withAlpha(55), blurRadius: 14, offset: const Offset(0, 6))],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Icon(Icons.school_rounded, size: size * 0.5, color: Colors.white),
          Positioned(
            bottom: size * 0.13,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(color: const Color(0xFFF59E0B), borderRadius: BorderRadius.circular(8)),
              child: Text('الرواد', style: TextStyle(fontSize: size * 0.14, fontWeight: FontWeight.w900, color: const Color(0xFF1B365D))),
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
        decoration: const BoxDecoration(gradient: LinearGradient(colors: [Color(0xFF0F172A), Color(0xFF1B365D), Color(0xFF0D9488)], begin: Alignment.topRight, end: Alignment.bottomLeft)),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AlRowadLogo(size: 108),
            SizedBox(height: 20),
            Text('مدرسة الرواد الخاصة', style: TextStyle(fontSize: 27, fontWeight: FontWeight.w900, color: Colors.white)),
            Text('Al Rowad Private School', style: TextStyle(fontSize: 14, color: Color(0xFFFEF08A), fontWeight: FontWeight.w600)),
            SizedBox(height: 30),
            CircularProgressIndicator(valueColor: AlwaysStoppedAnimation(Color(0xFFF59E0B))),
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
  final _phoneCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _obscure = true;
  bool _remember = true;
  bool _loading = false;
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
    await Future.delayed(const Duration(milliseconds: 280));
    if (!mounted) return;
    final err = AppScope.of(context).login(_phoneCtrl.text, _passCtrl.text, rememberSession: _remember);
    setState(() {
      _loading = false;
      _error = err;
    });
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: ListView(
              padding: const EdgeInsets.all(22),
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: IconButton(
                    tooltip: 'الوضع الليلي/النهاري',
                    icon: Icon(app.themeMode == ThemeMode.dark ? Icons.light_mode_rounded : Icons.dark_mode_rounded),
                    onPressed: app.toggleTheme,
                  ),
                ),
                const Center(child: AlRowadLogo(size: 92)),
                const SizedBox(height: 16),
                const Text('مدرسة الرواد الخاصة', textAlign: TextAlign.center, style: TextStyle(fontSize: 25, fontWeight: FontWeight.w900)),
                const SizedBox(height: 4),
                Text('Al Rowad Private School', textAlign: TextAlign.center, style: TextStyle(fontSize: 13.5, color: Theme.of(context).hintColor, fontWeight: FontWeight.w600)),
                const SizedBox(height: 28),
                Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22), side: BorderSide(color: Colors.grey.withAlpha(45))),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('تسجيل الدخول', style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        Text('أدخل رقم الهاتف وكلمة المرور الخاصة بحسابك', style: TextStyle(fontSize: 12.5, color: Theme.of(context).hintColor)),
                        const SizedBox(height: 18),
                        TextField(
                          controller: _phoneCtrl,
                          keyboardType: TextInputType.phone,
                          decoration: const InputDecoration(labelText: 'رقم الهاتف', prefixIcon: Icon(Icons.phone_android_rounded)),
                        ),
                        const SizedBox(height: 14),
                        TextField(
                          controller: _passCtrl,
                          obscureText: _obscure,
                          decoration: InputDecoration(
                            labelText: 'كلمة المرور',
                            prefixIcon: const Icon(Icons.lock_outline_rounded),
                            suffixIcon: IconButton(icon: Icon(_obscure ? Icons.visibility_off_rounded : Icons.visibility_rounded), onPressed: () => setState(() => _obscure = !_obscure)),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Checkbox(value: _remember, onChanged: (v) => setState(() => _remember = v ?? true)),
                                const Text('تذكرني', style: TextStyle(fontSize: 13)),
                              ],
                            ),
                            TextButton(
                              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ForgotPasswordScreen())),
                              child: const Text('نسيت كلمة المرور؟'),
                            ),
                          ],
                        ),
                        if (_error != null) ...[
                          const SizedBox(height: 8),
                          Container(width: double.infinity, padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: Colors.red.withAlpha(25), borderRadius: BorderRadius.circular(12)), child: Text(_error!, style: const TextStyle(color: Colors.red, fontWeight: FontWeight.w600, fontSize: 13))),
                        ],
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1B365D), foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                            onPressed: _loading ? null : _submit,
                            icon: _loading ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.login_rounded),
                            label: Text(_loading ? 'جاري التحقق...' : 'تسجيل الدخول', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('ليس لديك حساب مفعل؟'),
                    TextButton(
                      onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RegisterScreen())),
                      child: const Text('إنشاء حساب طالب / ولي أمر', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});
  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  UserRole _role = UserRole.student;
  GradeLevel _grade = GradeLevel.p4;
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _parentPhoneCtrl = TextEditingController();
  String? _err;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _passCtrl.dispose();
    _parentPhoneCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('إنشاء حساب جديد')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text('بيانات التسجيل', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          SegmentedButton<UserRole>(
            segments: const [
              ButtonSegment(value: UserRole.student, icon: Icon(Icons.school_rounded), label: Text('طالب')),
              ButtonSegment(value: UserRole.parent, icon: Icon(Icons.family_restroom_rounded), label: Text('ولي أمر')),
            ],
            selected: {_role},
            onSelectionChanged: (s) => setState(() => _role = s.first),
          ),
          const SizedBox(height: 14),
          TextField(controller: _nameCtrl, decoration: const InputDecoration(labelText: 'الاسم الكامل')),
          const SizedBox(height: 10),
          TextField(controller: _phoneCtrl, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'رقم الهاتف')),
          const SizedBox(height: 10),
          TextField(controller: _passCtrl, obscureText: true, decoration: const InputDecoration(labelText: 'كلمة المرور (6 أحرف فأكثر)')),
          if (_role == UserRole.student) ...[
            const SizedBox(height: 10),
            DropdownButtonFormField<GradeLevel>(value: _grade, decoration: const InputDecoration(labelText: 'الصف الدراسي'), items: GradeLevel.values.map((g) => DropdownMenuItem(value: g, child: Text(g.label))).toList(), onChanged: (v) { if (v != null) setState(() => _grade = v); }),
            const SizedBox(height: 10),
            TextField(controller: _parentPhoneCtrl, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'رقم هاتف ولي الأمر (اختياري للربط)')),
          ],
          if (_err != null) ...[
            const SizedBox(height: 10),
            Text(_err!, style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          ],
          const SizedBox(height: 18),
          SizedBox(
            height: 50,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1B365D), foregroundColor: Colors.white),
              onPressed: () {
                final res = AppScope.of(context).registerSelf(name: _nameCtrl.text, phone: _phoneCtrl.text, password: _passCtrl.text, role: _role, grade: _grade, linkedParentPhone: _parentPhoneCtrl.text);
                if (res.error != null) {
                  setState(() => _err = res.error);
                } else {
                  Navigator.pop(context);
                }
              },
              child: const Text('متابعة لتأكيد الحساب'),
            ),
          ),
        ],
      ),
    );
  }
}

class OtpVerificationScreen extends StatefulWidget {
  const OtpVerificationScreen({super.key});
  @override
  State<OtpVerificationScreen> createState() => _OtpVerificationScreenState();
}

class _OtpVerificationScreenState extends State<OtpVerificationScreen> {
  final _otpCtrl = TextEditingController();
  final _newPassCtrl = TextEditingController();
  String? _err;

  @override
  void dispose() {
    _otpCtrl.dispose();
    _newPassCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final user = app.currentUser!;

    return Scaffold(
      appBar: AppBar(
        title: const Text('تأكيد وتفعيل الحساب'),
        actions: [IconButton(icon: const Icon(Icons.logout_rounded), onPressed: app.logout)],
      ),
      body: ListView(
        padding: const EdgeInsets.all(22),
        children: [
          const Icon(Icons.verified_user_rounded, size: 72, color: Color(0xFF0D9488)),
          const SizedBox(height: 14),
          Text('مرحباً ${user.name}', textAlign: TextAlign.center, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          Text('لأمان حسابك، يرجى إدخال رمز التحقق المرسل إلى رقم الهاتف ${user.phone}', textAlign: TextAlign.center, style: TextStyle(color: Theme.of(context).hintColor)),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: const Color(0xFF0D9488).withAlpha(24), borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFF0D9488).withAlpha(80))),
            child: Row(
              children: [
                const Icon(Icons.sms_rounded, color: Color(0xFF0D9488)),
                const SizedBox(width: 10),
                Expanded(child: Text('رسالة التحقق (SMS): رمز تفعيل حسابك في مدرسة الرواد هو [ ${user.otpCode} ]', style: const TextStyle(fontWeight: FontWeight.bold))),
              ],
            ),
          ),
          const SizedBox(height: 18),
          TextField(controller: _otpCtrl, keyboardType: TextInputType.number, textAlign: TextAlign.center, decoration: const InputDecoration(labelText: 'أدخل رمز التحقق (4 أرقام)')),
          const SizedBox(height: 12),
          TextField(controller: _newPassCtrl, obscureText: true, decoration: const InputDecoration(labelText: 'تعيين كلمة مرور شخصية جديدة (اختياري)')),
          if (_err != null) ...[
            const SizedBox(height: 10),
            Text(_err!, style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          ],
          const SizedBox(height: 18),
          SizedBox(
            height: 50,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1B365D), foregroundColor: Colors.white),
              onPressed: () {
                final err = app.verifyCurrentUserOtp(_otpCtrl.text, newPassword: _newPassCtrl.text);
                if (err != null) setState(() => _err = err);
              },
              child: const Text('تأكيد وتفعيل الحساب'),
            ),
          ),
          TextButton(
            onPressed: () {
              final newOtp = app.resendOtpForCurrent();
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تم إرسال رمز جديد: $newOtp')));
            },
            child: const Text('إعادة إرسال الرمز'),
          ),
        ],
      ),
    );
  }
}

class PendingApprovalScreen extends StatelessWidget {
  const PendingApprovalScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final user = app.currentUser!;
    return Scaffold(
      appBar: AppBar(title: const Text('حالة الحساب'), actions: [IconButton(icon: const Icon(Icons.logout_rounded), onPressed: app.logout)]),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.hourglass_top_rounded, size: 78, color: Color(0xFFD97706)),
              const SizedBox(height: 16),
              Text('تم تأكيد رقم الهاتف بنجاح (${user.phone})', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
              const SizedBox(height: 8),
              Text('حسابك الآن بانتظار اعتماد إدارة مدرسة الرواد الخاصة لتفعيل جميع الصلاحيات.', textAlign: TextAlign.center, style: TextStyle(color: Theme.of(context).hintColor)),
              const SizedBox(height: 22),
              OutlinedButton.icon(onPressed: app.logout, icon: const Icon(Icons.arrow_back), label: const Text('العودة لتسجيل الدخول')),
            ],
          ),
        ),
      ),
    );
  }
}

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});
  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _phoneCtrl = TextEditingController();
  final _otpCtrl = TextEditingController();
  final _newPassCtrl = TextEditingController();
  String? _sentOtp;
  String? _err;

  @override
  void dispose() {
    _phoneCtrl.dispose();
    _otpCtrl.dispose();
    _newPassCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('استعادة كلمة المرور')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          TextField(controller: _phoneCtrl, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'رقم الهاتف المسجل')),
          const SizedBox(height: 12),
          if (_sentOtp == null)
            ElevatedButton(
              onPressed: () {
                final res = app.requestPasswordResetOtp(_phoneCtrl.text);
                setState(() {
                  _err = res.error;
                  _sentOtp = res.otp;
                });
              },
              child: const Text('إرسال رمز التحقق'),
            )
          else ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: const Color(0xFF0D9488).withAlpha(24), borderRadius: BorderRadius.circular(12)),
              child: Text('رمز الاستعادة (SMS): $_sentOtp', style: const TextStyle(fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 12),
            TextField(controller: _otpCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'رمز التحقق')),
            const SizedBox(height: 10),
            TextField(controller: _newPassCtrl, obscureText: true, decoration: const InputDecoration(labelText: 'كلمة المرور الجديدة')),
            const SizedBox(height: 14),
            ElevatedButton(
              onPressed: () {
                final err = app.completePasswordReset(_phoneCtrl.text, _otpCtrl.text, _newPassCtrl.text);
                if (err != null) {
                  setState(() => _err = err);
                } else {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم تحديث كلمة المرور بنجاح')));
                }
              },
              child: const Text('حفظ كلمة المرور الجديدة'),
            ),
          ],
          if (_err != null) ...[const SizedBox(height: 10), Text(_err!, style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold))],
        ],
      ),
    );
  }
} 
// ============================================================================
// 4. مكونات التصميم المشتركة (Clean Design System & Account Tab)
// ============================================================================

PreferredSizeWidget _buildAppBar(BuildContext context, String title) {
  final app = AppScope.of(context);
  final unread = app.unreadNotificationsCount;
  return AppBar(
    title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
    actions: [
      IconButton(
        tooltip: 'الإشعارات',
        icon: Badge(isLabelVisible: unread > 0, label: Text('$unread'), child: const Icon(Icons.notifications_none_rounded)),
        onPressed: () => _openNotificationsSheet(context),
      ),
      IconButton(
        tooltip: 'المظهر',
        icon: Icon(app.themeMode == ThemeMode.dark ? Icons.light_mode_rounded : Icons.dark_mode_rounded),
        onPressed: app.toggleTheme,
      ),
    ],
  );
}

void _openNotificationsSheet(BuildContext context) {
  final app = AppScope.of(context);
  app.markNotificationsRead();
  final list = app.notificationsForCurrentUser();
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    builder: (_) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.65,
      builder: (_, ctrl) => Column(
        children: [
          const SizedBox(height: 10),
          Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade400, borderRadius: BorderRadius.circular(4))),
          const Padding(padding: EdgeInsets.all(14), child: Text('مركز الإشعارات', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
          Expanded(
            child: list.isEmpty
                ? const Center(child: Text('لا توجد إشعارات حالياً'))
                : ListView.builder(
                    controller: ctrl,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    itemCount: list.length,
                    itemBuilder: (_, i) {
                      final n = list[i];
                      return Card(
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: BorderSide(color: Colors.grey.withAlpha(45))),
                        child: ListTile(
                          leading: CircleAvatar(backgroundColor: n.type.color.withAlpha(28), child: Icon(n.type.icon, color: n.type.color, size: 20)),
                          title: Text(n.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                          subtitle: Text('${n.body}\n${n.dateLabel}', style: const TextStyle(fontSize: 12.5)),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    ),
  );
}

class _HeroBanner extends StatelessWidget {
  final String title, subtitle, badge;
  final List<Color> colors;
  const _HeroBanner({required this.title, required this.subtitle, required this.badge, required this.colors});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: colors, begin: Alignment.topRight, end: Alignment.bottomLeft),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        children: [
          const AlRowadLogo(size: 60),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(color: Colors.white.withAlpha(40), borderRadius: BorderRadius.circular(8)),
                  child: Text(badge, style: const TextStyle(color: Color(0xFFFEF08A), fontSize: 11, fontWeight: FontWeight.bold)),
                ),
                const SizedBox(height: 6),
                Text(title, style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w900)),
                Text(subtitle, style: TextStyle(color: Colors.white.withAlpha(215), fontSize: 12.5)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ServiceTile extends StatelessWidget {
  final String title, subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  const _ServiceTile({required this.title, required this.subtitle, required this.icon, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Card(
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18), side: BorderSide(color: Colors.grey.withAlpha(45))),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              CircleAvatar(radius: 20, backgroundColor: color.withAlpha(28), child: Icon(icon, color: color, size: 22)),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14), maxLines: 1, overflow: TextOverflow.ellipsis),
                  Text(subtitle, style: TextStyle(fontSize: 11.5, color: Theme.of(context).hintColor), maxLines: 1, overflow: TextOverflow.ellipsis),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AccountTab extends StatelessWidget {
  const _AccountTab();

  void _changePasswordDialog(BuildContext context) {
    final oldCtrl = TextEditingController();
    final newCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('تغيير كلمة المرور'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: oldCtrl, obscureText: true, decoration: const InputDecoration(labelText: 'كلمة المرور الحالية')),
            const SizedBox(height: 10),
            TextField(controller: newCtrl, obscureText: true, decoration: const InputDecoration(labelText: 'كلمة المرور الجديدة')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: () {
              final err = AppScope.of(context).changeCurrentUserPassword(oldCtrl.text, newCtrl.text);
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err ?? 'تم تغيير كلمة المرور وحفظها بنجاح')));
            },
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final u = app.currentUser!;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: Colors.grey.withAlpha(45))),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              children: [
                CircleAvatar(radius: 34, backgroundColor: u.role.color.withAlpha(30), child: Icon(u.role.icon, size: 34, color: u.role.color)),
                const SizedBox(height: 10),
                Text(u.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(u.role.label, style: TextStyle(color: Theme.of(context).hintColor)),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(color: const Color(0xFF10B981).withAlpha(30), borderRadius: BorderRadius.circular(10)),
                      child: const Row(children: [Icon(Icons.verified_rounded, size: 14, color: Color(0xFF10B981)), SizedBox(width: 3), Text('حساب موثّق', style: TextStyle(fontSize: 11.5, color: Color(0xFF10B981), fontWeight: FontWeight.bold))]),
                    ),
                  ],
                ),
                const Divider(height: 24),
                ListTile(dense: true, leading: const Icon(Icons.phone_android), title: const Text('رقم الهاتف'), trailing: Text(u.phone, style: const TextStyle(fontWeight: FontWeight.bold))),
                if (u.role == UserRole.student) ListTile(dense: true, leading: const Icon(Icons.class_), title: const Text('الصف والفصل'), trailing: Text('${u.grade.shortLabel} (${u.classroom})')),
                if (u.role == UserRole.teacher) ListTile(dense: true, leading: const Icon(Icons.menu_book), title: const Text('التخصص'), trailing: Text(u.subject)),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18), side: BorderSide(color: Colors.grey.withAlpha(45))),
          child: Column(
            children: [
              ListTile(leading: const Icon(Icons.lock_reset_rounded), title: const Text('تغيير كلمة المرور'), trailing: const Icon(Icons.chevron_right), onTap: () => _changePasswordDialog(context)),
              const Divider(height: 1),
              SwitchListTile(secondary: const Icon(Icons.dark_mode_rounded), title: const Text('الوضع الليلي'), value: app.themeMode == ThemeMode.dark, onChanged: (_) => app.toggleTheme()),
              const Divider(height: 1),
              ListTile(leading: const Icon(Icons.logout_rounded, color: Colors.red), title: const Text('تسجيل الخروج', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)), onTap: app.logout),
            ],
          ),
        ),
      ],
    );
  }
}

// ============================================================================
// 5. لوحة إدارة المدرسة (Admin Dashboard + صفحات مستقلة نظيفة)
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
    final app = AppScope.of(context);
    final pendingCount = app.pendingUsers.length;
    final pages = [const _AdminHomeTab(), const _AdminApprovalsTab(), const _AccountTab()];

    return Scaffold(
      appBar: _buildAppBar(context, 'إدارة مدرسة الرواد'),
      body: pages[_tab],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: [
          const NavigationDestination(icon: Icon(Icons.dashboard_rounded), label: 'الرئيسية'),
          NavigationDestination(icon: Badge(isLabelVisible: pendingCount > 0, label: Text('$pendingCount'), child: const Icon(Icons.verified_user_rounded)), label: 'الاعتمادات'),
          const NavigationDestination(icon: Icon(Icons.person_rounded), label: 'حسابي'),
        ],
      ),
    );
  }
}

class _AdminHomeTab extends StatelessWidget {
  const _AdminHomeTab();

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final stCount = app.usersByRole(UserRole.student).length;
    final tchCount = app.usersByRole(UserRole.teacher).length;
    final totalFees = app.allInvoices.fold<double>(0, (s, i) => s + i.paidAmount);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _HeroBanner(title: app.currentUser!.name, subtitle: 'لوحة الإدارة المركزية (حفظ تلقائي)', badge: 'مدرسة الرواد الخاصة', colors: const [Color(0xFF1B365D), Color(0xFF0D9488)]),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(child: _MiniKpi('الطلاب', '$stCount', const Color(0xFF0284C7))),
            const SizedBox(width: 8),
            Expanded(child: _MiniKpi('المعلمون', '$tchCount', const Color(0xFF0D9488))),
            const SizedBox(width: 8),
            Expanded(child: _MiniKpi('التحصيل', '${totalFees.toStringAsFixed(0)} ج', const Color(0xFFD97706))),
          ],
        ),
        const SizedBox(height: 18),
        const Text('إدارة النظام والخدمات', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 10),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          childAspectRatio: 1.25,
          children: [
            _ServiceTile(title: 'الطلاب والمعلمون', subtitle: 'إضافة يدوية وكلمات مرور', icon: Icons.people_alt_rounded, color: const Color(0xFF1B365D), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const _AdminUsersPage()))),
            _ServiceTile(title: 'استيراد Excel', subtitle: 'رفع xlsx أو csv أو لصق', icon: Icons.table_view_rounded, color: const Color(0xFF0D9488), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const _AdminExcelPage()))),
            _ServiceTile(title: 'الفصول والمواد', subtitle: 'إدارة الفصول والجداول', icon: Icons.class_rounded, color: const Color(0xFF0284C7), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const _AdminClassesSchedulePage()))),
            _ServiceTile(title: 'الحضور والدرجات', subtitle: 'متابعة الغياب والامتحانات', icon: Icons.fact_check_rounded, color: const Color(0xFF10B981), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const _AdminAttendanceExamsPage()))),
            _ServiceTile(title: 'المصروفات', subtitle: 'الفواتير والتحصيل المالي', icon: Icons.payments_rounded, color: const Color(0xFFD97706), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const _AdminFeesPage()))),
            _ServiceTile(title: 'الإعلانات والرسائل', subtitle: 'نشر أخبار والرد على الآباء', icon: Icons.campaign_rounded, color: const Color(0xFF6D28D9), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const _AdminCommsPage()))),
          ],
        ),
      ],
    );
  }
}

class _AdminApprovalsTab extends StatelessWidget {
  const _AdminApprovalsTab();
  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final pending = app.pendingUsers;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text('حسابات بانتظار الاعتماد أو التأكيد', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 10),
        if (pending.isEmpty)
          const Card(child: Padding(padding: EdgeInsets.all(20), child: Center(child: Text('جميع الحسابات مفعّلة ومعتمدة ✓'))))
        else
          ...pending.map((u) => Card(
                child: ListTile(
                  leading: CircleAvatar(backgroundColor: u.role.color.withAlpha(30), child: Icon(u.role.icon, color: u.role.color)),
                  title: Text(u.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text('${u.role.label} • ${u.phone}\n${u.isVerified ? "الهاتف مؤكد ✓" : "رمز التحقق: ${u.otpCode}"} • ${u.isApproved ? "معتمد" : "بانتظار اعتماد المدير"}'),
                  trailing: ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981), foregroundColor: Colors.white),
                    onPressed: () => app.verifyUserByAdmin(u.id),
                    child: const Text('اعتماد'),
                  ),
                ),
              )),
      ],
    );
  }
}

class _AdminUsersPage extends StatefulWidget {
  const _AdminUsersPage();
  @override
  State<_AdminUsersPage> createState() => _AdminUsersPageState();
}

class _AdminUsersPageState extends State<_AdminUsersPage> {
  UserRole _filter = UserRole.student;

  void _openAdd() {
    final name = TextEditingController(), phone = TextEditingController(), pass = TextEditingController(), extra = TextEditingController();
    UserRole role = _filter;
    GradeLevel grade = GradeLevel.p4;
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
                const Text('إضافة حساب جديد', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                DropdownButtonFormField<UserRole>(value: role, items: UserRole.values.map((r) => DropdownMenuItem(value: r, child: Text(r.label))).toList(), onChanged: (v) { if (v != null) setM(() => role = v); }),
                const SizedBox(height: 8),
                TextField(controller: name, decoration: const InputDecoration(labelText: 'الاسم الكامل')),
                const SizedBox(height: 8),
                TextField(controller: phone, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'رقم الهاتف')),
                const SizedBox(height: 8),
                TextField(controller: pass, decoration: const InputDecoration(labelText: 'كلمة المرور المبدئية')),
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
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1B365D), foregroundColor: Colors.white),
                    onPressed: () {
                      final err = AppScope.of(context).addUserByAdmin(name: name.text, phone: phone.text, password: pass.text, role: role, grade: grade, subject: role == UserRole.teacher ? extra.text : 'عام', linkedParentPhone: role == UserRole.student ? extra.text : '');
                      if (err != null) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
                        return;
                      }
                      Navigator.pop(ctx);
                      setState(() => _filter = role);
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

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final users = app.usersByRole(_filter);
    return Scaffold(
      appBar: AppBar(title: const Text('إدارة المستخدمين')),
      floatingActionButton: FloatingActionButton.extended(onPressed: _openAdd, icon: const Icon(Icons.person_add), label: const Text('إضافة حساب')),
      body: Column(
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.all(12),
            child: Row(
              children: UserRole.values.map((r) => Padding(padding: const EdgeInsets.only(left: 6), child: ChoiceChip(label: Text('${r.label} (${app.usersByRole(r).length})'), selected: _filter == r, onSelected: (_) => setState(() => _filter = r)))).toList(),
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 80),
              itemCount: users.length,
              itemBuilder: (_, i) {
                final u = users[i];
                return Card(
                  child: ListTile(
                    leading: CircleAvatar(backgroundColor: u.role.color.withAlpha(28), child: Icon(u.role.icon, color: u.role.color)),
                    title: Text(u.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text('الهاتف: ${u.phone} • ${u.isVerified ? "موثّق ✓" : "رمز التفعيل: ${u.otpCode}"}'),
                    trailing: u.phone == '01129220696' ? const Chip(label: Text('المدير')) : IconButton(icon: const Icon(Icons.delete_outline, color: Colors.red), onPressed: () => app.deleteUser(u.id)),
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

class _AdminExcelPage extends StatefulWidget {
  const _AdminExcelPage();
  @override
  State<_AdminExcelPage> createState() => _AdminExcelPageState();
}

class _AdminExcelPageState extends State<_AdminExcelPage> {
  final _pasteCtrl = TextEditingController();
  static const _template = 'الاسم,الصفة,رقم الهاتف,كلمة المرور,الصف,هاتف ولي الأمر أو المادة\n'
      'يوسف أحمد علي,طالب,01055566601,Abc12345,4 ابتدائي,01030303030\n'
      'أ. رانيا سمير,معلم,01055566602,Teach123,5 ابتدائي,العلوم';

  @override
  void dispose() {
    _pasteCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('استيراد من Excel')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('ترتيب الأعمدة: الاسم | الصفة (طالب/معلم/ولي أمر) | الهاتف | كلمة المرور | الصف | هاتف ولي الأمر أو المادة', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 14),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0D9488), foregroundColor: Colors.white, minimumSize: const Size.fromHeight(48)),
            onPressed: () async {
              try {
                final picked = await FilePicker.pickFile(type: FileType.custom, allowedExtensions: ['xlsx', 'csv']);
                if (picked == null) return;
                final bytes = await picked.readAsBytes();
                if (!context.mounted) return;
                final res = AppScope.of(context).importExcelOrCsvBytes(bytes, picked.name);
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${res.message}: أضيف ${res.added} (تخطي ${res.skipped})')));
              } catch (_) {
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('استخدم اللصق المباشر بالأسفل')));
              }
            },
            icon: const Icon(Icons.upload_file_rounded),
            label: const Text('اختيار ملف .xlsx أو .csv من الهاتف'),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(onPressed: () => setState(() => _pasteCtrl.text = _template), icon: const Icon(Icons.description_outlined), label: const Text('تعبئة نموذج جدول تجريبي')),
          const SizedBox(height: 10),
          TextField(controller: _pasteCtrl, maxLines: 6, decoration: const InputDecoration(labelText: 'أو الصق صفوف الجدول هنا')),
          const SizedBox(height: 14),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1B365D), foregroundColor: Colors.white, minimumSize: const Size.fromHeight(48)),
            onPressed: () {
              if (_pasteCtrl.text.trim().isEmpty) return;
              final res = AppScope.of(context).importDelimitedText(_pasteCtrl.text);
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${res.message}: تم استيراد ${res.added} حساب (تخطي ${res.skipped})')));
            },
            icon: const Icon(Icons.playlist_add_check_rounded),
            label: const Text('تنفيذ الاستيراد والحفظ'),
          ),
        ],
      ),
    );
  }
}

class _AdminClassesSchedulePage extends StatelessWidget {
  const _AdminClassesSchedulePage();
  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('الفصول والمواد والجدول')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          final c1 = TextEditingController(), c2 = TextEditingController();
          GradeLevel g = GradeLevel.p4;
          String kind = 'فصل';
          showDialog(
            context: context,
            builder: (ctx) => StatefulBuilder(
              builder: (ctx, setM) => AlertDialog(
                title: const Text('إضافة عنصر أكاديمي'),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SegmentedButton<String>(segments: const [ButtonSegment(value: 'فصل', label: Text('فصل')), ButtonSegment(value: 'مادة', label: Text('مادة')), ButtonSegment(value: 'حصة', label: Text('حصة'))], selected: {kind}, onSelectionChanged: (s) => setM(() => kind = s.first)),
                    const SizedBox(height: 8),
                    TextField(controller: c1, decoration: InputDecoration(labelText: kind == 'فصل' ? 'اسم الفصل' : 'اسم المادة')),
                    const SizedBox(height: 8),
                    TextField(controller: c2, decoration: InputDecoration(labelText: kind == 'حصة' ? 'اليوم (الأحد..)' : 'المعلم / الرائد')),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<GradeLevel>(value: g, items: GradeLevel.values.map((e) => DropdownMenuItem(value: e, child: Text(e.shortLabel))).toList(), onChanged: (v) { if (v != null) setM(() => g = v); }),
                  ],
                ),
                actions: [
                  ElevatedButton(
                    onPressed: () {
                      if (c1.text.trim().isEmpty) return;
                      if (kind == 'فصل') app.addClass(c1.text.trim(), g, 28, c2.text.trim().isEmpty ? 'هيئة التدريس' : c2.text.trim());
                      if (kind == 'مادة') app.addSubject(c1.text.trim(), g, c2.text.trim().isEmpty ? 'هيئة التدريس' : c2.text.trim());
                      if (kind == 'حصة') app.addScheduleSlot(g, c2.text.trim().isEmpty ? 'الأحد' : c2.text.trim(), 1, '09:00 ص', c1.text.trim(), 'المعلم', 'فصل ${g.shortLabel}');
                      Navigator.pop(ctx);
                    },
                    child: const Text('حفظ'),
                  ),
                ],
              ),
            ),
          );
        },
        icon: const Icon(Icons.add),
        label: const Text('إضافة'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 80),
        children: [
          const Text('الفصول', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15.5)),
          ...app.allClasses.map((c) => Card(child: ListTile(title: Text('${c.name} (${c.grade.shortLabel})'), subtitle: Text('الرائد: ${c.supervisorName}'), trailing: IconButton(icon: const Icon(Icons.delete_outline, color: Colors.red), onPressed: () => app.deleteClass(c.id))))),
          const SizedBox(height: 12),
          const Text('المواد', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15.5)),
          ...app.allSubjects.map((s) => Card(child: ListTile(title: Text('${s.name} (${s.grade.shortLabel})'), subtitle: Text(s.teacherName), trailing: IconButton(icon: const Icon(Icons.delete_outline, color: Colors.red), onPressed: () => app.deleteSubject(s.id))))),
          const SizedBox(height: 12),
          const Text('الجدول الدراسي', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15.5)),
          ...app.allSchedule.map((sc) => Card(child: ListTile(title: Text('${sc.day}: ${sc.subject} (${sc.grade.shortLabel})'), subtitle: Text(sc.timeRange), trailing: IconButton(icon: const Icon(Icons.delete_outline, color: Colors.red), onPressed: () => app.deleteScheduleSlot(sc.id))))),
        ],
      ),
    );
  }
}

class _AdminAttendanceExamsPage extends StatelessWidget {
  const _AdminAttendanceExamsPage();
  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final students = app.usersByRole(UserRole.student);
    return Scaffold(
      appBar: AppBar(title: const Text('الحضور والامتحانات والدرجات')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          final sub = TextEditingController(), date = TextEditingController(text: 'الأحد القادم');
          GradeLevel g = GradeLevel.p4;
          showDialog(
            context: context,
            builder: (ctx) => StatefulBuilder(
              builder: (ctx, setM) => AlertDialog(
                title: const Text('إضافة موعد امتحان'),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(controller: sub, decoration: const InputDecoration(labelText: 'المادة')),
                    const SizedBox(height: 8),
                    TextField(controller: date, decoration: const InputDecoration(labelText: 'التاريخ')),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<GradeLevel>(value: g, items: GradeLevel.values.map((e) => DropdownMenuItem(value: e, child: Text(e.shortLabel))).toList(), onChanged: (v) { if (v != null) setM(() => g = v); }),
                  ],
                ),
                actions: [ElevatedButton(onPressed: () { if (sub.text.trim().isNotEmpty) app.addExam('اختبار شهري', sub.text.trim(), g, date.text.trim(), '09:00 ص', 'لجنة ${g.shortLabel}'); Navigator.pop(ctx); }, child: const Text('حفظ'))],
              ),
            ),
          );
        },
        icon: const Icon(Icons.event_available),
        label: const Text('إضافة امتحان'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 80),
        children: [
          const Text('مواعيد الامتحانات', style: TextStyle(fontWeight: FontWeight.bold)),
          ...app.allExams.map((e) => Card(child: ListTile(title: Text('${e.subject} (${e.grade.shortLabel})'), subtitle: Text('${e.dateStr} • ${e.timeStr}'), trailing: IconButton(icon: const Icon(Icons.delete_outline, color: Colors.red), onPressed: () => app.deleteExam(e.id))))),
          const SizedBox(height: 12),
          const Text('الحضور والغياب اليومي', style: TextStyle(fontWeight: FontWeight.bold)),
          if (students.isEmpty) const Card(child: Padding(padding: EdgeInsets.all(14), child: Text('أضف طلاباً أولاً لمتابعة الحضور'))),
          ...students.map((st) {
            final cur = app.attendanceOf(st.id);
            return Card(child: ListTile(title: Text(st.name), trailing: DropdownButton<AttendanceStatus>(value: cur, underline: const SizedBox(), items: AttendanceStatus.values.map((a) => DropdownMenuItem(value: a, child: Text(a.label, style: TextStyle(color: a.color)))).toList(), onChanged: (v) { if (v != null) app.recordAttendance(st, v); })));
          }),
          const SizedBox(height: 12),
          const Text('الدرجات المرصودة', style: TextStyle(fontWeight: FontWeight.bold)),
          ...app.allGrades.map((g) => Card(child: ListTile(title: Text('${g.studentName} • ${g.subject}'), trailing: Text('${g.score}/${g.maxScore}')))),
        ],
      ),
    );
  }
}

class _AdminFeesPage extends StatelessWidget {
  const _AdminFeesPage();
  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final students = app.usersByRole(UserRole.student);
    return Scaffold(
      appBar: AppBar(title: const Text('إدارة المصروفات')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          if (students.isEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('أضف طلاباً أولاً لإصدار الفواتير')));
            return;
          }
          AppUser st = students.first;
          final title = TextEditingController(text: 'قسط دراسي');
          final total = TextEditingController(text: '8000');
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
                    TextField(controller: total, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'المبلغ (ج.م)')),
                  ],
                ),
                actions: [ElevatedButton(onPressed: () { app.addInvoice(st, title.text.trim(), double.tryParse(total.text) ?? 0, 0, '2026-12-15'); Navigator.pop(ctx); }, child: const Text('حفظ وإرسال تنبيه'))],
              ),
            ),
          );
        },
        icon: const Icon(Icons.add_card),
        label: const Text('فاتورة جديدة'),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 80),
        itemCount: app.allInvoices.length,
        itemBuilder: (_, i) {
          final inv = app.allInvoices[i];
          return Card(child: ListTile(title: Text('${inv.studentName} • ${inv.title}'), subtitle: Text('المتبقي: ${inv.remaining.toStringAsFixed(0)} من ${inv.totalAmount.toStringAsFixed(0)} ج.م'), trailing: inv.isFullyPaid ? const Chip(label: Text('مسدد')) : ElevatedButton(onPressed: () => app.payInvoice(inv.id, inv.remaining), child: const Text('تحصيل'))));
        },
      ),
    );
  }
}

class _AdminCommsPage extends StatelessWidget {
  const _AdminCommsPage();
  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('الإعلانات والرسائل')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          final t = TextEditingController(), b = TextEditingController();
          showDialog(context: context, builder: (ctx) => AlertDialog(title: const Text('نشر إعلان وإشعار'), content: Column(mainAxisSize: MainAxisSize.min, children: [TextField(controller: t, decoration: const InputDecoration(labelText: 'العنوان')), const SizedBox(height: 8), TextField(controller: b, maxLines: 3, decoration: const InputDecoration(labelText: 'التفاصيل'))]), actions: [ElevatedButton(onPressed: () { if (t.text.trim().isNotEmpty) app.addAnnouncement(t.text.trim(), b.text.trim(), 'إعلان', null, true); Navigator.pop(ctx); }, child: const Text('نشر'))]));
        },
        icon: const Icon(Icons.campaign),
        label: const Text('نشر إعلان'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 80),
        children: [
          const Text('الإعلانات والأخبار', style: TextStyle(fontWeight: FontWeight.bold)),
          ...app.allAnnouncements.map((a) => Card(child: ListTile(title: Text(a.title, style: const TextStyle(fontWeight: FontWeight.bold)), subtitle: Text(a.body)))),
          const SizedBox(height: 12),
          const Text('رسائل أولياء الأمور', style: TextStyle(fontWeight: FontWeight.bold)),
          ...app.allMessages.map((m) => Card(child: ListTile(title: Text('${m.senderName}: ${m.subject}'), subtitle: Text('${m.body}\n${m.reply.isEmpty ? "بانتظار الرد" : "الرد: ${m.reply}"}'), trailing: IconButton(icon: const Icon(Icons.reply), onPressed: () { final r = TextEditingController(text: m.reply); showDialog(context: context, builder: (ctx) => AlertDialog(title: const Text('الرد على الرسالة'), content: TextField(controller: r), actions: [ElevatedButton(onPressed: () { app.replyMessage(m.id, r.text.trim()); Navigator.pop(ctx); }, child: const Text('إرسال'))])); })))),
        ],
      ),
    );
  }
}

// ============================================================================
// 6. بوابة المعلم (Teacher Dashboard)
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
    final app = AppScope.of(context);
    final t = app.currentUser!;
    final pages = [
      ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _HeroBanner(title: t.name, subtitle: 'معلم مادة ${t.subject} (${t.grade.shortLabel})', badge: 'بوابة المعلم', colors: const [Color(0xFF0D9488), Color(0xFF1B365D)]),
          const SizedBox(height: 16),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 1.25,
            children: [
              _ServiceTile(title: 'الطلاب والحضور', subtitle: 'تحضير بضغطة زر', icon: Icons.fact_check_rounded, color: const Color(0xFF0D9488), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const _TeacherAttendancePage()))),
              _ServiceTile(title: 'الواجبات', subtitle: 'إضافة مهام للطلاب', icon: Icons.assignment_rounded, color: const Color(0xFF0284C7), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const _TeacherHomeworkPage()))),
              _ServiceTile(title: 'رصد الدرجات', subtitle: 'إدخال وتحديث النتائج', icon: Icons.grade_rounded, color: const Color(0xFF10B981), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const _TeacherGradesPage()))),
              _ServiceTile(title: 'الملفات والفصول', subtitle: 'رفع PDF ومذكرات', icon: Icons.upload_file_rounded, color: const Color(0xFF6D28D9), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const _TeacherFilesPage()))),
            ],
          ),
        ],
      ),
      _SchoolFeedTab(user: t),
      const _AccountTab(),
    ];

    return Scaffold(
      appBar: _buildAppBar(context, 'المعلم • ${t.grade.shortLabel}'),
      body: pages[_tab],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_rounded), label: 'الرئيسية'),
          NavigationDestination(icon: Icon(Icons.campaign_rounded), label: 'الإعلانات'),
          NavigationDestination(icon: Icon(Icons.person_rounded), label: 'حسابي'),
        ],
      ),
    );
  }
}

class _TeacherAttendancePage extends StatelessWidget {
  const _TeacherAttendancePage();
  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final students = app.usersByRole(UserRole.student);
    return Scaffold(
      appBar: AppBar(title: const Text('الطلاب والحضور')),
      body: students.isEmpty
          ? const Center(child: Text('لا يوجد طلاب مسجلون بعد'))
          : ListView.builder(
              padding: const EdgeInsets.all(14),
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
                                    decoration: BoxDecoration(color: sel ? a.color : a.color.withAlpha(24), borderRadius: BorderRadius.circular(10)),
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
            ),
    );
  }
}

class _TeacherHomeworkPage extends StatelessWidget {
  const _TeacherHomeworkPage();
  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('الواجبات المدرسية')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          GradeLevel g = app.currentUser!.grade;
          final sub = TextEditingController(text: app.currentUser!.subject);
          final title = TextEditingController(), det = TextEditingController();
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
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 80),
        itemCount: app.allHomeworks.length,
        itemBuilder: (_, i) {
          final h = app.allHomeworks[i];
          return Card(child: ListTile(title: Text('${h.subject} (${h.grade.shortLabel}) - ${h.title}'), subtitle: Text('${h.details}\nالتسليم: ${h.dueDate}')));
        },
      ),
    );
  }
}

class _TeacherGradesPage extends StatelessWidget {
  const _TeacherGradesPage();
  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final students = app.usersByRole(UserRole.student);
    return Scaffold(
      appBar: AppBar(title: const Text('تسجيل الدرجات')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          if (students.isEmpty) return;
          AppUser st = students.first;
          final sub = TextEditingController(text: app.currentUser!.subject);
          final sc = TextEditingController(text: '28'), mx = TextEditingController(text: '30');
          showDialog(
            context: context,
            builder: (ctx) => StatefulBuilder(
              builder: (ctx, setM) => AlertDialog(
                title: const Text('رصد درجة'),
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
                actions: [ElevatedButton(onPressed: () { app.addGrade(st, sub.text.trim(), 'اختبار شهري', double.tryParse(sc.text) ?? 0, double.tryParse(mx.text) ?? 30, 'أداء جيد'); Navigator.pop(ctx); }, child: const Text('حفظ'))],
              ),
            ),
          );
        },
        icon: const Icon(Icons.add_chart),
        label: const Text('تسجيل درجة'),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 80),
        itemCount: app.allGrades.length,
        itemBuilder: (_, i) {
          final g = app.allGrades[i];
          return Card(child: ListTile(title: Text('${g.studentName} • ${g.subject}'), subtitle: Text(g.examTitle), trailing: Chip(label: Text('${g.score}/${g.maxScore}'))));
        },
      ),
    );
  }
}

class _TeacherFilesPage extends StatelessWidget {
  const _TeacherFilesPage();
  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('الملفات والفصول')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          final t = TextEditingController(), u = TextEditingController(text: 'notes.pdf');
          showDialog(context: context, builder: (ctx) => AlertDialog(title: const Text('رفع ملف تعليمي'), content: Column(mainAxisSize: MainAxisSize.min, children: [TextField(controller: t, decoration: const InputDecoration(labelText: 'العنوان')), const SizedBox(height: 8), TextField(controller: u, decoration: const InputDecoration(labelText: 'اسم الملف / الرابط'))]), actions: [ElevatedButton(onPressed: () { if (t.text.trim().isNotEmpty) app.addFile(t.text.trim(), 'PDF', app.currentUser!.grade, app.currentUser!.subject, u.text.trim()); Navigator.pop(ctx); }, child: const Text('رفع'))]));
        },
        icon: const Icon(Icons.upload_file),
        label: const Text('رفع ملف'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 80),
        children: [
          const Text('الفصول', style: TextStyle(fontWeight: FontWeight.bold)),
          ...app.allClasses.map((c) => Card(child: ListTile(title: Text(c.name), subtitle: Text('الرائد: ${c.supervisorName}')))),
          const SizedBox(height: 10),
          const Text('الملفات التعليمية', style: TextStyle(fontWeight: FontWeight.bold)),
          ...app.allFiles.map((f) => Card(child: ListTile(leading: const Icon(Icons.picture_as_pdf, color: Colors.red), title: Text(f.title), subtitle: Text(f.urlOrName)))),
        ],
      ),
    );
  }
}

// ============================================================================
// 7. بوابة الطالب (Student Dashboard)
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
      ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _HeroBanner(title: st.name, subtitle: '${st.grade.label} • ${st.classroom}', badge: 'حساب الطالب الموثّق', colors: const [Color(0xFF0284C7), Color(0xFF1B365D)]),
          const SizedBox(height: 16),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 1.25,
            children: [
              _ServiceTile(title: 'الجدول والامتحانات', subtitle: 'حصص الأسبوع واللجان', icon: Icons.calendar_month_rounded, color: const Color(0xFF0284C7), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => _StudentScheduleExamsPage(grade: st.grade)))),
              _ServiceTile(title: 'الواجبات والملفات', subtitle: 'المهام ومذكرات PDF', icon: Icons.assignment_rounded, color: const Color(0xFF0D9488), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => _StudentHwFilesPage(student: st)))),
              _ServiceTile(title: 'الدرجات والنتائج', subtitle: 'كشف الدرجات والمعدل', icon: Icons.grade_rounded, color: const Color(0xFF10B981), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => _StudentResultsPage(student: st)))),
              _ServiceTile(title: 'الحضور والغياب', subtitle: 'سجل الحضور اليومي', icon: Icons.fact_check_rounded, color: const Color(0xFF6D28D9), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => _StudentAttendancePage(student: st)))),
            ],
          ),
        ],
      ),
      _SchoolFeedTab(user: st),
      const _AccountTab(),
    ];

    return Scaffold(
      appBar: _buildAppBar(context, 'الطالب • ${st.grade.shortLabel}'),
      body: pages[_tab],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_rounded), label: 'الرئيسية'),
          NavigationDestination(icon: Icon(Icons.campaign_rounded), label: 'الإعلانات'),
          NavigationDestination(icon: Icon(Icons.person_rounded), label: 'حسابي'),
        ],
      ),
    );
  }
}

class _StudentScheduleExamsPage extends StatelessWidget {
  final GradeLevel grade;
  const _StudentScheduleExamsPage({required this.grade});
  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final slots = app.allSchedule.where((s) => s.grade == grade).toList();
    final exams = app.allExams.where((e) => e.grade == grade).toList();
    return Scaffold(
      appBar: AppBar(title: Text('الجدول والامتحانات (${grade.shortLabel})')),
      body: ListView(
        padding: const EdgeInsets.all(14),
        children: [
          const Text('الجدول الدراسي', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          if (slots.isEmpty) const Card(child: Padding(padding: EdgeInsets.all(14), child: Text('لا توجد حصص مسجلة'))),
          ...slots.map((s) => Card(child: ListTile(title: Text('${s.day} - ${s.subject}'), subtitle: Text('${s.teacherName} • ${s.classroom}'), trailing: Text(s.timeRange)))),
          const SizedBox(height: 14),
          const Text('مواعيد الامتحانات', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ...exams.map((e) => Card(child: ListTile(leading: const Icon(Icons.event_note, color: Color(0xFF6D28D9)), title: Text('${e.subject} - ${e.title}'), subtitle: Text('${e.dateStr} • ${e.timeStr} • ${e.room}')))),
        ],
      ),
    );
  }
}

class _StudentHwFilesPage extends StatelessWidget {
  final AppUser student;
  const _StudentHwFilesPage({required this.student});
  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final hws = app.allHomeworks.where((h) => h.grade == student.grade).toList();
    final files = app.allFiles.where((f) => f.grade == student.grade).toList();
    return Scaffold(
      appBar: AppBar(title: const Text('الواجبات والملفات')),
      body: ListView(
        padding: const EdgeInsets.all(14),
        children: [
          const Text('الواجبات المطلوبة', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ...hws.map((h) {
            final done = h.completedStudentIds.contains(student.id);
            return Card(child: CheckboxListTile(value: done, onChanged: (_) => app.toggleHomeworkCompletion(h.id, student.id), title: Text('${h.subject}: ${h.title}'), subtitle: Text('${h.details} • التسليم: ${h.dueDate}')));
          }),
          const SizedBox(height: 14),
          const Text('الملفات التعليمية', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ...files.map((f) => Card(child: ListTile(leading: const Icon(Icons.picture_as_pdf, color: Colors.red), title: Text(f.title), subtitle: Text(f.urlOrName)))),
        ],
      ),
    );
  }
}

class _StudentResultsPage extends StatelessWidget {
  final AppUser student;
  const _StudentResultsPage({required this.student});
  @override
  Widget build(BuildContext context) {
    final list = AppScope.of(context).allGrades.where((g) => g.studentId == student.id).toList();
    return Scaffold(
      appBar: AppBar(title: const Text('الدرجات والنتائج')),
      body: list.isEmpty
          ? const Center(child: Text('لم تُرصد درجات لهذا الطالب بعد'))
          : ListView.builder(
              padding: const EdgeInsets.all(14),
              itemCount: list.length,
              itemBuilder: (_, i) {
                final g = list[i];
                return Card(child: ListTile(title: Text('${g.subject} (${g.examTitle})'), subtitle: Text(g.note), trailing: Chip(label: Text('${g.score}/${g.maxScore}'))));
              },
            ),
    );
  }
}

class _StudentAttendancePage extends StatelessWidget {
  final AppUser student;
  const _StudentAttendancePage({required this.student});
  @override
  Widget build(BuildContext context) {
    final status = AppScope.of(context).attendanceOf(student.id);
    return Scaffold(
      appBar: AppBar(title: const Text('سجل الحضور والغياب')),
      body: ListView(
        padding: const EdgeInsets.all(14),
        children: [
          Card(child: ListTile(leading: Icon(status.icon, color: status.color, size: 32), title: Text('حالة الحضور: ${student.name}'), trailing: Text(status.label, style: TextStyle(color: status.color, fontWeight: FontWeight.bold)))),
        ],
      ),
    );
  }
}

// ============================================================================
// 8. بوابة ولي الأمر (Parent Dashboard)
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
    final p = app.currentUser!;
    final kids = app.childrenOfParent(p.phone);
    final active = app.selectedParentChild;

    final pages = [
      ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _HeroBanner(title: p.name, subtitle: 'متابعة الأبناء والمصروفات والتواصل المباشر', badge: 'بوابة ولي الأمر', colors: const [Color(0xFF6D28D9), Color(0xFF1B365D)]),
          const SizedBox(height: 12),
          if (kids.isNotEmpty) ...[
            const Text('اختر الابن:', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Wrap(spacing: 8, children: kids.map((k) => ChoiceChip(label: Text('${k.name} (${k.grade.shortLabel})'), selected: k.id == active?.id, onSelected: (_) => app.selectParentChild(k.id))).toList()),
            const SizedBox(height: 14),
          ],
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 1.25,
            children: [
              _ServiceTile(title: 'النتائج والحضور', subtitle: 'متابعة مستوى الابن', icon: Icons.grade_rounded, color: const Color(0xFF10B981), onTap: () { if (active != null) Navigator.push(context, MaterialPageRoute(builder: (_) => _StudentResultsPage(student: active))); }),
              _ServiceTile(title: 'الواجبات والجدول', subtitle: 'مهام الابن اليومية', icon: Icons.assignment_rounded, color: const Color(0xFF0284C7), onTap: () { if (active != null) Navigator.push(context, MaterialPageRoute(builder: (_) => _StudentHwFilesPage(student: active))); }),
              _ServiceTile(title: 'المصروفات', subtitle: 'الفواتير والسداد', icon: Icons.payments_rounded, color: const Color(0xFFD97706), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => _ParentFeesPage(kids: kids)))),
              _ServiceTile(title: 'تواصل مع المدرسة', subtitle: 'إرسال استفسار أو شكوى', icon: Icons.chat_rounded, color: const Color(0xFF6D28D9), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const _ParentMessagesPage()))),
            ],
          ),
        ],
      ),
      _SchoolFeedTab(user: p),
      const _AccountTab(),
    ];

    return Scaffold(
      appBar: _buildAppBar(context, 'ولي الأمر • الرواد'),
      body: pages[_tab],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_rounded), label: 'الرئيسية'),
          NavigationDestination(icon: Icon(Icons.campaign_rounded), label: 'الإعلانات'),
          NavigationDestination(icon: Icon(Icons.person_rounded), label: 'حسابي'),
        ],
      ),
    );
  }
}

class _ParentFeesPage extends StatelessWidget {
  final List<AppUser> kids;
  const _ParentFeesPage({required this.kids});
  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final ids = kids.map((k) => k.id).toSet();
    final invoices = app.allInvoices.where((i) => ids.contains(i.studentId)).toList();
    return Scaffold(
      appBar: AppBar(title: const Text('متابعة المصروفات')),
      body: invoices.isEmpty
          ? const Center(child: Text('لا توجد فواتير مصروفات مستحقة'))
          : ListView.builder(
              padding: const EdgeInsets.all(14),
              itemCount: invoices.length,
              itemBuilder: (_, i) {
                final inv = invoices[i];
                return Card(child: ListTile(title: Text('${inv.studentName} - ${inv.title}'), subtitle: Text('المتبقي: ${inv.remaining.toStringAsFixed(0)} من ${inv.totalAmount.toStringAsFixed(0)} ج.م'), trailing: inv.isFullyPaid ? const Chip(label: Text('مسدد')) : ElevatedButton(onPressed: () => app.payInvoice(inv.id, inv.remaining), child: const Text('سداد'))));
              },
            ),
    );
  }
}

class _ParentMessagesPage extends StatelessWidget {
  const _ParentMessagesPage();
  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('التواصل مع المدرسة')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          final sub = TextEditingController(), body = TextEditingController();
          showDialog(context: context, builder: (ctx) => AlertDialog(title: const Text('رسالة جديدة للمدرسة'), content: Column(mainAxisSize: MainAxisSize.min, children: [TextField(controller: sub, decoration: const InputDecoration(labelText: 'الموضوع')), const SizedBox(height: 8), TextField(controller: body, maxLines: 3, decoration: const InputDecoration(labelText: 'الرسالة'))]), actions: [ElevatedButton(onPressed: () { if (sub.text.trim().isNotEmpty) app.sendMessage('إدارة المدرسة', sub.text.trim(), body.text.trim()); Navigator.pop(ctx); }, child: const Text('إرسال'))]));
        },
        icon: const Icon(Icons.send),
        label: const Text('رسالة جديدة'),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 80),
        itemCount: app.allMessages.length,
        itemBuilder: (_, i) {
          final m = app.allMessages[i];
          return Card(child: ListTile(title: Text(m.subject, style: const TextStyle(fontWeight: FontWeight.bold)), subtitle: Text('${m.body}\n${m.reply.isEmpty ? "بانتظار الرد" : "رد المدرسة: ${m.reply}"}')));
        },
      ),
    );
  }
}

class _SchoolFeedTab extends StatelessWidget {
  final AppUser user;
  const _SchoolFeedTab({required this.user});
  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text('إعلانات وأخبار المدرسة', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        ...app.allAnnouncements.map((a) => Card(child: ListTile(leading: const Icon(Icons.campaign_rounded, color: Color(0xFF1B365D)), title: Text(a.title, style: const TextStyle(fontWeight: FontWeight.bold)), subtitle: Text('${a.body}\n${a.dateLabel}')))),
      ],
    );
  }
}

class _MiniKpi extends StatelessWidget {
  final String title, value;
  final Color color;
  const _MiniKpi(this.title, this.value, this.color);
  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: Colors.grey.withAlpha(45))),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
        child: Column(
          children: [
            Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: color)),
            const SizedBox(height: 2),
            Text(title, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}
