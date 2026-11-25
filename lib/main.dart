import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:excel/excel.dart' as xl;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const String kSupabaseUrl = 'https://tdpaaqisqlxidhnxnqhe.supabase.co';
const String kSupabaseKey = 'sb_publishable_n6oQgZCImd1-X4Di-X3CfQ_jCNXc6lk';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(url: kSupabaseUrl, publishableKey: kSupabaseKey);
  runApp(const AlRowadPrivateSchoolApp());
}

// ============================================================================
// 1. النماذج والتصنيفات (Cloud Models)
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
  String name, phone, email, password, classroom, subject, linkedParentPhone;
  UserRole role;
  GradeLevel grade;
  bool isVerified, isApproved;

  AppUser({
    required this.id,
    required this.name,
    required this.phone,
    required this.email,
    required this.password,
    required this.role,
    this.grade = GradeLevel.p4,
    this.classroom = 'فصل 4/أ',
    this.subject = 'عام',
    this.linkedParentPhone = '',
    this.isVerified = false,
    this.isApproved = true,
  });

  factory AppUser.fromMap(Map<String, dynamic> m) => AppUser(
        id: m['id'] ?? '',
        name: m['name'] ?? '',
        phone: m['phone'] ?? '',
        email: m['email'] ?? '',
        password: m['password'] ?? '',
        role: UserRole.fromName(m['role']),
        grade: GradeLevel.fromName(m['grade']),
        classroom: m['classroom'] ?? '',
        subject: m['subject'] ?? 'عام',
        linkedParentPhone: m['linked_parent_phone'] ?? '',
        isVerified: m['is_verified'] == true,
        isApproved: m['is_approved'] != false,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'phone': phone,
        'email': email,
        'password': password,
        'role': role.name,
        'grade': grade.name,
        'classroom': classroom,
        'subject': subject,
        'linked_parent_phone': linkedParentPhone,
        'is_verified': isVerified,
        'is_approved': isApproved,
      };
}

class SchoolClass {
  final String id;
  String name, supervisorName;
  GradeLevel grade;
  int capacity;
  SchoolClass({required this.id, required this.name, required this.grade, required this.capacity, required this.supervisorName});
  factory SchoolClass.fromMap(Map<String, dynamic> m) => SchoolClass(id: m['id'], name: m['name'], grade: GradeLevel.fromName(m['grade']), capacity: m['capacity'] ?? 28, supervisorName: m['supervisor_name'] ?? '');
}

class SubjectItem {
  final String id;
  String name, teacherName;
  GradeLevel grade;
  SubjectItem({required this.id, required this.name, required this.grade, required this.teacherName});
  factory SubjectItem.fromMap(Map<String, dynamic> m) => SubjectItem(id: m['id'], name: m['name'], grade: GradeLevel.fromName(m['grade']), teacherName: m['teacher_name'] ?? '');
}

class ScheduleSlot {
  final String id, day, timeRange, subject, teacherName, classroom;
  GradeLevel grade;
  int period;
  ScheduleSlot({required this.id, required this.grade, required this.day, required this.period, required this.timeRange, required this.subject, required this.teacherName, required this.classroom});
  factory ScheduleSlot.fromMap(Map<String, dynamic> m) => ScheduleSlot(id: m['id'], grade: GradeLevel.fromName(m['grade']), day: m['day'], period: m['period'] ?? 1, timeRange: m['time_range'], subject: m['subject'], teacherName: m['teacher_name'] ?? '', classroom: m['classroom'] ?? '');
}

class ExamItem {
  final String id, title, subject, dateStr, timeStr, room;
  GradeLevel grade;
  ExamItem({required this.id, required this.title, required this.subject, required this.grade, required this.dateStr, required this.timeStr, required this.room});
  factory ExamItem.fromMap(Map<String, dynamic> m) => ExamItem(id: m['id'], title: m['title'], subject: m['subject'], grade: GradeLevel.fromName(m['grade']), dateStr: m['date_str'], timeStr: m['time_str'], room: m['room'] ?? '');
}

class AttendanceEntry {
  final String id, studentId, studentName, dateStr;
  GradeLevel grade;
  AttendanceStatus status;
  AttendanceEntry({required this.id, required this.studentId, required this.studentName, required this.grade, required this.dateStr, required this.status});
  factory AttendanceEntry.fromMap(Map<String, dynamic> m) => AttendanceEntry(id: m['id'], studentId: m['student_id'], studentName: m['student_name'], grade: GradeLevel.fromName(m['grade']), dateStr: m['date_str'], status: AttendanceStatus.fromName(m['status']));
}

class HomeworkItem {
  final String id, subject, title, details, dueDate, teacherName;
  GradeLevel grade;
  final Set<String> completedIds;
  HomeworkItem({required this.id, required this.grade, required this.subject, required this.title, required this.details, required this.dueDate, required this.teacherName, Set<String>? completedIds}) : completedIds = completedIds ?? {};
  factory HomeworkItem.fromMap(Map<String, dynamic> m) => HomeworkItem(id: m['id'], grade: GradeLevel.fromName(m['grade']), subject: m['subject'], title: m['title'], details: m['details'] ?? '', dueDate: m['due_date'], teacherName: m['teacher_name'] ?? '', completedIds: Set<String>.from(m['completed_ids'] ?? []));
}

class GradeEntry {
  final String id, studentId, studentName, subject, examTitle, note;
  GradeLevel grade;
  double score, maxScore;
  GradeEntry({required this.id, required this.studentId, required this.studentName, required this.grade, required this.subject, required this.examTitle, required this.score, required this.maxScore, required this.note});
  factory GradeEntry.fromMap(Map<String, dynamic> m) => GradeEntry(id: m['id'], studentId: m['student_id'], studentName: m['student_name'], grade: GradeLevel.fromName(m['grade']), subject: m['subject'], examTitle: m['exam_title'], score: (m['score'] as num).toDouble(), maxScore: (m['max_score'] as num).toDouble(), note: m['note'] ?? '');
}

class FeeInvoice {
  final String id, studentId, studentName, title, dueDate;
  GradeLevel grade;
  double totalAmount, paidAmount;
  FeeInvoice({required this.id, required this.studentId, required this.studentName, required this.grade, required this.title, required this.totalAmount, required this.paidAmount, required this.dueDate});
  double get remaining => (totalAmount - paidAmount).clamp(0, totalAmount);
  bool get isFullyPaid => remaining <= 0;
  factory FeeInvoice.fromMap(Map<String, dynamic> m) => FeeInvoice(id: m['id'], studentId: m['student_id'], studentName: m['student_name'], grade: GradeLevel.fromName(m['grade']), title: m['title'], totalAmount: (m['total_amount'] as num).toDouble(), paidAmount: (m['paid_amount'] as num).toDouble(), dueDate: m['due_date']);
}

class AnnouncementNews {
  final String id, title, body, category, author, dateLabel;
  UserRole? targetRole;
  bool isUrgent;
  AnnouncementNews({required this.id, required this.title, required this.body, required this.category, this.targetRole, required this.author, required this.dateLabel, this.isUrgent = false});
  factory AnnouncementNews.fromMap(Map<String, dynamic> m) => AnnouncementNews(id: m['id'], title: m['title'], body: m['body'], category: m['category'] ?? 'إعلان', targetRole: m['target_role'] == null ? null : UserRole.fromName(m['target_role']), author: m['author'] ?? 'الإدارة', dateLabel: m['date_label'] ?? 'اليوم', isUrgent: m['is_urgent'] == true);
}

