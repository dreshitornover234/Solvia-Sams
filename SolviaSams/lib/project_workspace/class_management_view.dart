import 'package:flutter/material.dart';
import '../theme_manager.dart';
import '../shared/member_profile_dialog.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';


class EditSubjectModel {
  String name; String timeFrame;
  EditSubjectModel({this.name = '', this.timeFrame = ''});
}
class EditDayModel {
  String dayName; List<EditSubjectModel> subjects;
  EditDayModel({this.dayName = 'Thứ 2', List<EditSubjectModel>? subjects}) : subjects = subjects ?? [EditSubjectModel()];
}

class ClassManagementView extends StatefulWidget {
  final int classId;
  final String className;
  final bool isSuperAdmin; // THÊM BIẾN NÀY
  const ClassManagementView({super.key, required this.classId, required this.className, this.isSuperAdmin = true});

  @override
  State<ClassManagementView> createState() => _ClassManagementViewState();
}

class _ClassManagementViewState extends State<ClassManagementView> {
  bool _isLoading = true;
  late String _currentClassName;
  String _currentTeacher = 'Đang tải...';
  Map<String, dynamic> _teacherData = {};

  int _courseStartYear = 2025;
  int _courseEndYear = 2028;
  int _currentYearStart = 2026;
  int _currentYearEnd = 2027;
  String _currentSemester = 'Học kỳ 1';

  List<String> _historicalYears = [];
  List<String> _historicalSemesters = [];

  String _selectedFilter = 'Tất cả';
  DateTime? _selectedDate;
  String _selectedYearFilter = 'Hiện tại';
  String _selectedSemesterFilter = 'Hiện tại';
  final List<String> _filterOptions = ['Tất cả', 'Vi phạm', 'Đi trễ', 'Nghỉ học', 'Có phép'];

  // Biến trống chờ dữ liệu thật
  Map<String, dynamic> teacherInfo = {};
  List<EditDayModel> _editDays = [];
  List<Map<String, dynamic>> allStudents = [];

  @override
  void initState() {
    super.initState();
    _currentClassName = widget.className;
    _fetchClassData(); // ---> GỌI API KHI MỞ TRANG
  }

