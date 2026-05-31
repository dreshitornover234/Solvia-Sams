import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/intl.dart';
import '../theme_manager.dart';
import '../globals.dart' as globals;
import '../shared/member_profile_dialog.dart';
import 'dart:async';

class BellPeriod {
  final String name;
  final String timeFrame;
  BellPeriod(this.name, this.timeFrame);
}

class AttendanceReportView extends StatefulWidget {
  const AttendanceReportView({super.key});

  @override
  State<AttendanceReportView> createState() => _AttendanceReportViewState();
}

class _AttendanceReportViewState extends State<AttendanceReportView> with SingleTickerProviderStateMixin {
  AnimationController? _pulseController;
  Timer? _liveTimer;
  bool _isLoading = true;

  List<dynamic> _allClasses = [];
  List<dynamic> _homeroomClasses = [];
  List<dynamic> _subjectClasses = [];
  bool _isSuperAdmin = false;
  String _currentUserName = "";
  int? _selectedClassId;
  Map<String, dynamic>? _selectedClassData;
  String _liveStatusFilter = 'Tất cả';
  final List<String> _statusOptions = ['Tất cả', 'Có mặt', 'Vắng mặt', 'Ra ngoài', 'Được ra ngoài', 'Đi trễ', 'Nghỉ học', 'Có phép'];
  final Map<String, Map<String, dynamic>> _liveStatusOverrides = {};

  bool _isStudent = false;
  Map<String, dynamic>? _myClassData;
  List<BellPeriod> _bellSchedule = [];
  DateTime _timetableWeekStart = DateTime.now().subtract(Duration(days: DateTime.now().weekday - 1));

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(vsync: this, duration: const Duration(seconds: 1))..repeat(reverse: true);