class SchoolNotification {
  final String id, title, body, dateLabel;
  final NotificationType type;
  String? targetPhone;
  UserRole? targetRole;
  final Set<String> readBy;
  SchoolNotification({required this.id, required this.type, required this.title, required this.body, this.targetPhone, this.targetRole, required this.dateLabel, Set<String>? readBy}) : readBy = readBy ?? {};
  factory SchoolNotification.fromMap(Map<String, dynamic> m) => SchoolNotification(id: m['id'], type: NotificationType.fromName(m['type']), title: m['title'], body: m['body'], targetPhone: m['target_phone'], targetRole: m['target_role'] == null ? null : UserRole.fromName(m['target_role']), dateLabel: m['date_label'] ?? 'الآن', readBy: Set<String>.from(m['read_by'] ?? []));
}

class EducationalFile {
  final String id, title, fileType, subject, urlOrName, uploadedBy, dateLabel;
  GradeLevel grade;
  EducationalFile({required this.id, required this.title, required this.fileType, required this.grade, required this.subject, required this.urlOrName, required this.uploadedBy, required this.dateLabel});
  factory EducationalFile.fromMap(Map<String, dynamic> m) => EducationalFile(id: m['id'], title: m['title'], fileType: m['file_type'], grade: GradeLevel.fromName(m['grade']), subject: m['subject'], urlOrName: m['url_or_name'], uploadedBy: m['uploaded_by'] ?? '', dateLabel: m['date_label'] ?? 'اليوم');
}

class SchoolMessage {
  final String id, senderName, senderPhone, recipientLabel, subject, body, dateLabel;
  String reply;
  SchoolMessage({required this.id, required this.senderName, required this.senderPhone, required this.recipientLabel, required this.subject, required this.body, this.reply = '', required this.dateLabel});
  factory SchoolMessage.fromMap(Map<String, dynamic> m) => SchoolMessage(id: m['id'], senderName: m['sender_name'], senderPhone: m['sender_phone'], recipientLabel: m['recipient_label'], subject: m['subject'], body: m['body'], reply: m['reply'] ?? '', dateLabel: m['date_label'] ?? 'الآن');
}

// ============================================================================
// 2. إدارة الحالة السحابية (Supabase Cloud State + Real Verification)
// ============================================================================

class SchoolState extends ChangeNotifier {
  final _sb = Supabase.instance.client;
  final _prefs = SharedPreferencesAsync();
  static const _sessionKey = 'alrowad_session_uid';
  static const _themeKey = 'alrowad_dark_mode';

  bool _isInitialized = false;
  bool _isSyncing = false;
  String? _syncError;
  ThemeMode _themeMode = ThemeMode.light;
  String? _currentUserId;
  String _selectedParentChildId = '';

