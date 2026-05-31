import 'package:flutter/material.dart';
import '../theme_manager.dart';
import '../shared/member_profile_dialog.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/intl.dart';
import '../globals.dart' as globals;

class BellPeriod {
  final String name;
  final String timeFrame;
  BellPeriod(this.name, this.timeFrame);
}

class ClassManagementView extends StatefulWidget {
  final int classId;
  final String className;
  final bool isSuperAdmin;
  final VoidCallback? onDataChanged;

  const ClassManagementView({super.key, required this.classId, required this.className, this.isSuperAdmin = true, this.onDataChanged});

  @override
  State<ClassManagementView> createState() => _ClassManagementViewState();
}

class _ClassManagementViewState extends State<ClassManagementView> {
  String _currentClassAcademicYear = "2025-2026";
  bool _isLoading = true;
  late String _currentClassName;
  String _currentTeacher = 'Đang tải...';
  Map<String, dynamic> _teacherData = {};
  // THÊM DÒNG NÀY VÀO PHẦN KHAI BÁO BIẾN
  bool get _isMyHomeroom => _currentLoggedInName.isNotEmpty && _currentTeacher.contains(_currentLoggedInName);
  bool get _isStudent => globals.currentUserRole == 'Học sinh' || globals.currentUserRole == 'Thành viên';
  List<dynamic> _leaveRequests = [];
  int _courseStartYear = 2025;
  int _courseEndYear = 2028;
  int _currentYearStart = 2026;
  int _currentYearEnd = 2027;
  String _currentSemester = 'Học kỳ 1';

  List<String> _historicalYears = [];
  List<String> _historicalSemesters = [];

  List<dynamic> _teachersData = [];
  List<String> _allTeacherNames = [];
  Map<String, String> _teacherClassMap = {};

  // BIẾN LƯU TRỮ THÔNG TIN NGƯỜI ĐANG ĐĂNG NHẬP (Dùng cho Kính lọc Bộ môn)
  String _currentLoggedInName = "";
  String _currentTeachingSubject = "";

  String _selectedFilter = 'Tất cả';
  DateTime? _selectedDate;
  String _selectedYearFilter = 'Hiện tại';
  String _selectedSemesterFilter = 'Hiện tại';
  final List<String> _filterOptions = ['Tất cả', 'Vi phạm', 'Đi trễ', 'Nghỉ học', 'Có phép'];

  List<Map<String, dynamic>> allStudents = [];

  DateTime _timetableWeekStart = DateTime.now().subtract(Duration(days: DateTime.now().weekday - 1));
  List<BellPeriod> _bellSchedule = [];
  List<dynamic> _classTimetable = [];

  @override
  void initState() {
    super.initState();
    _currentClassName = widget.className;
    _fetchClassData();
  }

