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

// ============================================================================
// 1. النماذج والأنواع الأساسية (Domain Models & Enums)
// ============================================================================

enum UserRole {
admin('مدير المدرسة', 'إدارة شاملة للمدرسة والحسابات والمصروفات', Icons.admin_panel_settings_rounded, Color(0xFF1E3A8A)),
teacher('معلم', 'الطلاب، الحضور، الواجبات، الدرجات والملفات', Icons.cast_for_education_rounded, Color(0xFF0D9488)),
student('طالب', 'الجدول، الواجبات، الدرجات، النتائج والملفات', Icons.school_rounded, Color(0xFF0284C7)),
parent('ولي أمر', 'متابعة الأبناء، الحضور، النتائج، المصروفات والتواصل', Icons.family_restroom_rounded, Color(0xFF7C3AED));

final String label;
final String subtitle;
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

final String label;
final String shortLabel;
const GradeLevel(this.label, this.shortLabel);

static GradeLevel parseGrade(String raw) {
final s = raw.trim().toLowerCase();
for (final g in GradeLevel.values) {
if (g.name.toLowerCase() == s || g.shortLabel.toLowerCase() == s || g.label.toLowerCase().contains(s)) {
return g;
}
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
});
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

// ============================================================================
// 2. إدارة الحالة المركزية (SchoolState)
// ============================================================================

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
final p = phone.trim();
final pass = password.trim();
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
if (users.any((u) => u.phone == cleanPhone)) return 'رقم الهاتف مسجل بالفعل لحساب آخر';
final user = AppUser(
id: 'u {grade.shortLabel}' : classroom.trim(),
subject: subject.trim().isEmpty ? 'عام' : subject.trim(),
linkedParentPhone: linkedParentPhone.trim(),
);
_users.add(user);
if (role == UserRole.student) {
attendance.add(AttendanceEntry(id: 'att$`{DateTime.now().microsecondsSinceEpoch}', studentId: user.id, studentName: user.name, grade: user.grade, dateStr: '2026-11-25', status: AttendanceStatus.present));
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
if (fileName.toLowerCase().endsWith('.csv')) {
return importDelimitedText(utf8.decode(bytes, allowMalformed: true));
}
final wb = xl.Excel.decodeBytes(bytes);
final List<List<String>> rows = [];
for (final name in wb.tables.keys) {
final sheet = wb.tables[name];
if (sheet == null) continue;
for (final row in sheet.rows) {
rows.add(row.map((cell) => cellText(cell?.value)).toList());
}
break;
}
final res = importRows(rows);
return (added: res.added, skipped: res.skipped, message: 'تمت قراءة ملف الإكسيل');
} catch () {
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
classes.add(SchoolClass(id: 'c`${DateTime.now().microsecondsSinceEpoch}', name: name, grade: grade, capacity: cap, supervisorName: sup));
notifyListeners();
}

void deleteClass(String id) {
_classes.removeWhere((c) => c.id == id);
notifyListeners();
}

void addSubject(String name, GradeLevel grade, String teacher) {
subjects.add(SubjectItem(id: 'sb$`{DateTime.now().microsecondsSinceEpoch}', name: name, grade: grade, teacherName: teacher));
notifyListeners();
}

void deleteSubject(String id) {
_subjects.removeWhere((s) => s.id == id);
notifyListeners();
}

void addScheduleSlot(GradeLevel grade, String day, int period, String time, String sub, String teacher, String room) {
schedule.add(ScheduleSlot(id: 'sc`${DateTime.now().microsecondsSinceEpoch}', grade: grade, day: day, period: period, timeRange: time, subject: sub, teacherName: teacher, classroom: room));
notifyListeners();
}

void deleteScheduleSlot(String id) {
_schedule.removeWhere((s) => s.id == id);
notifyListeners();
}

void addExam(String title, String sub, GradeLevel grade, String dateStr, String timeStr, String room) {
exams.insert(0, ExamItem(id: 'ex sub', ' {grade.shortLabel}) يوم  timeStr');
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
attendance.insert(0, AttendanceEntry(id: 'attlatex
{DateTime.now().microsecondsSinceEpoch}', studentId: st.id, studentName: st.name, grade: st.grade, dateStr: '2026-11-25', status: status)); } if (status == AttendanceStatus.absent) { _pushNotif(NotificationType.absence, 'إشعار غياب', 'تم تسجيل (

{st.name}) غائباً اليوم.', targetPhone: st.linkedParentPhone.isNotEmpty ? st.linkedParentPhone : null, targetRole: UserRole.parent);
}
notifyListeners();
}

void addHomework(GradeLevel grade, String sub, String title, String details, String due) {
homeworks.insert(0, HomeworkItem(id: 'hw sub', ' {grade.shortLabel}) - التسليم: $`due');
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
grades.insert(0, GradeEntry(id: 'gr${DateTime.now().microsecondsSinceEpoch}', studentId: st.id, studentName: st.name, grade: st.grade, subject: sub, examTitle: exam, score: score, maxScore: maxScore, note: note)); _pushNotif(NotificationType.result, 'نتيجة جديدة: $sub', 'حصل ${st.name} على $score / $maxScore في $exam.', targetPhone: st.linkedParentPhone.isNotEmpty ? st.linkedParentPhone : null);
}

void addInvoice(AppUser st, String title, double total, double paid, String due) {
invoices.insert(0, FeeInvoice(id: 'inv${DateTime.now().microsecondsSinceEpoch}', studentId: st.id, studentName: st.name, grade: st.grade, title: title, totalAmount: total, paidAmount: paid, dueDate: due)); if (total &gt; paid) { _pushNotif(NotificationType.fees, 'تنبيه مصروفات', 'فاتورة ($title) للطالب ${st.name} متبقي ${(total - paid).toStringAsFixed(0)} ج.م.', targetPhone: st.linkedParentPhone.isNotEmpty ? st.linkedParentPhone : null, targetRole: UserRole.parent);
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
announcements.insert(0, AnnouncementNews(id: 'an${DateTime.now().microsecondsSinceEpoch}', title: title, body: body, category: cat, targetRole: target, author: _currentUser?.name ?? 'الإدارة', dateLabel: 'الآن', isUrgent: urgent)); _pushNotif(NotificationType.announcement, '$cat: `$title', body, targetRole: target);
}

void sendCustomNotif(NotificationType type, String title, String body, UserRole? target) => _pushNotif(type, title, body, targetRole: target);

void _pushNotif(NotificationType type, String title, String body, {String? targetPhone, UserRole? targetRole}) {
notifications.insert(0, SchoolNotification(id: 'n$`{DateTime.now().microsecondsSinceEpoch}', type: type, title: title, body: body, targetPhone: targetPhone, targetRole: targetRole, dateLabel: 'الآن'));
notifyListeners();
}

void addFile(String title, String type, GradeLevel grade, String sub, String url) {
files.insert(0, EducationalFile(id: 'f`${DateTime.now().microsecondsSinceEpoch}', title: title, fileType: type, grade: grade, subject: sub, urlOrName: url, uploadedBy: _currentUser?.name ?? 'المعلم', dateLabel: 'اليوم'));
notifyListeners();
}

void sendMessage(String recipient, String subject, String body) {
final u = _currentUser;
if (u == null) return;
messages.insert(0, SchoolMessage(id: 'm$`{DateTime.now().microsecondsSinceEpoch}', senderName: u.name, senderPhone: u.phone, recipientLabel: recipient, subject: subject, body: body, dateLabel: 'الآن'));
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

// ============================================================================
// 3. التطبيق الرئيسي والثيم الليلي/النهاري (Material Design 3 & RTL)
// ============================================================================

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
animation: state,
builder: (, __) {
final light = ColorScheme.fromSeed(seedColor: const Color(0xFF1E3A8A), secondary: const Color(0xFF0D9488), brightness: Brightness.light);
final dark = ColorScheme.fromSeed(seedColor: const Color(0xFF3B82F6), secondary: const Color(0xFF14B8A6), brightness: Brightness.dark);
return MaterialApp(
debugShowCheckedModeBanner: false,
title: 'مدرسة الرواد الخاصة',
themeMode: state.themeMode,
theme: ThemeData(
useMaterial3: true,
colorScheme: light,
scaffoldBackgroundColor: const Color(0xFFF3F6FB),
appBarTheme: AppBarTheme(centerTitle: true, backgroundColor: light.primary, foregroundColor: Colors.white),
inputDecorationTheme: InputDecorationTheme(filled: true, fillColor: Colors.white, border: OutlineInputBorder(borderRadius: BorderRadius.circular(14))),
),
darkTheme: ThemeData(
useMaterial3: true,
colorScheme: dark,
scaffoldBackgroundColor: const Color(0xFF0F172A),
appBarTheme: const AppBarTheme(centerTitle: true, backgroundColor: Color(0xFF1E293B), foregroundColor: Colors.white),
inputDecorationTheme: InputDecorationTheme(filled: true, fillColor: const Color(0xFF1E293B), border: OutlineInputBorder(borderRadius: BorderRadius.circular(14))),
),
builder: (, child) => Directionality(textDirection: TextDirection.rtl, child: child!),
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

// ============================================================================
// 4. الشعار والترحيب وتسجيل الدخول (Splash & Login)
// ============================================================================

class AlRowadLogo extends StatelessWidget {
final double size;
const AlRowadLogo({super.key, this.size = 82});
@override
Widget build(BuildContext context) {
return Container(
width: size,
height: size,
decoration: BoxDecoration(
shape: BoxShape.circle,
gradient: const LinearGradient(colors: [Color(0xFF1E3A8A), Color(0xFF0D9488)]),
border: Border.all(color: const Color(0xFFFBBF24), width: 3),
),
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
bool _obscure = true;
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
await Future.delayed(