  bool get isInitialized => _isInitialized;
  bool get isSyncing => _isSyncing;
  String? get syncError => _syncError;
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
      _themeMode = (await _prefs.getBool(_themeKey) ?? false) ? ThemeMode.dark : ThemeMode.light;
      _currentUserId = await _prefs.getString(_sessionKey);
      await refreshAll();
    } catch (e) {
      _syncError = 'تعذر الاتصال بالسحابة: تأكد من الإنترنت';
    }
    _isInitialized = true;
    notifyListeners();
  }

  Future<void> refreshAll() async {
    _isSyncing = true;
    _syncError = null;
    notifyListeners();
    try {
      final res = await Future.wait([
        _sb.from('school_users').select().order('created_at', ascending: false),
        _sb.from('school_classes').select(),
        _sb.from('school_subjects').select(),
        _sb.from('school_schedule').select(),
        _sb.from('school_exams').select(),
        _sb.from('school_attendance').select(),
        _sb.from('school_homeworks').select(),
        _sb.from('school_grades').select(),
        _sb.from('school_invoices').select(),
        _sb.from('school_announcements').select(),
        _sb.from('school_notifications').select(),
        _sb.from('school_files').select(),
        _sb.from('school_messages').select(),
      ]);
      _users = (res[0] as List).map((e) => AppUser.fromMap(e)).toList();
      _classes = (res[1] as List).map((e) => SchoolClass.fromMap(e)).toList();
      _subjects = (res[2] as List).map((e) => SubjectItem.fromMap(e)).toList();
      _schedule = (res[3] as List).map((e) => ScheduleSlot.fromMap(e)).toList();
      _exams = (res[4] as List).map((e) => ExamItem.fromMap(e)).toList();
      _attendance = (res[5] as List).map((e) => AttendanceEntry.fromMap(e)).toList();
      _homeworks = (res[6] as List).map((e) => HomeworkItem.fromMap(e)).toList();
      _grades = (res[7] as List).map((e) => GradeEntry.fromMap(e)).toList();
      _invoices = (res[8] as List).map((e) => FeeInvoice.fromMap(e)).toList();
      _announcements = (res[9] as List).map((e) => AnnouncementNews.fromMap(e)).toList();
      _notifications = (res[10] as List).map((e) => SchoolNotification.fromMap(e)).toList();
      _files = (res[11] as List).map((e) => EducationalFile.fromMap(e)).toList();
      _messages = (res[12] as List).map((e) => SchoolMessage.fromMap(e)).toList();
      if (currentUser?.role == UserRole.parent) {
        final kids = childrenOfParent(currentUser!.phone);
        if (kids.isNotEmpty && _selectedParentChildId.isEmpty) _selectedParentChildId = kids.first.id;
      }
    } catch (e) {
      _syncError = 'فشل التحديث السحابي، تحقق من الاتصال بالإنترنت';
    }
    _isSyncing = false;
    notifyListeners();
  }

  Future<void> toggleTheme() async {
    _themeMode = _themeMode == ThemeMode.light ? ThemeMode.dark : ThemeMode.light;
    await _prefs.setBool(_themeKey, _themeMode == ThemeMode.dark);
    notifyListeners();
  }

  // المصادقة السحابية وتأكيد ملكية البريد (Anti-Hijack)
  Future<String?> login(String identifier, String password, {bool remember = true}) async {
    final idOrPhone = identifier.trim(), pass = password.trim();
    if (idOrPhone.isEmpty || pass.isEmpty) return 'يرجى إدخال رقم الهاتف (أو البريد) وكلمة المرور';
    try {
      final rows = await _sb.from('school_users').select().or('phone.eq.$idOrPhone,email.eq.$idOrPhone');
      if (rows.isEmpty) return 'لا يوجد حساب مسجل بهذه البيانات';
      final user = AppUser.fromMap(rows.first);
      if (user.password != pass) return 'كلمة المرور غير صحيحة';

      // إذا كان الحساب غير مؤكد على السيرفر، نرسل رابط التأكيد لبريده الحقيقي
      if (!user.isVerified && user.email.contains('@') && !user.email.endsWith('.local')) {
        await _sendVerificationEmail(user);
      }

      _currentUserId = user.id;
      if (remember) await _prefs.setString(_sessionKey, user.id);
      await refreshAll();
      return null;
    } catch (e) {
      return 'حدث خطأ أثناء الاتصال بالسيرفر، تأكد من الإنترنت';
    }
  }

  Future<void> _sendVerificationEmail(AppUser user) async {
    try {
      await _sb.auth.signUp(email: user.email, password: user.password);
    } catch (_) {
      try {
        await _sb.auth.resend(type: OtpType.signup, email: user.email);
      } catch (_) {}
    }
  }

  Future<String?> registerSelf({
    required String name,
    required String phone,
    required String email,
    required String password,
    required UserRole role,
    required GradeLevel grade,
    String linkedParentPhone = '',
  }) async {
    final p = phone.trim(), em = email.trim().toLowerCase(), pass = password.trim();
    if (name.trim().isEmpty || p.length < 8 || !em.contains('@') || pass.length < 6) {
      return 'تأكد من الاسم ورقم الهاتف والبريد الإلكتروني الصحيح وكلمة مرور 6 أحرف فأكثر';
    }
    try {
      final existing = await _sb.from('school_users').select().or('phone.eq.$p,email.eq.$em');
      if (existing.isNotEmpty) return 'رقم الهاتف أو البريد الإلكتروني مسجل مسبقاً';

      // إرسال رسالة التأكيد الحقيقية من Supabase Auth لبريد المستخدم
      await _sb.auth.signUp(email: em, password: pass);

      final user = AppUser(
        id: 'u_${DateTime.now().microsecondsSinceEpoch}',
        name: name.trim(),
        phone: p,
        email: em,
        password: pass,
        role: role,
        grade: grade,
        classroom: 'فصل ${grade.shortLabel}',
        linkedParentPhone: linkedParentPhone.trim(),
        isVerified: false,
        isApproved: false,
      );
      await _sb.from('school_users').insert(user.toMap());
      _currentUserId = user.id;
      await _prefs.setString(_sessionKey, user.id);
      await refreshAll();
      return null;
    } on AuthException catch (e) {
      return 'تنبيه من نظام التحقق: ${e.message}';
    } catch (_) {
      return 'تعذر إنشاء الحساب، تأكد من اتصال الإنترنت';
    }
  }

  Future<String?> resendVerificationForCurrent() async {
    final u = currentUser;
    if (u == null) return 'لا توجد جلسة';
    try {
      await _sendVerificationEmail(u);
      return null;
    } catch (e) {
      return 'يرجى الانتظار قليلاً قبل إعادة الإرسال';
    }
  }

  Future<String?> confirmEmailVerifiedOnServer() async {
    final u = currentUser;
    if (u == null) return 'لا توجد جلسة';
    try {
      final res = await _sb.auth.signInWithPassword(email: u.email, password: u.password);
      if (res.user?.emailConfirmedAt == null) {
        return 'لم يتم الضغط على رابط التأكيد في بريدك بعد!';
      }
      await _sb.from('school_users').update({'is_verified': true}).eq('id', u.id);
      await refreshAll();
      return null;
    } on AuthException catch (e) {
      if (e.message.toLowerCase().contains('not confirmed')) {
        return 'البريد غير مؤكد بعد! افتح رسالة Gmail واضغط على رابط Confirm your mail أولاً.';
      }
      return e.message;
    } catch (_) {
      return 'تعذر التحقق من السيرفر، تأكد من الإنترنت';
    }
  }

  Future<String?> requestPasswordReset(String phoneOrEmail) async {
    final q = phoneOrEmail.trim();
    if (q.isEmpty) return 'أدخل رقم الهاتف أو البريد الإلكتروني';
    try {
      final rows = await _sb.from('school_users').select().or('phone.eq.$q,email.eq.$q');
      if (rows.isEmpty) return 'لا يوجد حساب مطابق لهذه البيانات';
      final user = AppUser.fromMap(rows.first);
      if (user.email.endsWith('.local') || !user.email.contains('@')) {
        return 'هذا الحساب لا يملك بريداً حقيقياً، تواصل مع مدير المدرسة لإعادة تعيين كلمة المرور.';
      }
      await _sb.auth.resetPasswordForEmail(user.email);
      return null;
    } catch (_) {
      return 'تعذر إرسال رابط الاستعادة، حاول بعد دقيقة';
    }
  }

  Future<String?> changeCurrentUserPassword(String oldPass, String newPass) async {
    final u = currentUser;
    if (u == null) return 'غير مسجل';
    if (u.password != oldPass.trim()) return 'كلمة المرور الحالية غير صحيحة';
    if (newPass.trim().length < 6) return 'كلمة المرور الجديدة يجب أن تكون 6 أحرف على الأقل';
    try {
      await _sb.from('school_users').update({'password': newPass.trim()}).eq('id', u.id);
      try {
        await _sb.auth.updateUser(UserAttributes(password: newPass.trim()));
      } catch (_) {}
      await refreshAll();
      return null;
    } catch (_) {
      return 'تعذر تحديث كلمة المرور على السيرفر';
    }
  }

  Future<void> logout() async {
    _currentUserId = null;
    await _prefs.remove(_sessionKey);
    try {
      await _sb.auth.signOut();
    } catch (_) {}
    notifyListeners();
  }

  // استعلامات القوائم
  List<AppUser> get allUsers => List.unmodifiable(_users);
  List<AppUser> usersByRole(UserRole r) => _users.where((u) => u.role == r).toList();
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
      _users.where((u) => u.role == UserRole.student && u.linked_parent_phone_match(parentPhone)).toList();

  AppUser? get selectedParentChild {
    final u = currentUser;
    if (u == null) return null;
    final kids = childrenOfParent(u.phone);
    if (kids.isEmpty) return null;
    return kids.firstWhere((k) => k.id == _selectedParentChildId, orElse: () => kids.first);
  }

  void selectParentChild(String id) {
    _selectedParentChildId = id;
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

  int get unreadNotificationsCount {
    final uid = currentUser?.id;
    if (uid == null) return 0;
    return notificationsForCurrentUser().where((n) => !n.readBy.contains(uid)).length;
  }

  Future<void> markNotificationsRead() async {
    final uid = currentUser?.id;
    if (uid == null) return;
    for (final n in notificationsForCurrentUser()) {
      if (!n.readBy.contains(uid)) {
        n.readBy.add(uid);
        await _sb.from('school_notifications').update({'read_by': n.readBy.toList()}).eq('id', n.id);
      }
    }
    notifyListeners();
  }

  // عمليات الإدارة السحابية + الإكسيل
  Future<String?> addUserByAdmin({
    required String name,
    required String phone,
    required String email,
    required String password,
    required UserRole role,
    GradeLevel grade = GradeLevel.p4,
    String subject = 'عام',
    String linkedParentPhone = '',
  }) async {
    final p = phone.trim(), em = email.trim().toLowerCase(), pass = password.trim();
    if (name.trim().isEmpty || p.isEmpty || !em.contains('@') || pass.length < 6) {
      return 'تأكد من الاسم ورقم الهاتف والبريد الإلكتروني وكلمة المرور (6 أحرف+)';
    }
    if (_users.any((u) => u.phone == p || u.email == em)) return 'رقم الهاتف أو البريد مسجل بالفعل';
    try {
      final user = AppUser(
        id: 'u_${DateTime.now().microsecondsSinceEpoch}',
        name: name.trim(),
        phone: p,
        email: em,
        password: pass,
        role: role,
        grade: grade,
        classroom: 'فصل ${grade.shortLabel}',
        subject: subject.trim().isEmpty ? 'عام' : subject.trim(),
        linkedParentPhone: linkedParentPhone.trim(),
        isVerified: false, // يؤكد المستخدم بريده في أول تسجيل دخول
        isApproved: true,
      );
      await _sb.from('school_users').insert(user.toMap());
      await refreshAll();
      return null;
    } catch (_) {
      return 'فشل الحفظ على السيرفر';
    }
  }

  Future<void> approveAndVerifyUser(String userId) async {
    await _sb.from('school_users').update({'is_verified': true, 'is_approved': true}).eq('id', userId);
    await refreshAll();
  }

  Future<void> resetUserPasswordByAdmin(String userId, String newPass) async {
    await _sb.from('school_users').update({'password': newPass.trim()}).eq('id', userId);
    await refreshAll();
  }

  Future<void> deleteUser(String id) async {
    if (_currentUserId == id) return;
    await _sb.from('school_users').delete().eq('id', id);
    await refreshAll();
  }

  String _cellText(xl.CellValue? val) {
    if (val == null) return '';
    if (val is xl.TextCellValue) return val.value.text ?? val.value.toString();
    if (val is xl.IntCellValue) return val.value.toString();
    if (val is xl.DoubleCellValue) {
      final d = val.value;
      return d == d.roundToDouble() ? d.toInt().toString() : d.toString();
    }
    return val.toString();
  }

  UserRole _parseRole(String raw) {
    final r = raw.trim().toLowerCase();
    if (r.contains('معلم') || r.contains('teacher')) return UserRole.teacher;
    if (r.contains('ولي') || r.contains('parent')) return UserRole.parent;
    if (r.contains('مدير') || r.contains('admin')) return UserRole.admin;
    return UserRole.student;
  }

  // الأعمدة: الاسم | الصفة | الهاتف | البريد | كلمة المرور | الصف | هاتف ولي الأمر أو المادة
  Future<({int added, int skipped, String message})> importRows(List<List<String>> rows) async {
    int added = 0, skipped = 0;
    for (int i = 0; i < rows.length; i++) {
      final c = rows[i].map((e) => e.trim()).toList();
      if (c.length < 5) continue;
      if (i == 0 && (c[0].contains('الاسم') || c[2].contains('الهاتف'))) continue;
      final err = await addUserByAdmin(
        name: c[0],
        role: _parseRole(c[1]),
        phone: c[2],
        email: c[3],
        password: c[4],
        grade: c.length > 5 && c[5].isNotEmpty ? GradeLevel.parseGrade(c[5]) : GradeLevel.p4,
        subject: c.length > 6 && c[6].isNotEmpty ? c[6] : 'عام',
        linkedParentPhone: c.length > 6 ? c[6] : '',
      );
      if (err == null) {
        added++;
      } else {
        skipped++;
      }
    }
    return (added: added, skipped: skipped, message: 'تمت المعالجة السحابية');
  }

  Future<({int added, int skipped, String message})> importExcelOrCsvBytes(Uint8List bytes, String fileName) async {
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
      return await importRows(rows);
    } catch (_) {
      return (added: 0, skipped: 0, message: 'تعذر قراءة الملف (.xlsx / .csv)');
    }
  }

  Future<({int added, int skipped, String message})> importDelimitedText(String text) async {
    final lines = text.split(RegExp(r'\r?\n')).where((l) => l.trim().isNotEmpty).toList();
    final rows = lines.map((l) => l.contains('\t') ? l.split('\t') : (l.contains(';') ? l.split(';') : l.split(','))).toList();
    return await importRows(rows);
  }

  // العمليات السحابية للمدرسة
  Future<void> addClass(String name, GradeLevel g, int cap, String sup) async {
    await _sb.from('school_classes').insert({'id': 'c_${DateTime.now().microsecondsSinceEpoch}', 'name': name, 'grade': g.name, 'capacity': cap, 'supervisor_name': sup});
    await refreshAll();
  }

  Future<void> deleteClass(String id) async {
    await _sb.from('school_classes').delete().eq('id', id);
    await refreshAll();
  }

  Future<void> addSubject(String name, GradeLevel g, String teacher) async {
    await _sb.from('school_subjects').insert({'id': 'sb_${DateTime.now().microsecondsSinceEpoch}', 'name': name, 'grade': g.name, 'teacher_name': teacher});
    await refreshAll();
  }

  Future<void> deleteSubject(String id) async {
    await _sb.from('school_subjects').delete().eq('id', id);
    await refreshAll();
  }

  Future<void> addScheduleSlot(GradeLevel g, String day, int period, String time, String sub, String teacher, String room) async {
    await _sb.from('school_schedule').insert({'id': 'sc_${DateTime.now().microsecondsSinceEpoch}', 'grade': g.name, 'day': day, 'period': period, 'time_range': time, 'subject': sub, 'teacher_name': teacher, 'classroom': room});
    await refreshAll();
  }

  Future<void> deleteScheduleSlot(String id) async {
    await _sb.from('school_schedule').delete().eq('id', id);
    await refreshAll();
  }

  Future<void> addExam(String title, String sub, GradeLevel g, String dateStr, String timeStr, String room) async {
    await _sb.from('school_exams').insert({'id': 'ex_${DateTime.now().microsecondsSinceEpoch}', 'title': title, 'subject': sub, 'grade': g.name, 'date_str': dateStr, 'time_str': timeStr, 'room': room});
    await _pushNotif(NotificationType.exam, 'موعد امتحان: $sub', '$title (${g.shortLabel}) يوم $dateStr');
  }

  Future<void> deleteExam(String id) async {
    await _sb.from('school_exams').delete().eq('id', id);
    await refreshAll();
  }

  AttendanceStatus attendanceOf(String studentId) {
    final m = _attendance.where((a) => a.studentId == studentId).toList();
    return m.isEmpty ? AttendanceStatus.present : m.first.status;
  }

  Future<void> recordAttendance(AppUser st, AttendanceStatus status) async {
    final today = DateTime.now().toIso8601String().substring(0, 10);
    final existing = _attendance.where((a) => a.studentId == st.id && a.dateStr == today).toList();
    if (existing.isNotEmpty) {
      await _sb.from('school_attendance').update({'status': status.name}).eq('id', existing.first.id);
    } else {
      await _sb.from('school_attendance').insert({'id': 'att_${DateTime.now().microsecondsSinceEpoch}', 'student_id': st.id, 'student_name': st.name, 'grade': st.grade.name, 'date_str': today, 'status': status.name});
    }
    if (status == AttendanceStatus.absent) {
      await _pushNotif(NotificationType.absence, 'تنبيه غياب طالب', 'تم تسجيل (${st.name}) غائباً بتاريخ $today.', targetPhone: st.linkedParentPhone.isNotEmpty ? st.linkedParentPhone : null, targetRole: UserRole.parent);
    } else {
      await refreshAll();
    }
  }

  Future<void> addHomework(GradeLevel g, String sub, String title, String details, String due) async {
    await _sb.from('school_homeworks').insert({'id': 'hw_${DateTime.now().microsecondsSinceEpoch}', 'grade': g.name, 'subject': sub, 'title': title, 'details': details, 'due_date': due, 'teacher_name': currentUser?.name ?? 'المعلم', 'completed_ids': []});
    await _pushNotif(NotificationType.homework, 'واجب جديد: $sub', '$title (${g.shortLabel}) - التسليم: $due');
  }

  Future<void> toggleHomeworkCompletion(HomeworkItem hw, String studentId) async {
    final updated = Set<String>.from(hw.completedIds);
    if (updated.contains(studentId)) {
      updated.remove(studentId);
    } else {
      updated.add(studentId);
    }
    await _sb.from('school_homeworks').update({'completed_ids': updated.toList()}).eq('id', hw.id);
    await refreshAll();
  }

  Future<void> addGrade(AppUser st, String sub, String exam, double score, double maxScore, String note) async {
    await _sb.from('school_grades').insert({'id': 'gr_${DateTime.now().microsecondsSinceEpoch}', 'student_id': st.id, 'student_name': st.name, 'grade': st.grade.name, 'subject': sub, 'exam_title': exam, 'score': score, 'max_score': maxScore, 'note': note});
    await _pushNotif(NotificationType.result, 'نتيجة جديدة: $sub', 'حصل ${st.name} على $score / $maxScore في $exam.', targetPhone: st.linkedParentPhone.isNotEmpty ? st.linkedParentPhone : null);
  }

  Future<void> addInvoice(AppUser st, String title, double total, double paid, String due) async {
    await _sb.from('school_invoices').insert({'id': 'inv_${DateTime.now().microsecondsSinceEpoch}', 'student_id': st.id, 'student_name': st.name, 'grade': st.grade.name, 'title': title, 'total_amount': total, 'paid_amount': paid, 'due_date': due});
    if (total > paid) {
      await _pushNotif(NotificationType.fees, 'تنبيه مصروفات', 'فاتورة ($title) للطالب ${st.name} متبقي ${(total - paid).toStringAsFixed(0)} ج.م.', targetPhone: st.linkedParentPhone.isNotEmpty ? st.linkedParentPhone : null, targetRole: UserRole.parent);
    } else {
      await refreshAll();
    }
  }

  Future<void> payInvoice(FeeInvoice inv, double amount) async {
    final newPaid = (inv.paidAmount + amount).clamp(0, inv.totalAmount);
    await _sb.from('school_invoices').update({'paid_amount': newPaid}).eq('id', inv.id);
    await _pushNotif(NotificationType.fees, 'تأكيد سداد مصروفات', 'تم سداد ${amount.toStringAsFixed(0)} ج.م لفاتورة (${inv.title}).');
  }

  Future<void> addAnnouncement(String title, String body, String cat, UserRole? target, bool urgent) async {
    await _sb.from('school_announcements').insert({'id': 'an_${DateTime.now().microsecondsSinceEpoch}', 'title': title, 'body': body, 'category': cat, 'target_role': target?.name, 'author': currentUser?.name ?? 'الإدارة', 'date_label': 'الآن', 'is_urgent': urgent});
    await _pushNotif(NotificationType.announcement, '$cat: $title', body, targetRole: target);
  }

  Future<void> sendCustomNotif(NotificationType type, String title, String body, UserRole? target) => _pushNotif(type, title, body, targetRole: target);

  Future<void> _pushNotif(NotificationType type, String title, String body, {String? targetPhone, UserRole? targetRole}) async {
    await _sb.from('school_notifications').insert({'id': 'n_${DateTime.now().microsecondsSinceEpoch}', 'type': type.name, 'title': title, 'body': body, 'target_phone': targetPhone, 'target_role': targetRole?.name, 'date_label': 'الآن', 'read_by': []});
    await refreshAll();
  }

  Future<void> addFile(String title, String type, GradeLevel g, String sub, String url) async {
    await _sb.from('school_files').insert({'id': 'f_${DateTime.now().microsecondsSinceEpoch}', 'title': title, 'file_type': type, 'grade': g.name, 'subject': sub, 'url_or_name': url, 'uploaded_by': currentUser?.name ?? 'المعلم', 'date_label': 'اليوم'});
    await refreshAll();
  }

  Future<void> sendMessage(String rec, String sub, String body) async {
    final u = currentUser;
    if (u == null) return;
    await _sb.from('school_messages').insert({'id': 'm_${DateTime.now().microsecondsSinceEpoch}', 'sender_name': u.name, 'sender_phone': u.phone, 'recipient_label': rec, 'subject': sub, 'body': body, 'reply': '', 'date_label': 'الآن'});
    await refreshAll();
  }

  Future<void> replyMessage(String id, String reply) async {
    await _sb.from('school_messages').update({'reply': reply}).eq('id', id);
    await refreshAll();
  }
}