  @override
  void didUpdateWidget(covariant ClassManagementView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.classId != widget.classId) {
      _currentClassName = widget.className;
      _fetchClassData();
    }
  }

  Future<void> _fetchClassData() async {
    setState(() => _isLoading = true);
    try {
      var response = await http.get(Uri.parse('http://127.0.0.1:8000/api/classes/${widget.classId}'));
      if (response.statusCode == 200) {
        var data = jsonDecode(utf8.decode(response.bodyBytes));
        if (data['status'] == 'success') {
          var cls = data['data'];
          setState(() {
            _currentClassName = cls['class_name'];
            _courseStartYear = cls['course_start_year'];
            _courseEndYear = cls['course_end_year'];
            _currentYearStart = cls['current_year_start'];
            _currentYearEnd = cls['current_year_end'];
            _currentSemester = cls['current_semester'];
            _currentTeacher = cls['teacher']['name'] ?? "Chưa phân công";
            _teacherData = cls['teacher'];
            if (cls['students'] != null) {
              allStudents = List<Map<String, dynamic>>.from(cls['students']);
            }
            _classTimetable = cls['timetable'] ?? [];
          });
        }
      }

      var resProj = await http.get(Uri.parse('http://127.0.0.1:8000/api/projects/${globals.currentProjectId}'));
      if (resProj.statusCode == 200) {
        var pData = jsonDecode(utf8.decode(resProj.bodyBytes));
        if (pData['status'] == 'success' && pData['data']['bell_schedule'] != null) {
          var bSched = pData['data']['bell_schedule'];
          _bellSchedule = (bSched as List).map((e) => BellPeriod(e['name'], "${e['start_time']} - ${e['end_time']}")).toList();
        }
      }
      if (_bellSchedule.isEmpty) {
        _bellSchedule = [BellPeriod("Tiết 1", "07:00 - 07:45"), BellPeriod("Tiết 2", "07:45 - 08:30")];
      }

      var resMembers = await http.get(Uri.parse('http://127.0.0.1:8000/api/projects/${globals.currentProjectId}/members'));
      if (resMembers.statusCode == 200) {
        var dataMem = jsonDecode(utf8.decode(resMembers.bodyBytes));
        if (dataMem['status'] == 'success') {
          if (dataMem['data'] is Map) {
            _teachersData = [...(dataMem['data']['admins'] ?? []), ...(dataMem['data']['managers'] ?? [])];
          } else if (dataMem['data'] is List) {
            _teachersData = List<dynamic>.from(dataMem['data']);
          }

          // LƯU THÔNG TIN CỦA CHÍNH MÌNH ĐỂ LÀM BỘ LỌC
          var me = _teachersData.where((m) => m['user_id'].toString() == globals.currentUserId.toString()).firstOrNull;
          if (me != null) {
            _currentLoggedInName = me['name'] ?? "";
            _currentTeachingSubject = me['teaching_subject'] ?? "";
          }

          setState(() {
            _allTeacherNames = _teachersData.map<String>((m) => m['name']?.toString() ?? '').where((n) => n.isNotEmpty).toList();
          });
        }
      }

      var resClasses = await http.get(Uri.parse('http://127.0.0.1:8000/api/projects/${globals.currentProjectId}/classes'));
      if (resClasses.statusCode == 200) {
        var dataClasses = jsonDecode(utf8.decode(resClasses.bodyBytes));
        if (dataClasses['status'] == 'success') {
          Map<String, String> newMap = {};
          for (var c in dataClasses['data']) {
            String className = c['class_name']?.toString() ?? "";
            String? tIdStr;
            if (c['teacher_id'] != null) {
              tIdStr = c['teacher_id'].toString();
            } else if (c['teacher'] != null && c['teacher'] is Map) {
              tIdStr = (c['teacher']['user_id'] ?? c['teacher']['id'])?.toString();
            }

            if (tIdStr != null && tIdStr.isNotEmpty) {
              newMap[tIdStr] = className;
            }
          }
          setState(() {
            _teacherClassMap = newMap;
          });
        }
      }// KÉO DANH SÁCH ĐƠN XIN NGHỈ CHƯA DUYỆT
      var resLeaves = await http.get(Uri.parse('http://127.0.0.1:8000/api/classes/${widget.classId}/leaves'));
      if (resLeaves.statusCode == 200) {
        var dataL = jsonDecode(utf8.decode(resLeaves.bodyBytes));
        if (dataL['status'] == 'success') setState(() => _leaveRequests = dataL['data']);
      }
    } catch (e) {
      debugPrint("Lỗi fetch: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
  Future<void> _handleLeaveAction(int leaveId, String action) async {
    try {
      var res = await http.put(Uri.parse('http://127.0.0.1:8000/api/leaves/$leaveId'), headers: {"Content-Type": "application/json"}, body: jsonEncode({"action": action}));
      if (res.statusCode == 200) {
        _fetchClassData(); // Tải lại danh sách đơn
        if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(action == 'approve' ? "Đã duyệt đơn nghỉ phép!" : "Đã từ chối đơn!"), backgroundColor: action == 'approve' ? Colors.green : Colors.redAccent));
      }
    } catch (e) {}
  }

// ==========================================================
  // THUẬT TOÁN ĐỒNG BỘ: KÍNH LỌC THEO QUYỀN (ĐÃ FIX LỖI ĐẾM TRÙNG)
  // ==========================================================
  Map<String, int> _calculateDisciplineStats(Map<String, dynamic> student) {
    int lateCount = 0; int absentCount = 0; int excusedCount = 0;

    String queryYear = _selectedYearFilter == 'Hiện tại' ? '$_currentYearStart-$_currentYearEnd' : _selectedYearFilter;
    String querySemester = _selectedSemesterFilter == 'Hiện tại' ? _currentSemester : _selectedSemesterFilter;

    var attRaw = student['attendance_data'] ?? student['attendance'];
    Map<String, dynamic>? att;
    if (attRaw is String) { try { att = jsonDecode(attRaw); } catch(_) {} }
    else if (attRaw is Map) { att = Map<String, dynamic>.from(attRaw); }

    if (att != null) {
      var termData = att[queryYear]?[querySemester];
      if (termData != null && termData['history'] != null) {
        List<dynamic> history = termData['history'];

        // ĐÃ FIX: Lọc trùng lịch sử, chỉ lấy kết quả chốt cuối cùng của mỗi tiết
        Map<String, String> latestStatusMap = {};

        for (var h in history) {
          String logStr = h.toString();
          // Lọc bỏ phần đuôi chứa ảnh
          if (logStr.contains("|img:")) logStr = logStr.split("|img:")[0];

          // Phân tích chuỗi: "25/05/26: Sửa thành Đi trễ Toán (Cập nhật lúc 14:05)"
          List<String> parts = logStr.split(': ');
          if (parts.length < 2) continue;

          String datePart = parts[0].trim(); // Lấy ngày "25/05/26"
          String detailPart = parts[1];
          String content = detailPart.split('(').first.trim(); // "Sửa thành Đi trễ Toán"

          String status = "";
          if (content.contains("Đi trễ")) status = "Đi trễ";
          else if (content.contains("Vắng mặt") || content.contains("Nghỉ học")) status = "Vắng mặt";
          else if (content.contains("Có phép")) status = "Có phép";
          else if (content.contains("Có mặt") || content.contains("Hợp lệ")) status = "Có mặt";

          // Bóc tách tên môn học bằng cách xóa các từ khóa trạng thái
          String subject = content
              .replaceAll("Sửa thành", "")
              .replaceAll("Có mặt", "")
              .replaceAll("Hợp lệ", "")
              .replaceAll("Đi trễ", "")
              .replaceAll("Vắng mặt", "")
              .replaceAll("Nghỉ học", "")
              .replaceAll("Có phép", "")
              .trim();

          String slotKey = "$datePart-$subject";

          // Chỉ lưu trạng thái MỚI NHẤT (Do history luôn đẩy dòng mới nhất lên index 0)
          if (!latestStatusMap.containsKey(slotKey)) {
            latestStatusMap[slotKey] = status;
          }
        }

        // Sau khi có danh sách các trạng thái ĐÃ LỌC TRÙNG, ta mới đếm & áp dụng Kính Lọc
        latestStatusMap.forEach((slotKey, finalStatus) {
          if (!widget.isSuperAdmin && !_isMyHomeroom) {
            bool isMyLog = false;
            if (_currentTeachingSubject.isNotEmpty && slotKey.toLowerCase().contains(_currentTeachingSubject.toLowerCase())) isMyLog = true;
            if (!isMyLog) return;
          }

          if (finalStatus == "Đi trễ") lateCount++;
          else if (finalStatus == "Vắng mặt") absentCount++;
          else if (finalStatus == "Có phép") excusedCount++;
        });
      }
    }

    return { 'late': lateCount, 'absent': absentCount, 'excused': excusedCount };
  }

  Map<String, dynamic> _getTermData(Map<String, dynamic> student, String yearFilter, String semesterFilter) {
    String queryYear = yearFilter == 'Hiện tại' ? '$_currentYearStart-$_currentYearEnd' : yearFilter;
    String querySemester = semesterFilter == 'Hiện tại' ? _currentSemester : semesterFilter;
    var defaultData = {"lateCount": 0, "absentCount": 0, "excusedCount": 0, "history": <String>[]};

    var attRaw = student['attendance_data'] ?? student['attendance'];
    Map<String, dynamic>? att;
    if (attRaw is String) { try { att = jsonDecode(attRaw); } catch(_) {} }
    else if (attRaw is Map) { att = Map<String, dynamic>.from(attRaw); }

    if (att == null || att[queryYear] == null || att[queryYear][querySemester] == null) return defaultData;
    return att[queryYear][querySemester];
  }



  Color _getTeacherColor(String teacherName, AppTheme theme) {
    if (teacherName.isEmpty || teacherName.contains("Chưa gán")) return theme.primaryColor;
    List<Color> palette = [ Colors.blue, Colors.teal, Colors.indigo, Colors.brown, Colors.deepOrange, Colors.cyan, Colors.pink ];
    return palette[teacherName.hashCode.abs() % palette.length];
  }

  String _getDayOfWeek(int index) => ['Thứ 2', 'Thứ 3', 'Thứ 4', 'Thứ 5', 'Thứ 6', 'Thứ 7', 'Chủ Nhật'][index];

  Map<String, dynamic>? _findCellDataForClass(DateTime targetDate, String dayOfWeek, String timeFrame) {
    String dateKey = DateFormat('yyyy-MM-dd').format(targetDate);
    for (var d in _classTimetable) {
      if (d['dayName'] == dateKey) {
        for (var s in d['subjects'] ?? []) {
          if (s['timeFrame'] == timeFrame) {
            if (s['status'] == 'Trống') return null;
            return s;
          }
        }
      }
    }
    for (var d in _classTimetable) {
      if (d['dayName'] == dayOfWeek) {
        for (var s in d['subjects'] ?? []) {
          if (s['timeFrame'] == timeFrame) return s;
        }
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
        animation: AppTheme.instance,
        builder: (context, child) {
          final theme = AppTheme.instance;
          if (_isLoading) return Center(child: Padding(padding: const EdgeInsets.only(top: 100), child: CircularProgressIndicator(color: theme.primaryColor)));

          List<Map<String, dynamic>> filteredStudents = allStudents.where((student) {
            var termData = _getTermData(student, _selectedYearFilter, _selectedSemesterFilter);
            // Áp dụng thuật toán kính lọc lên biến tạm
            Map<String, int> stats = _calculateDisciplineStats(student);

            if (_selectedFilter == 'Tất cả') return true;
            if (_selectedFilter == 'Vi phạm') return stats['late']! > 0 || stats['absent']! > 0;
            if (_selectedFilter == 'Đi trễ') return stats['late']! > 0;
            if (_selectedFilter == 'Nghỉ học') return stats['absent']! > 0;
            if (_selectedFilter == 'Có phép') return stats['excused']! > 0;
            return true;
          }).toList();

          List<String> yearOptions = ['Hiện tại']; yearOptions.addAll(_historicalYears);
          List<String> semesterOptions = ['Hiện tại']; semesterOptions.addAll(_historicalSemesters);

          return SingleChildScrollView(
            key: ValueKey('Class_$_currentClassName'),
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.all(40.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // SỬA LẠI ĐOẠN NÀY TRONG HÀM build()
                        AnimatedDefaultTextStyle(duration: const Duration(milliseconds: 300), style: TextStyle(fontSize: 32 * theme.fontScale, fontWeight: FontWeight.w900, color: theme.textColor, letterSpacing: 1.0, fontFamily: 'Segoe UI'), child: Text(_currentClassName)),
                        const SizedBox(height: 4),
                        // KIỂM TRA: NẾU KHÔNG PHẢI ADMIN THÌ HIỆN NHÃN CHỦ NHIỆM HOẶC BỘ MÔN
                        if (!widget.isSuperAdmin)
                          Text(
                              _isMyHomeroom
                                  ? "Truy cập dưới quyền: Giáo viên Chủ nhiệm"
                                  : "Truy cập dưới quyền: Giáo viên Bộ môn (${_currentTeachingSubject.isNotEmpty ? _currentTeachingSubject : 'Chung'})",
                              style: TextStyle(color: theme.purpleColor, fontSize: 13 * theme.fontScale, fontWeight: FontWeight.bold, fontStyle: FontStyle.italic)
                          ),
                      ],
                    ),
                    const SizedBox(width: 20),
                    Container(margin: const EdgeInsets.only(bottom: 6), padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), decoration: BoxDecoration(color: theme.primaryColor.withOpacity(0.15), borderRadius: BorderRadius.circular(8)), child: Text("Sĩ số: ${allStudents.length} hs", style: TextStyle(color: theme.primaryColor, fontSize: 13 * theme.fontScale, fontWeight: FontWeight.bold))),
                    const SizedBox(width: 10),
                    Container(margin: const EdgeInsets.only(bottom: 6), padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), decoration: BoxDecoration(color: theme.purpleColor.withOpacity(0.15), borderRadius: BorderRadius.circular(8)), child: Text("Khóa: $_courseStartYear - $_courseEndYear", style: TextStyle(color: theme.purpleColor, fontSize: 13 * theme.fontScale, fontWeight: FontWeight.bold))),

                    const Spacer(),

                    IconButton(
                      onPressed: _fetchClassData,
                      icon: Icon(Icons.sync_rounded, color: theme.primaryColor, size: 24 * theme.fontScale),
                      tooltip: "Làm mới dữ liệu",
                    ),
                    const SizedBox(width: 15),

                    // NÚT QUẢN TRỊ NÀY SẼ BỊ GIẤU NẾU LÀ GIÁO VIÊN BỘ MÔN
                    if (widget.isSuperAdmin)
                      ElevatedButton.icon(
                        onPressed: () => _showEditClassDialog(context, theme),
                        icon: Icon(Icons.settings_suggest_rounded, size: 16 * theme.fontScale, color: Colors.white),
                        label: Text("QUẢN TRỊ LỚP", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13 * theme.fontScale, color: Colors.white)),
                        style: ElevatedButton.styleFrom(backgroundColor: theme.primaryColor, padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                      ),
                    if (_isStudent)
                      ElevatedButton.icon(
                        onPressed: () => _showStudentLeaveDialog(theme),
                        icon: Icon(Icons.edit_document, size: 16 * theme.fontScale, color: Colors.white),
                        label: Text("TẠO ĐƠN XIN NGHỈ", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13 * theme.fontScale, color: Colors.white)),
                        style: ElevatedButton.styleFrom(backgroundColor: theme.infoColor, padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                      )
                  ],
                ),
                const SizedBox(height: 30),

                _buildSectionHeader(Icons.badge_rounded, "GIÁO VIÊN CHỦ NHIỆM", theme),
                const SizedBox(height: 15),
                (_currentTeacher == 'Chưa phân công' || _currentTeacher.isEmpty)
                    ? Padding(padding: const EdgeInsets.only(left: 10), child: Text("Chưa có giáo viên quản lý lớp.", style: TextStyle(color: theme.subTextColor, fontSize: 13 * theme.fontScale, fontStyle: FontStyle.italic)))
                    : Align(
                  alignment: Alignment.centerLeft,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 400),
                    child: Container(
                      decoration: BoxDecoration(color: theme.textColor.withOpacity(0.02), borderRadius: BorderRadius.circular(16), border: Border.all(color: theme.primaryColor.withOpacity(0.3))),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: () { showDialog(context: context, builder: (context) => MemberProfileDialog(isAdmin: widget.isSuperAdmin, memberData: _teacherData)); },
                          child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: Row(
                              children: [
                                (_teacherData['avatar_url'] != null && _teacherData['avatar_url'].toString().isNotEmpty)
                                    ? CircleAvatar(radius: 24 * theme.fontScale, backgroundImage: NetworkImage("http://127.0.0.1:8000${_teacherData['avatar_url']}"))
                                    : CircleAvatar(radius: 24 * theme.fontScale, backgroundColor: theme.primaryColor.withOpacity(0.2), child: Icon(Icons.person, color: theme.primaryColor, size: 24 * theme.fontScale)),
                                const SizedBox(width: 20),
                                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(_currentTeacher, style: TextStyle(color: theme.textColor, fontSize: 16 * theme.fontScale, fontWeight: FontWeight.bold)), const SizedBox(height: 4), Text("Giáo viên chủ nhiệm", style: TextStyle(color: theme.primaryColor, fontSize: 13 * theme.fontScale))])),
                                Icon(Icons.chevron_right_rounded, color: theme.subTextColor, size: 24 * theme.fontScale)
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 40),

                _buildSectionHeader(Icons.calendar_month_rounded, "THỜI KHÓA BIỂU CHI TIẾT", theme),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2), decoration: BoxDecoration(color: theme.cardColor, borderRadius: BorderRadius.circular(10), border: Border.all(color: theme.borderColor)),
                          child: Row(
                            children: [
                              IconButton(onPressed: () => setState(() => _timetableWeekStart = _timetableWeekStart.subtract(const Duration(days: 7))), icon: Icon(Icons.chevron_left_rounded, color: theme.primaryColor, size: 20)),
                              Text("Tuần ${DateFormat('dd/MM').format(_timetableWeekStart)} - ${DateFormat('dd/MM').format(_timetableWeekStart.add(const Duration(days: 6)))}", style: TextStyle(color: theme.textColor, fontWeight: FontWeight.bold, fontSize: 12 * theme.fontScale)),
                              IconButton(onPressed: () => setState(() => _timetableWeekStart = _timetableWeekStart.add(const Duration(days: 7))), icon: Icon(Icons.chevron_right_rounded, color: theme.primaryColor, size: 20)),
                              Container(width: 1, height: 15, color: theme.borderColor, margin: const EdgeInsets.symmetric(horizontal: 5)),
                              TextButton(onPressed: () => setState(() => _timetableWeekStart = DateTime.now().subtract(Duration(days: DateTime.now().weekday - 1))), child: Text("Hiện tại", style: TextStyle(color: theme.primaryColor, fontWeight: FontWeight.bold, fontSize: 11 * theme.fontScale)))
                            ],
                          ),
                        ),
                      ],
                    ),
                    TextButton.icon(
                      onPressed: _fetchClassData,
                      icon: Icon(Icons.sync_rounded, size: 16, color: theme.primaryColor),
                      label: Text("Đồng bộ", style: TextStyle(fontWeight: FontWeight.bold, color: theme.primaryColor)),
                    )
                  ],
                ),
                const SizedBox(height: 15),
                // =======================================================
                // DANH SÁCH ĐƠN XIN NGHỈ CHỜ DUYỆT
                // =======================================================
                if (_classTimetable.isEmpty)
                  Padding(padding: const EdgeInsets.all(30), child: Center(child: Text("Chưa có thời khóa biểu cho lớp này.\nVui lòng thiết lập TKB Chung ở trang Thời khóa biểu.", style: TextStyle(color: theme.subTextColor, fontSize: 14 * theme.fontScale), textAlign: TextAlign.center)))
                else
                  _buildClassTimetableGrid(theme),

                const SizedBox(height: 50),

                // 2. HIỂN THỊ DANH SÁCH ĐƠN XIN NGHỈ (NGAY DƯỚI BẢNG TKB)
                _buildSectionHeader(Icons.mark_email_unread_rounded, "ĐƠN XIN NGHỈ CHỜ DUYỆT", theme),
                const SizedBox(height: 15),

                if (_leaveRequests.isEmpty)
                  Container(
                    width: double.infinity, padding: const EdgeInsets.all(25), decoration: BoxDecoration(color: theme.textColor.withOpacity(0.02), borderRadius: BorderRadius.circular(16), border: Border.all(color: theme.borderColor, strokeAlign: BorderSide.strokeAlignOutside)),
                    child: Center(child: Text("Tuyệt vời! Không có đơn xin phép nào đang chờ duyệt.", style: TextStyle(color: theme.subTextColor, fontSize: 13 * theme.fontScale, fontStyle: FontStyle.italic))),
                  )
                else
                  Wrap(
                    spacing: 15,
                    runSpacing: 15,
                    children: _leaveRequests.map((leave) {
                      bool canApprove = false;
                      if (widget.isSuperAdmin || _isMyHomeroom) canApprove = true;
                      else if (leave['leave_mode'] == 'Theo tiết' && _currentTeachingSubject.isNotEmpty && leave['subject_name'].toString().contains(_currentTeachingSubject)) canApprove = true;

                      return Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () => _showLeaveDetailDialog(leave, canApprove, theme),
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            decoration: BoxDecoration(
                              color: theme.infoColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: theme.infoColor.withOpacity(0.3)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.mark_email_unread_rounded, color: theme.infoColor, size: 18 * theme.fontScale),
                                const SizedBox(width: 10),
                                Text(
                                  leave['student_name'],
                                  style: TextStyle(color: theme.textColor, fontWeight: FontWeight.bold, fontSize: 13 * theme.fontScale),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(color: theme.infoColor, borderRadius: BorderRadius.circular(6)),
                                  child: Text(
                                    leave['leave_mode'] == 'Theo ngày' || leave['leave_mode'] == 'Nguyên ngày' ? 'Nguyên ngày' : 'Theo tiết',
                                    style: TextStyle(color: Colors.white, fontSize: 10 * theme.fontScale, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),

                const SizedBox(height: 50),

                _buildSectionHeader(Icons.table_chart_rounded, "DỮ LIỆU ĐIỂM DANH LỊCH SỬ", theme),
                const SizedBox(height: 20),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildFilterDropdown("Năm học", _selectedYearFilter, yearOptions, (val) => setState(() => _selectedYearFilter = val!), theme), const SizedBox(width: 15),
                      _buildFilterDropdown("Học kỳ", _selectedSemesterFilter, semesterOptions, (val) => setState(() => _selectedSemesterFilter = val!), theme), const SizedBox(width: 15),
                      OutlinedButton.icon(
                        onPressed: () async {
                          final DateTime? picked = await showDatePicker(context: context, initialDate: _selectedDate ?? DateTime.now(), firstDate: DateTime(2025), lastDate: DateTime(2030), builder: (context, child) => Theme(data: Theme.of(context).copyWith(colorScheme: ColorScheme.dark(primary: theme.primaryColor, onPrimary: Colors.white, surface: theme.cardColor, onSurface: theme.textColor)), child: child!));
                          if (picked != null) setState(() => _selectedDate = picked);
                        },
                        icon: Icon(Icons.calendar_today_rounded, size: 16 * theme.fontScale, color: _selectedDate == null ? theme.subTextColor : theme.primaryColor),
                        label: Text(_selectedDate == null ? "Lọc theo ngày" : "${_selectedDate!.day}/${_selectedDate!.month}/${_selectedDate!.year}", style: TextStyle(color: _selectedDate == null ? theme.subTextColor : theme.primaryColor, fontWeight: FontWeight.bold, fontSize: 13 * theme.fontScale)),
                        style: OutlinedButton.styleFrom(side: BorderSide(color: _selectedDate == null ? theme.borderColor : theme.primaryColor), padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 15), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                      ),
                      if (_selectedDate != null) IconButton(onPressed: () => setState(() => _selectedDate = null), icon: Icon(Icons.clear_rounded, color: theme.errorColor)),
                      const SizedBox(width: 15),
                      _buildFilterDropdown("Trạng thái", _selectedFilter, _filterOptions, (val) => setState(() => _selectedFilter = val!), theme),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                Container(
                  width: double.infinity, decoration: BoxDecoration(color: theme.cardColor, borderRadius: BorderRadius.circular(16), border: Border.all(color: theme.borderColor)),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: DataTable(
                      showCheckboxColumn: false, headingRowColor: WidgetStateProperty.all(theme.primaryColor.withOpacity(0.05)), dataRowMaxHeight: 60,
                      columns: _buildDynamicColumns(theme),
                      rows: filteredStudents.map((student) {
                        var termData = _getTermData(student, _selectedYearFilter, _selectedSemesterFilter);
                        return DataRow(
                          onSelectChanged: (selected) {
                            if (selected == true) {
                              showDialog(
                                  context: context, builder: (_) => MemberProfileDialog(isAdmin: widget.isSuperAdmin,
                                  memberData: {
                                    "name": student["name"],
                                    "email": student["email"] ?? student["user"] ?? "Chưa có",
                                    "role": "Học sinh ${student['id']}",
                                    "avatar_url": student["avatar_url"] ?? "",
                                    "face_data": student["face_data"] ?? "",
                                    "dob": student["dob"] ?? "Chưa cập nhật",
                                    "phone": student["phone"] ?? "Chưa cập nhật",
                                    "hometown": student["hometown"] ?? "Chưa cập nhật",

                                    // ĐÃ THÁO CODE CỨNG Ở ĐÂY
                                    "religion": student["religion"] ?? "Không",
                                    "currentAddress": student["current_address"] ?? "Chưa cập nhật",
                                    "facebook": student["facebook"] ?? "Chưa liên kết",

                                    "jobRole": "Học sinh lớp $_currentClassName",
                                    "degree": "Khóa: $_currentClassAcademicYear",
                                    "school": "SAMS Cơ sở",
                                    "dynamicLabel1": "Giới tính",
                                    "dynamicValue1": student["gender"] ?? "Chưa rõ",
                                    "dynamicLabel2": "Tình trạng",
                                    "dynamicValue2": "Bình thường",
                                    "lateCount": termData["lateCount"],
                                    "absentCount": termData["absentCount"],
                                    "excusedCount": termData["excusedCount"],
                                    "violationHistory": <String>[]
                                  }
                              )
                              );
                            }
                          },
                          cells: _buildDynamicCells(student, termData, theme),
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ],
            ),
          );
        }
    );
  }

  Widget _buildClassTimetableGrid(AppTheme theme) {
    double cellW = 130 * theme.fontScale;
    double cellH = 70 * theme.fontScale;
    double timeW = 95 * theme.fontScale;

    List<Widget> gridRows = [];

    List<Widget> headerCells = [
      Container(width: timeW, height: 45, decoration: BoxDecoration(color: theme.primaryColor.withOpacity(0.15), border: Border(right: BorderSide(color: theme.borderColor), bottom: BorderSide(color: theme.borderColor))), child: Center(child: Text("TIẾT \\ NGÀY", style: TextStyle(color: theme.primaryColor, fontWeight: FontWeight.bold, fontSize: 10 * theme.fontScale))))
    ];

    for (int i = 0; i < 7; i++) {
      DateTime d = _timetableWeekStart.add(Duration(days: i));
      headerCells.add(
          Container(
              width: cellW, height: 45,
              decoration: BoxDecoration(color: theme.cardColor, border: Border(right: BorderSide(color: theme.borderColor), bottom: BorderSide(color: theme.borderColor))),
              child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(_getDayOfWeek(i), style: TextStyle(color: theme.textColor, fontWeight: FontWeight.bold, fontSize: 12 * theme.fontScale)),
                    Text(DateFormat('dd/MM').format(d), style: TextStyle(color: theme.subTextColor, fontSize: 10 * theme.fontScale)),
                  ]
              )
          )
      );
    }
    gridRows.add(Row(children: headerCells));

    for (int pIndex = 0; pIndex < _bellSchedule.length; pIndex++) {
      var period = _bellSchedule[pIndex];
      var nextPeriod = (pIndex < _bellSchedule.length - 1) ? _bellSchedule[pIndex + 1] : null;

      List<Widget> rowCells = [
        Container(
            width: timeW, height: cellH, padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(color: theme.cardColor, border: Border(right: BorderSide(color: theme.borderColor), bottom: BorderSide(color: theme.borderColor))),
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Text(period.name, style: TextStyle(color: theme.textColor, fontWeight: FontWeight.bold, fontSize: 11 * theme.fontScale)), Text(period.timeFrame, style: TextStyle(color: theme.subTextColor, fontSize: 9 * theme.fontScale))])
        )
      ];

      for (int d = 0; d < 7; d++) {
        DateTime currentDate = _timetableWeekStart.add(Duration(days: d));
        String dayStr = _getDayOfWeek(d);

        var cellData = _findCellDataForClass(currentDate, dayStr, period.timeFrame);

        bool mergeBottom = false;
        bool hideContent = false;
        Color? cellBgColor;
        bool isMySubject = false; // <-- Biến kiểm tra tiết này có phải của mình không

        if (cellData != null && cellData['status'] != 'Trống') {
          bool isCancelled = cellData['status'] == 'Nghỉ học';
          bool isSub = cellData['status'] == 'Dạy thế';
          bool isMakeup = cellData['status'] == 'Học bù';

          Color baseColor = _getTeacherColor(cellData['teacher_name'] ?? "", theme);
          if (cellData['type'] == 'Cuộc họp') baseColor = theme.purpleColor;
          if (cellData['type'] == 'Hoạt động') baseColor = theme.warningColor;
          cellBgColor = isCancelled ? theme.errorColor.withOpacity(0.2) : (isSub || isMakeup ? theme.infoColor.withOpacity(0.2) : baseColor.withOpacity(0.25));

          // Kiểm tra xem tiết này mình có dạy không
          String cTeacher = (cellData['teacher_name'] ?? "").toString();
          if (_currentLoggedInName.isNotEmpty && cTeacher.contains(_currentLoggedInName)) {
            isMySubject = true;
          }

          if (nextPeriod != null) {
            var b = _findCellDataForClass(currentDate, dayStr, nextPeriod.timeFrame);
            if (b != null && b['name'] == cellData['name'] && b['teacher_id'] == cellData['teacher_id'] && b['type'] == cellData['type']) mergeBottom = true;
          }
          if (pIndex > 0) {
            var t = _findCellDataForClass(currentDate, dayStr, _bellSchedule[pIndex - 1].timeFrame);
            if (t != null && t['name'] == cellData['name'] && t['teacher_id'] == cellData['teacher_id'] && t['type'] == cellData['type']) hideContent = true;
          }
        }

        // ==========================================
        // THUẬT TOÁN LÀM MỜ KHI LÀ GIÁO VIÊN BỘ MÔN
        // ==========================================
        // ==========================================
        // THUẬT TOÁN LÀM MỜ KHI LÀ GIÁO VIÊN BỘ MÔN
        // ==========================================
        bool isDimmed = false;
        bool isStudent = globals.currentUserRole == 'Học sinh' || globals.currentUserRole == 'Thành viên';

        // NẾU LÀ HỌC SINH: KHÔNG BAO GIỜ LÀM MỜ (XEM RÕ TOÀN BỘ LỚP MÌNH)
        if (!isStudent) {
          // Nếu không phải Admin và không phải Chủ nhiệm lớp này -> Đang là GV Bộ môn
          if (!widget.isSuperAdmin && !_isMyHomeroom) {
            // Làm mờ các ô trống hoặc các ô có môn học nhưng không phải do mình dạy
            if (cellData == null || cellData['status'] == 'Trống' || !isMySubject) {
              isDimmed = true;
            }
          }
        }

        // Tạo Widget Ô dữ liệu
        Widget cellWidget = Container(
            width: cellW, height: cellH,
            decoration: BoxDecoration(
              border: Border(
                  right: BorderSide(color: theme.borderColor),
                  bottom: mergeBottom ? BorderSide.none : BorderSide(color: theme.borderColor)
              ),
              color: cellBgColor ?? Colors.transparent,
            ),
            child: Material(
                color: Colors.transparent,
                child: InkWell(
                    hoverColor: theme.primaryColor.withOpacity(0.05),
                    onTap: () {
                      if (cellData != null && cellData['status'] != 'Trống') {
                        _showCellDetail(cellData, currentDate, dayStr, period, theme);
                      }
                    },
                    child: Padding(
                        padding: const EdgeInsets.all(2.0),
                        child: (cellData == null || cellData['status'] == 'Trống')
                            ? Center(child: Icon(Icons.add_rounded, color: theme.subTextColor.withOpacity(0.15), size: 18))
                            : (hideContent ? const SizedBox() : _buildCellText(cellData, theme))
                    )
                )
            )
        );

        // NẾU CẦN LÀM MỜ THÌ BỌC OPACITY = 0.35 VÀO Ô ĐÓ
        rowCells.add(isDimmed ? Opacity(opacity: 0.35, child: cellWidget) : cellWidget);
      }
      gridRows.add(Row(children: rowCells));
    }

    return Container(
        decoration: BoxDecoration(color: theme.cardColor, border: Border.all(color: theme.borderColor), borderRadius: BorderRadius.circular(12)),
        child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SingleChildScrollView(
                scrollDirection: Axis.vertical, physics: const BouncingScrollPhysics(),
                child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal, physics: const BouncingScrollPhysics(),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: gridRows)
                )
            )
        )
    );
  }

  Widget _buildCellText(Map<String, dynamic> data, AppTheme theme) {
    bool isCancelled = data['status'] == 'Nghỉ học';
    bool isSub = data['status'] == 'Dạy thế';
    bool isMakeup = data['status'] == 'Học bù';

    Color baseColor = _getTeacherColor(data['teacher_name'] ?? "", theme);
    if (data['type'] == 'Cuộc họp') baseColor = theme.purpleColor;
    if (data['type'] == 'Hoạt động') baseColor = theme.warningColor;

    Color textColor = isCancelled ? theme.errorColor : (isSub || isMakeup ? theme.infoColor : baseColor);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Flexible(child: Text(data['name'] ?? "", style: TextStyle(color: textColor, fontWeight: FontWeight.bold, decoration: isCancelled ? TextDecoration.lineThrough : null, fontSize: 12 * theme.fontScale), overflow: TextOverflow.ellipsis, textAlign: TextAlign.center)),
            if (isCancelled) Icon(Icons.block_rounded, color: theme.errorColor, size: 12)
            else if (isSub) Icon(Icons.swap_horiz_rounded, color: theme.infoColor, size: 12)
            else if (isMakeup) Icon(Icons.restore_rounded, color: theme.infoColor, size: 12)
          ]),
          const SizedBox(height: 2),
          Text(data['teacher_name'] ?? data['notes'] ?? "", style: TextStyle(color: theme.textColor, fontSize: 10 * theme.fontScale), overflow: TextOverflow.ellipsis, textAlign: TextAlign.center),
        ],
      ),
    );
  }

  void _showCellDetail(Map<String, dynamic> data, DateTime date, String dayStr, BellPeriod period, AppTheme theme) {
    Map<String, dynamic>? fullTeacherData;
    try {
      fullTeacherData = _teachersData.firstWhere((t) => t['user_id'] == data['teacher_id'],
          orElse: () => _teachersData.firstWhere((t) => t['name'] == data['teacher_name'], orElse: () => null)
      );
    } catch (e) {
      fullTeacherData = null;
    }

    bool isCancelled = data['status'] == 'Nghỉ học';
    bool isSub = data['status'] == 'Dạy thế';
    bool isMakeup = data['status'] == 'Học bù';

    Color baseColor = _getTeacherColor(data['teacher_name'] ?? "", theme);
    if (data['type'] == 'Cuộc họp') baseColor = theme.purpleColor;
    if (data['type'] == 'Hoạt động') baseColor = theme.warningColor;
    Color statusColor = isCancelled ? theme.errorColor : (isSub || isMakeup ? theme.infoColor : baseColor);

    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: theme.cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: theme.borderColor)),
        child: Container(
          width: 450,
          padding: const EdgeInsets.all(0),
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(20)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(25),
                decoration: BoxDecoration(color: statusColor.withOpacity(0.15)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(color: statusColor, borderRadius: BorderRadius.circular(6)),
                          child: Text(data['status'] ?? "Bình thường", style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                        ),
                        IconButton(onPressed: () => Navigator.pop(context), icon: Icon(Icons.close, color: theme.textColor), padding: EdgeInsets.zero, constraints: const BoxConstraints())
                      ],
                    ),
                    const SizedBox(height: 15),
                    Text(data['name'] ?? "Sự kiện", style: TextStyle(color: statusColor, fontWeight: FontWeight.w900, fontSize: 24, decoration: isCancelled ? TextDecoration.lineThrough : null)),
                    const SizedBox(height: 5),
                    Text("Thời gian: $dayStr, ${DateFormat('dd/MM/yyyy').format(date)}", style: TextStyle(color: theme.textColor, fontSize: 13)),
                    Text("Khung giờ: ${period.name} (${period.timeFrame})", style: TextStyle(color: theme.subTextColor, fontSize: 13)),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(25),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Người phụ trách", style: TextStyle(color: theme.textColor, fontWeight: FontWeight.bold, fontSize: 13)),
                    const SizedBox(height: 10),
                    Container(
                      decoration: BoxDecoration(color: theme.textColor.withOpacity(0.03), borderRadius: BorderRadius.circular(12), border: Border.all(color: theme.borderColor)),
                      child: ListTile(
                        onTap: () {
                          if (fullTeacherData != null) {
                            showDialog(context: context, builder: (_) => MemberProfileDialog(isAdmin: widget.isSuperAdmin, memberData: fullTeacherData!));
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: const Text("Hệ thống chưa tải được dữ liệu hồ sơ của người này."), backgroundColor: theme.warningColor));
                          }
                        },
                        leading: (fullTeacherData != null && fullTeacherData['avatar_url'] != null && fullTeacherData['avatar_url'].toString().isNotEmpty)
                            ? CircleAvatar(backgroundImage: NetworkImage("http://127.0.0.1:8000${fullTeacherData['avatar_url']}"))
                            : CircleAvatar(backgroundColor: statusColor.withOpacity(0.2), child: Icon(Icons.person, color: statusColor)),
                        title: Text(data['teacher_name'] ?? "Chưa gán", style: TextStyle(color: theme.textColor, fontWeight: FontWeight.bold)),
                        subtitle: Text(fullTeacherData != null ? "Nhấn để xem Hồ sơ" : "Dữ liệu ngoại tuyến", style: TextStyle(color: theme.subTextColor, fontSize: 11)),
                        trailing: Icon(Icons.arrow_forward_ios_rounded, color: theme.subTextColor, size: 16),
                      ),
                    ),
                    if (data['notes'] != null && data['notes'].toString().isNotEmpty) ...[
                      const SizedBox(height: 20),
                      Text("Ghi chú bổ sung", style: TextStyle(color: theme.textColor, fontWeight: FontWeight.bold, fontSize: 13)),
                      const SizedBox(height: 8),
                      Container(
                        width: double.infinity, padding: const EdgeInsets.all(15),
                        decoration: BoxDecoration(color: theme.warningColor.withOpacity(0.1), borderRadius: BorderRadius.circular(12), border: Border.all(color: theme.warningColor.withOpacity(0.3))),
                        child: Text(data['notes'].toString(), style: TextStyle(color: theme.textColor, fontSize: 13, height: 1.5)),
                      )
                    ]
                  ],
                ),
              )
            ],
          ),
        ),
      ),
    );
  }

  void _showEditClassDialog(BuildContext context, AppTheme theme) {
    showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) {
          String editClassName = _currentClassName;
          int editCourseStart = _courseStartYear;
          int editCourseEnd = _courseEndYear;

          Map<String, dynamic> editTeacherData = Map.from(_teacherData);
          String searchTeacherQuery = "";

          return StatefulBuilder(
              builder: (context, setStateDialog) {
                bool isLastYear = _currentYearEnd >= editCourseEnd;

                List<dynamic> filteredTeachers = _teachersData.where((t) {
                  String tName = (t['name'] ?? "").toString().toLowerCase();
                  String tRole = (t['role'] ?? "").toString().toLowerCase();
                  return tName.contains(searchTeacherQuery.toLowerCase()) || tRole.contains(searchTeacherQuery.toLowerCase());
                }).toList();

                return Dialog(
                  backgroundColor: theme.cardColor,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24), side: BorderSide(color: theme.borderColor)),
                  child: Container(
                    width: 850, height: 750,
                    clipBehavior: Clip.antiAlias,
                    decoration: BoxDecoration(borderRadius: BorderRadius.circular(24)),
                    child: DefaultTabController(
                      length: 3,
                      child: Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(20), color: theme.textColor.withOpacity(0.02),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text("Quản Trị Lớp: $_currentClassName", style: TextStyle(color: theme.textColor, fontSize: 20 * theme.fontScale, fontWeight: FontWeight.bold)),
                                IconButton(onPressed: () => Navigator.pop(context), icon: Icon(Icons.close_rounded, color: theme.subTextColor))
                              ],
                            ),
                          ),
                          TabBar(
                            indicatorColor: theme.primaryColor, labelColor: theme.primaryColor, unselectedLabelColor: theme.subTextColor,
                            tabs: const [
                              Tab(icon: Icon(Icons.info_outline), text: "Cấu hình Lớp"),
                              Tab(icon: Icon(Icons.groups_rounded), text: "Học sinh"),
                              Tab(icon: Icon(Icons.badge_rounded), text: "Giáo viên CN"),
                            ],
                          ),
                          Expanded(
                            child: TabBarView(
                              children: [
                                SingleChildScrollView(
                                  padding: const EdgeInsets.all(30),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      _buildDialogTextField("Tên lớp", editClassName, (v) => editClassName = v, theme),
                                      const SizedBox(height: 25),

                                      Container(
                                        padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: theme.purpleColor.withOpacity(0.05), borderRadius: BorderRadius.circular(12), border: Border.all(color: theme.purpleColor.withOpacity(0.3))),
                                        child: Row(
                                          children: [
                                            Icon(Icons.timeline_rounded, color: theme.purpleColor, size: 30 * theme.fontScale), const SizedBox(width: 15),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text("NIÊN KHÓA HỌC (VÒNG ĐỜI TOÀN KHOÁ)", style: TextStyle(color: theme.purpleColor, fontWeight: FontWeight.bold, fontSize: 13 * theme.fontScale)), const SizedBox(height: 8),
                                                  Row(
                                                    children: [
                                                      Text("Bắt đầu năm: ", style: TextStyle(color: theme.subTextColor, fontSize: 13 * theme.fontScale)),
                                                      SizedBox(width: 100, child: DropdownButtonFormField<int>(value: editCourseStart, dropdownColor: theme.cardColor, decoration: const InputDecoration(isDense: true, contentPadding: EdgeInsets.all(10)), items: [2024, 2025, 2026, 2027].map((e) => DropdownMenuItem(value: e, child: Text(e.toString(), style: TextStyle(color: theme.textColor, fontSize: 13 * theme.fontScale)))).toList(), onChanged: (v) => setStateDialog(() => editCourseStart = v!))),
                                                      const SizedBox(width: 20),
                                                      Text("Kết thúc năm: ", style: TextStyle(color: theme.subTextColor, fontSize: 13 * theme.fontScale)),
                                                      SizedBox(width: 100, child: DropdownButtonFormField<int>(value: editCourseEnd, dropdownColor: theme.cardColor, decoration: const InputDecoration(isDense: true, contentPadding: EdgeInsets.all(10)), items: [2026, 2027, 2028, 2029].map((e) => DropdownMenuItem(value: e, child: Text(e.toString(), style: TextStyle(color: theme.textColor, fontSize: 13 * theme.fontScale)))).toList(), onChanged: (v) => setStateDialog(() => editCourseEnd = v!))),
                                                    ],
                                                  )
                                                ],
                                              ),
                                            )
                                          ],
                                        ),
                                      ),
                                      const SizedBox(height: 30), Divider(color: theme.borderColor), const SizedBox(height: 20),

                                      Row(children: [Icon(Icons.history_toggle_off_rounded, color: theme.warningColor, size: 20 * theme.fontScale), const SizedBox(width: 10), Text("TIẾN TRÌNH NĂM HỌC HIỆN TẠI", style: TextStyle(color: theme.warningColor, fontWeight: FontWeight.bold, fontSize: 13 * theme.fontScale))]),
                                      const SizedBox(height: 10),
                                      Text("Bạn đang ở: Năm $_currentYearStart-$_currentYearEnd | $_currentSemester. Khi tiến lên, dữ liệu hiện tại sẽ được lưu vào Lịch sử.", style: TextStyle(color: theme.subTextColor, fontSize: 12 * theme.fontScale)),
                                      const SizedBox(height: 20),

                                      Row(
                                        children: [
                                          Expanded(
                                            child: ElevatedButton.icon(
                                              onPressed: () => _confirmAction(context, "Kết thúc Học kỳ hiện tại để chuyển sang Kỳ mới?", () {
                                                setStateDialog(() {
                                                  if (!_historicalSemesters.contains(_currentSemester)) _historicalSemesters.add(_currentSemester);
                                                  int num = int.parse(_currentSemester.split(' ')[2]);
                                                  _currentSemester = "Học kỳ ${num + 1}";
                                                });
                                                setState((){});
                                              }),
                                              icon: Icon(Icons.skip_next_rounded, color: theme.isDarkMode ? Colors.black : Colors.white), label: Text("Chuyển lên Học kỳ tiếp theo", style: TextStyle(color: theme.isDarkMode ? Colors.black : Colors.white, fontWeight: FontWeight.bold)),
                                              style: ElevatedButton.styleFrom(backgroundColor: theme.warningColor, padding: const EdgeInsets.symmetric(vertical: 16)),
                                            ),
                                          ),
                                          const SizedBox(width: 15),
                                          Expanded(
                                            child: ElevatedButton.icon(
                                              onPressed: isLastYear ? null : () => _confirmAction(context, "Kết thúc Năm học hiện tại để chuyển sang Năm mới?", () {
                                                setStateDialog(() {
                                                  if (!_historicalYears.contains("$_currentYearStart-$_currentYearEnd")) _historicalYears.add("$_currentYearStart-$_currentYearEnd");
                                                  _currentYearStart++; _currentYearEnd++;
                                                  _currentSemester = "Học kỳ 1";
                                                });
                                                setState((){});
                                              }),
                                              icon: Icon(isLastYear ? Icons.block_rounded : Icons.fast_forward_rounded, color: isLastYear ? theme.subTextColor : Colors.white),
                                              label: Text(isLastYear ? "Đã đến năm cuối khóa" : "Lên lớp (Năm học mới)", style: TextStyle(color: isLastYear ? theme.subTextColor : Colors.white, fontWeight: FontWeight.bold)),
                                              style: ElevatedButton.styleFrom(backgroundColor: isLastYear ? theme.textColor.withOpacity(0.1) : theme.primaryColor, padding: const EdgeInsets.symmetric(vertical: 16)),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 40),

                                      Container(
                                        padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: theme.errorColor.withOpacity(0.05), borderRadius: BorderRadius.circular(12), border: Border.all(color: theme.errorColor.withOpacity(0.3))),
                                        child: Row(
                                          children: [
                                            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text("KẾT THÚC VÒNG ĐỜI LỚP HỌC", style: TextStyle(color: theme.errorColor, fontWeight: FontWeight.bold, fontSize: 13 * theme.fontScale)), const SizedBox(height: 4), Text("Học sinh ra trường/giải tán. Lớp sẽ bị đóng băng, không thể thao tác thêm.", style: TextStyle(color: theme.errorColor.withOpacity(0.7), fontSize: 12 * theme.fontScale))])),
                                            ElevatedButton(
                                              onPressed: () => _confirmAction(context, "CẢNH BÁO: Lớp sẽ bị đóng băng hoàn toàn. Bạn có chắc chắn?", () {
                                                Navigator.pop(context);
                                                Navigator.pop(context);
                                                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Lớp học đã hoàn thành khóa và được đóng băng thành công!"), backgroundColor: Colors.orange));
                                              }),
                                              style: ElevatedButton.styleFrom(backgroundColor: theme.errorColor), child: const Text("HOÀN THÀNH / GIẢI TÁN", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                            )
                                          ],
                                        ),
                                      )
                                    ],
                                  ),
                                ),

                                Column(
                                  children: [
                                    Padding(
                                      padding: const EdgeInsets.all(20.0),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text("Sĩ số: ${allStudents.length}", style: TextStyle(color: theme.textColor, fontWeight: FontWeight.bold, fontSize: 14 * theme.fontScale)),
                                          ElevatedButton.icon(
                                              onPressed: () => _showAddStudentDialog(context, setStateDialog, theme),
                                              icon: const Icon(Icons.person_add_rounded, color: Colors.white), label: const Text("Thêm học sinh", style: TextStyle(color: Colors.white)), style: ElevatedButton.styleFrom(backgroundColor: theme.successColor)
                                          )
                                        ],
                                      ),
                                    ),
                                    Expanded(
                                      child: ListView.builder(
                                        padding: const EdgeInsets.symmetric(horizontal: 20),
                                        itemCount: allStudents.length,
                                        itemBuilder: (context, index) {
                                          var st = allStudents[index];
                                          return Container(
                                            margin: const EdgeInsets.only(bottom: 10), decoration: BoxDecoration(color: theme.textColor.withOpacity(0.03), borderRadius: BorderRadius.circular(12)),
                                            child: ListTile(
                                              leading: CircleAvatar(backgroundColor: theme.primaryColor.withOpacity(0.1), child: Icon(Icons.person, color: theme.primaryColor, size: 16 * theme.fontScale)),
                                              title: Text(st['name'], style: TextStyle(color: theme.textColor, fontSize: 14 * theme.fontScale, fontWeight: FontWeight.bold)),
                                              subtitle: Text(st['id'], style: TextStyle(color: theme.subTextColor, fontSize: 12 * theme.fontScale)),
                                              trailing: PopupMenuButton<String>(
                                                icon: Icon(Icons.more_vert, color: theme.subTextColor), color: theme.cardColor,
                                                onSelected: (val) {
                                                  if (val == 'transfer') _showTransferDialog(context, st['name'], index, setStateDialog, theme);
                                                  else if (val == 'delete') {
                                                    setStateDialog(() => allStudents.removeAt(index));
                                                    setState((){});
                                                  }
                                                },
                                                itemBuilder: (context) => [PopupMenuItem(value: 'transfer', child: Text("Chuyển sang lớp khác", style: TextStyle(color: theme.textColor))), PopupMenuItem(value: 'delete', child: Text("Xóa khỏi danh sách", style: TextStyle(color: theme.errorColor)))],
                                              ),
                                            ),
                                          );
                                        },
                                      ),
                                    ),
                                  ],
                                ),

                                Column(
                                  children: [
                                    Padding(
                                      padding: const EdgeInsets.all(20.0),
                                      child: TextField(
                                        style: TextStyle(color: theme.textColor),
                                        onChanged: (val) => setStateDialog(() => searchTeacherQuery = val),
                                        decoration: InputDecoration(
                                          hintText: "Tìm kiếm giáo viên theo tên hoặc chức vụ...",
                                          hintStyle: TextStyle(color: theme.subTextColor),
                                          prefixIcon: Icon(Icons.search_rounded, color: theme.primaryColor),
                                          filled: true,
                                          fillColor: theme.textColor.withOpacity(0.04),
                                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                                        ),
                                      ),
                                    ),
                                    Expanded(
                                      child: ListView.builder(
                                        padding: const EdgeInsets.symmetric(horizontal: 20),
                                        itemCount: filteredTeachers.length,
                                        itemBuilder: (context, index) {
                                          var t = filteredTeachers[index];

                                          // TÌM ID CHÍNH XÁC CỦA CẢ 2 BÊN
                                          int? tId = t['user_id'] ?? t['id'];
                                          int? selectedId = editTeacherData['user_id'] ?? editTeacherData['id'];

                                          String assignedClass = "";
                                          String? tIdStr = tId?.toString();

                                          if (tIdStr != null && _teacherClassMap.containsKey(tIdStr)) {
                                            assignedClass = _teacherClassMap[tIdStr]!;
                                          } else {
                                            assignedClass = t['unit']?.toString() ?? "";
                                          }

                                          bool isCurrentClassTeacher = assignedClass == _currentClassName;
                                          bool isBusy = assignedClass.isNotEmpty && !isCurrentClassTeacher;

                                          // =====================================
                                          // ĐÃ FIX: CHỐNG LỖI KÉO THEO TẤT CẢ
                                          // =====================================
                                          bool isSelected = false;
                                          if (selectedId != null && tId != null) {
                                            isSelected = (selectedId == tId);
                                          } else if (editTeacherData['name'] != null && t['name'] != null) {
                                            isSelected = (editTeacherData['name'] == t['name']);
                                          }

                                          return Container(
                                            margin: const EdgeInsets.only(bottom: 10),
                                            decoration: BoxDecoration(
                                              color: isSelected
                                                  ? theme.primaryColor.withOpacity(0.12)
                                                  : (isBusy ? theme.errorColor.withOpacity(0.06) : theme.textColor.withOpacity(0.02)),
                                              borderRadius: BorderRadius.circular(12),
                                              border: Border.all(
                                                color: isSelected
                                                    ? theme.primaryColor
                                                    : (isBusy ? theme.errorColor.withOpacity(0.4) : Colors.transparent),
                                                width: 1.5,
                                              ),
                                            ),
                                            child: ListTile(
                                              onTap: isBusy ? null : () {
                                                setStateDialog(() => editTeacherData = Map.from(t));
                                              },
                                              leading: (t['avatar_url'] != null && t['avatar_url'].toString().isNotEmpty)
                                                  ? CircleAvatar(backgroundImage: NetworkImage("http://127.0.0.1:8000${t['avatar_url']}"))
                                                  : CircleAvatar(backgroundColor: theme.primaryColor.withOpacity(0.2), child: Icon(Icons.person, color: theme.primaryColor)),

                                              title: Text(
                                                t['name'] ?? "Chưa rõ",
                                                style: TextStyle(
                                                  color: isBusy ? theme.subTextColor : theme.textColor,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                              subtitle: Text(
                                                isBusy
                                                    ? "Đang chủ nhiệm: $assignedClass"
                                                    : (t['role'] ?? "Giáo viên"),
                                                style: TextStyle(
                                                  color: isBusy ? theme.errorColor : theme.subTextColor,
                                                  fontWeight: isBusy ? FontWeight.bold : FontWeight.normal,
                                                ),
                                              ),
                                              trailing: isBusy
                                                  ? const Icon(Icons.block_rounded, color: Colors.red)
                                                  : (isSelected
                                                  ? Icon(Icons.check_circle_rounded, color: theme.primaryColor, size: 28)
                                                  : Icon(Icons.circle_outlined, color: theme.subTextColor)),
                                            ),
                                          );
                                        },
                                      ),
                                    )
                                  ],
                                )
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.all(20), decoration: BoxDecoration(border: Border(top: BorderSide(color: theme.borderColor))),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                TextButton(onPressed: () => Navigator.pop(context), child: Text("Đóng", style: TextStyle(color: theme.subTextColor))), const SizedBox(width: 15),
                                ElevatedButton(
                                  onPressed: () async {
                                    int? tId = editTeacherData['user_id'] ?? editTeacherData['id'];

                                    Map<String, dynamic> payload = {
                                      "class_name": editClassName,
                                      "teacher_id": tId,
                                      "teacher_name": editTeacherData['name'] ?? "Chưa phân công",
                                      "course_start_year": editCourseStart,
                                      "course_end_year": editCourseEnd,
                                      "current_year_start": _currentYearStart,
                                      "current_year_end": _currentYearEnd,
                                      "current_semester": _currentSemester,
                                      "timetable": _classTimetable,
                                      "students": allStudents
                                    };

                                    try {
                                      var response = await http.put(
                                          Uri.parse('http://127.0.0.1:8000/api/classes/${widget.classId}'),
                                          headers: {"Content-Type": "application/json"},
                                          body: jsonEncode(payload)
                                      );

                                      if (response.statusCode == 200) {
                                        var data = jsonDecode(response.body);
                                        if (data['status'] == 'success') {
                                          setState(() {
                                            _currentClassName = editClassName;
                                            _currentTeacher = editTeacherData['name'] ?? "Chưa phân công";
                                            _teacherData = editTeacherData;
                                            _courseStartYear = editCourseStart;
                                            _courseEndYear = editCourseEnd;
                                          });
                                          if (context.mounted) Navigator.pop(context);
                                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Đã lưu Cấu hình Lớp học an toàn!"), backgroundColor: Colors.green));
                                          widget.onDataChanged?.call();
                                        }
                                      }
                                    } catch (e) {
                                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Lỗi kết nối đến Server!"), backgroundColor: Colors.redAccent));
                                    }
                                  },
                                  style: ElevatedButton.styleFrom(backgroundColor: theme.primaryColor, padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14)), child: const Text("LƯU THAY ĐỔI", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                )
                              ],
                            ),
                          )
                        ],
                      ),
                    ),
                  ),
                );
              }
          );
        }
    );
  }

  String _generateAutoPassword(String fullName, String dob) {
    if (fullName.isEmpty || dob.isEmpty) return "12345678";
    String firstName = fullName.trim().split(' ').last.toLowerCase();
    const withDia = 'áàảãạăâắằẳẵặâấầẩẫậéèẻẽẹêếềểễệíìỉĩịóòỏõọôốồổỗộơớờởỡợúùủũụưứừửữựýỳỷỹỵđ';
    const withoutDia = 'aaaaaaaaaaaaaaaaaeeeeeeeeeeeiiiiiooooooooooooooooouuuuuuuuuuuyyyyyd';
    for (int i = 0; i < withDia.length; i++) {
      firstName = firstName.replaceAll(withDia[i], withoutDia[i]);
    }
    String cleanDob = dob.replaceAll('/', '').replaceAll('-', '').replaceAll(' ', '');
    return "$firstName$cleanDob";
  }

  void _showAddStudentDialog(BuildContext context, StateSetter parentSetState, AppTheme theme) {
    String newId = "HS${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}";
    String newName = "";
    String newGender = "Nam";
    String newDob = "";
    String newParent = "";
    String newPhone = "";
    String newEmail = "";

    showDialog(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: theme.cardColor,
          title: Text("Thêm Học Sinh Mới", style: TextStyle(color: theme.textColor, fontWeight: FontWeight.bold)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildDialogTextField("Mã HS (Tự động)", newId, (v) => newId = v, theme), const SizedBox(height: 15),
                _buildDialogTextField("Họ và Tên", newName, (v) => newName = v, theme), const SizedBox(height: 15),
                _buildFilterDropdown("Giới tính", newGender, ["Nam", "Nữ"], (v) => newGender = v!, theme), const SizedBox(height: 15),
                _buildDialogTextField("Ngày sinh (dd/mm/yyyy)", newDob, (v) => newDob = v, theme), const SizedBox(height: 15),
                _buildDialogTextField("Gmail cá nhân (Tài khoản)", newEmail, (v) => newEmail = v, theme), const SizedBox(height: 15),
                _buildDialogTextField("Số điện thoại", newPhone, (v) => newPhone = v, theme), const SizedBox(height: 15),
                _buildDialogTextField("Tên Phụ huynh (Tùy chọn)", newParent, (v) => newParent = v, theme),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: Text("Hủy", style: TextStyle(color: theme.subTextColor))),
            ElevatedButton(
              onPressed: () {
                if (newName.isNotEmpty && newDob.isNotEmpty && newEmail.isNotEmpty) {
                  String autoPass = _generateAutoPassword(newName, newDob);

                  parentSetState(() {
                    allStudents.add({
                      "id": newId,
                      "name": newName,
                      "gender": newGender,
                      "dob": newDob,
                      "parent": newParent,
                      "phone": newPhone,
                      "email": newEmail,
                      "password": autoPass,
                      "attendance": {"$_currentYearStart-$_currentYearEnd": {_currentSemester: {"lateCount": 0, "absentCount": 0, "excusedCount": 0, "history": <String>[]}}}
                    });
                  });
                  setState((){});
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Thêm thành công! Mật khẩu mặc định là: $autoPass"), backgroundColor: Colors.green));
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Vui lòng điền đủ Tên, Ngày sinh và Gmail!"), backgroundColor: Colors.red));
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: theme.primaryColor), child: const Text("Thêm vào lớp", style: TextStyle(color: Colors.white)),
            )
          ],
        )
    );
  }

  void _confirmAction(BuildContext context, String message, VoidCallback onConfirm) {
    showDialog(context: context, builder: (context) => AlertDialog(backgroundColor: AppTheme.instance.cardColor, title: Row(children: [Icon(Icons.warning_amber_rounded, color: AppTheme.instance.warningColor), const SizedBox(width: 10), Text("Xác nhận", style: TextStyle(color: AppTheme.instance.textColor))]), content: Text(message, style: TextStyle(color: AppTheme.instance.subTextColor)), actions: [TextButton(onPressed: () => Navigator.pop(context), child: Text("Hủy", style: TextStyle(color: AppTheme.instance.subTextColor))), ElevatedButton(onPressed: () { onConfirm(); Navigator.pop(context); }, style: ElevatedButton.styleFrom(backgroundColor: AppTheme.instance.warningColor), child: const Text("Đồng ý", style: TextStyle(color: Colors.black)))]));
  }

  void _showTransferDialog(BuildContext context, String studentName, int index, StateSetter setStateDialog, AppTheme theme) {
    String targetClass = 'Lớp 10A2';
    showDialog(context: context, builder: (context) => AlertDialog(backgroundColor: theme.cardColor, title: Text("Chuyển lớp", style: TextStyle(color: theme.textColor)), content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [Text("Chuyển học sinh '$studentName' sang lớp:", style: TextStyle(color: theme.subTextColor)), const SizedBox(height: 15), DropdownButtonFormField<String>(value: targetClass, dropdownColor: theme.cardColor, style: TextStyle(color: theme.textColor, fontSize: 13 * theme.fontScale), decoration: InputDecoration(filled: true, fillColor: theme.textColor.withOpacity(0.03), border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none)), items: ['Lớp 10A2', 'Lớp 11B1', 'Lớp 12C3'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(), onChanged: (val) => targetClass = val!)]), actions: [TextButton(onPressed: () => Navigator.pop(context), child: Text("Hủy", style: TextStyle(color: theme.subTextColor))), ElevatedButton(onPressed: () { setStateDialog(() => allStudents.removeAt(index)); setState((){}); Navigator.pop(context); ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Đã chuyển $studentName sang $targetClass"), backgroundColor: Colors.green)); }, style: ElevatedButton.styleFrom(backgroundColor: theme.primaryColor), child: const Text("Xác nhận chuyển", style: TextStyle(color: Colors.white)))]));
  }

  Widget _buildFilterDropdown(String label, String value, List<String> items, Function(String?) onChanged, AppTheme theme) { String safeValue = items.contains(value) ? value : items.first; return Container(height: 45, decoration: BoxDecoration(color: theme.textColor.withOpacity(0.02), borderRadius: BorderRadius.circular(10)), child: DropdownButtonHideUnderline(child: DropdownButton<String>(value: safeValue, dropdownColor: theme.cardColor, icon: Icon(Icons.arrow_drop_down, color: theme.primaryColor), padding: const EdgeInsets.symmetric(horizontal: 15), style: TextStyle(color: theme.textColor, fontSize: 13 * theme.fontScale, fontWeight: FontWeight.bold), items: items.map((opt) => DropdownMenuItem(value: opt, child: Text(opt))).toList(), onChanged: onChanged))); }
  Widget _buildDialogTextField(String label, String value, Function(String) onChanged, AppTheme theme, {String? hint, IconData? icon}) {
    return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: TextStyle(color: theme.textColor, fontSize: 12 * theme.fontScale, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          TextFormField(
              initialValue: value,
              onChanged: onChanged,
              style: TextStyle(color: theme.textColor, fontSize: 13 * theme.fontScale),
              decoration: InputDecoration(
                  hintText: hint,
                  hintStyle: TextStyle(color: theme.subTextColor.withOpacity(0.5)),
                  prefixIcon: icon != null ? Icon(icon, color: theme.primaryColor, size: 18) : null,
                  filled: true,
                  fillColor: theme.textColor.withOpacity(0.03),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none)
              )
          )
        ]
    );
  }
  Widget _buildSectionHeader(IconData icon, String title, AppTheme theme) => Row(children: [AnimatedContainer(duration: const Duration(milliseconds: 300), child: Icon(icon, color: theme.primaryColor, size: 18 * theme.fontScale)), const SizedBox(width: 10), AnimatedDefaultTextStyle(duration: const Duration(milliseconds: 300), style: TextStyle(color: theme.textColor, fontSize: 14 * theme.fontScale, fontWeight: FontWeight.bold, letterSpacing: 1.2, fontFamily: 'Segoe UI'), child: Text(title))]);
  Widget _buildDialogDropdown(String label, String value, List<String> items, Function(String?) onChanged, AppTheme theme) {
    String safeValue = items.contains(value) ? value : items.first;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
      Text(label, style: TextStyle(color: theme.textColor, fontSize: 12 * theme.fontScale, fontWeight: FontWeight.bold)),
      const SizedBox(height: 8),
      SizedBox(height: 45, child: DropdownButtonFormField<String>(value: safeValue, dropdownColor: theme.cardColor, style: TextStyle(color: theme.textColor, fontSize: 13 * theme.fontScale), decoration: InputDecoration(contentPadding: const EdgeInsets.symmetric(horizontal: 15), filled: true, fillColor: theme.textColor.withOpacity(0.03), border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none)), items: items.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(), onChanged: onChanged))
    ]);
  }
  List<DataColumn> _buildDynamicColumns(AppTheme theme) {
    List<DataColumn> cols = [
      DataColumn(label: Text("Mã HS", style: TextStyle(color: theme.primaryColor, fontWeight: FontWeight.bold))),
      DataColumn(label: Text("Họ và Tên", style: TextStyle(color: theme.primaryColor, fontWeight: FontWeight.bold))),
      DataColumn(label: Text("Ngày sinh", style: TextStyle(color: theme.primaryColor, fontWeight: FontWeight.bold))),
      DataColumn(label: Text("Giới tính", style: TextStyle(color: theme.primaryColor, fontWeight: FontWeight.bold))),
      DataColumn(label: Text("Tài khoản (Gmail)", style: TextStyle(color: theme.primaryColor, fontWeight: FontWeight.bold)))
    ];

    if (_selectedFilter == 'Vi phạm') {
      cols.addAll([
        DataColumn(label: Text("Đi Trễ", style: TextStyle(color: theme.warningColor, fontWeight: FontWeight.bold))),
        DataColumn(label: Text("Nghỉ Học", style: TextStyle(color: theme.errorColor, fontWeight: FontWeight.bold)))
      ]);
    }
    else if (_selectedFilter == 'Đi trễ') { cols.add(DataColumn(label: Text("Đi Trễ", style: TextStyle(color: theme.warningColor, fontWeight: FontWeight.bold)))); }
    else if (_selectedFilter == 'Nghỉ học') { cols.add(DataColumn(label: Text("Nghỉ Học", style: TextStyle(color: theme.errorColor, fontWeight: FontWeight.bold)))); }
    else if (_selectedFilter == 'Có phép') { cols.add(DataColumn(label: Text("Có phép", style: TextStyle(color: theme.infoColor, fontWeight: FontWeight.bold)))); }
    return cols;
  }

  List<DataCell> _buildDynamicCells(Map<String, dynamic> student, Map<String, dynamic> termData, AppTheme theme) {
    Map<String, int> stats = _calculateDisciplineStats(student);

    termData["lateCount"] = stats['late'];
    termData["absentCount"] = stats['absent'];
    termData["excusedCount"] = stats['excused'];

    List<DataCell> cells = [
      DataCell(Text(student["id"] ?? student["student_code"] ?? "", style: TextStyle(color: theme.primaryColor, fontWeight: FontWeight.bold))),
      DataCell(Text(student["name"] ?? student["full_name"] ?? "", style: TextStyle(color: theme.textColor, fontWeight: FontWeight.bold))),
      DataCell(Text(student["dob"] ?? "Chưa rõ", style: TextStyle(color: theme.subTextColor))),
      DataCell(Text(student["gender"] ?? "Nam", style: TextStyle(color: theme.subTextColor))),
      DataCell(Text(student["email"] ?? student["user"] ?? "Chưa có", style: TextStyle(color: theme.warningColor, fontWeight: FontWeight.bold))),
    ];

    if (_selectedFilter == 'Vi phạm') {
      cells.addAll([
        DataCell(
            stats['late']! > 0
                ? Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2), decoration: BoxDecoration(color: theme.warningColor.withOpacity(0.1), borderRadius: BorderRadius.circular(4)), child: Text("${stats['late']} lần", style: TextStyle(color: theme.warningColor, fontWeight: FontWeight.bold)))
                : Text("-", style: TextStyle(color: theme.subTextColor.withOpacity(0.3)))
        ),
        DataCell(
            stats['absent']! > 0
                ? Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2), decoration: BoxDecoration(color: theme.errorColor.withOpacity(0.1), borderRadius: BorderRadius.circular(4)), child: Text("${stats['absent']} lần", style: TextStyle(color: theme.errorColor, fontWeight: FontWeight.bold)))
                : Text("-", style: TextStyle(color: theme.subTextColor.withOpacity(0.3)))
        )
      ]);
    }
    else if (_selectedFilter == 'Đi trễ') {
      cells.add(DataCell(
          stats['late']! > 0
              ? Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2), decoration: BoxDecoration(color: theme.warningColor.withOpacity(0.1), borderRadius: BorderRadius.circular(4)), child: Text("${stats['late']} lần", style: TextStyle(color: theme.warningColor, fontWeight: FontWeight.bold)))
              : Text("-", style: TextStyle(color: theme.subTextColor.withOpacity(0.3)))
      ));
    }
    else if (_selectedFilter == 'Nghỉ học') {
      cells.add(DataCell(
          stats['absent']! > 0
              ? Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2), decoration: BoxDecoration(color: theme.errorColor.withOpacity(0.1), borderRadius: BorderRadius.circular(4)), child: Text("${stats['absent']} lần", style: TextStyle(color: theme.errorColor, fontWeight: FontWeight.bold)))
              : Text("-", style: TextStyle(color: theme.subTextColor.withOpacity(0.3)))
      ));
    }
    else if (_selectedFilter == 'Có phép') {
      cells.add(DataCell(
          stats['excused']! > 0
              ? Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2), decoration: BoxDecoration(color: theme.infoColor.withOpacity(0.1), borderRadius: BorderRadius.circular(4)), child: Text("${stats['excused']} lần", style: TextStyle(color: theme.infoColor, fontWeight: FontWeight.bold)))
              : Text("-", style: TextStyle(color: theme.subTextColor.withOpacity(0.3)))
      ));
    }

    return cells;
  }
  void _showStudentLeaveDialog(AppTheme theme) {
    String leaveMode = 'Theo ngày';
    bool isOneDay = true;
    String startDate = DateFormat('dd/MM/yyyy').format(DateTime.now());
    String endDate = DateFormat('dd/MM/yyyy').format(DateTime.now());

    // ĐÃ FIX: LẤY DANH SÁCH TIẾT HỌC TỪ CẤU HÌNH BELL SCHEDULE
    List<String> periodNames = _bellSchedule.map((e) => e.name).toList();
    if (periodNames.isEmpty) periodNames = ['Tiết 1', 'Tiết 2', 'Tiết 3', 'Tiết 4', 'Tiết 5'];

    // Khởi tạo mặc định là Tiết đầu tiên trong danh sách
    List<Map<String, String>> subjectLeaves = [{"date": startDate, "subject": periodNames.first}];
    String reason = "";

    showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) {
          return StatefulBuilder(
              builder: (context, setStateDialog) {
                return Dialog(
                  backgroundColor: theme.cardColor,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24), side: BorderSide(color: theme.infoColor.withOpacity(0.5))),
                  child: Container(
                    width: 600, padding: const EdgeInsets.all(30),
                    child: Column(
                      mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(children: [Icon(Icons.edit_document, color: theme.infoColor, size: 28 * theme.fontScale), const SizedBox(width: 15), Text("Gửi Đơn Xin Nghỉ", style: TextStyle(color: theme.textColor, fontWeight: FontWeight.bold, fontSize: 20 * theme.fontScale))]),
                            IconButton(onPressed: () => Navigator.pop(context), icon: Icon(Icons.close_rounded, color: theme.subTextColor))
                          ],
                        ),
                        const SizedBox(height: 10), Text("Đơn xin nghỉ sẽ được gửi đến GVCN và GVBM liên quan để xét duyệt.", style: TextStyle(color: theme.subTextColor, fontSize: 13 * theme.fontScale)), const SizedBox(height: 30),

                        Row(
                          children: [
                            Expanded(child: GestureDetector(
                              onTap: () => setStateDialog(() => leaveMode = 'Theo ngày'),
                              child: AnimatedContainer(duration: const Duration(milliseconds: 300), padding: const EdgeInsets.symmetric(vertical: 12), decoration: BoxDecoration(color: leaveMode == 'Theo ngày' ? theme.infoColor.withOpacity(0.2) : theme.textColor.withOpacity(0.03), borderRadius: BorderRadius.circular(10), border: Border.all(color: leaveMode == 'Theo ngày' ? theme.infoColor : theme.borderColor, width: 1.5)), child: Center(child: Text("Nghỉ theo ngày", style: TextStyle(color: leaveMode == 'Theo ngày' ? theme.infoColor : theme.subTextColor, fontWeight: FontWeight.bold, fontSize: 13)))),
                            )), const SizedBox(width: 15),
                            Expanded(child: GestureDetector(
                              onTap: () => setStateDialog(() => leaveMode = 'Theo tiết'),
                              child: AnimatedContainer(duration: const Duration(milliseconds: 300), padding: const EdgeInsets.symmetric(vertical: 12), decoration: BoxDecoration(color: leaveMode == 'Theo tiết' ? theme.infoColor.withOpacity(0.2) : theme.textColor.withOpacity(0.03), borderRadius: BorderRadius.circular(10), border: Border.all(color: leaveMode == 'Theo tiết' ? theme.infoColor : theme.borderColor, width: 1.5)), child: Center(child: Text("Nghỉ theo tiết", style: TextStyle(color: leaveMode == 'Theo tiết' ? theme.infoColor : theme.subTextColor, fontWeight: FontWeight.bold, fontSize: 13)))),
                            )),
                          ],
                        ),
                        const SizedBox(height: 25),

                        Container(
                          constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.4),
                          child: SingleChildScrollView(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (leaveMode == 'Theo ngày') ...[
                                  Row(children: [
                                    Checkbox(value: isOneDay, activeColor: theme.infoColor, onChanged: (v) => setStateDialog(() => isOneDay = v!)),
                                    Text("Chỉ nghỉ 1 ngày", style: TextStyle(color: theme.textColor, fontWeight: FontWeight.bold))
                                  ]),
                                  const SizedBox(height: 10),
                                  Row(
                                    children: [
                                      Expanded(child: _buildDialogTextField("Từ ngày", startDate, (v) => startDate = v, theme, hint: "dd/mm/yyyy", icon: Icons.calendar_today_rounded)),
                                      if (!isOneDay) ...[
                                        const SizedBox(width: 20),
                                        Expanded(child: _buildDialogTextField("Đến ngày", endDate, (v) => endDate = v, theme, hint: "dd/mm/yyyy", icon: Icons.calendar_today_rounded)),
                                      ]
                                    ],
                                  )
                                ] else ...[
                                  ...subjectLeaves.asMap().entries.map((entry) {
                                    int idx = entry.key; Map<String, String> item = entry.value;
                                    return Padding(
                                      padding: const EdgeInsets.only(bottom: 15),
                                      child: Row(
                                        crossAxisAlignment: CrossAxisAlignment.end,
                                        children: [
                                          Expanded(flex: 2, child: _buildDialogTextField("Ngày vắng", item['date']!, (v) => item['date'] = v, theme, hint: "dd/mm/yyyy", icon: Icons.calendar_today_rounded)), const SizedBox(width: 15),

                                          // ĐÃ FIX: CHUYỂN THÀNH DROPDOWN CHỌN TIẾT HỌC
                                          Expanded(flex: 2, child: _buildDialogDropdown("Chọn Tiết nghỉ", item['subject']!, periodNames, (val) => setStateDialog(() => item['subject'] = val!), theme)), const SizedBox(width: 10),

                                          if (subjectLeaves.length > 1) Container(margin: const EdgeInsets.only(bottom: 5), child: IconButton(onPressed: () => setStateDialog(() => subjectLeaves.removeAt(idx)), icon: const Icon(Icons.remove_circle_outline, color: Colors.redAccent)))
                                        ],
                                      ),
                                    );
                                  }),
                                  TextButton.icon(onPressed: () => setStateDialog(() => subjectLeaves.add({"date": startDate, "subject": periodNames.first})), icon: Icon(Icons.add_rounded, color: theme.infoColor), label: Text("Thêm tiết nghỉ", style: TextStyle(color: theme.infoColor, fontWeight: FontWeight.bold)))
                                ],

                                const SizedBox(height: 25),
                                Text("Lý do xin nghỉ", style: TextStyle(color: theme.textColor, fontWeight: FontWeight.bold, fontSize: 13)),
                                const SizedBox(height: 8),
                                TextField(
                                    maxLines: 5,
                                    onChanged: (v) => reason = v,
                                    style: TextStyle(color: theme.textColor, fontSize: 14),
                                    decoration: InputDecoration(
                                      hintText: "Viết lý do chi tiết vào đây...\n(VD: Bị ốm, việc gia đình, ...)",
                                      hintStyle: TextStyle(color: theme.subTextColor.withOpacity(0.5)),
                                      filled: true, fillColor: theme.textColor.withOpacity(0.04),
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                                    )
                                )
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 30),

                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            TextButton(onPressed: () => Navigator.pop(context), child: Text("Hủy bỏ", style: TextStyle(color: theme.subTextColor))), const SizedBox(width: 15),
                            ElevatedButton(
                              onPressed: () async {
                                if (reason.trim().isEmpty) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Vui lòng ghi rõ lý do!"), backgroundColor: Colors.orange)); return; }

                                Map<String, dynamic> payload = {
                                  "leave_mode": leaveMode,
                                  "reason": reason,
                                  "start_date": leaveMode == 'Theo ngày' ? startDate : null,
                                  "end_date": leaveMode == 'Theo ngày' ? (isOneDay ? startDate : endDate) : null,
                                  "periods": leaveMode == 'Theo tiết' ? subjectLeaves : [],
                                  "is_approved": false
                                };

                                showDialog(context: context, barrierDismissible: false, builder: (c) => Center(child: CircularProgressIndicator(color: theme.infoColor)));

                                try {
                                  var response = await http.post(
                                      Uri.parse('http://127.0.0.1:8000/api/students/${globals.currentUserId}/leave'),
                                      headers: {"Content-Type": "application/json"},
                                      body: jsonEncode(payload)
                                  );

                                  if (context.mounted) Navigator.pop(context);

                                  if (response.statusCode == 200) {
                                    var data = jsonDecode(utf8.decode(response.bodyBytes));
                                    if (data['status'] == 'success') {
                                      _fetchClassData();
                                      if (context.mounted) Navigator.pop(context);
                                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Đơn xin phép đã được gửi. Vui lòng chờ duyệt!"), backgroundColor: Colors.green));
                                    } else {
                                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Lỗi Server: ${data['message']}"), backgroundColor: Colors.redAccent));
                                    }
                                  }
                                } catch (e) {
                                  if (context.mounted) Navigator.pop(context);
                                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Lỗi kết nối máy chủ!"), backgroundColor: Colors.redAccent));
                                }
                              },
                              style: ElevatedButton.styleFrom(backgroundColor: theme.infoColor, padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15)), child: const Text("GỬI ĐƠN", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                            )
                          ],
                        )
                      ],
                    ),
                  ),
                );
              }
          );
        }
    );
  }
  // ==============================================================
  // HỘP THOẠI DUYỆT ĐƠN XIN NGHỈ DÀNH CHO GIÁO VIÊN
  // ==============================================================
  void _showLeaveDetailDialog(Map<String, dynamic> leave, bool canApprove, AppTheme theme) {
    showDialog(
        context: context,
        builder: (context) {
          return Dialog(
              backgroundColor: theme.cardColor,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: theme.infoColor.withOpacity(0.5))),
              child: Container(
                  width: 450,
                  padding: const EdgeInsets.all(30),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(children: [
                              Icon(Icons.event_note_rounded, color: theme.infoColor, size: 24 * theme.fontScale),
                              const SizedBox(width: 10),
                              Text("Chi tiết Đơn xin nghỉ", style: TextStyle(color: theme.textColor, fontWeight: FontWeight.bold, fontSize: 16 * theme.fontScale)),
                            ]),
                            IconButton(onPressed: () => Navigator.pop(context), icon: Icon(Icons.close, color: theme.subTextColor)),
                          ]
                      ),
                      const SizedBox(height: 20),

                      Row(
                          children: [
                            Text(leave['student_name'], style: TextStyle(color: theme.textColor, fontWeight: FontWeight.bold, fontSize: 18 * theme.fontScale)),
                            const SizedBox(width: 10),
                            Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: theme.infoColor, borderRadius: BorderRadius.circular(6)), child: Text(leave['leave_mode'], style: TextStyle(color: Colors.white, fontSize: 10 * theme.fontScale, fontWeight: FontWeight.bold)))
                          ]
                      ),
                      const SizedBox(height: 10),
                      Text(leave['leave_mode'] == 'Theo ngày' || leave['leave_mode'] == 'Nguyên ngày' ? "Nghỉ từ: ${leave['start_date']} đến ${leave['end_date']}" : "Nghỉ tiết: ${leave['subject_name']} (${leave['start_date']})", style: TextStyle(color: theme.subTextColor, fontWeight: FontWeight.bold, fontSize: 13 * theme.fontScale)),
                      const SizedBox(height: 20),

                      Text("Lý do xin nghỉ:", style: TextStyle(color: theme.textColor, fontWeight: FontWeight.bold, fontSize: 12 * theme.fontScale)),
                      const SizedBox(height: 8),
                      Container(
                          width: double.infinity, padding: const EdgeInsets.all(15),
                          decoration: BoxDecoration(color: theme.textColor.withOpacity(0.03), borderRadius: BorderRadius.circular(12), border: Border.all(color: theme.borderColor)),
                          child: Text(leave['reason'], style: TextStyle(color: theme.textColor, fontStyle: FontStyle.italic, fontSize: 13 * theme.fontScale, height: 1.5))
                      ),
                      const SizedBox(height: 30),

                      if (canApprove)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            OutlinedButton.icon(
                                onPressed: () { Navigator.pop(context); _handleLeaveAction(leave['id'], 'reject'); },
                                icon: const Icon(Icons.close, color: Colors.redAccent, size: 16),
                                label: const Text("Từ chối", style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
                                style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.redAccent), padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12))
                            ),
                            const SizedBox(width: 15),
                            ElevatedButton.icon(
                                onPressed: () { Navigator.pop(context); _handleLeaveAction(leave['id'], 'approve'); },
                                icon: const Icon(Icons.check, color: Colors.white, size: 16),
                                label: const Text("Duyệt Đơn", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                style: ElevatedButton.styleFrom(backgroundColor: Colors.green, padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12))
                            ),
                          ],
                        )
                      else
                        Container(width: double.infinity, padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: theme.warningColor.withOpacity(0.1), borderRadius: BorderRadius.circular(8)), child: Center(child: Text("Bạn không có quyền duyệt đơn này.", style: TextStyle(color: theme.warningColor, fontWeight: FontWeight.bold, fontSize: 12 * theme.fontScale)))),
                    ],
                  )
              )
          );
        }
    );
  }

}