    if (globals.currentUserRole == 'Học sinh' || globals.currentUserRole == 'Thành viên') {
      _isStudent = true;
      _fetchStudentViewData();
    } else {
      _fetchAttendanceData();

      _liveTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
        if (mounted && _selectedClassId == null) {
          _fetchAttendanceData(isSilent: true);
        } else if (mounted && _selectedClassId != null) {
          _silentFetchClassDetail();
        }
      });
    }
  }

  @override
  void dispose() {
    _pulseController?.dispose();
    _liveTimer?.cancel();
    super.dispose();
  }

  Future<void> _fetchStudentViewData() async {
    setState(() => _isLoading = true);
    try {
      var resClass = await http.get(Uri.parse('http://127.0.0.1:8000/api/classes/${globals.currentClassId}'));
      if (resClass.statusCode == 200) {
        var data = jsonDecode(utf8.decode(resClass.bodyBytes));
        if (data['status'] == 'success') _myClassData = data['data'];
      }

      var resProj = await http.get(Uri.parse('http://127.0.0.1:8000/api/projects/${globals.currentProjectId}'));
      if (resProj.statusCode == 200) {
        var pData = jsonDecode(utf8.decode(resProj.bodyBytes));
        if (pData['status'] == 'success' && pData['data']['bell_schedule'] != null) {
          _bellSchedule = (pData['data']['bell_schedule'] as List).map((e) => BellPeriod(e['name'], "${e['start_time']} - ${e['end_time']}")).toList();
        }
      }
      if (_bellSchedule.isEmpty) _bellSchedule = [BellPeriod("Tiết 1", "07:00 - 07:45"), BellPeriod("Tiết 2", "07:45 - 08:30")];

    } catch(e) {}
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _fetchAttendanceData({bool isSilent = false}) async {
    if (!isSilent) setState(() => _isLoading = true);
    try {
      var resMembers = await http.get(Uri.parse('http://127.0.0.1:8000/api/projects/${globals.currentProjectId}/members'));
      if (resMembers.statusCode == 200) {
        var dataMembers = jsonDecode(utf8.decode(resMembers.bodyBytes));
        if (dataMembers['status'] == 'success') {
          List<dynamic> admins = dataMembers['data']['admins'] ?? [];
          List<dynamic> managers = dataMembers['data']['managers'] ?? [];

          var myAdminProfile = admins.where((m) => m['user_id'].toString() == globals.currentUserId.toString()).firstOrNull;
          if (myAdminProfile != null) {
            _isSuperAdmin = true;
            _currentUserName = myAdminProfile['name'] ?? "";
          } else {
            var myManagerProfile = managers.where((m) => m['user_id'].toString() == globals.currentUserId.toString()).firstOrNull;
            if (myManagerProfile != null) {
              _isSuperAdmin = false;
              _currentUserName = myManagerProfile['name'] ?? "";
            }
          }
        }
      }

      var resClasses = await http.get(Uri.parse('http://127.0.0.1:8000/api/projects/${globals.currentProjectId}/classes'));
      if (resClasses.statusCode == 200) {
        var dataClasses = jsonDecode(utf8.decode(resClasses.bodyBytes));
        if (dataClasses['status'] == 'success') {
          List<dynamic> classList = dataClasses['data'];
          List<dynamic> tempAll = [];
          List<dynamic> tempHome = [];
          List<dynamic> tempSubj = [];

          for (var cls in classList) {
            var resDetail = await http.get(Uri.parse('http://127.0.0.1:8000/api/classes/${cls['id']}'));
            if (resDetail.statusCode == 200) {
              var dataDetail = jsonDecode(utf8.decode(resDetail.bodyBytes));
              if (dataDetail['status'] == 'success') {
                var clsData = dataDetail['data'];
                clsData['id'] = cls['id'];
                tempAll.add(clsData);

                bool isHome = false;
                String tIdStr = "";
                if (clsData['teacher'] != null && clsData['teacher']['user_id'] != null) {
                  tIdStr = clsData['teacher']['user_id'].toString();
                }
                if (tIdStr == globals.currentUserId.toString()) {
                  isHome = true;
                  tempHome.add(clsData);
                }

                bool isSubj = false;
                List<dynamic> timetable = clsData['timetable'] ?? [];
                for (var day in timetable) {
                  for (var sub in day['subjects'] ?? []) {
                    String subTeacherName = (sub['teacher_name'] ?? "").toString();
                    if (_currentUserName.isNotEmpty && subTeacherName.contains(_currentUserName)) isSubj = true;
                  }
                }
                if (isSubj) tempSubj.add(clsData);
              }
            }
          }

          if (mounted) {
            setState(() {
              _allClasses = tempAll;
              _homeroomClasses = tempHome;
              _subjectClasses = tempSubj;
              if (!isSilent) _isLoading = false;
            });
          }
        }
      }
    } catch (e) {
      if (mounted && !isSilent) setState(() => _isLoading = false);
    }
  }

  Future<void> _silentFetchClassDetail() async {
    try {
      var resDetail = await http.get(Uri.parse('http://127.0.0.1:8000/api/classes/$_selectedClassId'));
      if (resDetail.statusCode == 200) {
        var dataDetail = jsonDecode(utf8.decode(resDetail.bodyBytes));
        if (dataDetail['status'] == 'success') {
          if (mounted) {
            setState(() {
              _selectedClassData = dataDetail['data'];
              _selectedClassData!['id'] = _selectedClassId;
            });
          }
        }
      }
    } catch (e) {}
  }

  String _getWeekdayString(DateTime date) {
    switch (date.weekday) {
      case 1: return "Thứ 2"; case 2: return "Thứ 3"; case 3: return "Thứ 4";
      case 4: return "Thứ 5"; case 5: return "Thứ 6"; case 6: return "Thứ 7";
      case 7: return "Chủ Nhật"; default: return "Thứ 2";
    }
  }

  Map<String, dynamic>? _getCurrentEventDetail(List<dynamic> timetable) {
    DateTime nowDt = DateTime.now();
    String todayStr = _getWeekdayString(nowDt);
    String dateKey = DateFormat('yyyy-MM-dd').format(nowDt);
    TimeOfDay now = TimeOfDay.now();
    int nowMinutes = now.hour * 60 + now.minute;

    for (var day in timetable) {
      if (day['dayName'] == todayStr || day['dayName'] == dateKey) {
        for (var sub in day['subjects'] ?? []) {
          try {
            List<String> times = sub['timeFrame'].split('-');
            if (times.length == 2) {
              List<String> startSplit = times[0].trim().split(':');
              List<String> endSplit = times[1].trim().split(':');
              int startMins = int.parse(startSplit[0]) * 60 + int.parse(startSplit[1]);
              int endMins = int.parse(endSplit[0]) * 60 + int.parse(endSplit[1]);

              if (nowMinutes >= startMins && nowMinutes <= endMins) return sub;
            }
          } catch (e) { continue; }
        }
      }
    }
    return null;
  }

  // =========================================================================
  // ĐÃ FIX: TRÍCH XUẤT THỐNG KÊ VI PHẠM (DÙNG CHO PROFILE DIALOG)
  // =========================================================================
  Map<String, dynamic> _calculateDisciplineStats(Map<String, dynamic> student) {
    int lateCount = 0; int absentCount = 0; int excusedCount = 0;
    List<String> violationHistory = [];

    String queryYear = "${_selectedClassData?['current_year_start'] ?? '2026'}-${_selectedClassData?['current_year_end'] ?? '2027'}";
    String querySemester = _selectedClassData?['current_semester'] ?? 'Học kỳ 1';

    var attRaw = student['attendance_data'] ?? student['attendance'];
    Map<String, dynamic>? att;
    if (attRaw is String) { try { att = jsonDecode(attRaw); } catch(_) {} }
    else if (attRaw is Map) { att = Map<String, dynamic>.from(attRaw); }

    if (att != null) {
      var termData = att[queryYear]?[querySemester];
      if (termData != null && termData['history'] != null) {
        List<dynamic> history = termData['history'];
        Map<String, String> latestStatusMap = {};
        Map<String, String> latestLogStrMap = {};

        for (var h in history) {
          String logStr = h.toString();
          String rawLog = logStr;
          if (logStr.contains("|img:")) logStr = logStr.split("|img:")[0];
          List<String> parts = logStr.split(': ');
          if (parts.length < 2) continue;

          String datePart = parts[0].trim();
          String detailPart = parts[1];
          String content = detailPart.split('(').first.trim();

          String status = "";
          if (content.contains("Đi trễ")) status = "Đi trễ";
          else if (content.contains("Vắng mặt") || content.contains("Nghỉ học")) status = "Vắng mặt";
          else if (content.contains("Có phép")) status = "Có phép";
          else if (content.contains("Có mặt") || content.contains("Hợp lệ")) status = "Có mặt";

          String subject = content.replaceAll("Sửa thành", "").replaceAll("Có mặt", "").replaceAll("Hợp lệ", "").replaceAll("Đi trễ", "").replaceAll("Vắng mặt", "").replaceAll("Nghỉ học", "").replaceAll("Có phép", "").trim();
          String slotKey = "$datePart-$subject";

          if (!latestStatusMap.containsKey(slotKey)) {
            latestStatusMap[slotKey] = status;
            latestLogStrMap[slotKey] = rawLog;
          }
        }

        latestStatusMap.forEach((slotKey, finalStatus) {
          if (finalStatus == "Đi trễ") { lateCount++; violationHistory.add(latestLogStrMap[slotKey]!); }
          else if (finalStatus == "Vắng mặt") { absentCount++; violationHistory.add(latestLogStrMap[slotKey]!); }
          else if (finalStatus == "Có phép") { excusedCount++; violationHistory.add(latestLogStrMap[slotKey]!); }
        });
      }
    }
    return { 'late': lateCount, 'absent': absentCount, 'excused': excusedCount, 'violationHistory': violationHistory };
  }

  // =========================================================================
  // ĐÃ FIX: CHÈN THÊM LOG "CÓ MẶT" VÀ BÁO CÁO TOÀN BỘ TIMELINE
  // =========================================================================
  Map<String, dynamic> _getLiveStatusData(Map<String, dynamic> student, String eventName, String timeFrame) {
    if (_liveStatusOverrides.containsKey(student['id'].toString())) {
      return _liveStatusOverrides[student['id'].toString()]!;
    }
    if (eventName.contains("Trống tiết") || eventName.contains("Nghỉ giải lao") || eventName == "--:--") {
      return {"status": "Trống tiết", "logs": [], "reason": ""};
    }

    String realStatus = "Chưa điểm danh";
    List<dynamic> realLogs = [];

    try {
      String queryYear = "${_selectedClassData?['current_year_start'] ?? '2026'}-${_selectedClassData?['current_year_end'] ?? '2027'}";
      String querySemester = _selectedClassData?['current_semester'] ?? 'Học kỳ 1';

      var attRaw = student['attendance_data'] ?? student['attendance'];
      Map<String, dynamic>? att;
      if (attRaw is String) { try { att = jsonDecode(attRaw); } catch(_) {} }
      else if (attRaw is Map) { att = Map<String, dynamic>.from(attRaw); }

      if (att != null) {
        var termData = att[queryYear]?[querySemester];
        if (termData != null && termData['history'] != null) {
          List<dynamic> history = termData['history'];
          String todayStr = DateFormat('dd/MM/yy').format(DateTime.now());
          String subjectKey = eventName.replaceAll('[Bù] ', '').trim();

          bool isLatest = true;

          for (var h in history) {
            String logStr = h.toString();
            if (logStr.startsWith(todayStr)) {
              if (logStr.contains("Sáng") || logStr.contains("Chiều") || logStr.contains("Tiết") || logStr.contains(subjectKey)) {

                String? imgUrl;
                if (logStr.contains("|img:")) {
                  var parts = logStr.split("|img:");
                  logStr = parts[0];
                  if (parts[1].trim() != "none") imgUrl = parts[1].trim();
                }

                String lineStatus = "Chưa điểm danh";
                if (logStr.contains("Đi trễ")) lineStatus = "Đi trễ";
                else if (logStr.contains("Vắng mặt") || logStr.contains("Nghỉ học")) lineStatus = "Vắng mặt";
                else if (logStr.contains("Có phép")) lineStatus = "Có phép";
                else if (logStr.contains("Hợp lệ") || logStr.contains("Có mặt")) lineStatus = "Có mặt";

                String logTime = "Auto";
                try { logTime = logStr.split('(').last.replaceAll(')', '').replaceAll('Vào lúc ', '').replaceAll('Cập nhật lúc ', '').replaceAll('Hệ thống tự chốt', 'Auto').trim(); } catch(e){}

                if (isLatest) {
                  realStatus = lineStatus;
                  isLatest = false;
                }

                // NẾU LÀ "ĐI TRỄ", GẮN THÊM MỘT LOG "CÓ MẶT" VÀO TRƯỚC ĐỂ LOGIC LIỀN MẠCH
                if (lineStatus == "Đi trễ") {
                  realLogs.add({
                    "time": logTime,
                    "status": "Có mặt",
                    "detail": "Xác nhận có mặt tại lớp (cập nhật từ Đi trễ).",
                    "type": "success",
                    "updatedBy": "Hệ thống / AI",
                    "period": eventName,
                    "subjectTeacher": "Camera",
                    "img": imgUrl
                  });
                  realLogs.add({
                    "time": logTime,
                    "status": "Đi trễ",
                    "detail": logStr.split(': ')[1].trim(),
                    "type": "warning",
                    "updatedBy": "Hệ thống / AI",
                    "period": eventName,
                    "subjectTeacher": "Camera",
                    "img": null
                  });
                } else {
                  realLogs.add({
                    "time": logTime,
                    "status": lineStatus,
                    "detail": logStr.split(': ')[1].trim(),
                    "type": (lineStatus == 'Vắng mặt' || lineStatus == 'Nghỉ học') ? 'error' : (lineStatus == 'Đi trễ' ? 'warning' : 'success'),
                    "updatedBy": "Hệ thống / AI",
                    "period": eventName,
                    "subjectTeacher": "Camera",
                    "img": imgUrl
                  });
                }
              }
            }
          }
        }
      }
    } catch(e) { debugPrint("Lỗi Parse Live Status: $e"); }

    if (realStatus == 'Chưa điểm danh' && timeFrame != '--:--' && timeFrame.contains('-')) {
      try {
        String startStr = timeFrame.split('-')[0].trim();
        List<String> parts = startStr.split(':');
        DateTime now = DateTime.now();
        DateTime startTime = DateTime(now.year, now.month, now.day, int.parse(parts[0]), int.parse(parts[1]));

        if (now.isAfter(startTime.add(const Duration(minutes: 5)))) {
          realStatus = "Vắng mặt";
          realLogs.insert(0, {
            "time": DateFormat('HH:mm').format(startTime.add(const Duration(minutes: 5))),
            "status": "Vắng mặt",
            "detail": "Vào tiết quá 5 phút chưa ghi nhận điểm danh AI.",
            "type": "error",
            "updatedBy": "Hệ thống (Auto)",
            "period": eventName,
            "subjectTeacher": "AI Camera",
            "img": null
          });
        }
      } catch (e) {}
    }

    return {"status": realStatus, "logs": realLogs, "reason": ""};
  }

  Color _getStatusColor(String status, AppTheme theme) {
    switch (status) {
      case 'Có mặt': return theme.successColor;
      case 'Hợp lệ': return theme.successColor;
      case 'Vắng mặt': return theme.errorColor;
      case 'Ra ngoài': return Colors.deepOrange;
      case 'Được ra ngoài': return Colors.teal;
      case 'Đi trễ': return theme.warningColor;
      case 'Nghỉ học': return theme.errorColor;
      case 'Có phép': return theme.infoColor;
      case 'Trống tiết': return theme.subTextColor;
      case 'Chưa điểm danh': return theme.primaryColor.withOpacity(0.5);
      default: return theme.textColor;
    }
  }

  Color _getColorByType(String type, AppTheme theme) {
    if (type == 'success') return theme.successColor;
    if (type == 'warning') return theme.warningColor;
    if (type == 'error') return theme.errorColor;
    if (type == 'info') return theme.infoColor;
    if (type == 'orange') return Colors.deepOrange;
    return theme.textColor;
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
        animation: AppTheme.instance,
        builder: (context, child) {
          final theme = AppTheme.instance;
          return AnimatedSwitcher(
            duration: const Duration(milliseconds: 400),
            transitionBuilder: (child, animation) => SlideTransition(
              position: Tween<Offset>(begin: const Offset(0.05, 0), end: Offset.zero).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic)),
              child: FadeTransition(opacity: animation, child: child),
            ),
            child: _isStudent
                ? _buildStudentAttendanceView(theme)
                : (_selectedClassId == null ? _buildMasterView(theme) : _buildDetailLiveView(theme)),
          );
        }
    );
  }

  Widget _buildBeautifulCard({
    required String title,
    required String subtitle,
    required String middleTitle,
    required String middleValue,
    required IconData middleIcon,
    required Color middleIconColor,
    required String openTime,
    required int total,
    required int present,
    required int absent,
    required int excused,
    required int late,
    required bool isDimmed,
    required bool showStats,
    required AppTheme theme,
    required VoidCallback onTap,
    Color? accentColor,
    String? customBottomText,
  }) {
    Color activeAccent = accentColor ?? theme.primaryColor;

    return Opacity(
      opacity: isDimmed ? 0.4 : 1.0,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          width: 350 * theme.fontScale,
          constraints: BoxConstraints(minHeight: 280 * theme.fontScale),
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
              color: theme.isDarkMode ? const Color(0xFF131313) : theme.cardColor,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: activeAccent.withOpacity(isDimmed ? 0.2 : 0.6), width: 1.5),
              boxShadow: theme.isDarkMode ? [] : [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 15, offset: const Offset(0, 5))]
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title, style: TextStyle(color: theme.textColor, fontSize: 25 * theme.fontScale, fontWeight: FontWeight.w900, fontFamily: 'Segoe UI', height: 1.1), maxLines: 1, overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 6),
                        Text(subtitle, style: TextStyle(color: theme.subTextColor.withOpacity(0.8), fontSize: 14 * theme.fontScale, fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: activeAccent.withOpacity(0.1), shape: BoxShape.circle),
                    child: Icon(Icons.meeting_room_rounded, color: activeAccent, size: 24 * theme.fontScale),
                  )
                ],
              ),
              const SizedBox(height: 15),

              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: theme.isDarkMode ? const Color(0xFF1C1C1E) : theme.textColor.withOpacity(0.03),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(middleIcon, color: middleIconColor, size: 24 * theme.fontScale),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(middleTitle, style: TextStyle(color: middleIconColor, fontSize: 12 * theme.fontScale, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
                          const SizedBox(height: 4),
                          Text(middleValue, style: TextStyle(color: theme.textColor, fontSize: 16 * theme.fontScale, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
                          if (openTime != '--:--') ...[
                            const SizedBox(height: 3),
                            Text("Giờ: $openTime", style: TextStyle(color: theme.subTextColor, fontSize: 13 * theme.fontScale, fontStyle: FontStyle.italic)),
                          ]
                        ],
                      ),
                    )
                  ],
                ),
              ),
              const SizedBox(height: 20),

              if (showStats)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildStatColumn("$present/$total", "Sĩ số", const Color(0xFF2C7BE5), theme),
                    _buildStatColumn("$absent", "Vắng", const Color(0xFFE53935), theme),
                    _buildStatColumn("$excused", "Phép", const Color(0xFF00B0FF), theme),
                    _buildStatColumn("$late", "Trễ", const Color(0xFFFFB300), theme),
                  ],
                )
              else
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(color: activeAccent.withOpacity(0.05), borderRadius: BorderRadius.circular(10)),
                  child: Center(
                    child: Text(
                        customBottomText ?? (isDimmed ? "CHƯA TỚI GIỜ DẠY/HỌC" : "NHẤN VÀO ĐỂ VÀO LỚP"),
                        style: TextStyle(color: isDimmed ? theme.subTextColor : activeAccent, fontWeight: FontWeight.w900, fontSize: 12 * theme.fontScale, letterSpacing: 1.0)
                    ),
                  ),
                )
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatColumn(String value, String label, Color color, AppTheme theme) {
    return Column(
      children: [
        Text(value, style: TextStyle(color: color, fontSize: 16 * theme.fontScale, fontWeight: FontWeight.w900, fontFamily: 'Segoe UI')),
        const SizedBox(height: 4),
        Text(label, style: TextStyle(color: theme.subTextColor, fontSize: 12 * theme.fontScale, fontWeight: FontWeight.w600)),
      ],
    );
  }

  // ==========================================================
  // [1] GIAO DIỆN HỌC SINH
  // ==========================================================
  Widget _buildStudentAttendanceView(AppTheme theme) {
    if (_isLoading) return Center(child: Padding(padding: const EdgeInsets.only(top: 100), child: CircularProgressIndicator(color: theme.primaryColor)));
    if (_myClassData == null) return Center(child: Padding(padding: const EdgeInsets.only(top: 100), child: Text("Không có dữ liệu lớp.", style: TextStyle(color: theme.subTextColor))));

    List<dynamic> timetable = _myClassData!['timetable'] ?? [];
    Map<String, Map<String, dynamic>> baseSubjects = {};
    for (var day in timetable) {
      for (var sub in day['subjects'] ?? []) {
        if (sub['status'] != 'Trống') {
          String name = sub['name'] ?? 'Môn học';
          String baseName = name.replaceAll('[Bù] ', '').trim();
          if (baseName.isNotEmpty && !baseSubjects.containsKey(baseName)) {
            baseSubjects[baseName] = { 'teacher_name': sub['teacher_name'] ?? '', 'type': sub['type'] ?? 'Môn học' };
          }
        }
      }
    }

    Map<String, dynamic>? currentEvent = _getCurrentEventDetail(timetable);
    List<Map<String, dynamic>> displayCards = [];
    DateTime now = DateTime.now();

    for (String baseName in baseSubjects.keys) {
      Map<String, dynamic>? nextOcc;
      for (int i = 0; i < 14; i++) {
        DateTime checkDate = now.add(Duration(days: i));
        String dayStr = _getWeekdayString(checkDate);
        String dateKey = DateFormat('yyyy-MM-dd').format(checkDate);

        List<dynamic> subjectsForDay = [];
        bool foundOverride = false;
        for (var day in timetable) {
          if (day['dayName'] == dateKey) { subjectsForDay.addAll(day['subjects'] ?? []); foundOverride = true; }
        }
        if (!foundOverride) {
          for (var day in timetable) {
            if (day['dayName'] == dayStr) { subjectsForDay.addAll(day['subjects'] ?? []); }
          }
        }

        for (var sub in subjectsForDay) {
          String status = sub['status'] ?? 'Bình thường';
          if (status != 'Trống' && status != 'Nghỉ học') {
            if ((sub['name'] ?? '').replaceAll('[Bù] ', '').trim() == baseName) {
              bool isPast = false;
              if (i == 0) {
                try {
                  String endStr = (sub['timeFrame'] ?? '').split('-')[1].trim();
                  List<String> endParts = endStr.split(':');
                  DateTime endTime = DateTime(checkDate.year, checkDate.month, checkDate.day, int.parse(endParts[0]), int.parse(endParts[1]));
                  if (now.isAfter(endTime)) isPast = true;
                } catch(e){}
              }

              if (!isPast && nextOcc == null) {
                nextOcc = { 'date': checkDate, 'isToday': i == 0, 'timeFrame': sub['timeFrame'] ?? '--:--', 'status': status, 'teacher_name': sub['teacher_name'] ?? baseSubjects[baseName]!['teacher_name'] };
              }
            }
          }
        }
        if (nextOcc != null) break;
      }
      displayCards.add({ 'baseName': baseName, 'occurrence': nextOcc, 'teacher_name': baseSubjects[baseName]!['teacher_name'], 'type': baseSubjects[baseName]!['type'] });
    }

    return SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.all(40.0),
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AnimatedDefaultTextStyle(duration: const Duration(milliseconds: 300), style: TextStyle(fontSize: 28 * theme.fontScale, fontWeight: FontWeight.w900, color: theme.textColor, letterSpacing: 1.0, fontFamily: 'Segoe UI'), child: const Text("Báo Cáo Điểm Danh")),
              const SizedBox(height: 8),
              AnimatedDefaultTextStyle(duration: const Duration(milliseconds: 300), style: TextStyle(fontSize: 14 * theme.fontScale, color: theme.subTextColor, fontFamily: 'Segoe UI'), child: const Text("Danh sách các môn học của bạn. Theo dõi lịch học kế tiếp và trạng thái điểm danh hiện tại.")),
              const SizedBox(height: 40),

              if (displayCards.isEmpty)
                Text("Chưa có môn học nào được thiết lập.", style: TextStyle(color: theme.subTextColor))
              else
                Wrap(
                  spacing: 25, runSpacing: 25,
                  children: displayCards.map((card) {
                    String baseName = card['baseName']; var occ = card['occurrence']; String eventType = card['type'];
                    String middleTitle = "CHƯA XẾP LỊCH"; String middleValue = "Chưa có lịch tiếp theo"; IconData middleIcon = Icons.lock_clock_rounded; Color middleIconColor = theme.subTextColor; bool isDimmed = true; String openTime = '--:--'; String teacherName = card['teacher_name'] ?? "";
                    Color cardAccentColor = theme.primaryColor;

                    if (eventType == 'Cuộc họp') cardAccentColor = theme.purpleColor;
                    else if (eventType == 'Hoạt động') cardAccentColor = Colors.orange;
                    else if (eventType == 'Ngoại khóa') cardAccentColor = Colors.teal;

                    if (occ != null) {
                      teacherName = occ['teacher_name']; openTime = occ['timeFrame'];
                      bool isHappeningNow = currentEvent != null && currentEvent['name'] != null && currentEvent['name'].toString().contains(baseName);
                      bool isMakeup = occ['status'] == 'Học bù';

                      if (isHappeningNow) {
                        middleTitle = "ĐANG DIỄN RA"; middleValue = "Đang mở điểm danh"; middleIcon = Icons.sensors_rounded; middleIconColor = theme.successColor; isDimmed = false;
                      } else {
                        if (isMakeup) {
                          middleTitle = "LỊCH DẠY BÙ SẮP TỚI"; middleIcon = Icons.restore_rounded; middleIconColor = Colors.deepOrange; cardAccentColor = Colors.deepOrange;
                        } else {
                          middleTitle = "SẮP TỚI HỌC"; middleIcon = Icons.calendar_month_rounded; middleIconColor = cardAccentColor;
                        }
                        middleValue = occ['isToday'] ? "Hôm nay" : "Ngày ${DateFormat('dd/MM').format(occ['date'])}";
                        isDimmed = true;
                      }
                    }

                    return _buildBeautifulCard(title: baseName, subtitle: "GV: $teacherName", middleTitle: middleTitle, middleValue: middleValue, middleIcon: middleIcon, middleIconColor: middleIconColor, openTime: openTime, total: 0, present: 0, absent: 0, excused: 0, late: 0, isDimmed: isDimmed, showStats: false, theme: theme, accentColor: cardAccentColor, onTap: () { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: const Text("Bạn chỉ có quyền xem trạng thái điểm danh!"), backgroundColor: theme.warningColor)); });
                  }).toList(),
                )
            ]
        )
    );
  }

  // ==========================================================
  // [2] GIAO DIỆN GIÁO VIÊN: TỔNG QUAN
  // ==========================================================
  Widget _buildMasterView(AppTheme theme) {
    List<Widget> subjectClassCards = [];
    for (var cls in _subjectClasses) {
      Map<String, String> mySubjectsInClass = {};
      for (var day in (cls['timetable'] ?? [])) {
        for (var sub in (day['subjects'] ?? [])) {
          if (sub['status'] != 'Trống') {
            String teacher = sub['teacher_name'] ?? '';
            if (_currentUserName.isNotEmpty && teacher.contains(_currentUserName)) {
              String baseName = (sub['name'] ?? 'Môn học').replaceAll('[Bù] ', '').trim();
              if (baseName.isNotEmpty && !mySubjectsInClass.containsKey(baseName)) {
                mySubjectsInClass[baseName] = sub['type'] ?? 'Môn học';
              }
            }
          }
        }
      }
      for (String baseName in mySubjectsInClass.keys) {
        subjectClassCards.add(_buildClassSubjectCard(cls, baseName, mySubjectsInClass[baseName]!, theme));
      }
    }

    return SingleChildScrollView(
      key: const ValueKey('MasterView'),
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(40.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      AnimatedDefaultTextStyle(duration: const Duration(milliseconds: 300), style: TextStyle(fontSize: 28 * theme.fontScale, fontWeight: FontWeight.w900, color: theme.textColor, letterSpacing: 1.0, fontFamily: 'Segoe UI'), child: const Text("Giám Sát Điểm Danh")),
                      const SizedBox(width: 15),
                      if (_pulseController != null)
                        Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: theme.errorColor.withOpacity(0.15), borderRadius: BorderRadius.circular(6), border: Border.all(color: theme.errorColor.withOpacity(0.5))), child: Row(mainAxisSize: MainAxisSize.min, children: [FadeTransition(opacity: _pulseController!, child: Icon(Icons.circle, color: theme.errorColor, size: 10 * theme.fontScale)), const SizedBox(width: 6), Text("LIVE", style: TextStyle(color: theme.errorColor, fontWeight: FontWeight.bold, fontSize: 11 * theme.fontScale, letterSpacing: 1.0))]))
                    ],
                  ),
                  const SizedBox(height: 8),
                  AnimatedDefaultTextStyle(duration: const Duration(milliseconds: 300), style: TextStyle(fontSize: 14 * theme.fontScale, color: theme.subTextColor, fontFamily: 'Segoe UI'), child: const Text("Theo dõi tình trạng sĩ số và vi phạm thời gian thực của toàn bộ các lớp.")),
                ],
              ),
              IconButton(onPressed: _fetchAttendanceData, icon: Icon(Icons.refresh_rounded, color: theme.primaryColor), tooltip: "Làm mới dữ liệu")
            ],
          ),
          const SizedBox(height: 40),

          if (_isLoading)
            Center(child: Padding(padding: const EdgeInsets.only(top: 100), child: CircularProgressIndicator(color: theme.primaryColor)))
          else if (_allClasses.isEmpty)
            Center(child: Padding(padding: const EdgeInsets.only(top: 100), child: Text("Dự án hiện chưa có lớp học nào.", style: TextStyle(color: theme.subTextColor, fontSize: 16 * theme.fontScale, fontStyle: FontStyle.italic))))
          else ...[
              if (_homeroomClasses.isNotEmpty) ...[
                _buildSectionTitle("LỚP ĐANG CHỦ NHIỆM", Icons.star_rounded, theme.successColor, theme),
                const SizedBox(height: 20),
                Wrap(spacing: 25, runSpacing: 25, children: _homeroomClasses.map((cls) => _buildClassSummaryCard(cls, theme)).toList()),
                const SizedBox(height: 40),
              ],
              if (_subjectClasses.isNotEmpty) ...[
                _buildSectionTitle("LỚP ĐANG GIẢNG DẠY (BỘ MÔN / HOẠT ĐỘNG)", Icons.class_rounded, theme.purpleColor, theme),
                const SizedBox(height: 20),
                Wrap(spacing: 25, runSpacing: 25, children: subjectClassCards),
                const SizedBox(height: 40),
              ],
              if (_isSuperAdmin) ...[
                _buildSectionTitle("GIÁM SÁT ĐIỂM DANH TOÀN CƠ SỞ", Icons.domain_rounded, theme.primaryColor, theme),
                const SizedBox(height: 20),
                Wrap(spacing: 25, runSpacing: 25, children: _allClasses.map((cls) => _buildClassSummaryCard(cls, theme)).toList()),
              ]
            ]
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title, IconData icon, Color color, AppTheme theme) {
    return Row(
      children: [
        Icon(icon, color: color, size: 20 * theme.fontScale),
        const SizedBox(width: 10),
        Text(title, style: TextStyle(color: color, fontSize: 14 * theme.fontScale, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
        const SizedBox(width: 15),
        Expanded(child: Divider(color: theme.borderColor))
      ],
    );
  }

  Widget _buildClassSummaryCard(Map<String, dynamic> cls, AppTheme theme) {
    Map<String, dynamic>? currentEvent = _getCurrentEventDetail(cls['timetable'] ?? []);
    String eventName = currentEvent != null ? currentEvent['name'] : "Trống tiết / Nghỉ giải lao";
    String openTime = currentEvent != null ? currentEvent['timeFrame'] : '--:--';

    List<dynamic> classStudents = cls['students'] ?? [];
    int totalStudents = classStudents.length;

    int present = 0; int absent = 0; int late = 0; int excused = 0;

    _selectedClassData = cls;

    for (var st in classStudents) {
      Map<String, dynamic> statusData = _getLiveStatusData(st, eventName, openTime);
      String status = statusData['status'];

      if (status == 'Có mặt') present++;
      else if (status == 'Đi trễ') { present++; late++; }
      else if (status == 'Nghỉ học' || status == 'Vắng mặt') absent++;
      else if (status == 'Có phép') excused++;
    }
    _selectedClassData = null;

    String middleTitle = "ĐANG DIỄN RA";
    String middleValue = eventName;
    IconData middleIcon = Icons.play_circle_fill_rounded;
    Color middleIconColor = theme.subTextColor;

    if (currentEvent != null) {
      middleIcon = Icons.sensors_rounded;
      middleIconColor = theme.successColor;
    } else {
      middleTitle = "TRẠNG THÁI";
    }

    return _buildBeautifulCard(
        title: cls['class_name'], subtitle: "GV: ${cls['teacher']['name'] ?? 'Chưa phân công'}",
        middleTitle: middleTitle, middleValue: middleValue, middleIcon: middleIcon, middleIconColor: middleIconColor,
        openTime: openTime, total: totalStudents, present: present, absent: absent, excused: excused, late: late,
        isDimmed: false, showStats: true, theme: theme,
        onTap: () {
          setState(() {
            _selectedClassId = cls['id'];
            _selectedClassData = cls;
            _liveStatusFilter = 'Tất cả';
          });
        }
    );
  }

  Widget _buildClassSubjectCard(Map<String, dynamic> cls, String targetBaseName, String eventType, AppTheme theme) {
    Map<String, dynamic>? currentEvent = _getCurrentEventDetail(cls['timetable'] ?? []);
    String eventTeacher = currentEvent != null ? (currentEvent['teacher_name'] ?? "") : "";

    bool isHappeningNow = currentEvent != null && currentEvent['name'].toString().replaceAll('[Bù] ', '').trim() == targetBaseName && eventTeacher.contains(_currentUserName);

    String middleTitle = "CHƯA XẾP LỊCH"; String middleValue = targetBaseName; IconData middleIcon = Icons.lock_clock_rounded; Color middleIconColor = theme.subTextColor; bool isDimmed = true; String openTime = '--:--'; String? customBottomText; Color cardAccentColor = theme.primaryColor;

    if (eventType == 'Cuộc họp') cardAccentColor = theme.purpleColor; else if (eventType == 'Hoạt động') cardAccentColor = Colors.orange; else if (eventType == 'Ngoại khóa') cardAccentColor = Colors.teal;

    if (isHappeningNow) {
      middleTitle = "ĐANG DIỄN RA"; middleIcon = Icons.sensors_rounded; middleIconColor = theme.successColor; cardAccentColor = theme.successColor; isDimmed = false; openTime = currentEvent!['timeFrame'] ?? '--:--'; customBottomText = "NHẤN VÀO ĐỂ MỞ ĐIỂM DANH";
    } else {
      DateTime now = DateTime.now(); Map<String, dynamic>? nextOcc; List<dynamic> timetable = cls['timetable'] ?? [];
      for (int i = 0; i < 14; i++) {
        DateTime checkDate = now.add(Duration(days: i)); String dayStr = _getWeekdayString(checkDate); String dateKey = DateFormat('yyyy-MM-dd').format(checkDate);
        List<dynamic> subjectsForDay = []; bool foundOverride = false;
        for (var day in timetable) { if (day['dayName'] == dateKey) { subjectsForDay.addAll(day['subjects'] ?? []); foundOverride = true; } }
        if (!foundOverride) { for (var day in timetable) { if (day['dayName'] == dayStr) { subjectsForDay.addAll(day['subjects'] ?? []); } } }
        for (var sub in subjectsForDay) {
          if (sub['status'] != 'Trống' && sub['status'] != 'Nghỉ học') {
            String teacher = sub['teacher_name'] ?? ""; String baseName = (sub['name'] ?? '').toString().replaceAll('[Bù] ', '').trim();
            if (baseName == targetBaseName && teacher.contains(_currentUserName)) {
              bool isPast = false;
              if (i == 0) {
                try {
                  String endStr = (sub['timeFrame'] ?? '').split('-')[1].trim(); List<String> endParts = endStr.split(':');
                  DateTime endTime = DateTime(checkDate.year, checkDate.month, checkDate.day, int.parse(endParts[0]), int.parse(endParts[1]));
                  if (now.isAfter(endTime)) isPast = true;
                } catch(e){}
              }
              if (!isPast && nextOcc == null) { nextOcc = { 'date': checkDate, 'isToday': i == 0, 'timeFrame': sub['timeFrame'], 'name': sub['name'], 'status': sub['status'] }; }
            }
          }
        }
        if (nextOcc != null) break;
      }

      if (nextOcc != null) {
        String dateStr = nextOcc['isToday'] ? "Hôm nay" : DateFormat('dd/MM').format(nextOcc['date']);
        String startHour = nextOcc['timeFrame'].split('-')[0].trim();
        bool isMakeup = nextOcc['status'] == 'Dạy thế' || nextOcc['status'] == 'Học bù';
        if (isMakeup) { customBottomText = "LỊCH DẠY BÙ: $dateStr LÚC $startHour"; cardAccentColor = Colors.deepOrange; middleIconColor = Colors.deepOrange; middleIcon = Icons.restore_rounded; middleTitle = "LỊCH DẠY BÙ SẮP TỚI"; }
        else { customBottomText = "LỊCH DẠY TIẾP THEO: $dateStr LÚC $startHour"; middleIconColor = cardAccentColor; middleIcon = Icons.calendar_month_rounded; middleTitle = "SẮP TỚI DẠY"; }
        openTime = nextOcc['timeFrame'];
      }
    }

    return _buildBeautifulCard(title: "Lớp ${cls['class_name']}", subtitle: "Phụ trách: $targetBaseName", middleTitle: middleTitle, middleValue: middleValue, middleIcon: middleIcon, middleIconColor: middleIconColor, openTime: openTime, total: 0, present: 0, absent: 0, excused: 0, late: 0, isDimmed: isDimmed, showStats: false, customBottomText: customBottomText, accentColor: cardAccentColor, theme: theme, onTap: () { if (!isHappeningNow) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Chưa tới giờ! Bạn chỉ có thể điểm danh Live trong khung giờ bạn phụ trách."), backgroundColor: Colors.orange)); return; } setState(() { _selectedClassId = cls['id']; _selectedClassData = cls; _liveStatusFilter = 'Tất cả'; }); });
  }

  // ==========================================================
  // [3] CHI TIẾT BÊN TRONG LỚP (REAL-TIME NHẢY SỐ)
  // ==========================================================
  Widget _buildDetailLiveView(AppTheme theme) {
    String className = _selectedClassData!['class_name'];
    List<dynamic> rawStudents = _selectedClassData!['students'] ?? [];
    List<dynamic> timetable = _selectedClassData!['timetable'] ?? [];
    Map<String, dynamic> homeroomTeacher = _selectedClassData!['teacher'] ?? {};

    Map<String, dynamic>? liveEvent = _getCurrentEventDetail(timetable);
    String eventName = liveEvent != null ? liveEvent['name'] : "Lớp đang trống tiết";
    String eventTeacher = liveEvent != null ? (liveEvent['teacher_name'] ?? "Chưa gán") : "Không có";
    String eventType = liveEvent != null ? (liveEvent['type'] ?? "Sự kiện") : "Trạng thái";
    String eventTime = liveEvent != null ? liveEvent['timeFrame'] : "--:--";

    List<Map<String, dynamic>> processedStudents = [];
    int sTotal = rawStudents.length;
    int sPresent = 0; int sAbsent = 0; int sExcused = 0; int sLate = 0; int sOut = 0; int sAllowedOut = 0;

    for (var st in rawStudents) {
      Map<String, dynamic> statusData = _getLiveStatusData(st, eventName, eventTime);
      String status = statusData['status'];

      if (status == 'Có mặt') sPresent++;
      else if (status == 'Đi trễ') { sPresent++; sLate++; }
      else if (status == 'Ra ngoài') sOut++;
      else if (status == 'Được ra ngoài') sAllowedOut++;
      else if (status == 'Nghỉ học' || status == 'Vắng mặt') sAbsent++;
      else if (status == 'Có phép') sExcused++;

      processedStudents.add({ "data": st, "statusData": statusData });
    }

    int actualInClass = sPresent;

    // ĐÃ FIX: Lọc thông minh giữ nguyên logic "Có mặt" cho dropdown
    List<Map<String, dynamic>> filteredStudents = processedStudents.where((st) {
      if (_liveStatusFilter == 'Tất cả') return true;
      String originalStatus = st['statusData']['status'];
      String displayStatus = (originalStatus == 'Đi trễ' || originalStatus == 'Hợp lệ') ? 'Có mặt' : originalStatus;

      if (_liveStatusFilter == 'Có mặt' && displayStatus == 'Có mặt') return true;
      if (_liveStatusFilter == 'Đi trễ' && originalStatus == 'Đi trễ') return true;

      return originalStatus == _liveStatusFilter;
    }).toList();

    return SingleChildScrollView(
      key: ValueKey('LiveDetailView_$_selectedClassId'),
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(40.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton(onPressed: () => setState(() => _selectedClassId = null), icon: Icon(Icons.arrow_back_ios_new_rounded, color: theme.textColor, size: 20 * theme.fontScale)),
              const SizedBox(width: 10),
              AnimatedDefaultTextStyle(duration: const Duration(milliseconds: 300), style: TextStyle(fontSize: 28 * theme.fontScale, fontWeight: FontWeight.w900, color: theme.textColor, letterSpacing: 1.0, fontFamily: 'Segoe UI'), child: Text("Trạng thái Live: $className")),
            ],
          ),
          const SizedBox(height: 30),

          Container(
            padding: const EdgeInsets.all(25),
            decoration: BoxDecoration(color: theme.primaryColor.withOpacity(0.05), borderRadius: BorderRadius.circular(16), border: Border.all(color: theme.primaryColor.withOpacity(0.3))),
            child: Row(
              children: [
                if (_pulseController != null)
                  FadeTransition(opacity: _pulseController!, child: Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: liveEvent != null ? theme.successColor : theme.subTextColor, shape: BoxShape.circle), child: Icon(Icons.sensors_rounded, color: Colors.white, size: 24 * theme.fontScale))),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [Text("ĐANG DIỄN RA:", style: TextStyle(color: theme.primaryColor, fontWeight: FontWeight.bold, fontSize: 12 * theme.fontScale, letterSpacing: 1.2)), const SizedBox(width: 10), Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2), decoration: BoxDecoration(color: theme.primaryColor, borderRadius: BorderRadius.circular(4)), child: Text(eventType.toUpperCase(), style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold))), const SizedBox(width: 10), Text("•  Khung giờ: $eventTime", style: TextStyle(color: theme.subTextColor, fontSize: 12 * theme.fontScale, fontWeight: FontWeight.bold))]),
                      const SizedBox(height: 6),
                      Text(eventName, style: TextStyle(color: theme.textColor, fontSize: 24 * theme.fontScale, fontWeight: FontWeight.w900)),
                      const SizedBox(height: 12),
                      Row(children: [_buildTeacherProfileChip("Bộ môn", eventTeacher, theme, isHomeroom: false), const SizedBox(width: 15), _buildTeacherProfileChip("Chủ nhiệm", homeroomTeacher['name'] ?? "Chưa có", theme, isHomeroom: true, teacherData: homeroomTeacher)])
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 30),

          Text("THÔNG SỐ TẠI LỚP", style: TextStyle(color: theme.textColor, fontWeight: FontWeight.bold, fontSize: 14 * theme.fontScale, letterSpacing: 1.0)),
          const SizedBox(height: 15),
          Row(
            children: [
              Expanded(
                flex: 2,
                child: Container(
                  height: 120, padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(color: theme.primaryColor, borderRadius: BorderRadius.circular(16), boxShadow: theme.isDarkMode ? [] : [BoxShadow(color: theme.primaryColor.withOpacity(0.3), blurRadius: 15, offset: const Offset(0, 5))]),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text("ĐANG CÓ MẶT TẠI LỚP", style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 12 * theme.fontScale, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 5),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text("$actualInClass", style: TextStyle(color: Colors.white, fontSize: 36 * theme.fontScale, fontWeight: FontWeight.w900, height: 1.0)),
                          Padding(padding: const EdgeInsets.only(bottom: 4, left: 5), child: Text("/ $sTotal hs", style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 16 * theme.fontScale, fontWeight: FontWeight.bold))),
                        ],
                      )
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 15),
              Expanded(flex: 5, child: SizedBox(
                height: 120,
                child: Row(
                  children: [
                    Expanded(child: _buildLiveStatBox("Có phép", "$sExcused", theme.infoColor, Icons.assignment_ind_rounded, theme)), const SizedBox(width: 15),
                    Expanded(child: _buildLiveStatBox("Nghỉ / Vắng", "$sAbsent", theme.errorColor, Icons.person_off_rounded, theme)), const SizedBox(width: 15),
                    Expanded(child: _buildLiveStatBox("Đi trễ", "$sLate", theme.warningColor, Icons.watch_later_rounded, theme)), const SizedBox(width: 15),
                    Expanded(child: _buildLiveStatBox("Ra ngoài", "$sOut", Colors.deepOrange, Icons.directions_walk_rounded, theme, isAlert: sOut > 0)), const SizedBox(width: 15),
                    Expanded(child: _buildLiveStatBox("Được ra ngoài", "$sAllowedOut", Colors.teal, Icons.verified_user_rounded, theme)),
                  ],
                ),
              ))
            ],
          ),
          const SizedBox(height: 40),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("DANH SÁCH HỌC SINH LIVE", style: TextStyle(color: theme.textColor, fontWeight: FontWeight.bold, fontSize: 14 * theme.fontScale, letterSpacing: 1.0)),
              Container(
                height: 40, padding: const EdgeInsets.symmetric(horizontal: 15), decoration: BoxDecoration(color: theme.textColor.withOpacity(0.05), borderRadius: BorderRadius.circular(10)),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _liveStatusFilter, dropdownColor: theme.cardColor,
                    icon: Icon(Icons.filter_list_rounded, color: theme.primaryColor, size: 18),
                    style: TextStyle(color: theme.textColor, fontWeight: FontWeight.bold, fontSize: 13 * theme.fontScale),
                    items: _statusOptions.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                    onChanged: (val) => setState(() => _liveStatusFilter = val!),
                  ),
                ),
              )
            ],
          ),
          const SizedBox(height: 15),

          Container(
            width: double.infinity, decoration: BoxDecoration(color: theme.cardColor, borderRadius: BorderRadius.circular(16), border: Border.all(color: theme.borderColor)),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: DataTable(
                showCheckboxColumn: false, headingRowColor: WidgetStateProperty.all(theme.primaryColor.withOpacity(0.05)), dataRowMaxHeight: 70,
                columns: [
                  DataColumn(label: Text("Mã HS", style: TextStyle(color: theme.primaryColor, fontWeight: FontWeight.bold))),
                  DataColumn(label: Text("Họ và Tên", style: TextStyle(color: theme.primaryColor, fontWeight: FontWeight.bold))),
                  DataColumn(label: Text("Tài khoản", style: TextStyle(color: theme.primaryColor, fontWeight: FontWeight.bold))),
                  DataColumn(label: Text("Trạng thái Live", style: TextStyle(color: theme.primaryColor, fontWeight: FontWeight.bold))),
                  DataColumn(label: Text("Hành động", style: TextStyle(color: theme.primaryColor, fontWeight: FontWeight.bold))),
                ],
                rows: filteredStudents.map((stData) {
                  Map<String, dynamic> st = stData['data'];
                  Map<String, dynamic> sData = stData['statusData'];

                  String originalStatus = sData['status'];
                  // ĐÃ FIX: Đánh lừa thị giác người xem: "Đi trễ" bên ngoài hiển thị "Có mặt"
                  String displayStatus = (originalStatus == 'Đi trễ' || originalStatus == 'Hợp lệ') ? 'Có mặt' : originalStatus;

                  return DataRow(
                    onSelectChanged: (_) {
                      // ĐÃ FIX: Truyền thống kê vi phạm vào Dialog
                      Map<String, dynamic> stats = _calculateDisciplineStats(st);

                      showDialog(
                          context: context,
                          builder: (_) => MemberProfileDialog(
                              isAdmin: true,
                              memberData: {
                                "name": st["name"],
                                "email": st["email"] ?? st["user"] ?? "Chưa có",
                                "role": "Học sinh ${st['id']}",
                                "avatar_url": st["avatar_url"] ?? "",
                                "face_data": st["face_data"] ?? "",
                                "dob": st["dob"] ?? "Chưa cập nhật",
                                "phone": st["phone"] ?? "Chưa cập nhật",
                                "hometown": st["hometown"] ?? "Chưa cập nhật",
                                "religion": st["religion"] ?? "Không",
                                "currentAddress": st["current_address"] ?? "Chưa cập nhật",
                                "facebook": st["facebook"] ?? "Chưa liên kết",
                                "jobRole": "Học sinh lớp $className",
                                "degree": "Niên khóa hiện tại",
                                "school": "SAMS Cơ sở",
                                "dynamicLabel1": "Giới tính",
                                "dynamicValue1": st["gender"] ?? "Chưa rõ",
                                "dynamicLabel2": "Tình trạng",
                                "dynamicValue2": originalStatus,
                                "lateCount": stats['late'],
                                "absentCount": stats['absent'],
                                "excusedCount": stats['excused'],
                                "violationHistory": stats['violationHistory']
                              }
                          )
                      );
                    },
                    cells: [
                      DataCell(Text(st["id"] ?? "N/A", style: TextStyle(color: theme.subTextColor))),
                      DataCell(Text(st["name"] ?? "Không tên", style: TextStyle(color: theme.textColor, fontWeight: FontWeight.bold))),
                      DataCell(Text(st["email"] ?? st["user"] ?? "Chưa có", style: TextStyle(color: theme.subTextColor))),
                      DataCell(
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(color: _getStatusColor(displayStatus, theme).withOpacity(0.1), borderRadius: BorderRadius.circular(6), border: Border.all(color: _getStatusColor(displayStatus, theme).withOpacity(0.4))),
                            child: Text(displayStatus, style: TextStyle(color: _getStatusColor(displayStatus, theme), fontWeight: FontWeight.bold, fontSize: 11)),
                          )
                      ),
                      DataCell(
                          ElevatedButton.icon(
                            onPressed: () => _showLiveStatusDetailDialog(st, sData, eventName, eventTime, theme),
                            icon: Icon(Icons.manage_search_rounded, color: theme.primaryColor, size: 16),
                            label: Text("Chi tiết", style: TextStyle(color: theme.primaryColor, fontWeight: FontWeight.bold)),
                            style: ElevatedButton.styleFrom(backgroundColor: theme.primaryColor.withOpacity(0.1), elevation: 0, padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
                          )
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTeacherProfileChip(String label, String name, AppTheme theme, {required bool isHomeroom, Map<String, dynamic>? teacherData}) {
    return Material(color: Colors.transparent, child: InkWell(borderRadius: BorderRadius.circular(8), onTap: () { if (name != "Chưa có" && name != "Chưa gán") { showDialog(context: context, builder: (_) => MemberProfileDialog(isAdmin: true, memberData: teacherData ?? {"name": name, "role": isHomeroom ? "Giáo viên Chủ nhiệm" : "Giáo viên Bộ môn", "email": "Đang cập nhật..."})); } }, child: Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6), decoration: BoxDecoration(color: theme.cardColor, borderRadius: BorderRadius.circular(8), border: Border.all(color: theme.borderColor)), child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(isHomeroom ? Icons.badge_rounded : Icons.co_present_rounded, color: isHomeroom ? theme.primaryColor : theme.purpleColor, size: 14 * theme.fontScale), const SizedBox(width: 6), Text("$label: ", style: TextStyle(color: theme.subTextColor, fontSize: 11 * theme.fontScale)), Text(name, style: TextStyle(color: theme.textColor, fontWeight: FontWeight.bold, fontSize: 12 * theme.fontScale))]))));
  }

  Widget _buildLiveStatBox(String title, String value, Color color, IconData icon, AppTheme theme, {bool isAlert = false}) {
    return Container(padding: const EdgeInsets.all(15), decoration: BoxDecoration(color: isAlert ? color.withOpacity(0.1) : theme.textColor.withOpacity(0.02), borderRadius: BorderRadius.circular(16), border: Border.all(color: isAlert ? color.withOpacity(0.5) : theme.borderColor)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Icon(icon, color: color.withOpacity(0.8), size: 20), Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(value, style: TextStyle(color: color, fontSize: 24, fontWeight: FontWeight.w900)), Text(title, style: TextStyle(color: theme.textColor, fontSize: 11, fontWeight: FontWeight.bold))])]));
  }

  void _showLiveStatusDetailDialog(Map<String, dynamic> student, Map<String, dynamic> currentStatusData, String currentSubject, String currentTime, AppTheme theme) {
    String pStatus = currentStatusData['status'] ?? "Chưa điểm danh";
    List<dynamic> pLogs = List.from((currentStatusData['logs'] ?? []).map((x) => Map<String, dynamic>.from(x)));
    String updateReason = currentStatusData['reason'] ?? "";
    TextEditingController reasonController = TextEditingController(text: updateReason);

    String? currentImageUrl;
    for (var l in pLogs.reversed) { if (l['img'] != null) { currentImageUrl = l['img']; break; } }

    showDialog(
        context: context,
        builder: (context) {
          return StatefulBuilder(
              builder: (context, setStateDialog) {

                Widget buildInteractiveTimelineRow(Map<String, dynamic> log, Color color, {bool isLast = false}) {
                  bool isSelected = currentImageUrl == log['img'] && log['img'] != null;
                  String logTime = log['time'] ?? "Không rõ giờ"; String logStatus = log['status'] ?? "Chưa cập nhật"; String logDetail = log['detail'] ?? "Không có ghi chú."; String logPeriod = log['period'] ?? "Không rõ tiết"; String logSubTeacher = log['subjectTeacher'] ?? "Chưa gán"; String logUpdater = log['updatedBy'] ?? log['teacher'] ?? "Hệ thống / Admin";
                  return IntrinsicHeight(child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [Column(children: [Container(width: 14, height: 14, decoration: BoxDecoration(color: color, shape: BoxShape.circle, border: Border.all(color: theme.cardColor, width: 3))), if (!isLast) Expanded(child: Container(width: 2, color: color.withOpacity(0.3)))]), const SizedBox(width: 15), Expanded(child: Padding(padding: const EdgeInsets.only(bottom: 25), child: Material(color: Colors.transparent, child: InkWell(borderRadius: BorderRadius.circular(12), onTap: log['img'] == null ? null : () => setStateDialog(() => currentImageUrl = log['img']), child: AnimatedContainer(duration: const Duration(milliseconds: 200), padding: const EdgeInsets.all(15), decoration: BoxDecoration(color: isSelected ? color.withOpacity(0.08) : theme.textColor.withOpacity(0.02), borderRadius: BorderRadius.circular(12), border: Border.all(color: isSelected ? color.withOpacity(0.5) : theme.borderColor)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Row(children: [Icon(Icons.access_time_rounded, size: 14, color: color), const SizedBox(width: 6), Text(logTime, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 13))]), Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(6)), child: Text(logStatus, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 10)))]), const SizedBox(height: 8), Text(logDetail, style: TextStyle(color: theme.textColor, fontSize: 14, height: 1.4)), const SizedBox(height: 12), Divider(color: theme.borderColor, height: 1), const SizedBox(height: 10), Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Expanded(child: Row(children: [Icon(Icons.class_rounded, size: 12, color: theme.subTextColor), const SizedBox(width: 4), Expanded(child: Text("$logPeriod - $logSubTeacher", style: TextStyle(color: theme.subTextColor, fontSize: 11), overflow: TextOverflow.ellipsis))])), Row(children: [Icon(Icons.manage_accounts_rounded, size: 12, color: theme.primaryColor), const SizedBox(width: 4), Text(logUpdater, style: TextStyle(color: theme.primaryColor, fontSize: 11, fontWeight: FontWeight.bold))])])]))))))]));
                }

                String stName = student['name'] ?? "Chưa có tên"; String stId = student['id'] ?? "N/A"; String stGender = student['gender'] ?? "Nam";

                return Dialog(
                  backgroundColor: theme.cardColor, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24), side: BorderSide(color: theme.borderColor)),
                  child: Container(
                    width: 1100, height: 800, padding: const EdgeInsets.all(0),
                    clipBehavior: Clip.antiAlias, decoration: BoxDecoration(borderRadius: BorderRadius.circular(24)),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 5,
                          child: Container(
                            padding: const EdgeInsets.all(30), decoration: BoxDecoration(color: theme.textColor.withOpacity(0.02), border: Border(right: BorderSide(color: theme.borderColor))),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text("BẰNG CHỨNG CAMERA AI", style: TextStyle(color: theme.primaryColor, fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 1.2)),
                                const SizedBox(height: 15),

                                AnimatedSwitcher(
                                  duration: const Duration(milliseconds: 300),
                                  child: currentImageUrl != null
                                      ? Container(
                                    key: ValueKey(currentImageUrl),
                                    width: double.infinity, height: 260,
                                    decoration: BoxDecoration(color: Colors.black, borderRadius: BorderRadius.circular(16), image: DecorationImage(image: NetworkImage(currentImageUrl!.startsWith('data:') ? currentImageUrl! : 'http://127.0.0.1:8000$currentImageUrl'), fit: BoxFit.cover, opacity: 0.9)),
                                    child: Stack(children: [Positioned(top: 10, left: 10, child: Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: Colors.redAccent, borderRadius: BorderRadius.circular(4)), child: const Row(children: [Icon(Icons.fiber_manual_record, color: Colors.white, size: 10), SizedBox(width: 4), Text("REC", style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold))]))), Positioned(bottom: 10, left: 10, child: Text("Cam_Gate_01 • Nguồn: Solvia SAMS", style: const TextStyle(color: Colors.white, fontSize: 11, backgroundColor: Colors.black54)))]),
                                  )
                                      : Container(
                                    key: const ValueKey("no_signal"),
                                    width: double.infinity, height: 260,
                                    decoration: BoxDecoration(color: theme.textColor.withOpacity(0.05), borderRadius: BorderRadius.circular(16), border: Border.all(color: theme.borderColor)),
                                    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.videocam_off_rounded, color: theme.subTextColor.withOpacity(0.5), size: 60), const SizedBox(height: 15), Text("Không có hình ảnh cho sự kiện này", style: TextStyle(color: theme.subTextColor, fontWeight: FontWeight.bold, fontSize: 14))]),
                                  ),
                                ),
                                const SizedBox(height: 25),

                                Text("NHẬT KÝ KIỂM TOÁN TỪNG TIẾT (AUDIT LOG)", style: TextStyle(color: theme.textColor, fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 1.2)),
                                const SizedBox(height: 15),

                                Expanded(child: SingleChildScrollView(physics: const BouncingScrollPhysics(), child: Column(children: [...pLogs.asMap().entries.map((entry) { int idx = entry.key; var log = entry.value; return buildInteractiveTimelineRow(log, _getColorByType(log['type'] ?? 'info', theme), isLast: idx == pLogs.length - 1); })])))
                              ],
                            ),
                          ),
                        ),

                        Expanded(
                            flex: 4,
                            child: Padding(
                              padding: const EdgeInsets.all(30),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(stName, style: TextStyle(color: theme.textColor, fontSize: 24, fontWeight: FontWeight.w900)), IconButton(onPressed: () => Navigator.pop(context), icon: Icon(Icons.close_rounded, color: theme.subTextColor))]), Text("Mã HS: $stId  •  Giới tính: $stGender", style: TextStyle(color: theme.subTextColor, fontSize: 13)), const SizedBox(height: 25),

                                  if (updateReason.isNotEmpty || pStatus == 'Có phép')
                                    Container(
                                        margin: const EdgeInsets.only(bottom: 25), padding: const EdgeInsets.all(20),
                                        decoration: BoxDecoration(color: theme.infoColor.withOpacity(0.08), borderRadius: BorderRadius.circular(16), border: Border.all(color: theme.infoColor.withOpacity(0.6), width: 1.5)),
                                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Row(children: [Icon(Icons.edit_document, color: theme.infoColor, size: 28), const SizedBox(width: 12), Text("ĐƠN XIN PHÉP / GHI CHÚ ĐÍNH KÈM", style: TextStyle(color: theme.infoColor, fontSize: 14, fontWeight: FontWeight.w900, letterSpacing: 1.0))]), const SizedBox(height: 12), Text(updateReason.isNotEmpty ? updateReason : "Giáo viên/Phụ huynh đã báo phép qua ứng dụng.", style: TextStyle(color: theme.textColor, fontSize: 15, height: 1.5))])
                                    ),

                                  Text("Cập nhật trạng thái tiết hiện tại\n($currentSubject)", style: TextStyle(color: theme.primaryColor, fontWeight: FontWeight.bold, fontSize: 13)), const SizedBox(height: 8),
                                  Container(
                                    height: 50, decoration: BoxDecoration(color: theme.primaryColor.withOpacity(0.05), borderRadius: BorderRadius.circular(10), border: Border.all(color: theme.primaryColor.withOpacity(0.5))),
                                    child: DropdownButtonHideUnderline(
                                      child: DropdownButton<String>(
                                        isExpanded: true, padding: const EdgeInsets.symmetric(horizontal: 15), dropdownColor: theme.cardColor,
                                        value: ['Có mặt', 'Vắng mặt', 'Ra ngoài', 'Được ra ngoài', 'Đi trễ', 'Nghỉ học', 'Có phép', 'Chưa điểm danh', 'Trống tiết'].contains(pStatus) ? pStatus : 'Chưa điểm danh',
                                        style: TextStyle(color: theme.primaryColor, fontWeight: FontWeight.bold, fontSize: 15),
                                        items: ['Có mặt', 'Vắng mặt', 'Ra ngoài', 'Được ra ngoài', 'Đi trễ', 'Nghỉ học', 'Có phép', 'Chưa điểm danh', 'Trống tiết'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                                        onChanged: (val) => setStateDialog(() => pStatus = val!),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 25),

                                  Text("Ghi chú đính kèm hồ sơ (Thay đổi Đơn xin phép)", style: TextStyle(color: theme.textColor, fontWeight: FontWeight.bold, fontSize: 13)), const SizedBox(height: 8),
                                  TextFormField(
                                    controller: reasonController,
                                    maxLines: 4, onChanged: (v) => updateReason = v, style: TextStyle(color: theme.textColor, fontSize: 14),
                                    decoration: InputDecoration(hintText: "Nhập nội dung vào đây...", hintStyle: TextStyle(color: theme.subTextColor), filled: true, fillColor: theme.textColor.withOpacity(0.04), border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: theme.borderColor)), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: theme.primaryColor))),
                                  ),

                                  const Spacer(),
                                  SizedBox(
                                      width: double.infinity,
                                      child: ElevatedButton.icon(
                                          onPressed: () async {
                                            pLogs.insert(0, { "id": "manual_log_${DateTime.now().millisecondsSinceEpoch}", "time": "${DateTime.now().hour.toString().padLeft(2,'0')}:${DateTime.now().minute.toString().padLeft(2,'0')}", "period": currentSubject.isNotEmpty ? currentSubject : "Tiết hiện tại", "status": pStatus, "detail": updateReason.isNotEmpty ? updateReason : "Giáo viên chốt cập nhật trạng thái.", "type": (pStatus == 'Nghỉ học' || pStatus == 'Vắng mặt') ? "error" : "info", "img": null, "subjectTeacher": "Chưa gán", "updatedBy": "Giáo viên Đứng lớp" });
                                            showDialog(context: context, barrierDismissible: false, builder: (c) => Center(child: CircularProgressIndicator(color: theme.primaryColor)));

                                            try {
                                              Map<String, dynamic> payload = { "status": pStatus, "reason": updateReason, "logs": pLogs };
                                              var response = await http.post(Uri.parse('http://127.0.0.1:8000/api/students/${student["id"]}/live_update'), headers: {"Content-Type": "application/json"}, body: jsonEncode(payload));

                                              if (context.mounted) Navigator.pop(context); // Tắt vòng xoay

                                              if (response.statusCode == 200 || response.statusCode == 201) {
                                                var data = jsonDecode(response.body);
                                                if (data['status'] == 'success') {
                                                  setState(() { _liveStatusOverrides[student['id'].toString()] = { "status": pStatus, "logs": pLogs, "reason": updateReason }; });
                                                  Navigator.pop(context); // Đóng bảng Chi tiết
                                                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Đã đồng bộ dữ liệu điểm danh lên Hệ thống trung tâm!"), backgroundColor: Colors.green));
                                                } else {
                                                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(data['message']), backgroundColor: Colors.redAccent));
                                                }
                                              } else {
                                                // ĐÃ FIX: HIỂN THỊ MÃ LỖI NẾU BỊ TỪ CHỐI
                                                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Lỗi API (Mã: ${response.statusCode})"), backgroundColor: Colors.redAccent));
                                              }
                                            } catch (e) {
                                              if (context.mounted) Navigator.pop(context);
                                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Lỗi kết nối máy chủ: Vui lòng kiểm tra Python Server"), backgroundColor: Colors.redAccent));
                                            }
                                          },
                                          icon: const Icon(Icons.save_rounded, color: Colors.white, size: 18), label: const Text("XÁC NHẬN CHỐT LẠI", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                          style: ElevatedButton.styleFrom(backgroundColor: theme.primaryColor, padding: const EdgeInsets.symmetric(vertical: 20), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)))
                                      )
                                  )
                                ],
                              ),
                            )
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
}