extension on AppUser {
  bool linked_parent_phone_match(String parentPhone) => linkedParentPhone.trim() == parentPhone.trim();
}

class AppScope extends InheritedNotifier<SchoolState> {
  const AppScope({super.key, required SchoolState state, required super.child}) : super(notifier: state);
  static SchoolState of(BuildContext context) => context.dependOnInheritedWidgetOfExactType<AppScope>()!.notifier!;
}

// ============================================================================
// 3. التطبيق وبوابات الدخول والتحقق الحقيقي من السيرفر (Auth & Verification)
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
            theme: ThemeData(useMaterial3: true, colorScheme: light, scaffoldBackgroundColor: const Color(0xFFF5F7FA), appBarTheme: const AppBarTheme(centerTitle: true, elevation: 0, backgroundColor: Color(0xFF1B365D), foregroundColor: Colors.white), inputDecorationTheme: InputDecorationTheme(filled: true, fillColor: Colors.white, border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFE2E8F0))), enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFE2E8F0))))),
            darkTheme: ThemeData(useMaterial3: true, colorScheme: dark, scaffoldBackgroundColor: const Color(0xFF0B1120), appBarTheme: const AppBarTheme(centerTitle: true, elevation: 0, backgroundColor: Color(0xFF111827), foregroundColor: Colors.white), inputDecorationTheme: InputDecorationTheme(filled: true, fillColor: const Color(0xFF1E293B), border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)))),
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
    if (!user.isVerified) return const EmailVerificationScreen();
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
        color: Colors.white,
        border: Border.all(color: const Color(0xFFF59E0B), width: 2),
        boxShadow: [BoxShadow(color: const Color(0xFF1B365D).withAlpha(55), blurRadius: 14, offset: const Offset(0, 6))],
      ),
      child: ClipOval(
        child: Image.asset(
          'assets/logo.png',
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => Icon(Icons.school_rounded, size: size * 0.55, color: const Color(0xFF1B365D)),
        ),
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
            AlRowadLogo(size: 112),
            SizedBox(height: 20),
            Text('مدرسة الرواد الخاصة', style: TextStyle(fontSize: 27, fontWeight: FontWeight.w900, color: Colors.white)),
            Text('متصل بالسحابة ☁️', style: TextStyle(fontSize: 13.5, color: Color(0xFFFEF08A), fontWeight: FontWeight.w600)),
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
  bool _obscure = true, _remember = true, _loading = false;
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
    final err = await AppScope.of(context).login(_phoneCtrl.text, _passCtrl.text, remember: _remember);
    if (!mounted) return;
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
                Align(alignment: Alignment.centerLeft, child: IconButton(icon: Icon(app.themeMode == ThemeMode.dark ? Icons.light_mode : Icons.dark_mode), onPressed: app.toggleTheme)),
                const Center(child: AlRowadLogo(size: 96)),
                const SizedBox(height: 16),
                const Text('مدرسة الرواد الخاصة', textAlign: TextAlign.center, style: TextStyle(fontSize: 25, fontWeight: FontWeight.w900)),
                Text('Al Rowad Private School', textAlign: TextAlign.center, style: TextStyle(fontSize: 13.5, color: Theme.of(context).hintColor, fontWeight: FontWeight.w600)),
                const SizedBox(height: 26),
                Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22), side: BorderSide(color: Colors.grey.withAlpha(45))),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('تسجيل الدخول السحابي', style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 16),
                        TextField(controller: _phoneCtrl, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'رقم الهاتف أو البريد الإلكتروني', prefixIcon: Icon(Icons.phone_android_rounded))),
                        const SizedBox(height: 14),
                        TextField(controller: _passCtrl, obscureText: _obscure, decoration: InputDecoration(labelText: 'كلمة المرور', prefixIcon: const Icon(Icons.lock_outline_rounded), suffixIcon: IconButton(icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility), onPressed: () => setState(() => _obscure = !_obscure)))),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(children: [Checkbox(value: _remember, onChanged: (v) => setState(() => _remember = v ?? true)), const Text('تذكرني', style: TextStyle(fontSize: 13))]),
                            TextButton(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ForgotPasswordScreen())), child: const Text('نسيت كلمة المرور؟')),
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
                            label: Text(_loading ? 'جاري الاتصال...' : 'تسجيل الدخول', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('مستخدم جديد؟'),
                    TextButton(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RegisterScreen())), child: const Text('تسجيل حساب وتأكيد البريد', style: TextStyle(fontWeight: FontWeight.bold))),
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
  final _nameCtrl = TextEditingController(), _phoneCtrl = TextEditingController(), _emailCtrl = TextEditingController(), _passCtrl = TextEditingController(), _parentPhoneCtrl = TextEditingController();
  bool _loading = false;
  String? _err;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
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
          SegmentedButton<UserRole>(
            segments: const [ButtonSegment(value: UserRole.student, icon: Icon(Icons.school), label: Text('طالب')), ButtonSegment(value: UserRole.parent, icon: Icon(Icons.family_restroom), label: Text('ولي أمر'))],
            selected: {_role},
            onSelectionChanged: (s) => setState(() => _role = s.first),
          ),
          const SizedBox(height: 14),
          TextField(controller: _nameCtrl, decoration: const InputDecoration(labelText: 'الاسم الكامل')),
          const SizedBox(height: 10),
          TextField(controller: _phoneCtrl, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'رقم الهاتف')),
          const SizedBox(height: 10),
          TextField(controller: _emailCtrl, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'البريد الإلكتروني الحقيقي (Gmail لتأكيد الحساب)')),
          const SizedBox(height: 10),
          TextField(controller: _passCtrl, obscureText: true, decoration: const InputDecoration(labelText: 'كلمة المرور (6 أحرف فأكثر)')),
          if (_role == UserRole.student) ...[
            const SizedBox(height: 10),
            DropdownButtonFormField<GradeLevel>(value: _grade, decoration: const InputDecoration(labelText: 'الصف الدراسي'), items: GradeLevel.values.map((g) => DropdownMenuItem(value: g, child: Text(g.label))).toList(), onChanged: (v) { if (v != null) setState(() => _grade = v); }),
            const SizedBox(height: 10),
            TextField(controller: _parentPhoneCtrl, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'هاتف ولي الأمر (اختياري للربط)')),
          ],
          if (_err != null) ...[const SizedBox(height: 10), Text(_err!, style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold))],
          const SizedBox(height: 18),
          SizedBox(
            height: 50,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1B365D), foregroundColor: Colors.white),
              onPressed: _loading
                  ? null
                  : () async {
                      setState(() {
                        _loading = true;
                        _err = null;
                      });
                      final err = await AppScope.of(context).registerSelf(name: _nameCtrl.text, phone: _phoneCtrl.text, email: _emailCtrl.text, password: _passCtrl.text, role: _role, grade: _grade, linkedParentPhone: _parentPhoneCtrl.text);
                      if (!context.mounted) return;
                      if (err != null) {
                        setState(() {
                          _loading = false;
                          _err = err;
                        });
                      } else {
                        Navigator.pop(context);
                      }
                    },
              child: Text(_loading ? 'جاري إرسال رابط التأكيد...' : 'تسجيل وإرسال تأكيد البريد'),
            ),
          ),
        ],
      ),
    );
  }
}

