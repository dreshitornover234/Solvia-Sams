import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/intl.dart';
import '../theme_manager.dart';
import '../globals.dart' as globals;

class BellPeriod {
  final String name;
  final String timeFrame;
  BellPeriod(this.name, this.timeFrame);
}

class MergedSlot {
  final Map<String, dynamic> cls;
  final BellPeriod period;
  MergedSlot(this.cls, this.period);
}

class UnifiedTimetableView extends StatefulWidget {
  final VoidCallback? onDataChanged;
  final bool isSuperAdmin; // THÊM BIẾN QUYỀN TRUY CẬP

  const UnifiedTimetableView({super.key, this.isSuperAdmin = false, this.onDataChanged});

  @override
  State<UnifiedTimetableView> createState() => _UnifiedTimetableViewState();
}

class _UnifiedTimetableViewState extends State<UnifiedTimetableView> {

  bool _isLoading = true;
  List<dynamic> _classesData = [];
  List<dynamic> _teachersData = [];
  List<BellPeriod> _bellSchedule = [];

  final List<String> _daysOfWeek = ['Thứ 2', 'Thứ 3', 'Thứ 4', 'Thứ 5', 'Thứ 6', 'Thứ 7', 'Chủ Nhật'];
  DateTime _currentWeekStart = DateTime.now().subtract(Duration(days: DateTime.now().weekday - 1));

  final Map<String, Map<String, dynamic>> _weeklyOverrides = {};

  bool _isMultiSelecting = false;
  Map<String, dynamic>? _pendingEventData;
  List<String> _selectedMultiCells = [];
  Map<String, String> _teacherClassMap = {};

  @override
  void initState() {
    super.initState();
    _fetchAllData();
  }