  Future<void> _fetchClassData() async {
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
            teacherInfo = cls['teacher'];


            // Xử lý list Học sinh
            allStudents = List<Map<String, dynamic>>.from(cls['students']);

            // Xử lý Thời khóa biểu (Ép kiểu JSON thành Object)
            if (cls['timetable'] != null && (cls['timetable'] as List).isNotEmpty) {
              _editDays = (cls['timetable'] as List).map((dayJson) {
                List<EditSubjectModel> subs = (dayJson['subjects'] as List).map((subJson) => EditSubjectModel(name: subJson['name'], timeFrame: subJson['timeFrame'])).toList();
                return EditDayModel(dayName: dayJson['dayName'], subjects: subs);
              }).toList();
            } else {
              // Nếu TKB trống, cho hiển thị mặc định 1 ngày để dễ thêm
              _editDays = [];
            }

            _isLoading = false;
          });
        }
      }
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Map<String, dynamic> _getTermData(Map<String, dynamic> student, String yearFilter, String semesterFilter) {
    String queryYear = yearFilter == 'Hiện tại' ? '$_currentYearStart-$_currentYearEnd' : yearFilter;
    String querySemester = semesterFilter == 'Hiện tại' ? _currentSemester : semesterFilter;

    var defaultData = {"lateCount": 0, "absentCount": 0, "excusedCount": 0, "history": <String>[]};
    if (student['attendance'] == null || student['attendance'][queryYear] == null || student['attendance'][queryYear][querySemester] == null) return defaultData;
    return student['attendance'][queryYear][querySemester];
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
        animation: AppTheme.instance,
        builder: (context, child) {
          final theme = AppTheme.instance;
          if (_isLoading) {
            return Center(child: Padding(padding: const EdgeInsets.only(top: 100), child: CircularProgressIndicator(color: theme.primaryColor)));
          }

          List<Map<String, dynamic>> filteredStudents = allStudents.where((student) {
            var termData = _getTermData(student, _selectedYearFilter, _selectedSemesterFilter);
            if (_selectedFilter == 'Tất cả') return true;
            if (_selectedFilter == 'Vi phạm') return termData['lateCount'] > 0 || termData['absentCount'] > 0;
            if (_selectedFilter == 'Đi trễ') return termData['lateCount'] > 0;
            if (_selectedFilter == 'Nghỉ học') return termData['absentCount'] > 0;
            if (_selectedFilter == 'Có phép') return termData['excusedCount'] > 0;
            return true;
          }).toList();

          List<String> yearOptions = ['Hiện tại']; yearOptions.addAll(_historicalYears);
          List<String> semesterOptions = ['Hiện tại']; semesterOptions.addAll(_historicalSemesters);

          return SingleChildScrollView(
            key: ValueKey('Class_$_currentClassName'),
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.all(50.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    AnimatedDefaultTextStyle(duration: const Duration(milliseconds: 300), style: TextStyle(fontSize: 32 * theme.fontScale, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 1.0, fontFamily: 'Segoe UI'), child: Text(_currentClassName)),
                    const SizedBox(width: 20),
                    Container(margin: const EdgeInsets.only(bottom: 6), padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), decoration: BoxDecoration(color: theme.primaryColor.withOpacity(0.15), borderRadius: BorderRadius.circular(8)), child: Text("Sĩ số: ${allStudents.length} hs", style: TextStyle(color: theme.primaryColor, fontSize: 13 * theme.fontScale, fontWeight: FontWeight.bold))),
                    const SizedBox(width: 10),
                    Container(margin: const EdgeInsets.only(bottom: 6), padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), decoration: BoxDecoration(color: Colors.purpleAccent.withOpacity(0.15), borderRadius: BorderRadius.circular(8)), child: Text("Khóa: $_courseStartYear - $_courseEndYear", style: TextStyle(color: Colors.purpleAccent, fontSize: 13 * theme.fontScale, fontWeight: FontWeight.bold))),
                    const SizedBox(width: 10),
                    Container(margin: const EdgeInsets.only(bottom: 6), padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), decoration: BoxDecoration(color: Colors.white.withOpacity(0.1), borderRadius: BorderRadius.circular(8)), child: Text("Năm: $_currentYearStart - $_currentYearEnd | $_currentSemester", style: TextStyle(color: Colors.white70, fontSize: 13 * theme.fontScale, fontWeight: FontWeight.bold))),

                    const Spacer(),
                    if (widget.isSuperAdmin)
                    ElevatedButton.icon(
                      onPressed: () => _showEditClassDialog(context, theme),
                      icon: Icon(Icons.settings_suggest_rounded, size: 16 * theme.fontScale, color: Colors.white),
                      label: Text("QUẢN TRỊ LỚP", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13 * theme.fontScale, color: Colors.white)),
                      style: ElevatedButton.styleFrom(backgroundColor: theme.primaryColor, padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                    )
                  ],
                ),
                const SizedBox(height: 30),

                _buildSectionHeader(Icons.badge_rounded, "GIÁO VIÊN CHỦ NHIỆM", theme),
                const SizedBox(height: 15),

                // LOGIC KIỂM TRA: CÓ GIÁO VIÊN KHÔNG?
                (_currentTeacher == 'Chưa phân công' || _currentTeacher.isEmpty)

                // TRƯỜNG HỢP 1: KHÔNG CÓ -> HIỆN CHỮ MỜ
                    ? Padding(
                  padding: const EdgeInsets.only(left: 10),
                  child: Text(
                    "Chưa có giáo viên quản lý lớp.",
                    style: TextStyle(color: Colors.white54, fontSize: 13 * theme.fontScale, fontStyle: FontStyle.italic),
                  ),
                )

                // TRƯỜNG HỢP 2: CÓ GIÁO VIÊN -> VẼ THẺ VÀ CHO BẤM VÀO XEM HỒ SƠ
                    : Container(
                  decoration: BoxDecoration(color: Colors.white.withOpacity(0.02), borderRadius: BorderRadius.circular(16), border: Border.all(color: theme.primaryColor.withOpacity(0.3))),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () {
                        // GỌI BẢNG POPUP XỊN SÒ MÀ CHÚNG TA VỪA LÀM
                        showDialog(
                          context: context,
                          builder: (context) => MemberProfileDialog(
                            isAdmin: true, // Cho phép xem chi tiết
                            memberData: _teacherData, // Truyền nguyên cục data thật vào
                          ),
                        );
                      },
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Row(
                          children: [
                            // AVATAR GIÁO VIÊN
                            (_teacherData['avatar_url'] != null && _teacherData['avatar_url'].toString().isNotEmpty)
                                ? CircleAvatar(radius: 24 * theme.fontScale, backgroundImage: NetworkImage("http://127.0.0.1:8000${_teacherData['avatar_url']}"))
                                : CircleAvatar(radius: 24 * theme.fontScale, backgroundColor: theme.primaryColor.withOpacity(0.2), child: Icon(Icons.person, color: theme.primaryColor, size: 24 * theme.fontScale)),

                            const SizedBox(width: 20),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(_currentTeacher, style: TextStyle(color: Colors.white, fontSize: 16 * theme.fontScale, fontWeight: FontWeight.bold)),
                                  const SizedBox(height: 4),
                                  Text("Giáo viên chủ nhiệm", style: TextStyle(color: theme.primaryColor, fontSize: 13 * theme.fontScale)),
                                ],
                              ),
                            ),
                            Icon(Icons.chevron_right_rounded, color: Colors.white24, size: 24 * theme.fontScale)
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 40),

                _buildSectionHeader(Icons.calendar_month_rounded, "THỜI KHÓA BIỂU HIỆN TẠI", theme),
                _editDays.isEmpty
                    ? Padding(
                  padding: const EdgeInsets.only(left: 10, top: 10),
                  child: Text("Chưa thiết lập thời khóa biểu.", style: TextStyle(color: Colors.white54, fontSize: 13 * theme.fontScale, fontStyle: FontStyle.italic)),
                )
                    : SingleChildScrollView(scrollDirection: Axis.horizontal, physics: const BouncingScrollPhysics(), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: _editDays.map((dayData) => _buildDayCard(dayData, theme)).toList())),

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
                          final DateTime? picked = await showDatePicker(context: context, initialDate: _selectedDate ?? DateTime.now(), firstDate: DateTime(2025), lastDate: DateTime(2030), builder: (context, child) => Theme(data: Theme.of(context).copyWith(colorScheme: ColorScheme.dark(primary: theme.primaryColor, onPrimary: Colors.white, surface: const Color(0xFF101520), onSurface: Colors.white)), child: child!));
                          if (picked != null) setState(() => _selectedDate = picked);
                        },
                        icon: Icon(Icons.calendar_today_rounded, size: 16 * theme.fontScale, color: _selectedDate == null ? Colors.white54 : theme.primaryColor),
                        label: Text(_selectedDate == null ? "Lọc theo ngày" : "${_selectedDate!.day}/${_selectedDate!.month}/${_selectedDate!.year}", style: TextStyle(color: _selectedDate == null ? Colors.white54 : theme.primaryColor, fontWeight: FontWeight.bold, fontSize: 13 * theme.fontScale)),
                        style: OutlinedButton.styleFrom(side: BorderSide(color: _selectedDate == null ? Colors.white.withOpacity(0.2) : theme.primaryColor), padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 15), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                      ),
                      if (_selectedDate != null) IconButton(onPressed: () => setState(() => _selectedDate = null), icon: const Icon(Icons.clear_rounded, color: Colors.redAccent)),
                      const SizedBox(width: 15),
                      _buildFilterDropdown("Trạng thái", _selectedFilter, _filterOptions, (val) => setState(() => _selectedFilter = val!), theme),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                Container(
                  width: double.infinity, decoration: BoxDecoration(color: Colors.white.withOpacity(0.015), borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white.withOpacity(0.05))),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: DataTable(
                      showCheckboxColumn: false, headingRowColor: WidgetStateProperty.all(Colors.white.withOpacity(0.05)), dataRowMaxHeight: 60,
                      columns: _buildDynamicColumns(theme),
                      rows: filteredStudents.map((student) {
                        var termData = _getTermData(student, _selectedYearFilter, _selectedSemesterFilter);
                        return DataRow(
                          onSelectChanged: (selected) {
                            if (selected == true) {
                              showDialog(
                                  context: context, builder: (_) => MemberProfileDialog(isAdmin: true, memberData: {
                                "name": student["name"], "email": student["email"], "role": "Học sinh ${student['id']}",
                                "dob": student["dob"], "phone": student["phone"], "hometown": "Hồ Chí Minh", "religion": "Không",
                                "currentAddress": "Quận 1", "facebook": "Chưa liên kết",
                                "jobRole": "Học sinh lớp $_currentClassName", "degree": "Khóa: $_courseStartYear-$_courseEndYear | $_currentYearStart-$_currentYearEnd", "school": "SAMS Cơ sở 1",
                                "dynamicLabel1": "Giới tính", "dynamicValue1": student["gender"], "dynamicLabel2": "Người giám hộ", "dynamicValue2": student["parent"],
                                "lateCount": termData["lateCount"], "absentCount": termData["absentCount"], "excusedCount": termData["excusedCount"], "violationHistory": termData["history"]
                              })
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

  // ==========================================================
  // DIALOG CHỈNH SỬA LỚP HỌC (ĐÃ FIX LỖI NHẤN LIÊN TỤC VÀ THÊM FORM HS)
  // ==========================================================
  void _showEditClassDialog(BuildContext context, AppTheme theme) {
    showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) {
          String editClassName = _currentClassName;
          String editTeacher = _currentTeacher;
          int editCourseStart = _courseStartYear;
          int editCourseEnd = _courseEndYear;
          // THÊM BỘ LỌC NÀY ĐỂ KHÔNG BỊ CRASH DROPDOWN:
          List<String> teacherOptions = ['Chưa phân công', 'Phạm Thị D', 'Nguyễn Văn A', 'Trần Văn B'];
          if (!teacherOptions.contains(editTeacher)) {
            teacherOptions.add(editTeacher);
          }

          return StatefulBuilder(
              builder: (context, setStateDialog) {
                // Kiểm tra trạng thái Khóa Mới Nhất bằng State của Dialog để nút tự mờ
                bool isLastYear = _currentYearEnd >= editCourseEnd;

                return Dialog(
                  backgroundColor: const Color(0xFF101520),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24), side: BorderSide(color: theme.primaryColor.withOpacity(0.5))),
                  child: Container(
                    width: 850, height: 700,
                    clipBehavior: Clip.antiAlias,
                    decoration: BoxDecoration(borderRadius: BorderRadius.circular(24)),
                    child: DefaultTabController(
                      length: 3,
                      child: Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(20), color: Colors.white.withOpacity(0.02),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text("Quản Trị Lớp: $_currentClassName", style: TextStyle(color: Colors.white, fontSize: 20 * theme.fontScale, fontWeight: FontWeight.bold)),
                                IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close_rounded, color: Colors.white54))
                              ],
                            ),
                          ),
                          TabBar(
                            indicatorColor: theme.primaryColor, labelColor: theme.primaryColor, unselectedLabelColor: Colors.white54,
                            tabs: const [Tab(icon: Icon(Icons.info_outline), text: "Cấu hình & Vòng đời"), Tab(icon: Icon(Icons.edit_calendar_rounded), text: "Thời khóa biểu"), Tab(icon: Icon(Icons.groups_rounded), text: "Danh sách Học sinh")],
                          ),
                          Expanded(
                            child: TabBarView(
                              children: [
                                // TAB 1: THÔNG TIN & VÒNG ĐỜI
                                SingleChildScrollView(
                                  padding: const EdgeInsets.all(30),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(child: _buildDialogTextField("Tên lớp", editClassName, (v) => editClassName = v, theme)),
                                          const SizedBox(width: 20),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text("Giáo viên chủ nhiệm", style: TextStyle(color: Colors.white70, fontSize: 12 * theme.fontScale, fontWeight: FontWeight.bold)), const SizedBox(height: 8),
                                                DropdownButtonFormField<String>(
                                                  value: editTeacher, dropdownColor: const Color(0xFF0A101E), style: TextStyle(color: Colors.white, fontSize: 13 * theme.fontScale),
                                                  decoration: InputDecoration(filled: true, fillColor: Colors.black.withOpacity(0.3), border: OutlineInputBorder(borderRadius: BorderRadius.circular(10))),
                                                  // SỬA CHỖ NÀY: Dùng danh sách an toàn vừa tạo ở trên
                                                  items: teacherOptions.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                                                  onChanged: (val) => setStateDialog(() => editTeacher = val!),
                                                ),
                                              ],
                                            ),
                                          )
                                        ],
                                      ),
                                      const SizedBox(height: 20),

                                      Container(
                                        padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: Colors.purpleAccent.withOpacity(0.05), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.purpleAccent.withOpacity(0.3))),
                                        child: Row(
                                          children: [
                                            Icon(Icons.timeline_rounded, color: Colors.purpleAccent, size: 30 * theme.fontScale), const SizedBox(width: 15),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text("NIÊN KHÓA HỌC (VÒNG ĐỜI TOÀN KHOÁ)", style: TextStyle(color: Colors.purpleAccent, fontWeight: FontWeight.bold, fontSize: 13 * theme.fontScale)), const SizedBox(height: 8),
                                                  Row(
                                                    children: [
                                                      Text("Bắt đầu năm: ", style: TextStyle(color: Colors.white70, fontSize: 13 * theme.fontScale)),
                                                      SizedBox(width: 100, child: DropdownButtonFormField<int>(value: editCourseStart, dropdownColor: const Color(0xFF0A101E), decoration: const InputDecoration(isDense: true, contentPadding: EdgeInsets.all(10)), items: [2024, 2025, 2026, 2027].map((e) => DropdownMenuItem(value: e, child: Text(e.toString(), style: TextStyle(color: Colors.white, fontSize: 13 * theme.fontScale)))).toList(), onChanged: (v) => setStateDialog(() => editCourseStart = v!))),
                                                      const SizedBox(width: 20),
                                                      Text("Kết thúc năm: ", style: TextStyle(color: Colors.white70, fontSize: 13 * theme.fontScale)),
                                                      SizedBox(width: 100, child: DropdownButtonFormField<int>(value: editCourseEnd, dropdownColor: const Color(0xFF0A101E), decoration: const InputDecoration(isDense: true, contentPadding: EdgeInsets.all(10)), items: [2026, 2027, 2028, 2029].map((e) => DropdownMenuItem(value: e, child: Text(e.toString(), style: TextStyle(color: Colors.white, fontSize: 13 * theme.fontScale)))).toList(), onChanged: (v) => setStateDialog(() => editCourseEnd = v!))),
                                                    ],
                                                  )
                                                ],
                                              ),
                                            )
                                          ],
                                        ),
                                      ),
                                      const SizedBox(height: 30), Divider(color: Colors.white.withOpacity(0.05)), const SizedBox(height: 20),

                                      Row(children: [Icon(Icons.history_toggle_off_rounded, color: Colors.orangeAccent, size: 20 * theme.fontScale), const SizedBox(width: 10), Text("TIẾN TRÌNH NĂM HỌC HIỆN TẠI", style: TextStyle(color: Colors.orangeAccent, fontWeight: FontWeight.bold, fontSize: 13 * theme.fontScale))]),
                                      const SizedBox(height: 10),
                                      Text("Bạn đang ở: Năm $_currentYearStart-$_currentYearEnd | $_currentSemester. Khi tiến lên, dữ liệu hiện tại sẽ được lưu vào Lịch sử.", style: TextStyle(color: Colors.grey[500], fontSize: 12 * theme.fontScale)),
                                      const SizedBox(height: 20),

                                      Row(
                                        children: [
                                          Expanded(
                                            child: ElevatedButton.icon(
                                              onPressed: () => _confirmAction(context, "Kết thúc Học kỳ hiện tại để chuyển sang Kỳ mới?", () {
                                                // FIX LỖI: Update cả Dialog State và Screen State cùng lúc
                                                setStateDialog(() {
                                                  if (!_historicalSemesters.contains(_currentSemester)) _historicalSemesters.add(_currentSemester);
                                                  int num = int.parse(_currentSemester.split(' ')[2]);
                                                  _currentSemester = "Học kỳ ${num + 1}";
                                                });
                                                setState((){});
                                              }),
                                              icon: const Icon(Icons.skip_next_rounded, color: Colors.black), label: const Text("Chuyển lên Học kỳ tiếp theo", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                                              style: ElevatedButton.styleFrom(backgroundColor: Colors.orangeAccent, padding: const EdgeInsets.symmetric(vertical: 16)),
                                            ),
                                          ),
                                          const SizedBox(width: 15),
                                          Expanded(
                                            child: ElevatedButton.icon(
                                              // NÚT KHÓA: Nếu isLastYear = true thì onPressed = null (Nút sẽ tự mờ đi không bấm được)
                                              onPressed: isLastYear ? null : () => _confirmAction(context, "Kết thúc Năm học hiện tại để chuyển sang Năm mới?", () {
                                                setStateDialog(() {
                                                  if (!_historicalYears.contains("$_currentYearStart-$_currentYearEnd")) _historicalYears.add("$_currentYearStart-$_currentYearEnd");
                                                  _currentYearStart++; _currentYearEnd++;
                                                  _currentSemester = "Học kỳ 1";
                                                });
                                                setState((){});
                                              }),
                                              icon: Icon(isLastYear ? Icons.block_rounded : Icons.fast_forward_rounded, color: isLastYear ? Colors.white54 : Colors.white),
                                              label: Text(isLastYear ? "Đã đến năm cuối khóa" : "Lên lớp (Năm học mới)", style: TextStyle(color: isLastYear ? Colors.white54 : Colors.white, fontWeight: FontWeight.bold)),
                                              style: ElevatedButton.styleFrom(backgroundColor: isLastYear ? Colors.grey[800] : Colors.blueAccent, padding: const EdgeInsets.symmetric(vertical: 16)),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 40),

                                      Container(
                                        padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: Colors.redAccent.withOpacity(0.05), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.redAccent.withOpacity(0.3))),
                                        child: Row(
                                          children: [
                                            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text("KẾT THÚC VÒNG ĐỜI LỚP HỌC", style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 13 * theme.fontScale)), const SizedBox(height: 4), Text("Học sinh ra trường/giải tán. Lớp sẽ bị đóng băng, không thể thao tác thêm.", style: TextStyle(color: Colors.redAccent.withOpacity(0.7), fontSize: 12 * theme.fontScale))])),
                                            ElevatedButton(
                                              onPressed: () => _confirmAction(context, "CẢNH BÁO: Lớp sẽ bị đóng băng hoàn toàn. Bạn có chắc chắn?", () {
                                                Navigator.pop(context);
                                                Navigator.pop(context);
                                                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Lớp học đã hoàn thành khóa và được đóng băng thành công!"), backgroundColor: Colors.orange));
                                              }),
                                              style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent), child: const Text("HOÀN THÀNH / GIẢI TÁN", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                            )
                                          ],
                                        ),
                                      )
                                    ],
                                  ),
                                ),

                                // TAB 2: THỜI KHÓA BIỂU
                                SingleChildScrollView(
                                  padding: const EdgeInsets.all(20),
                                  child: Column(
                                    children: [
                                      ..._editDays.asMap().entries.map((dayEntry) {
                                        int dIndex = dayEntry.key; EditDayModel dModel = dayEntry.value;
                                        return Container(
                                          margin: const EdgeInsets.only(bottom: 15), padding: const EdgeInsets.all(15), decoration: BoxDecoration(color: Colors.white.withOpacity(0.02), borderRadius: BorderRadius.circular(12), border: const Border(left: BorderSide(color: Colors.white30, width: 3))),
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Row(children: [Expanded(flex: 2, child: _buildFilterDropdown("Thứ", dModel.dayName, ['Thứ 2', 'Thứ 3', 'Thứ 4', 'Thứ 5', 'Thứ 6', 'Thứ 7', 'Chủ Nhật'], (val) => setStateDialog(() => dModel.dayName = val!), theme)), const SizedBox(width: 20), Expanded(flex: 5, child: Container()), if (_editDays.length > 1) IconButton(onPressed: () => setStateDialog(() => _editDays.removeAt(dIndex)), icon: Icon(Icons.close_rounded, color: Colors.redAccent.withOpacity(0.8), size: 18 * theme.fontScale))]),
                                              const SizedBox(height: 15),
                                              ...dModel.subjects.asMap().entries.map((subEntry) {
                                                int sIndex = subEntry.key; EditSubjectModel sModel = subEntry.value;
                                                return Padding(
                                                  padding: const EdgeInsets.only(bottom: 10, left: 15),
                                                  child: Row(children: [Icon(Icons.subdirectory_arrow_right_rounded, color: Colors.white24, size: 16 * theme.fontScale), const SizedBox(width: 10), Expanded(flex: 3, child: _buildDialogTextFieldNoLabel("Tên môn", sModel.name, (v) => sModel.name = v, theme)), const SizedBox(width: 15), Expanded(flex: 2, child: _buildDialogTextFieldNoLabel("Giờ (07:00-08:30)", sModel.timeFrame, (v) => sModel.timeFrame = v, theme)), const SizedBox(width: 10), if (dModel.subjects.length > 1) IconButton(onPressed: () => setStateDialog(() => dModel.subjects.removeAt(sIndex)), icon: Icon(Icons.remove_circle_outline_rounded, color: Colors.redAccent.withOpacity(0.6), size: 18 * theme.fontScale))]),
                                                );
                                              }),
                                              Padding(padding: const EdgeInsets.only(left: 40, top: 5), child: GestureDetector(onTap: () => setStateDialog(() => dModel.subjects.add(EditSubjectModel())), child: Row(children: [Icon(Icons.add_rounded, color: theme.primaryColor, size: 16 * theme.fontScale), const SizedBox(width: 4), Text("Thêm Môn học", style: TextStyle(color: theme.primaryColor, fontSize: 11 * theme.fontScale, fontWeight: FontWeight.bold))])) )
                                            ],
                                          ),
                                        );
                                      }),
                                      Align(alignment: Alignment.centerLeft, child: TextButton.icon(onPressed: () => setStateDialog(() => _editDays.add(EditDayModel())), icon: Icon(Icons.add_rounded, color: Colors.white70, size: 16 * theme.fontScale), label: Text("Thêm Thứ học", style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold, fontSize: 12 * theme.fontScale))))
                                    ],
                                  ),
                                ),

                                // TAB 3: THÀNH VIÊN
                                Column(
                                  children: [
                                    Padding(
                                      padding: const EdgeInsets.all(20.0),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text("Sĩ số: ${allStudents.length}", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14 * theme.fontScale)),
                                          // NÚT THÊM HỌC SINH MỞ FORM
                                          ElevatedButton.icon(
                                              onPressed: () => _showAddStudentDialog(context, setStateDialog, theme),
                                              icon: const Icon(Icons.person_add_rounded, color: Colors.white), label: const Text("Thêm học sinh", style: TextStyle(color: Colors.white)), style: ElevatedButton.styleFrom(backgroundColor: Colors.green)
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
                                            margin: const EdgeInsets.only(bottom: 10), decoration: BoxDecoration(color: Colors.white.withOpacity(0.03), borderRadius: BorderRadius.circular(12)),
                                            child: ListTile(
                                              leading: CircleAvatar(backgroundColor: Colors.white10, child: Icon(Icons.person, color: Colors.white54, size: 16 * theme.fontScale)),
                                              title: Text(st['name'], style: TextStyle(color: Colors.white, fontSize: 14 * theme.fontScale, fontWeight: FontWeight.bold)),
                                              subtitle: Text(st['id'], style: TextStyle(color: Colors.white54, fontSize: 12 * theme.fontScale)),
                                              trailing: PopupMenuButton<String>(
                                                icon: const Icon(Icons.more_vert, color: Colors.white54), color: const Color(0xFF101520),
                                                onSelected: (val) {
                                                  if (val == 'transfer') _showTransferDialog(context, st['name'], index, setStateDialog, theme);
                                                  else if (val == 'delete') setStateDialog(() => allStudents.removeAt(index));
                                                },
                                                itemBuilder: (context) => [const PopupMenuItem(value: 'transfer', child: Text("Chuyển sang lớp khác", style: TextStyle(color: Colors.white))), const PopupMenuItem(value: 'delete', child: Text("Xóa khỏi danh sách", style: TextStyle(color: Colors.redAccent)))],
                                              ),
                                            ),
                                          );
                                        },
                                      ),
                                    ),
                                  ],
                                )
                              ],
                            ),
                          ),

                          // Footer Dialog
                          Container(
                            padding: const EdgeInsets.all(20), color: Colors.white.withOpacity(0.02),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                TextButton(onPressed: () => Navigator.pop(context), child: const Text("Đóng", style: TextStyle(color: Colors.white54))), const SizedBox(width: 15),
                                ElevatedButton(
                                  onPressed: () async {
                                    // 1. Đóng gói dữ liệu
                                    Map<String, dynamic> payload = {
                                      "class_name": editClassName,
                                      "course_start_year": editCourseStart,
                                      "course_end_year": editCourseEnd,
                                      "current_year_start": _currentYearStart,
                                      "current_year_end": _currentYearEnd,
                                      "current_semester": _currentSemester,
                                      "timetable": _editDays.map((d) => {
                                        "dayName": d.dayName,
                                        "subjects": d.subjects.map((s) => {"name": s.name, "timeFrame": s.timeFrame}).toList()
                                      }).toList()
                                    };

                                    // 2. Gọi API cập nhật
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
                                            _currentTeacher = editTeacher;
                                            _courseStartYear = editCourseStart;
                                            _courseEndYear = editCourseEnd;
                                          });
                                          if (context.mounted) Navigator.pop(context);
                                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Đã lưu Cấu hình & Thời khóa biểu an toàn!"), backgroundColor: Colors.green));
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

  // ==========================================================
  // FORM THÊM HỌC SINH MỚI
  // ==========================================================
  void _showAddStudentDialog(BuildContext context, StateSetter parentSetState, AppTheme theme) {
    String newId = "HS${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}";
    String newName = ""; String newGender = "Nam"; String newDob = ""; String newParent = ""; String newPhone = "";

    showDialog(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: const Color(0xFF101520), title: const Text("Thêm Học Sinh Mới", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildDialogTextField("Mã HS (Tự động)", newId, (v) => newId = v, theme), const SizedBox(height: 15),
                _buildDialogTextField("Họ và Tên", newName, (v) => newName = v, theme), const SizedBox(height: 15),
                _buildFilterDropdown("Giới tính", newGender, ["Nam", "Nữ"], (v) => newGender = v!, theme), const SizedBox(height: 15),
                _buildDialogTextField("Ngày sinh (dd/mm/yyyy)", newDob, (v) => newDob = v, theme), const SizedBox(height: 15),
                _buildDialogTextField("Tên Phụ huynh", newParent, (v) => newParent = v, theme), const SizedBox(height: 15),
                _buildDialogTextField("SĐT Phụ huynh", newPhone, (v) => newPhone = v, theme),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text("Hủy")),
            ElevatedButton(
              onPressed: () {
                if (newName.isNotEmpty) {
                  // Cập nhật State của Dialog Edit Lớp
                  parentSetState(() {
                    allStudents.add({
                      "id": newId, "name": newName, "gender": newGender, "dob": newDob, "parent": newParent, "phone": newPhone, "email": "hs@edu.vn",
                      "attendance": {"$_currentYearStart-$_currentYearEnd": {_currentSemester: {"lateCount": 0, "absentCount": 0, "excusedCount": 0, "history": <String>[]}}}
                    });
                  });
                  // Cập nhật State của Màn hình chính
                  setState((){});
                  Navigator.pop(context);
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: theme.primaryColor), child: const Text("Thêm vào lớp", style: TextStyle(color: Colors.white)),
            )
          ],
        )
    );
  }

  // Popup Xác nhận chung
  void _confirmAction(BuildContext context, String message, VoidCallback onConfirm) {
    showDialog(context: context, builder: (context) => AlertDialog(backgroundColor: const Color(0xFF101520), title: const Row(children: [Icon(Icons.warning_amber_rounded, color: Colors.orangeAccent), SizedBox(width: 10), Text("Xác nhận", style: TextStyle(color: Colors.white))]), content: Text(message, style: TextStyle(color: Colors.white70)), actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text("Hủy")), ElevatedButton(onPressed: () { onConfirm(); Navigator.pop(context); }, style: ElevatedButton.styleFrom(backgroundColor: Colors.orangeAccent), child: const Text("Đồng ý", style: TextStyle(color: Colors.black)))]));
  }

  // Popup Chọn lớp để Chuyển Học Sinh
  void _showTransferDialog(BuildContext context, String studentName, int index, StateSetter setStateDialog, AppTheme theme) {
    String targetClass = 'Lớp 10A2';
    showDialog(context: context, builder: (context) => AlertDialog(backgroundColor: const Color(0xFF101520), title: const Text("Chuyển lớp", style: TextStyle(color: Colors.white)), content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [Text("Chuyển học sinh '$studentName' sang lớp:", style: const TextStyle(color: Colors.white70)), const SizedBox(height: 15), DropdownButtonFormField<String>(value: targetClass, dropdownColor: const Color(0xFF0A101E), style: TextStyle(color: Colors.white, fontSize: 13 * theme.fontScale), decoration: InputDecoration(filled: true, fillColor: Colors.black.withOpacity(0.3), border: OutlineInputBorder(borderRadius: BorderRadius.circular(10))), items: ['Lớp 10A2', 'Lớp 11B1', 'Lớp 12C3'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(), onChanged: (val) => targetClass = val!)]), actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text("Hủy")), ElevatedButton(onPressed: () { setStateDialog(() => allStudents.removeAt(index)); setState((){}); Navigator.pop(context); ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Đã chuyển $studentName sang $targetClass"), backgroundColor: Colors.green)); }, style: ElevatedButton.styleFrom(backgroundColor: theme.primaryColor), child: const Text("Xác nhận chuyển", style: TextStyle(color: Colors.white)))]));
  }

  // --- CÁC WIDGET BỔ TRỢ ---
  Widget _buildFilterDropdown(String label, String value, List<String> items, Function(String?) onChanged, AppTheme theme) { String safeValue = items.contains(value) ? value : items.first; return Container(height: 45, decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(10)), child: DropdownButtonHideUnderline(child: DropdownButton<String>(value: safeValue, dropdownColor: const Color(0xFF101520), icon: Icon(Icons.arrow_drop_down, color: theme.primaryColor), padding: const EdgeInsets.symmetric(horizontal: 15), style: TextStyle(color: Colors.white, fontSize: 13 * theme.fontScale, fontWeight: FontWeight.bold), items: items.map((opt) => DropdownMenuItem(value: opt, child: Text(opt))).toList(), onChanged: onChanged))); }
  Widget _buildDialogTextField(String label, String value, Function(String) onChanged, AppTheme theme) { return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(label, style: TextStyle(color: Colors.white70, fontSize: 12 * theme.fontScale, fontWeight: FontWeight.bold)), const SizedBox(height: 8), TextFormField(initialValue: value, onChanged: onChanged, style: TextStyle(color: Colors.white, fontSize: 13 * theme.fontScale), decoration: InputDecoration(filled: true, fillColor: Colors.black.withOpacity(0.3), border: OutlineInputBorder(borderRadius: BorderRadius.circular(10))))]); }
  Widget _buildDialogTextFieldNoLabel(String hint, String value, Function(String) onChanged, AppTheme theme) { return SizedBox(height: 45, child: TextFormField(initialValue: value, onChanged: onChanged, style: TextStyle(color: Colors.white, fontSize: 13 * theme.fontScale), decoration: InputDecoration(contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 15), hintText: hint, hintStyle: TextStyle(color: Colors.white24, fontSize: 13 * theme.fontScale), filled: true, fillColor: Colors.black.withOpacity(0.3), enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.white.withOpacity(0.05))), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: theme.primaryColor, width: 1.5))))); }
  Widget _buildSectionHeader(IconData icon, String title, AppTheme theme) => Row(children: [AnimatedContainer(duration: const Duration(milliseconds: 300), child: Icon(icon, color: theme.primaryColor, size: 18 * theme.fontScale)), const SizedBox(width: 10), AnimatedDefaultTextStyle(duration: const Duration(milliseconds: 300), style: TextStyle(color: Colors.white, fontSize: 14 * theme.fontScale, fontWeight: FontWeight.bold, letterSpacing: 1.2, fontFamily: 'Segoe UI'), child: Text(title))]);
  Widget _buildDayCard(EditDayModel dayData, AppTheme theme) { return Container(width: 220 * theme.fontScale, margin: const EdgeInsets.only(right: 20), decoration: BoxDecoration(color: Colors.white.withOpacity(0.02), borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white.withOpacity(0.05))), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Container(width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 12), decoration: BoxDecoration(color: theme.primaryColor.withOpacity(0.15), borderRadius: const BorderRadius.vertical(top: Radius.circular(16))), child: Center(child: Text(dayData.dayName, style: TextStyle(color: theme.primaryColor, fontSize: 14 * theme.fontScale, fontWeight: FontWeight.bold)))), Padding(padding: const EdgeInsets.all(15.0), child: Column(children: dayData.subjects.map((sub) => Padding(padding: const EdgeInsets.only(bottom: 15), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Container(width: 8, height: 8, margin: const EdgeInsets.only(top: 6), decoration: BoxDecoration(color: theme.primaryColor, shape: BoxShape.circle)), const SizedBox(width: 10), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(sub.name, style: TextStyle(color: Colors.white, fontSize: 14 * theme.fontScale, fontWeight: FontWeight.bold)), const SizedBox(height: 2), Text(sub.timeFrame, style: TextStyle(color: Colors.grey[500], fontSize: 11 * theme.fontScale))]))]))).toList()))])); }

  // --- LOGIC BẢNG EXCEL ---
  // --- LOGIC BẢNG EXCEL (ĐÃ ĐỔI PHỤ HUYNH THÀNH EMAIL) ---
  List<DataColumn> _buildDynamicColumns(AppTheme theme) {
    List<DataColumn> cols = [DataColumn(label: Text("Mã HS", style: TextStyle(color: theme.primaryColor, fontWeight: FontWeight.bold))), DataColumn(label: Text("Họ và Tên", style: TextStyle(color: theme.primaryColor, fontWeight: FontWeight.bold)))];
    if (_selectedFilter == 'Tất cả' || _selectedFilter == 'Có phép') {
      cols.addAll([DataColumn(label: Text("Giới tính", style: TextStyle(color: theme.primaryColor, fontWeight: FontWeight.bold))), DataColumn(label: Text("Email", style: TextStyle(color: theme.primaryColor, fontWeight: FontWeight.bold)))]);
      if (_selectedFilter == 'Có phép') cols.add(DataColumn(label: Text("Có phép", style: TextStyle(color: theme.infoColor, fontWeight: FontWeight.bold))));
    }
    else if (_selectedFilter == 'Vi phạm') { cols.addAll([DataColumn(label: Text("Đi Trễ", style: TextStyle(color: theme.warningColor, fontWeight: FontWeight.bold))), DataColumn(label: Text("Nghỉ Học", style: TextStyle(color: theme.errorColor, fontWeight: FontWeight.bold)))]); }
    else if (_selectedFilter == 'Đi trễ') { cols.addAll([DataColumn(label: Text("Giới tính", style: TextStyle(color: theme.primaryColor, fontWeight: FontWeight.bold))), DataColumn(label: Text("Đi Trễ", style: TextStyle(color: theme.warningColor, fontWeight: FontWeight.bold)))]); }
    else if (_selectedFilter == 'Nghỉ học') { cols.addAll([DataColumn(label: Text("Giới tính", style: TextStyle(color: theme.primaryColor, fontWeight: FontWeight.bold))), DataColumn(label: Text("Nghỉ Học", style: TextStyle(color: theme.errorColor, fontWeight: FontWeight.bold)))]); }
    return cols;
  }

  List<DataCell> _buildDynamicCells(Map<String, dynamic> student, Map<String, dynamic> termData, AppTheme theme) {
    List<DataCell> cells = [DataCell(Text(student["id"], style: TextStyle(color: theme.subTextColor))), DataCell(Text(student["name"], style: TextStyle(color: theme.textColor, fontWeight: FontWeight.bold)))];
    if (_selectedFilter == 'Tất cả' || _selectedFilter == 'Có phép') {
      cells.addAll([DataCell(Text(student["gender"], style: TextStyle(color: theme.subTextColor))), DataCell(Text(student["email"], style: TextStyle(color: theme.subTextColor)))]);
      if (_selectedFilter == 'Có phép') cells.add(DataCell(Text(termData["excusedCount"].toString(), style: TextStyle(color: theme.infoColor, fontWeight: FontWeight.bold))));
    }
    else if (_selectedFilter == 'Vi phạm') { cells.addAll([DataCell(Text(termData["lateCount"].toString(), style: TextStyle(color: termData["lateCount"] > 0 ? theme.warningColor : theme.subTextColor.withOpacity(0.5), fontWeight: FontWeight.bold))), DataCell(Text(termData["absentCount"].toString(), style: TextStyle(color: termData["absentCount"] > 0 ? theme.errorColor : theme.subTextColor.withOpacity(0.5), fontWeight: FontWeight.bold)))]); }
    else if (_selectedFilter == 'Đi trễ') { cells.addAll([DataCell(Text(student["gender"], style: TextStyle(color: theme.subTextColor))), DataCell(Text(termData["lateCount"].toString(), style: TextStyle(color: theme.warningColor, fontWeight: FontWeight.bold)))]); }
    else if (_selectedFilter == 'Nghỉ học') { cells.addAll([DataCell(Text(student["gender"], style: TextStyle(color: theme.subTextColor))), DataCell(Text(termData["absentCount"].toString(), style: TextStyle(color: theme.errorColor, fontWeight: FontWeight.bold)))]); }
    return cells;
  }
}