class EmailVerificationScreen extends StatefulWidget {
  const EmailVerificationScreen({super.key});
  @override
  State<EmailVerificationScreen> createState() => _EmailVerificationScreenState();
}

class _EmailVerificationScreenState extends State<EmailVerificationScreen> {
  bool _checking = false;
  String? _err;

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final u = app.currentUser!;
    return Scaffold(
      appBar: AppBar(title: const Text('تأكيد ملكية البريد'), actions: [IconButton(icon: const Icon(Icons.logout_rounded), onPressed: app.logout)]),
      body: ListView(
        padding: const EdgeInsets.all(22),
        children: [
          const Icon(Icons.mark_email_read_rounded, size: 78, color: Color(0xFF0D9488)),
          const SizedBox(height: 14),
          Text('مرحباً ${u.name}', textAlign: TextAlign.center, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text('تم إرسال رسالة تأكيد حقيقية من السيرفر إلى بريدك:\n${u.email}', textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Text(
                '1. افتح تطبيق Gmail على هاتفك.\n2. افتح الرسالة واضغط على رابط Confirm your mail.\n3. إذا ظهرت صفحة المتصفح بعد الضغط، ارجع هنا واضغط الزر الأخضر بالأسفل.',
                style: TextStyle(height: 1.6, color: Theme.of(context).hintColor),
              ),
            ),
          ),
          if (_err != null) ...[const SizedBox(height: 10), Text(_err!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold))],
          const SizedBox(height: 18),
          SizedBox(
            height: 52,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981), foregroundColor: Colors.white),
              onPressed: _checking
                  ? null
                  : () async {
                      setState(() {
                        _checking = true;
                        _err = null;
                      });
                      final err = await app.confirmEmailVerifiedOnServer();
                      if (!mounted) return;
                      setState(() {
                        _checking = false;
                        _err = err;
                      });
                    },
              icon: _checking ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.verified_rounded),
              label: Text(_checking ? 'جاري التحقق من السيرفر...' : 'تم الضغط على الرابط — تفعيل الدخول ✓'),
            ),
          ),
          TextButton(
            onPressed: () async {
              final err = await app.resendVerificationForCurrent();
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err ?? 'تم إعادة إرسال رسالة التأكيد لبريدك')));
            },
            child: const Text('إعادة إرسال رسالة التأكيد'),
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
    return Scaffold(
      appBar: AppBar(title: const Text('اعتماد الإدارة'), actions: [IconButton(icon: const Icon(Icons.refresh), onPressed: app.refreshAll), IconButton(icon: const Icon(Icons.logout_rounded), onPressed: app.logout)]),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.hourglass_top_rounded, size: 78, color: Color(0xFFD97706)),
              const SizedBox(height: 14),
              const Text('تم تأكيد بريدك بنجاح ✓', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text('حسابك الآن بانتظار موافقة مدير المدرسة لتفعيل الصلاحيات.', textAlign: TextAlign.center, style: TextStyle(color: Theme.of(context).hintColor)),
              const SizedBox(height: 18),
              ElevatedButton.icon(onPressed: app.refreshAll, icon: const Icon(Icons.refresh), label: const Text('تحديث الحالة الآن')),
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
  final _ctrl = TextEditingController();
  bool _sent = false;
  String? _err;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('استعادة كلمة المرور')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          TextField(controller: _ctrl, decoration: const InputDecoration(labelText: 'رقم الهاتف أو البريد المسجل')),
          const SizedBox(height: 14),
          ElevatedButton(
            onPressed: () async {
              final err = await AppScope.of(context).requestPasswordReset(_ctrl.text);
              if (!mounted) return;
              setState(() {
                _err = err;
                _sent = err == null;
              });
            },
            child: const Text('إرسال رابط الاستعادة لبريدك'),
          ),
          if (_sent) const Padding(padding: EdgeInsets.only(top: 12), child: Text('تم إرسال رابط استعادة كلمة المرور إلى بريدك الإلكتروني بنجاح ✓', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold))),
          if (_err != null) Padding(padding: EdgeInsets.only(top: 12), child: Text(_err!, style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold))),
        ],
      ),
    );
  }
}
// ============================================================================
// 4. مكونات التصميم المشتركة والتحديث السحابي (Cloud UI & Account Tab)
// ============================================================================