  Future<void> _fetchAllData() async {
    setState(() => _isLoading = true);
    try {
      var resProj = await http.get(Uri.parse('http://127.0.0.1:8000/api/projects/${globals.currentProjectId}'));
      if (resProj.statusCode == 200) {
        var pData = jsonDecode(utf8.decode(resProj.bodyBytes));
        if (pData['status'] == 'success') {
          var bSched = pData['data']['bell_schedule'];
          if (bSched != null && (bSched as List).isNotEmpty) {
            _bellSchedule = bSched.map((e) => BellPeriod(e['name'], "${e['start_time']} - ${e['end_time']}")).toList();
          }
        }
      }
      if (_bellSchedule.isEmpty) _bellSchedule = [BellPeriod("Tiết 1", "07:00 - 07:45"), BellPeriod("Tiết 2", "07:45 - 08:30")];

      var resMembers = await http.get(Uri.parse('http://127.0.0.1:8000/api/projects/${globals.currentProjectId}/members'));
      if (resMembers.statusCode == 200) {
        var dataMem = jsonDecode(utf8.decode(resMembers.bodyBytes));
        if (dataMem['status'] == 'success') _teachersData = [...(dataMem['data']['admins'] ?? []), ...(dataMem['data']['managers'] ?? [])];
      }

      var resClasses = await http.get(Uri.parse('http://127.0.0.1:8000/api/projects/${globals.currentProjectId}/classes'));
      if (resClasses.statusCode == 200) {
        var dataClasses = jsonDecode(utf8.decode(resClasses.bodyBytes));
        if (dataClasses['status'] == 'success') {
          List<dynamic> classList = dataClasses['data'];
          List<dynamic> fullClassesData = [];
          Map<String, String> tempTeacherClassMap = {};

          for (var cls in classList) {
            var resDetail = await http.get(Uri.parse('http://127.0.0.1:8000/api/classes/${cls['id']}'));
            if (resDetail.statusCode == 200) {
              var clsData = jsonDecode(utf8.decode(resDetail.bodyBytes))['data'];
              clsData['id'] = cls['id'];
              fullClassesData.add(clsData);

              if (clsData['teacher'] != null && clsData['teacher']['id'] != null) {
                tempTeacherClassMap[clsData['teacher']['id'].toString()] = clsData['class_name'];
              }

              List<dynamic> tb = clsData['timetable'] ?? [];
              for (var d in tb) {
                if (d['dayName'].toString().contains("-")) {
                  for(var s in d['subjects']) { _weeklyOverrides["${d['dayName']}_${cls['id']}_${s['timeFrame']}"] = s; }
                }
              }
            }
          }
          if (mounted) setState(() {
            _classesData = fullClassesData;
            _teacherClassMap = tempTeacherClassMap;
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _changeWeek(int offset) { setState(() => _currentWeekStart = _currentWeekStart.add(Duration(days: offset * 7))); }
  String _getWeekLabel() { DateTime end = _currentWeekStart.add(const Duration(days: 6)); return "Tuần: ${DateFormat('dd/MM').format(_currentWeekStart)} - ${DateFormat('dd/MM/yyyy').format(end)}"; }
  String _formatDateKey(DateTime date) => DateFormat('yyyy-MM-dd').format(date);
  String _getDayOfWeek(int dayIndex) => ['Thứ 2', 'Thứ 3', 'Thứ 4', 'Thứ 5', 'Thứ 6', 'Thứ 7', 'Chủ Nhật'][dayIndex];

  Map<String, dynamic>? _findCellData(Map<String, dynamic> cls, DateTime targetDate, String dayOfWeek, String timeFrame) {
    String overrideKey = "${_formatDateKey(targetDate)}_${cls['id']}_$timeFrame";
    if (_weeklyOverrides.containsKey(overrideKey)) {
      if (_weeklyOverrides[overrideKey]!['status'] == 'Trống') return null;
      return _weeklyOverrides[overrideKey];
    }
    for (var d in (cls['timetable'] ?? [])) {
      if (d['dayName'] == dayOfWeek) {
        for (var s in d['subjects'] ?? []) { if (s['timeFrame'] == timeFrame) return s; }
      }
    }
    return null;
  }

  Map<String, dynamic> _analyzeTeacherWorkload(int teacherId, DateTime targetDate, String dayOfWeek, String timeFrame) {
    int totalSlots = 0; bool isConflict = false; String conflictDetail = "";
    for (var cls in _classesData) {
      var cellData = _findCellData(cls, targetDate, dayOfWeek, timeFrame);
      if (cellData != null && cellData['teacher_id'] == teacherId && cellData['status'] != 'Nghỉ học') {
        totalSlots++;
        isConflict = true;
        conflictDetail = "Cấn lịch ở ${cls['class_name']}";
      }
    }
    return {"totalSlots": totalSlots, "isConflict": isConflict, "conflictDetail": conflictDetail};
  }

  int _getTeacherWeeklyTotal(int teacherId) {
    int total = 0; Set<String> countedKeys = {};
    for (var cls in _classesData) {
      for (var d in (cls['timetable'] ?? [])) {
        String dayName = d['dayName'].toString();
        bool isInCurrentWeek = false;
        for (int i = 0; i < 7; i++) {
          DateTime weekDay = _currentWeekStart.add(Duration(days: i));
          if (_formatDateKey(weekDay) == dayName || _getDayOfWeek(weekDay.weekday - 1) == dayName) { isInCurrentWeek = true; break; }
        }
        if (!isInCurrentWeek) continue;
        for (var s in (d['subjects'] ?? [])) {
          if (s['teacher_id'] == teacherId && s['status'] != 'Nghỉ học' && s['status'] != 'Trống') {
            String key = "${cls['id']}_${dayName}_${s['timeFrame']}";
            if (!countedKeys.contains(key)) { countedKeys.add(key); total++; }
          }
        }
      }
    }
    _weeklyOverrides.forEach((key, value) {
      if (value['teacher_id'] == teacherId && value['status'] != 'Nghỉ học' && value['status'] != 'Trống') {
        List<String> parts = key.split('_');
        if (parts.length >= 2) {
          String dateStr = parts[0];
          try {
            DateTime overrideDate = DateTime.parse(dateStr);
            if (overrideDate.isAfter(_currentWeekStart.subtract(const Duration(days: 1))) && overrideDate.isBefore(_currentWeekStart.add(const Duration(days: 7)))) {
              String uniqueKey = "${parts[1]}_${dateStr}_${parts[2]}";
              if (!countedKeys.contains(uniqueKey)) { countedKeys.add(uniqueKey); total++; }
            }
          } catch (_) {}
        }
      }
    });
    return total;
  }

  void _insertEventToClassLocal(Map<String, dynamic> cls, String dateKey, String timeFrame, Map<String, dynamic> eventData) {
    String overrideKey = "${dateKey}_${cls['id']}_$timeFrame";
    _weeklyOverrides[overrideKey] = eventData;

    List<dynamic> timetable = cls['timetable'] ?? [];
    var targetDay;
    for(var d in timetable) { if (d['dayName'] == dateKey) { targetDay = d; break; } }

    if (targetDay == null) {
      targetDay = {"dayName": dateKey, "subjects": []};
      timetable.add(targetDay);
    }
    var subjects = targetDay['subjects'] as List<dynamic>;
    subjects.removeWhere((s) => s['timeFrame'] == timeFrame);

    if (eventData['status'] != 'Trống') {
      Map<String, dynamic> newSub = Map.from(eventData);
      newSub['timeFrame'] = timeFrame;
      subjects.add(newSub);
    }
    cls['timetable'] = timetable;
  }

  Future<void> _syncTimetableToServer(Map<String, dynamic> cls) async {
    Map<String, dynamic> payload = { "class_name": cls['class_name'], "course_start_year": cls['course_start_year'], "course_end_year": cls['course_end_year'], "current_year_start": cls['current_year_start'], "current_year_end": cls['current_year_end'], "current_semester": cls['current_semester'], "timetable": cls['timetable'] };
    try { await http.put(Uri.parse('http://127.0.0.1:8000/api/classes/${cls['id']}'), headers: {"Content-Type": "application/json"}, body: jsonEncode(payload)); widget.onDataChanged?.call();} catch (e) {}
  }

  List<MergedSlot> _getAllMergedSlots(DateTime targetDate, String dayOfWeek, Map<String, dynamic> cellData) {
    List<MergedSlot> merged = [];
    for (var c in _classesData) {
      for (var p in _bellSchedule) {
        var d = _findCellData(c, targetDate, dayOfWeek, p.timeFrame);
        if (d != null && d['name'] == cellData['name'] && d['teacher_id'] == cellData['teacher_id'] && d['type'] == cellData['type']) {
          merged.add(MergedSlot(c, p));
        }
      }
    }
    return merged;
  }

  Color _getTeacherColor(String teacherName, AppTheme theme) {
    if (teacherName.isEmpty || teacherName.contains("Chưa gán")) return theme.primaryColor;
    List<Color> palette = [ Colors.blue, Colors.teal, Colors.indigo, Colors.brown, Colors.deepOrange, Colors.cyan, Colors.pink ];
    return palette[teacherName.hashCode.abs() % palette.length];
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
        animation: AppTheme.instance,
        builder: (context, child) {
          final theme = AppTheme.instance;

          return Scaffold(
            backgroundColor: Colors.transparent,
            body: Stack(
              children: [
                Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text("Thời Khóa Biểu Excel", style: TextStyle(fontSize: 22 * theme.fontScale, fontWeight: FontWeight.w900, color: theme.textColor)),
                              const SizedBox(height: 4),
                              Text("Quản lý học bù, dạy thế và tự động gộp khối liên thông Lớp - Tiết.", style: TextStyle(fontSize: 12 * theme.fontScale, color: theme.subTextColor)),
                            ],
                          ),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5), decoration: BoxDecoration(color: theme.cardColor, borderRadius: BorderRadius.circular(12), border: Border.all(color: theme.borderColor)),
                                child: Row(
                                  children: [
                                    IconButton(onPressed: () => _changeWeek(-1), icon: Icon(Icons.chevron_left_rounded, color: theme.primaryColor, size: 20)),
                                    Text(_getWeekLabel(), style: TextStyle(color: theme.textColor, fontWeight: FontWeight.bold, fontSize: 12 * theme.fontScale)),
                                    IconButton(onPressed: () => _changeWeek(1), icon: Icon(Icons.chevron_right_rounded, color: theme.primaryColor, size: 20)),
                                    Container(width: 1, height: 15, color: theme.borderColor, margin: const EdgeInsets.symmetric(horizontal: 5)),
                                    TextButton(onPressed: () => setState(() => _currentWeekStart = DateTime.now().subtract(Duration(days: DateTime.now().weekday - 1))), child: Text("Hiện tại", style: TextStyle(color: theme.primaryColor, fontWeight: FontWeight.bold, fontSize: 11 * theme.fontScale)))
                                  ],
                                ),
                              ),
                              const SizedBox(width: 15),

                              // CHỈ SUPER ADMIN MỚI ĐƯỢC PHÉP ĐỒNG BỘ TKB
                              if (widget.isSuperAdmin)
                                ElevatedButton.icon(
                                  onPressed: () => _showSyncDialog(theme),
                                  icon: const Icon(Icons.cloud_sync_rounded, color: Colors.white, size: 14),
                                  label: const Text("Đồng bộ TKB", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                                  style: ElevatedButton.styleFrom(backgroundColor: theme.primaryColor, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)), padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12)),
                                )
                            ],
                          )
                        ],
                      ),
                      const SizedBox(height: 15),

                      if (_isMultiSelecting)
                        Container(
                          margin: const EdgeInsets.only(bottom: 10), padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(color: theme.successColor.withOpacity(0.15), borderRadius: BorderRadius.circular(8), border: Border.all(color: theme.successColor.withOpacity(0.5))),
                          child: Row(children: [Icon(Icons.touch_app_rounded, color: theme.successColor, size: 18), const SizedBox(width: 10), Text("Chế độ Dán khối: Bấm vào các ô để dán '${_pendingEventData?['name']}'. Bấm Hoàn Thành để lưu.", style: TextStyle(color: theme.successColor, fontWeight: FontWeight.bold, fontSize: 12 * theme.fontScale))]),
                        ),

                      if (_isLoading)
                        Center(child: Padding(padding: const EdgeInsets.all(50), child: CircularProgressIndicator(color: theme.primaryColor)))
                      else if (_classesData.isEmpty || _bellSchedule.isEmpty)
                        Center(child: Text("Khởi tạo Lớp học và Cấu hình Khung giờ để hiển thị Ma trận.", style: TextStyle(color: theme.subTextColor, fontStyle: FontStyle.italic)))
                      else
                        Expanded(child: _buildExcelMatrixGrid(theme))
                    ],
                  ),
                ),

                if (_isMultiSelecting)
                  Positioned(
                    bottom: 30, right: 30,
                    child: FloatingActionButton.extended(
                      onPressed: () async {
                        setState(() {
                          for (String key in _selectedMultiCells) {
                            var parts = key.split('_');
                            if(parts.length == 3) {
                              String dateKey = parts[0]; int clsId = int.parse(parts[1]); String tf = parts[2];
                              var targetCls = _classesData.firstWhere((c) => c['id'] == clsId);
                              _insertEventToClassLocal(targetCls, dateKey, tf, Map.from(_pendingEventData!));
                            }
                          }
                          _isMultiSelecting = false; _pendingEventData = null; _selectedMultiCells.clear();
                        });
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Đang đồng bộ chùm sự kiện lên Server..."), backgroundColor: Colors.orange));
                        for (var cls in _classesData) { await _syncTimetableToServer(cls); }
                        if(mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Đã lưu hoàn tất!"), backgroundColor: Colors.green));
                      },
                      backgroundColor: theme.successColor,
                      icon: const Icon(Icons.check_circle_rounded, color: Colors.white),
                      label: const Text("Hoàn Thành Dán", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                  )
              ],
            ),
          );
        }
    );
  }

  Widget _buildExcelMatrixGrid(AppTheme theme) {
    double cellW = 120 * theme.fontScale;
    double cellH = 70 * theme.fontScale;
    double timeW = 95 * theme.fontScale;

    List<Widget> gridRows = [];

    List<Widget> headerCells = [Container(width: timeW, height: 45, decoration: BoxDecoration(color: theme.primaryColor.withOpacity(0.15), border: Border(right: BorderSide(color: theme.borderColor), bottom: BorderSide(color: theme.borderColor))), child: Center(child: Text("THỜI GIAN", style: TextStyle(color: theme.primaryColor, fontWeight: FontWeight.bold, fontSize: 11 * theme.fontScale))))];
    for (var cls in _classesData) {
      headerCells.add(Container(width: cellW, height: 45, decoration: BoxDecoration(color: theme.cardColor, border: Border(right: BorderSide(color: theme.borderColor), bottom: BorderSide(color: theme.borderColor))), child: Center(child: Text(cls['class_name'], style: TextStyle(color: theme.textColor, fontWeight: FontWeight.bold, fontSize: 14 * theme.fontScale)))));
    }
    gridRows.add(Row(children: headerCells));

    for (int dayIndex = 0; dayIndex < 7; dayIndex++) {
      DateTime currentDate = _currentWeekStart.add(Duration(days: dayIndex));
      String dayStr = _getDayOfWeek(dayIndex);
      String dateLabel = DateFormat('dd/MM').format(currentDate);
      String dateKey = _formatDateKey(currentDate);

      gridRows.add(Container(color: theme.primaryColor.withOpacity(0.05), child: Row(children: [Container(width: timeW, padding: const EdgeInsets.symmetric(vertical: 6), decoration: BoxDecoration(border: Border(right: BorderSide(color: theme.borderColor), bottom: BorderSide(color: theme.borderColor))), child: Center(child: Text("$dayStr\n($dateLabel)", textAlign: TextAlign.center, style: TextStyle(color: theme.primaryColor, fontWeight: FontWeight.bold, fontSize: 11 * theme.fontScale)))), Container(width: _classesData.length * cellW, decoration: BoxDecoration(border: Border(bottom: BorderSide(color: theme.borderColor))))])));

      for (int pIndex = 0; pIndex < _bellSchedule.length; pIndex++) {
        var period = _bellSchedule[pIndex];
        var nextPeriod = (pIndex < _bellSchedule.length - 1) ? _bellSchedule[pIndex + 1] : null;

        List<Widget> rowCells = [Container(width: timeW, height: cellH, padding: const EdgeInsets.all(4), decoration: BoxDecoration(color: theme.cardColor, border: Border(right: BorderSide(color: theme.borderColor), bottom: BorderSide(color: theme.borderColor))), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Text(period.name, style: TextStyle(color: theme.textColor, fontWeight: FontWeight.bold, fontSize: 11 * theme.fontScale)), Text(period.timeFrame, style: TextStyle(color: theme.subTextColor, fontSize: 10 * theme.fontScale))]))];

        for (int cIndex = 0; cIndex < _classesData.length; cIndex++) {
          var cls = _classesData[cIndex];
          var nextCls = (cIndex < _classesData.length - 1) ? _classesData[cIndex + 1] : null;
          var cellData = _findCellData(cls, currentDate, dayStr, period.timeFrame);

          bool mergeRight = false;
          bool mergeBottom = false;
          bool hideContent = false;
          Color? cellBgColor;

          if (cellData != null && cellData['status'] != 'Trống') {
            bool isCancelled = cellData['status'] == 'Nghỉ học';
            bool isSub = cellData['status'] == 'Dạy thế';
            bool isMakeup = cellData['status'] == 'Học bù';

            Color baseColor = _getTeacherColor(cellData['teacher_name'] ?? "", theme);
            if (cellData['type'] == 'Cuộc họp') baseColor = theme.purpleColor;
            if (cellData['type'] == 'Hoạt động') baseColor = theme.warningColor;
            cellBgColor = isCancelled ? theme.errorColor.withOpacity(0.2) : (isSub || isMakeup ? theme.infoColor.withOpacity(0.2) : baseColor.withOpacity(0.25));

            if (nextCls != null) {
              var r = _findCellData(nextCls, currentDate, dayStr, period.timeFrame);
              if (r != null && r['name'] == cellData['name'] && r['teacher_id'] == cellData['teacher_id'] && r['type'] == cellData['type']) mergeRight = true;
            }
            if (nextPeriod != null) {
              var b = _findCellData(cls, currentDate, dayStr, nextPeriod.timeFrame);
              if (b != null && b['name'] == cellData['name'] && b['teacher_id'] == cellData['teacher_id'] && b['type'] == cellData['type']) mergeBottom = true;
            }
            if (cIndex > 0) {
              var l = _findCellData(_classesData[cIndex - 1], currentDate, dayStr, period.timeFrame);
              if (l != null && l['name'] == cellData['name'] && l['teacher_id'] == cellData['teacher_id'] && l['type'] == cellData['type']) hideContent = true;
            }
            if (pIndex > 0) {
              var t = _findCellData(cls, currentDate, dayStr, _bellSchedule[pIndex - 1].timeFrame);
              if (t != null && t['name'] == cellData['name'] && t['teacher_id'] == cellData['teacher_id'] && t['type'] == cellData['type']) hideContent = true;
            }
          }

          String cellKey = "${dateKey}_${cls['id']}_${period.timeFrame}";
          bool isSelected = _selectedMultiCells.contains(cellKey);

          rowCells.add(
              Container(
                  width: cellW,
                  height: cellH,
                  decoration: BoxDecoration(
                    border: Border(
                      right: mergeRight ? BorderSide.none : BorderSide(color: theme.borderColor),
                      bottom: mergeBottom ? BorderSide.none : BorderSide(color: theme.borderColor),
                    ),
                    color: isSelected ? theme.successColor.withOpacity(0.3) : (cellBgColor ?? Colors.transparent),
                  ),
                  child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                          hoverColor: theme.primaryColor.withOpacity(0.05),
                          onTap: () {
                            // ==========================================
                            // KHÓA CHỨC NĂNG SỬA/THÊM TIẾT NẾU LÀ HỌC SINH
                            // ==========================================
                            if (globals.currentUserRole == 'Học sinh' || globals.currentUserRole == 'Thành viên') {
                              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: const Text("Tài khoản Học sinh chỉ có quyền Xem thời khóa biểu!"), backgroundColor: theme.warningColor));
                              return;
                            }
                            if (_isMultiSelecting) {
                              if (cellData == null || cellData['status'] == 'Trống') {
                                setState(() { isSelected ? _selectedMultiCells.remove(cellKey) : _selectedMultiCells.add(cellKey); });
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: const Text("Ô này đã có sự kiện!"), backgroundColor: theme.errorColor));
                              }
                            } else {
                              if (cellData == null || cellData['status'] == 'Trống') {
                                _showAddSlotDialog(currentDate, dayStr, cls, period, theme);
                              } else {
                                // XÁC ĐỊNH QUYỀN SỞ HỮU TIẾT HỌC (Super Admin HOẶC chính chủ mới được sửa)
                                bool canEdit = widget.isSuperAdmin || (cellData['teacher_id']?.toString() == globals.currentUserId.toString());

                                // Truyền canEdit vào Dialog
                                _showActionSlotDialog(currentDate, dayStr, cls, period, cellData, theme, canEdit: canEdit);
                              }
                            }
                          },
                          child: Padding(
                            padding: const EdgeInsets.all(2.0),
                            child: isSelected
                                ? Center(child: Icon(Icons.check_circle, color: theme.successColor, size: 20))
                                : (cellData == null || cellData['status'] == 'Trống'
                                ? Center(child: Icon(Icons.add_rounded, color: theme.subTextColor.withOpacity(0.15), size: 18))
                                : (hideContent ? const SizedBox() : _buildCellText(cellData, theme))),
                          )
                      )
                  )
              )
          );
        }
        gridRows.add(Row(children: rowCells));
      }
    }

    return Container(
        decoration: BoxDecoration(color: theme.cardColor, border: Border.all(color: theme.borderColor), borderRadius: BorderRadius.circular(12)),
        child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SingleChildScrollView(
                scrollDirection: Axis.vertical,
                physics: const BouncingScrollPhysics(),
                child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(children: [
            Expanded(
                child: Text(data['name'] ?? "", style: TextStyle(color: textColor, fontWeight: FontWeight.bold, decoration: isCancelled ? TextDecoration.lineThrough : null, fontSize: 13 * theme.fontScale), overflow: TextOverflow.ellipsis)
            ),
            if (isCancelled) Icon(Icons.block_rounded, color: theme.errorColor, size: 14)
            else if (isSub) Icon(Icons.swap_horiz_rounded, color: theme.infoColor, size: 14)
            else if (isMakeup) Icon(Icons.restore_rounded, color: theme.infoColor, size: 14)
          ]),
          const SizedBox(height: 2),
          Text(data['teacher_name'] ?? data['notes'] ?? "", style: TextStyle(color: theme.textColor, fontSize: 11 * theme.fontScale), overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }

  void _showAddSlotDialog(DateTime date, String dayStr, Map<String, dynamic> cls, BellPeriod period, AppTheme theme) {
    // GIÁO VIÊN MẶC ĐỊNH LÀ CUỘC HỌP, ADMIN MẶC ĐỊNH LÀ MÔN HỌC
    String type = widget.isSuperAdmin ? 'Môn học' : 'Cuộc họp';

    String subjectName = "";
    String eventName = "Họp";
    String activityName = "Lao động";
    String notes = "";

    dynamic selectedTeacher;
    bool showAllTeachers = false;
    String searchQuery = "";

    showDialog(
        context: context,
        builder: (context) {
          return StatefulBuilder(
              builder: (context, setStateDialog) {

                String currentName() {
                  if (type == 'Môn học') return subjectName;
                  if (type == 'Cuộc họp') return eventName;
                  return activityName;
                }

                void updateCurrentName(String newValue) {
                  setStateDialog(() {
                    if (type == 'Môn học') subjectName = newValue;
                    else if (type == 'Cuộc họp') eventName = newValue;
                    else activityName = newValue;
                  });
                }

                // SỬA LOGIC TRONG HÀM LOC / SEARCH CỦA THỜI KHÓA BIỂU CHUNG
                // ĐÃ SỬA: Đổi tên lại thành availableTeachers và dùng đúng biến searchQuery
                List<dynamic> availableTeachers = _teachersData.where((t) {
                  String tName = (t['name'] ?? "").toString().toLowerCase();

                  // Đọc chính xác trường teaching_subject
                  String tSpec = (t['teaching_subject'] ?? "").toString().toLowerCase();

                  // Sử dụng đúng biến searchQuery thay vì query
                  String searchKey = searchQuery.toLowerCase();

                  if (type == 'Môn học') {
                    if (showAllTeachers) {
                      if (searchKey.isEmpty) return true;
                      // Quét cả tên HOẶC môn học
                      return tName.contains(searchKey) || tSpec.contains(searchKey);
                    } else {
                      if (subjectName.trim().isEmpty) return true;
                      // Nếu không bật "Tất cả", chỉ hiển thị đúng GV dạy môn đang nhập
                      return tSpec.contains(subjectName.toLowerCase());
                    }
                  } else { // Cuộc họp hoặc Hoạt động
                    if (searchKey.isEmpty) return true;
                    return tName.contains(searchKey) || tSpec.contains(searchKey);
                  }
                }).toList();

                return Dialog(
                  backgroundColor: theme.cardColor,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: theme.borderColor)),
                  child: Container(
                    width: 600, height: 750, padding: const EdgeInsets.all(30),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                          Text("Phân bổ Sự kiện", style: TextStyle(color: theme.textColor, fontSize: 18 * theme.fontScale, fontWeight: FontWeight.bold)),
                          IconButton(onPressed: () => Navigator.pop(context), icon: Icon(Icons.close, color: theme.subTextColor))
                        ]),
                        Text("${cls['class_name']} | ${DateFormat('dd/MM/yyyy').format(date)} (${period.name}: ${period.timeFrame})",
                            style: TextStyle(color: theme.primaryColor, fontWeight: FontWeight.bold, fontSize: 13)),
                        const SizedBox(height: 20),

                        Row(children: [
                          // ẨN MÔN HỌC NẾU KHÔNG PHẢI ADMIN
                          if (widget.isSuperAdmin) ...[
                            Expanded(child: _buildRadioOption("Môn học", type, (v) => setStateDialog((){ type = v; showAllTeachers = false; searchQuery = ""; selectedTeacher = null; }), theme, theme.primaryColor)),
                            const SizedBox(width: 8),
                          ],
                          Expanded(child: _buildRadioOption("Cuộc họp", type, (v) => setStateDialog((){ type = v; searchQuery = ""; selectedTeacher = null; }), theme, theme.purpleColor)),
                          const SizedBox(width: 8),
                          Expanded(child: _buildRadioOption("Hoạt động", type, (v) => setStateDialog((){ type = v; searchQuery = ""; selectedTeacher = null; }), theme, theme.warningColor))
                        ]),
                        const SizedBox(height: 20),

                        if (type == 'Môn học' && widget.isSuperAdmin) ...[
                          _buildDialogInput("Tên môn học (VD: Toán, Lý, Văn...)", (v) => updateCurrentName(v), theme, initial: subjectName),
                          const SizedBox(height: 15),

                          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                            Text("Giáo viên bộ môn", style: TextStyle(color: theme.textColor, fontWeight: FontWeight.bold, fontSize: 13)),
                            TextButton(onPressed: () => setStateDialog((){ showAllTeachers = !showAllTeachers; searchQuery = ""; }),
                                child: Text(showAllTeachers ? "Về gợi ý tự động" : "Tìm giáo viên khác...", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)))
                          ]),

                          Expanded(child: Container(
                            decoration: BoxDecoration(color: theme.textColor.withOpacity(0.01), borderRadius: BorderRadius.circular(10), border: Border.all(color: theme.borderColor)),
                            child: Column(children: [
                              if (showAllTeachers)
                                Padding(padding: const EdgeInsets.all(10), child: _buildDialogInput("Gõ tìm tên hoặc chuyên môn...", (v) => setStateDialog(() => searchQuery = v), theme, icon: Icons.search)),
                              Expanded(
                                child: ListView.builder(
                                  itemCount: availableTeachers.length,
                                  itemBuilder: (context, index) {
                                    var teacher = availableTeachers[index];
                                    Map<String, dynamic> analysis = _analyzeTeacherWorkload(teacher['user_id'], date, dayStr, period.timeFrame);
                                    bool isConflict = analysis['isConflict'];
                                    int weeklyTotal = _getTeacherWeeklyTotal(teacher['user_id']);
                                    bool isSelected = selectedTeacher == teacher;
                                    String tIdStr = (teacher['user_id'] ?? teacher['id'])?.toString() ?? "";
                                    String assignedClass = _teacherClassMap[tIdStr] ?? teacher['unit']?.toString() ?? "";
                                    String unitStr = assignedClass.isNotEmpty ? " | Lớp CN: $assignedClass" : "";

                                    return ListTile(
                                      dense: true,
                                      onTap: isConflict ? null : () => setStateDialog(() => selectedTeacher = teacher),
                                      leading: CircleAvatar(backgroundColor: theme.primaryColor.withOpacity(0.1), child: Icon(Icons.person, color: theme.primaryColor, size: 16)),
                                      title: Text(teacher['name'], style: TextStyle(color: isConflict ? theme.subTextColor : theme.textColor, fontWeight: FontWeight.bold, fontSize: 13)),
                                      subtitle: Text(
                                          isConflict
                                              ? analysis['conflictDetail']
                                              : "Môn: ${teacher['teaching_subject'] ?? 'Chung'}$unitStr | Tuần này: $weeklyTotal tiết",
                                          style: TextStyle(color: isConflict ? theme.errorColor : theme.subTextColor, fontSize: 11)
                                      ),
                                      trailing: isConflict
                                          ? Icon(Icons.block_rounded, color: theme.errorColor, size: 16)
                                          : (isSelected ? Icon(Icons.check_circle_rounded, color: theme.successColor, size: 18) : const Icon(Icons.circle_outlined, size: 18)),
                                    );
                                  },
                                ),
                              )
                            ]),
                          ))
                        ] else ...[
                          _buildDialogInput(
                              type == 'Cuộc họp' ? "Tên cuộc họp..." : "Tên hoạt động...",
                                  (v) => updateCurrentName(v), theme, initial: currentName()
                          ),
                          const SizedBox(height: 15),
                          _buildDialogInput("Ghi chú", (v) => setStateDialog(() => notes = v), theme, initial: notes),
                          const SizedBox(height: 15),

                          Text("Giáo viên phụ trách", style: TextStyle(color: theme.textColor, fontWeight: FontWeight.bold, fontSize: 13)),
                          const SizedBox(height: 8),

                          Expanded(child: Container(
                            decoration: BoxDecoration(color: theme.textColor.withOpacity(0.01), borderRadius: BorderRadius.circular(10), border: Border.all(color: theme.borderColor)),
                            child: Column(children: [
                              Padding(padding: const EdgeInsets.all(10), child: _buildDialogInput("Gõ tìm tên giáo viên...", (v) => setStateDialog(() => searchQuery = v), theme, icon: Icons.search)),
                              Expanded(
                                child: ListView.builder(
                                  itemCount: availableTeachers.length,
                                  itemBuilder: (context, index) {
                                    var teacher = availableTeachers[index];
                                    Map<String, dynamic> analysis = _analyzeTeacherWorkload(teacher['user_id'], date, dayStr, period.timeFrame);
                                    bool isConflict = analysis['isConflict'];
                                    int weeklyTotal = _getTeacherWeeklyTotal(teacher['user_id']);
                                    bool isSelected = selectedTeacher == teacher;
                                    String unitStr = (teacher['unit'] != null && teacher['unit'].toString().isNotEmpty) ? " | Lớp CN: ${teacher['unit']}" : "";

                                    return ListTile(
                                      dense: true,
                                      onTap: isConflict ? null : () => setStateDialog(() => selectedTeacher = teacher),
                                      leading: CircleAvatar(backgroundColor: theme.primaryColor.withOpacity(0.1), child: Icon(Icons.person, color: theme.primaryColor, size: 16)),
                                      title: Text(teacher['name'], style: TextStyle(color: isConflict ? theme.subTextColor : theme.textColor, fontWeight: FontWeight.bold, fontSize: 13)),
                                      subtitle: Text(
                                          isConflict
                                              ? analysis['conflictDetail']
                                              : "Chức vụ: ${teacher['role']}$unitStr | Tuần này: $weeklyTotal tiết",
                                          style: TextStyle(color: isConflict ? theme.errorColor : theme.subTextColor, fontSize: 11)
                                      ),
                                      trailing: isConflict
                                          ? Icon(Icons.block_rounded, color: theme.errorColor, size: 16)
                                          : (isSelected ? Icon(Icons.check_circle_rounded, color: theme.successColor, size: 18) : const Icon(Icons.circle_outlined, size: 18)),
                                    );
                                  },
                                ),
                              )
                            ]),
                          ))
                        ],

                        const SizedBox(height: 20),

                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            TextButton.icon(
                                onPressed: () {
                                  String nameToUse = currentName();
                                  if (nameToUse.trim().isEmpty) return;
                                  setState(() {
                                    _isMultiSelecting = true;
                                    _pendingEventData = { "name": nameToUse, "type": type, "status": "Bình thường", "teacher_id": selectedTeacher?['user_id'], "teacher_name": selectedTeacher?['name'], "notes": notes };
                                    _selectedMultiCells.add("${_formatDateKey(date)}_${cls['id']}_${period.timeFrame}");
                                  });
                                  Navigator.pop(context);
                                },
                                icon: Icon(Icons.touch_app_rounded, color: theme.primaryColor, size: 18),
                                label: Text("Chọn khối nhiều tiết", style: TextStyle(color: theme.primaryColor, fontWeight: FontWeight.bold, fontSize: 13))
                            ),
                            ElevatedButton(
                              onPressed: () async {
                                String nameToUse = currentName();
                                if (nameToUse.trim().isEmpty) return;
                                Map<String, dynamic> event = { "name": nameToUse, "type": type, "status": "Bình thường", "teacher_id": selectedTeacher?['user_id'], "teacher_name": selectedTeacher?['name'], "notes": notes };
                                setState(() => _insertEventToClassLocal(cls, _formatDateKey(date), period.timeFrame, event));
                                Navigator.pop(context);
                                await _syncTimetableToServer(cls);
                              },
                              style: ElevatedButton.styleFrom(backgroundColor: theme.primaryColor, padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15)),
                              child: const Text("Lưu 1 tiết này", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
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

  void _showActionSlotDialog(DateTime date, String dayStr, Map<String, dynamic> cls, BellPeriod period, Map<String, dynamic> data, AppTheme theme, {required bool canEdit}) {
    bool isCancelled = data['status'] == 'Nghỉ học';
    bool isMakeup = data['status'] == 'Học bù';

    List<MergedSlot> mergedPeriods = _getAllMergedSlots(date, dayStr, data);

    String periodNames = mergedPeriods.map((e) => e.period.name).toSet().join(", ");
    Set<String> classNames = mergedPeriods.map((e) => e.cls['class_name'] as String).toSet();

    showDialog(
        context: context,
        builder: (context) {
          return Dialog(
            backgroundColor: theme.cardColor, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: theme.borderColor)),
            child: Container(
              width: 500, padding: const EdgeInsets.all(30),
              child: Column(
                mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text("Chi tiết Sự kiện", style: TextStyle(color: theme.textColor, fontSize: 18 * theme.fontScale, fontWeight: FontWeight.bold)), IconButton(onPressed: () => Navigator.pop(context), icon: Icon(Icons.close, color: theme.subTextColor))]),
                  Container(
                      padding: const EdgeInsets.all(15), decoration: BoxDecoration(color: theme.primaryColor.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text("${data['name']} - ${data['teacher_name'] ?? data['notes'] ?? ''}", style: TextStyle(color: theme.primaryColor, fontWeight: FontWeight.bold, fontSize: 15)), const SizedBox(height: 6),
                        Text("Lớp: ${classNames.join(', ')}\nThời gian: ${DateFormat('dd/MM').format(date)} | $periodNames", style: TextStyle(color: theme.textColor, fontSize: 13, height: 1.4))
                      ])
                  ),
                  const SizedBox(height: 25),

                  // NẾU KHÔNG CÓ QUYỀN -> HIỆN THÔNG BÁO KHÓA
                  if (!canEdit)
                    Container(
                      padding: const EdgeInsets.all(15),
                      decoration: BoxDecoration(color: theme.warningColor.withOpacity(0.1), borderRadius: BorderRadius.circular(12), border: Border.all(color: theme.warningColor.withOpacity(0.4))),
                      child: Row(
                        children: [
                          Icon(Icons.lock_rounded, color: theme.warningColor, size: 24),
                          const SizedBox(width: 15),
                          Expanded(child: Text("Quyền truy cập bị từ chối. Chỉ Super Admin hoặc Giáo viên phụ trách tiết này mới có thể thao tác thay đổi.", style: TextStyle(color: theme.warningColor, fontSize: 13, height: 1.4))),
                        ],
                      ),
                    )
                  // NẾU CÓ QUYỀN -> HIỆN CÁC NÚT THAO TÁC BÌNH THƯỜNG
                  else ...[
                    if (isCancelled)
                      _buildActionButton(Icons.settings_backup_restore_rounded, "Khôi phục khối lịch (Học lại)", "Hủy trạng thái nghỉ, đi học bình thường.", theme.successColor, () async {
                        String dateKey = _formatDateKey(date);
                        setState(() { for(var s in mergedPeriods) _insertEventToClassLocal(s.cls, dateKey, s.period.timeFrame, Map.from(data)..['status'] = "Bình thường"); });
                        Navigator.pop(context);
                        for(var cn in classNames) await _syncTimetableToServer(_classesData.firstWhere((c) => c['class_name'] == cn));
                      }, theme)
                    else ...[
                      _buildActionButton(Icons.block_rounded, "Báo nghỉ nhóm tiết này", "Vô hiệu hóa điểm danh cho khối liên kết này.", theme.errorColor, () async {
                        String dateKey = _formatDateKey(date);
                        setState(() { for(var s in mergedPeriods) _insertEventToClassLocal(s.cls, dateKey, s.period.timeFrame, Map.from(data)..['status'] = "Nghỉ học"); });
                        Navigator.pop(context);
                        for(var cn in classNames) await _syncTimetableToServer(_classesData.firstWhere((c) => c['class_name'] == cn));
                      }, theme),

                      _buildActionButton(Icons.swap_horiz_rounded, "Giáo viên dạy thế", "Phân công người khác thay.", theme.purpleColor, () {
                        Navigator.pop(context);
                        Future.delayed(const Duration(milliseconds: 100), () => _showSubstituteDialog(date, dayStr, mergedPeriods, data, theme));
                      }, theme),

                      if (!isMakeup)
                        _buildActionButton(Icons.restore_rounded, "Sắp xếp Học bù / Dời lịch", "Đưa khối sự kiện này sang một ngày khác.", theme.infoColor, () {
                          Navigator.pop(context);
                          Future.delayed(const Duration(milliseconds: 100), () => _showMakeUpDialog(mergedPeriods, data, theme));
                        }, theme),
                    ],

                    const SizedBox(height: 20), Divider(color: theme.borderColor), const SizedBox(height: 10),
                    Center(
                        child: TextButton.icon(
                            onPressed: () async {
                              setState(() { for(var s in mergedPeriods) _insertEventToClassLocal(s.cls, _formatDateKey(date), s.period.timeFrame, {"status": "Trống"}); });
                              Navigator.pop(context);
                              for(var cn in classNames) await _syncTimetableToServer(_classesData.firstWhere((c) => c['class_name'] == cn));
                            },
                            icon: Icon(Icons.delete_outline, color: theme.errorColor, size: 18),
                            label: Text(isMakeup ? "Xóa tiết học bù này" : "Xóa vĩnh viễn khối sự kiện này", style: TextStyle(color: theme.errorColor, fontSize: 13, fontWeight: FontWeight.bold))
                        )
                    )
                  ]
                ],
              ),
            ),
          );
        }
    );
  }

  void _showSubstituteDialog(DateTime date, String dayStr, List<MergedSlot> mergedPeriods, Map<String, dynamic> data, AppTheme theme) {
    bool showAllTeachers = false;
    String searchQuery = "";

    showDialog(context: context, builder: (context) {
      return StatefulBuilder(builder: (context, setStateDialog) {

        List<dynamic> baseTeachers = _teachersData.where((t) {
          String tName = (t['name'] ?? "").toString().toLowerCase();
          String tSpec = (t['teaching_subject'] ?? "").toString().toLowerCase();
          String subjectName = data['name'].toString().replaceAll('[Bù] ', '').toLowerCase();

          if (showAllTeachers) {
            if (searchQuery.isEmpty) return true;
            return tName.contains(searchQuery.toLowerCase()) || tSpec.contains(searchQuery.toLowerCase());
          } else {
            return tSpec.contains(subjectName);
          }
        }).toList();

        List<Map<String, dynamic>> processedTeachers = baseTeachers.map((t) {
          bool isConflict = false; String conflictDetail = "";
          for (var p in mergedPeriods) {
            var analysis = _analyzeTeacherWorkload(t['user_id'], date, dayStr, p.period.timeFrame);
            if (analysis['isConflict']) { isConflict = true; conflictDetail = analysis['conflictDetail']; break; }
          }
          int weeklyTotal = _getTeacherWeeklyTotal(t['user_id']);
          return { "teacher": t, "isConflict": isConflict, "conflictDetail": conflictDetail, "weeklyTotal": weeklyTotal };
        }).toList();

        processedTeachers.sort((a, b) {
          if (a['isConflict'] == b['isConflict']) return 0;
          return a['isConflict'] ? 1 : -1;
        });

        return Dialog(backgroundColor: theme.cardColor, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: theme.borderColor)), child: Container(width: 550, height: 650, padding: const EdgeInsets.all(30), child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text("Chọn Giáo viên Dạy Thế", style: TextStyle(color: theme.purpleColor, fontSize: 18, fontWeight: FontWeight.bold)), IconButton(onPressed:()=>Navigator.pop(context), icon: Icon(Icons.close, color: theme.subTextColor))]), const SizedBox(height: 15),

          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text("Danh sách Giáo viên", style: TextStyle(color: theme.textColor, fontWeight: FontWeight.bold, fontSize: 13)),
            TextButton(onPressed: () => setStateDialog((){ showAllTeachers = !showAllTeachers; searchQuery = ""; }), child: Text(showAllTeachers ? "Về gợi ý đúng môn" : "Tìm giáo viên khác...", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)))
          ]),
          if (showAllTeachers) Padding(padding: const EdgeInsets.only(bottom: 10), child: _buildDialogInput("Gõ tìm tên hoặc chuyên môn...", (v) => setStateDialog(() => searchQuery = v), theme, icon: Icons.search)),

          Expanded(
              child: Container(
                  decoration: BoxDecoration(color: theme.textColor.withOpacity(0.01), borderRadius: BorderRadius.circular(10), border: Border.all(color: theme.borderColor)),
                  child: ListView.builder(
                      itemCount: processedTeachers.length,
                      itemBuilder: (context, index) {
                        var item = processedTeachers[index];
                        var teacher = item['teacher'];
                        bool isConflict = item['isConflict'];

                        return Container(
                          margin: const EdgeInsets.only(bottom: 8), decoration: BoxDecoration(color: theme.textColor.withOpacity(0.02), borderRadius: BorderRadius.circular(10)),
                          child: ListTile(
                            dense: true,
                            onTap: isConflict ? null : () async {
                              String dateKey = _formatDateKey(date);
                              setState(() {
                                for (var p in mergedPeriods) {
                                  Map<String, dynamic> overrideEvent = Map.from(data);
                                  overrideEvent['status'] = "Dạy thế"; overrideEvent['teacher_id'] = teacher['user_id']; overrideEvent['teacher_name'] = "[Thế] ${teacher['name']}";
                                  _insertEventToClassLocal(p.cls, dateKey, p.period.timeFrame, overrideEvent);
                                }
                              });
                              Navigator.pop(context);
                              Set<String> cNames = mergedPeriods.map((e) => e.cls['class_name'] as String).toSet();
                              for(var cn in cNames) await _syncTimetableToServer(_classesData.firstWhere((c) => c['class_name'] == cn));
                            },
                            leading: CircleAvatar(backgroundColor: theme.purpleColor.withOpacity(isConflict ? 0.05 : 0.1), child: Icon(Icons.person, color: theme.purpleColor.withOpacity(isConflict ? 0.3 : 1.0), size: 16)),
                            title: Text(teacher['name'], style: TextStyle(color: isConflict ? theme.subTextColor : theme.textColor, fontWeight: FontWeight.bold, fontSize: 13)),
                            subtitle: Text(isConflict ? item['conflictDetail'] : "Môn: ${teacher['teaching_subject'] ?? 'Chung'} | Tuần này: ${item['weeklyTotal']} tiết", style: TextStyle(color: isConflict ? theme.errorColor : theme.subTextColor, fontSize: 11)),
                            trailing: isConflict ? Icon(Icons.block_rounded, color: theme.errorColor, size: 18) : Icon(Icons.check_circle_outline_rounded, color: theme.purpleColor, size: 20),
                          ),
                        );
                      }
                  )
              )
          )
        ])));
      });
    });
  }

  void _showMakeUpDialog(List<MergedSlot> mergedSlots, Map<String, dynamic> data, AppTheme theme) {
    DateTime? pickedDate;
    List<String> selectedPeriods = [];

    showDialog(context: context, builder: (context) {
      return StatefulBuilder(builder: (context, setStateDialog) {
        return Dialog(backgroundColor: theme.cardColor, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: theme.borderColor)), child: Container(width: 550, padding: const EdgeInsets.all(30), child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text("Xếp lịch Học Bù", style: TextStyle(color: theme.infoColor, fontSize: 18, fontWeight: FontWeight.bold)), IconButton(onPressed:()=>Navigator.pop(context), icon: Icon(Icons.close, color: theme.subTextColor))]), const SizedBox(height: 15),

          Text("1. Chọn ngày học bù:", style: TextStyle(color: theme.textColor, fontWeight: FontWeight.bold, fontSize: 13)), const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () async {
              pickedDate = await showDatePicker(context: context, initialDate: DateTime.now(), firstDate: DateTime.now(), lastDate: DateTime(2030), builder: (c, w) => Theme(data: Theme.of(context).copyWith(colorScheme: ColorScheme.light(primary: theme.infoColor)), child: w!));
              setStateDialog((){ selectedPeriods.clear(); });
            },
            icon: Icon(Icons.calendar_month_rounded, color: theme.infoColor, size: 18), label: Text(pickedDate == null ? "Bấm để chọn lịch..." : DateFormat('dd/MM/yyyy').format(pickedDate!), style: TextStyle(color: theme.infoColor, fontWeight: FontWeight.bold, fontSize: 14)),
          ),
          const SizedBox(height: 25),

          Text("2. Chọn các tiết học bù:", style: TextStyle(color: theme.textColor, fontWeight: FontWeight.bold, fontSize: 13)), const SizedBox(height: 8),
          if (pickedDate == null)
            Text("Vui lòng chọn ngày trước.", style: TextStyle(color: theme.subTextColor, fontStyle: FontStyle.italic, fontSize: 12))
          else
            Wrap(
              spacing: 10, runSpacing: 10,
              children: _bellSchedule.map((p) {
                bool isOccupied = false;
                for(var s in mergedSlots) {
                  if (_findCellData(s.cls, pickedDate!, _getDayOfWeek(pickedDate!.weekday - 1), p.timeFrame) != null) isOccupied = true;
                }
                bool isSelected = selectedPeriods.contains(p.timeFrame);

                return FilterChip(
                  label: Text(p.name, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: isOccupied ? Colors.white : (isSelected ? Colors.white : theme.textColor))),
                  selected: isSelected,
                  backgroundColor: isOccupied ? theme.errorColor : theme.cardColor,
                  selectedColor: theme.infoColor,
                  shape: StadiumBorder(side: BorderSide(color: isOccupied ? theme.errorColor : theme.borderColor)),
                  onSelected: isOccupied ? null : (bool selected) {
                    setStateDialog(() { selected ? selectedPeriods.add(p.timeFrame) : selectedPeriods.remove(p.timeFrame); });
                  },
                );
              }).toList(),
            ),
          const SizedBox(height: 35),

          Align(alignment: Alignment.centerRight, child: ElevatedButton(onPressed: () async {
            if (pickedDate == null || selectedPeriods.isEmpty) return;
            String dateKey = _formatDateKey(pickedDate!);
            setState(() {
              for (String tf in selectedPeriods) {
                for (var s in mergedSlots) {
                  Map<String, dynamic> makeUpEvent = Map.from(data);
                  makeUpEvent['status'] = "Học bù"; makeUpEvent['name'] = "[Bù] ${data['name'].toString().replaceAll('[Bù] ', '')}";
                  _insertEventToClassLocal(s.cls, dateKey, tf, makeUpEvent);
                }
              }
            });
            Navigator.pop(context);
            Set<String> cNames = mergedSlots.map((e) => e.cls['class_name'] as String).toSet();
            for(var cn in cNames) await _syncTimetableToServer(_classesData.firstWhere((c) => c['class_name'] == cn));
            if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Đã xếp học bù vào ${DateFormat('dd/MM').format(pickedDate!)}"), backgroundColor: Colors.green));
          }, style: ElevatedButton.styleFrom(backgroundColor: theme.infoColor, padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 15)), child: const Text("Xác nhận Lưu", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13))))
        ])));
      });
    });
  }

  void _showSyncDialog(AppTheme theme) {
    DateTime? startDate; DateTime? endDate;
    showDialog(context: context, builder: (c) {
      return StatefulBuilder(builder: (context, setStateDialog) {
        return Dialog(
            backgroundColor: theme.cardColor, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: theme.borderColor)),
            child: Container(
                width: 550, padding: const EdgeInsets.all(35),
                child: Column(
                    mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Đồng Bộ Thời Khóa Biểu", style: TextStyle(color: theme.primaryColor, fontWeight: FontWeight.bold, fontSize: 20)), const SizedBox(height: 10),
                      Text("Hệ thống sẽ lấy chính xác bố cục của tuần hiện tại (kể cả dạy thế/học bù) và dán đè lên toàn bộ các ngày trong khoảng thời gian bạn chọn.", style: TextStyle(color: theme.subTextColor, fontSize: 13, height: 1.4)), const SizedBox(height: 25),

                      Row(
                        children: [
                          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text("Từ ngày", style: TextStyle(color: theme.textColor, fontWeight: FontWeight.bold, fontSize: 13)), const SizedBox(height: 8), OutlinedButton.icon(onPressed: () async { startDate = await showDatePicker(context: context, initialDate: DateTime.now(), firstDate: DateTime.now(), lastDate: DateTime(2030)); setStateDialog((){}); }, icon: Icon(Icons.calendar_today, size: 16, color: theme.primaryColor), label: Text(startDate == null ? "Bấm chọn..." : DateFormat('dd/MM/yyyy').format(startDate!), style: TextStyle(color: theme.primaryColor, fontSize: 13, fontWeight: FontWeight.bold)))])), const SizedBox(width: 20),
                          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text("Đến ngày", style: TextStyle(color: theme.textColor, fontWeight: FontWeight.bold, fontSize: 13)), const SizedBox(height: 8), OutlinedButton.icon(onPressed: () async { endDate = await showDatePicker(context: context, initialDate: DateTime.now(), firstDate: DateTime.now(), lastDate: DateTime(2030)); setStateDialog((){}); }, icon: Icon(Icons.calendar_today, size: 16, color: theme.primaryColor), label: Text(endDate == null ? "Bấm chọn..." : DateFormat('dd/MM/yyyy').format(endDate!), style: TextStyle(color: theme.primaryColor, fontSize: 13, fontWeight: FontWeight.bold)))])),
                        ],
                      ),
                      const SizedBox(height: 35),
                      Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            TextButton(onPressed: () => Navigator.pop(context), child: Text("Hủy", style: TextStyle(color: theme.subTextColor, fontWeight: FontWeight.bold, fontSize: 13))), const SizedBox(width: 15),
                            ElevatedButton(
                                onPressed: () async {
                                  if (startDate == null || endDate == null) return;
                                  Navigator.pop(context);
                                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Đang tiến hành đồng bộ dữ liệu..."), backgroundColor: Colors.orange));

                                  Map<int, Map<int, Map<String, dynamic>?>> weeklyTemplate = {};
                                  for (var cls in _classesData) {
                                    weeklyTemplate[cls['id']] = {};
                                    for (int i = 0; i < 7; i++) {
                                      DateTime currD = _currentWeekStart.add(Duration(days: i));
                                      String dayStr = _getDayOfWeek(i);
                                      weeklyTemplate[cls['id']]![i] = {};
                                      for (var p in _bellSchedule) {
                                        var cellData = _findCellData(cls, currD, dayStr, p.timeFrame);
                                        weeklyTemplate[cls['id']]![i]![p.timeFrame] = cellData;
                                      }
                                    }
                                  }

                                  setState(() {
                                    DateTime d = startDate!;
                                    while (d.isBefore(endDate!.add(const Duration(days: 1)))) {
                                      int dayIndex = d.weekday - 1;
                                      String dateKey = _formatDateKey(d);

                                      for (var cls in _classesData) {
                                        var dayTemplate = weeklyTemplate[cls['id']]![dayIndex]!;
                                        for (var p in _bellSchedule) {
                                          var dataToPaste = dayTemplate[p.timeFrame];
                                          if (dataToPaste != null && dataToPaste['status'] != 'Trống') {
                                            Map<String, dynamic> newData = Map.from(dataToPaste);
                                            if (newData['status'] == 'Học bù' || newData['status'] == 'Dạy thế') {
                                              newData['status'] = 'Bình thường';
                                              newData['name'] = newData['name'].toString().replaceAll('[Bù] ', '');
                                              newData['teacher_name'] = newData['teacher_name'].toString().replaceAll('[Thế] ', '');
                                            }
                                            if (newData['status'] == 'Nghỉ học') newData['status'] = 'Bình thường';

                                            _insertEventToClassLocal(cls, dateKey, p.timeFrame, newData);
                                          } else {
                                            _insertEventToClassLocal(cls, dateKey, p.timeFrame, {"status": "Trống"});
                                          }
                                        }
                                      }
                                      d = d.add(const Duration(days: 1));
                                    }
                                  });

                                  for (var cls in _classesData) { await _syncTimetableToServer(cls); }
                                  if(mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("TKB đã được đồng bộ hóa thành công cho toàn bộ hệ thống!"), backgroundColor: Colors.green));
                                },
                                style: ElevatedButton.styleFrom(backgroundColor: theme.primaryColor, padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 15)), child: const Text("Xác nhận Đồng Bộ", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13))
                            )
                          ]
                      )
                    ]
                )
            )
        );
      });
    });
  }

  Widget _buildDialogInput(String hint, Function(String) onChanged, AppTheme theme, {String initial = "", IconData? icon}) { return SizedBox(height: 45, child: TextFormField(initialValue: initial, style: TextStyle(color: theme.textColor, fontSize: 13), onChanged: onChanged, decoration: InputDecoration(hintText: hint, hintStyle: TextStyle(color: theme.subTextColor), prefixIcon: icon != null ? Icon(icon, size: 18) : null, filled: true, fillColor: theme.textColor.withOpacity(0.03), contentPadding: const EdgeInsets.symmetric(horizontal: 15), border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none)))); }
  Widget _buildRadioOption(String title, String groupValue, Function(String) onTap, AppTheme theme, Color activeColor) { return GestureDetector(onTap: () => onTap(title), child: Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: groupValue == title ? activeColor.withOpacity(0.1) : Colors.transparent, borderRadius: BorderRadius.circular(8), border: Border.all(color: groupValue == title ? activeColor : theme.borderColor)), child: Center(child: Text(title, style: TextStyle(color: groupValue == title ? activeColor : theme.textColor, fontSize: 12 * theme.fontScale, fontWeight: FontWeight.bold))))); }
  Widget _buildActionButton(IconData icon, String title, String desc, Color color, VoidCallback onTap, AppTheme theme) { return Container(margin: const EdgeInsets.only(bottom: 12), child: InkWell(onTap: onTap, borderRadius: BorderRadius.circular(10), child: Container(padding: const EdgeInsets.all(15), decoration: BoxDecoration(border: Border.all(color: color.withOpacity(0.3)), borderRadius: BorderRadius.circular(10)), child: Row(children: [Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle), child: Icon(icon, color: color, size: 18)), const SizedBox(width: 15), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: TextStyle(color: theme.textColor, fontWeight: FontWeight.bold, fontSize: 13)), const SizedBox(height: 2), Text(desc, style: TextStyle(color: theme.subTextColor, fontSize: 11))]))])))); }
}