PreferredSizeWidget _buildAppBar(BuildContext context, String title) {
  final app = AppScope.of(context);
  final unread = app.unreadNotificationsCount;
  return AppBar(
    title: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(child: Text(title, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17.5))),
        if (app.isSyncing) ...[
          const SizedBox(width: 8),
          const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
        ],
      ],
    ),
    actions: [
      IconButton(
        tooltip: 'تحديث السحابة',
        icon: const Icon(Icons.sync_rounded),
        onPressed: app.refreshAll,
      ),
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
          const Padding(padding: EdgeInsets.all(14), child: Text('مركز الإشعارات السحابي', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
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
            onPressed: () async {
              final err = await AppScope.of(context).changeCurrentUserPassword(oldCtrl.text, newCtrl.text);
              if (!context.mounted) return;
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err ?? 'تم تحديث كلمة المرور على السحابة بنجاح')));
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
    return RefreshIndicator(
      onRefresh: app.refreshAll,
      child: ListView(
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
                        child: const Row(children: [Icon(Icons.verified_rounded, size: 14, color: Color(0xFF10B981)), SizedBox(width: 3), Text('موثّق سحابياً', style: TextStyle(fontSize: 11.5, color: Color(0xFF10B981), fontWeight: FontWeight.bold))]),
                      ),
                    ],
                  ),
                  const Divider(height: 24),
                  ListTile(dense: true, leading: const Icon(Icons.phone_android), title: const Text('رقم الهاتف'), trailing: Text(u.phone, style: const TextStyle(fontWeight: FontWeight.bold))),
                  ListTile(dense: true, leading: const Icon(Icons.email_outlined), title: const Text('البريد الإلكتروني'), trailing: Text(u.email, style: const TextStyle(fontSize: 12))),
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
                ListTile(leading: const Icon(Icons.sync_rounded), title: const Text('مزامنة البيانات من السيرفر'), onTap: app.refreshAll),
                const Divider(height: 1),
                SwitchListTile(secondary: const Icon(Icons.dark_mode_rounded), title: const Text('الوضع الليلي'), value: app.themeMode == ThemeMode.dark, onChanged: (_) => app.toggleTheme()),
                const Divider(height: 1),
                ListTile(leading: const Icon(Icons.logout_rounded, color: Colors.red), title: const Text('تسجيل الخروج', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)), onTap: app.logout),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// 5. لوحة إدارة المدرسة (Admin Dashboard)
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

    return RefreshIndicator(
      onRefresh: app.refreshAll,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _HeroBanner(title: app.currentUser!.name, subtitle: 'قاعدة بيانات سحابية متصلة بجميع الهواتف ☁️', badge: 'مدرسة الرواد الخاصة', colors: const [Color(0xFF1B365D), Color(0xFF0D9488)]),
          if (app.syncError != null) ...[
            const SizedBox(height: 10),
            Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: Colors.red.withAlpha(25), borderRadius: BorderRadius.circular(12)), child: Text(app.syncError!, style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold))),
          ],
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
              _ServiceTile(title: 'الطلاب والمعلمون', subtitle: 'إضافة وتأكيد وكلمات مرور', icon: Icons.people_alt_rounded, color: const Color(0xFF1B365D), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const _AdminUsersPage()))),
              _ServiceTile(title: 'استيراد Excel', subtitle: 'رفع xlsx أو csv أو لصق', icon: Icons.table_view_rounded, color: const Color(0xFF0D9488), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const _AdminExcelPage()))),
              _ServiceTile(title: 'الفصول والمواد', subtitle: 'إدارة الفصول والجداول', icon: Icons.class_rounded, color: const Color(0xFF0284C7), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const _AdminClassesSchedulePage()))),
              _ServiceTile(title: 'الحضور والدرجات', subtitle: 'متابعة الغياب والامتحانات', icon: Icons.fact_check_rounded, color: const Color(0xFF10B981), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const _AdminAttendanceExamsPage()))),
              _ServiceTile(title: 'المصروفات', subtitle: 'الفواتير والتحصيل المالي', icon: Icons.payments_rounded, color: const Color(0xFFD97706), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const _AdminFeesPage()))),
              _ServiceTile(title: 'الإعلانات والرسائل', subtitle: 'نشر أخبار والرد على الآباء', icon: Icons.campaign_rounded, color: const Color(0xFF6D28D9), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const _AdminCommsPage()))),
            ],
          ),
        ],
      ),
    );
  }
}

class _AdminApprovalsTab extends StatelessWidget {
  const _AdminApprovalsTab();
  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final pending = app.pendingUsers;
    return RefreshIndicator(
      onRefresh: app.refreshAll,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('حسابات بانتظار الاعتماد أو التوثيق', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          if (pending.isEmpty)
            const Card(child: Padding(padding: EdgeInsets.all(20), child: Center(child: Text('جميع الحسابات مفعّلة ومعتمدة ✓'))))
          else
            ...pending.map((u) => Card(
                  child: ListTile(
                    leading: CircleAvatar(backgroundColor: u.role.color.withAlpha(30), child: Icon(u.role.icon, color: u.role.color)),
                    title: Text(u.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text('${u.role.label} • ${u.phone}\n${u.email}\n${u.isVerified ? "البريد مؤكد ✓" : "بانتظار تأكيد البريد"} • ${u.isApproved ? "معتمد" : "بانتظار اعتمادك"}'),
                    trailing: ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981), foregroundColor: Colors.white),
                      onPressed: () => app.approveAndVerifyUser(u.id),
                      child: const Text('اعتماد'),
                    ),
                  ),
                )),
        ],
      ),
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
    final name = TextEditingController(), phone = TextEditingController(), email = TextEditingController(), pass = TextEditingController(), extra = TextEditingController();
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
                const Text('إضافة حساب سحابي جديد', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                DropdownButtonFormField<UserRole>(value: role, items: UserRole.values.map((r) => DropdownMenuItem(value: r, child: Text(r.label))).toList(), onChanged: (v) { if (v != null) setM(() => role = v); }),
                const SizedBox(height: 8),
                TextField(controller: name, decoration: const InputDecoration(labelText: 'الاسم الكامل')),
                const SizedBox(height: 8),
                TextField(controller: phone, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'رقم الهاتف')),
                const SizedBox(height: 8),
                TextField(controller: email, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'البريد الإلكتروني (لتأكيد الحساب)')),
                const SizedBox(height: 8),
                TextField(controller: pass, decoration: const InputDecoration(labelText: 'كلمة المرور (6 أحرف فأكثر)')),
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
                    onPressed: () async {
                      final err = await AppScope.of(context).addUserByAdmin(name: name.text, phone: phone.text, email: email.text, password: pass.text, role: role, grade: grade, subject: role == UserRole.teacher ? extra.text : 'عام', linkedParentPhone: role == UserRole.student ? extra.text : '');
                      if (!context.mounted) return;
                      if (err != null) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
                        return;
                      }
                      Navigator.pop(ctx);
                      setState(() => _filter = role);
                    },
                    child: const Text('حفظ على السيرفر'),
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
                    subtitle: Text('${u.phone} • ${u.email}\n${u.isVerified ? "موثّق ✓" : "ينتظر تأكيد البريد"}'),
                    trailing: u.phone == '01129220696'
                        ? const Chip(label: Text('المدير'))
                        : Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                tooltip: 'تغيير كلمة مروره',
                                icon: const Icon(Icons.key_rounded, color: Color(0xFF0284C7)),
                                onPressed: () {
                                  final p = TextEditingController();
                                  showDialog(context: context, builder: (ctx) => AlertDialog(title: Text('تعيين كلمة مرور جديدة لـ ${u.name}'), content: TextField(controller: p, decoration: const InputDecoration(labelText: 'كلمة المرور الجديدة')), actions: [ElevatedButton(onPressed: () { if (p.text.trim().length >= 6) app.resetUserPasswordByAdmin(u.id, p.text); Navigator.pop(ctx); }, child: const Text('حفظ'))]));
                                },
                              ),
                              IconButton(icon: const Icon(Icons.delete_outline, color: Colors.red), onPressed: () => app.deleteUser(u.id)),
                            ],
                          ),
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
  bool _busy = false;
  static const _template = 'الاسم,الصفة,الهاتف,البريد,كلمة المرور,الصف,هاتف ولي الأمر أو المادة\n'
      'يوسف أحمد علي,طالب,01055566601,youssef@gmail.com,Abc12345,4 ابتدائي,01030303030\n'
      'أ. رانيا سمير,معلم,01055566602,rania@gmail.com,Teach123,5 ابتدائي,العلوم';

  @override
  void dispose() {
    _pasteCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('استيراد Excel السحابي')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('ترتيب الأعمدة (7 أعمدة): الاسم | الصفة | الهاتف | البريد الإلكتروني | كلمة المرور | الصف | هاتف ولي الأمر أو المادة', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 14),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0D9488), foregroundColor: Colors.white, minimumSize: const Size.fromHeight(48)),
            onPressed: _busy
                ? null
                : () async {
                    try {
                      final picked = await FilePicker.pickFile(type: FileType.custom, allowedExtensions: ['xlsx', 'csv']);
                      if (picked == null) return;
                      setState(() => _busy = true);
                      final bytes = await picked.readAsBytes();
                      if (!context.mounted) return;
                      final res = await AppScope.of(context).importExcelOrCsvBytes(bytes, picked.name);
                      if (!context.mounted) return;
                      setState(() => _busy = false);
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${res.message}: أضيف ${res.added} (تخطي ${res.skipped})')));
                    } catch (_) {
                      if (!context.mounted) return;
                      setState(() => _busy = false);
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('استخدم اللصق المباشر بالأسفل')));
                    }
                  },
            icon: const Icon(Icons.upload_file_rounded),
            label: const Text('اختيار ملف .xlsx أو .csv من الهاتف'),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(onPressed: () => setState(() => _pasteCtrl.text = _template), icon: const Icon(Icons.description_outlined), label: const Text('تعبئة نموذج جدول Excel')),
          const SizedBox(height: 10),
          TextField(controller: _pasteCtrl, maxLines: 6, decoration: const InputDecoration(labelText: 'أو الصق صفوف الجدول هنا')),
          const SizedBox(height: 14),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1B365D), foregroundColor: Colors.white, minimumSize: const Size.fromHeight(48)),
            onPressed: _busy
                ? null
                : () async {
                    if (_pasteCtrl.text.trim().isEmpty) return;
                    setState(() => _busy = true);
                    final res = await AppScope.of(context).importDelimitedText(_pasteCtrl.text);
                    if (!context.mounted) return;
                    setState(() => _busy = false);
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${res.message}: تم رفع ${res.added} حساب (تخطي ${res.skipped})')));
                  },
            icon: const Icon(Icons.cloud_upload_rounded),
            label: Text(_busy ? 'جاري الرفع للسحابة...' : 'تنفيذ الاستيراد والرفع'),
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
          final title = TextEditingController(text: 'قسط دراسي'), total = TextEditingController(text: '8000');
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
          return Card(child: ListTile(title: Text('${inv.studentName} • ${inv.title}'), subtitle: Text('المتبقي: ${inv.remaining.toStringAsFixed(0)} من ${inv.totalAmount.toStringAsFixed(0)} ج.م'), trailing: inv.isFullyPaid ? const Chip(label: Text('مسدد')) : ElevatedButton(onPressed: () => app.payInvoice(inv, inv.remaining), child: const Text('تحصيل'))));
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
      RefreshIndicator(
        onRefresh: app.refreshAll,
        child: ListView(
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
      ),
      const _SchoolFeedTab(),
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
          final sub = TextEditingController(text: app.currentUser!.subject), title = TextEditingController(), det = TextEditingController();
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
          final sub = TextEditingController(text: app.currentUser!.subject), sc = TextEditingController(text: '28'), mx = TextEditingController(text: '30');
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
// 7. بوابة الطالب وولي الأمر (Student & Parent Dashboards)
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
    final app = AppScope.of(context);
    final st = app.currentUser!;
    final pages = [
      RefreshIndicator(
        onRefresh: app.refreshAll,
        child: ListView(
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
      ),
      const _SchoolFeedTab(),
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
            final done = h.completedIds.contains(student.id);
            return Card(child: CheckboxListTile(value: done, onChanged: (_) => app.toggleHomeworkCompletion(h, student.id), title: Text('${h.subject}: ${h.title}'), subtitle: Text('${h.details} • التسليم: ${h.dueDate}')));
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
        children: [Card(child: ListTile(leading: Icon(status.icon, color: status.color, size: 32), title: Text('حالة الحضور: ${student.name}'), trailing: Text(status.label, style: TextStyle(color: status.color, fontWeight: FontWeight.bold))))],
      ),
    );
  }
}

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
      RefreshIndicator(
        onRefresh: app.refreshAll,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _HeroBanner(title: p.name, subtitle: 'متابعة الأبناء والمصروفات والتواصل السحابي', badge: 'بوابة ولي الأمر', colors: const [Color(0xFF6D28D9), Color(0xFF1B365D)]),
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
                _ServiceTile(title: 'النتائج والدرجات', subtitle: 'متابعة مستوى الابن', icon: Icons.grade_rounded, color: const Color(0xFF10B981), onTap: () { if (active != null) Navigator.push(context, MaterialPageRoute(builder: (_) => _StudentResultsPage(student: active))); }),
                _ServiceTile(title: 'الواجبات والملفات', subtitle: 'مهام الابن اليومية', icon: Icons.assignment_rounded, color: const Color(0xFF0284C7), onTap: () { if (active != null) Navigator.push(context, MaterialPageRoute(builder: (_) => _StudentHwFilesPage(student: active))); }),
                _ServiceTile(title: 'المصروفات', subtitle: 'الفواتير والسداد', icon: Icons.payments_rounded, color: const Color(0xFFD97706), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => _ParentFeesPage(kids: kids)))),
                _ServiceTile(title: 'تواصل مع المدرسة', subtitle: 'إرسال استفسار أو شكوى', icon: Icons.chat_rounded, color: const Color(0xFF6D28D9), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const _ParentMessagesPage()))),
              ],
            ),
          ],
        ),
      ),
      const _SchoolFeedTab(),
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
                return Card(child: ListTile(title: Text('${inv.studentName} - ${inv.title}'), subtitle: Text('المتبقي: ${inv.remaining.toStringAsFixed(0)} من ${inv.totalAmount.toStringAsFixed(0)} ج.م'), trailing: inv.isFullyPaid ? const Chip(label: Text('مسدد')) : ElevatedButton(onPressed: () => app.payInvoice(inv, inv.remaining), child: const Text('سداد'))));
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
  const _SchoolFeedTab();
  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    return RefreshIndicator(
      onRefresh: app.refreshAll,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('إعلانات وأخبار المدرسة', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          ...app.allAnnouncements.map((a) => Card(child: ListTile(leading: const Icon(Icons.campaign_rounded, color: Color(0xFF1B365D)), title: Text(a.title, style: const TextStyle(fontWeight: FontWeight.bold)), subtitle: Text('${a.body}\n${a.dateLabel}')))),
        ],
      ),
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
