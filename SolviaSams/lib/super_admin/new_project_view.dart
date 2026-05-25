import 'package:flutter/material.dart';
import 'package:solviasams/globals.dart' as globals;
import '../theme_manager.dart';
import '../project_workspace/project_workspace_screen.dart';
import 'package:file_picker/file_picker.dart';
import 'package:excel/excel.dart' as ex;
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';

// ==============================================================
// 1. CÁC CLASS QUẢN LÝ TRẠNG THÁI DỮ LIỆU ĐỘNG (MODELS)
// ==============================================================
class SubjectModel {
  String name = '';
  String timeFrame = '';
}

class DayModel {
  String dayName = 'Thứ 2';
  List<SubjectModel> morningSubjects = [SubjectModel()];
  List<SubjectModel> afternoonSubjects = [SubjectModel()];
}

class ClassModel {
  String className = '';
  String? uploadedExcelFile;
  List<DayModel> days = [DayModel()];
  List<Map<String, dynamic>>? parsedStudents;
}

class OfficeDayModel {
  String dayName = 'Thứ 2';
  String timeFrameMorning = '';
  String timeFrameAfternoon = '';
}

class DepartmentModel {
  String deptName = '';
  String? uploadedExcelFile;
  List<OfficeDayModel> days = [OfficeDayModel()];
  bool overrideRule = false;
}

// ==============================================================
// 2. GIAO DIỆN CHÍNH
// ==============================================================
class NewProjectView extends StatefulWidget {
  const NewProjectView({super.key});

  @override
  State<NewProjectView> createState() => _NewProjectViewState();
}

class _NewProjectViewState extends State<NewProjectView> {
  bool _isCreatingProject = false;
  String _projectName = '';
  String _projectType = 'Trường học';

  String _schoolName = '';
  String _academicYear = '';

  String _sessionType = 'Sáng';
  String _globalTimeMorning = '';
  String _globalTimeAfternoon = '';

  String _attendanceMode = 'Quy định chung';
  String _globalRule = 'Giờ đầu';
  String _dailyMode = 'Từng môn';
  String _subjectRule = 'Đầu tiết';
  String _firstPeriodRule = 'Giờ đầu tiên';

  List<ClassModel> _classes = [ClassModel()];

  String _companyName = '';
  String _companyScale = '';

  String _officeSessionType = 'Sáng & Chiều';
  String _officeGlobalTimeMorning = '';
  String _officeGlobalTimeAfternoon = '';

  String _officeAttendanceMode = 'Quy định chung';
  String _officeGlobalRule = 'Đầu và cuối';

  List<DepartmentModel> _departments = [DepartmentModel()];
  List<dynamic> _projectList = [];
  bool _isLoadingProjects = true;

  @override
  void initState() {
    super.initState();
    _fetchProjects();
  }

  Future<void> _fetchProjects() async {
    if (!mounted) return;
    setState(() => _isLoadingProjects = true);

    try {
      var response = await http.get(Uri.parse('http://127.0.0.1:8000/api/users/${globals.currentUserId}/projects'));
      if (response.statusCode == 200) {
        var responseBody = jsonDecode(utf8.decode(response.bodyBytes));
        if (responseBody['status'] == 'success') {
          if (mounted) {
            setState(() {
              _projectList = responseBody['data'] ?? [];
              _isLoadingProjects = false;
            });
          }
          return;
        }
      }
    } catch (e) {
      debugPrint("Lỗi kéo dự án: $e");
    }

    if (mounted) {
      setState(() => _isLoadingProjects = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: AppTheme.instance,
      builder: (context, child) {
        final theme = AppTheme.instance;

        return SingleChildScrollView(
          key: const ValueKey('NewProjectView'),
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 40.0, vertical: 30.0),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 400),
            switchInCurve: Curves.easeInOut,
            switchOutCurve: Curves.easeInOut,
            child: !_isCreatingProject
                ? _buildOverviewScreen(theme)
                : _buildCreateProjectForm(theme),
          ),
        );
      },
    );
  }

  // ==============================================================
  // MÀN HÌNH 1: TỔNG QUAN (KHO DỰ ÁN)
  // ==============================================================
  Widget _buildOverviewScreen(AppTheme theme) {
    return Column(
      key: const ValueKey('Overview'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AnimatedDefaultTextStyle(duration: const Duration(milliseconds: 300), style: TextStyle(fontSize: 28 * theme.fontScale, fontWeight: FontWeight.w900, color: theme.textColor, letterSpacing: 1.0, fontFamily: 'Segoe UI'), child: const Text("Quản Lý Dự Án")),
        const SizedBox(height: 8),
        AnimatedDefaultTextStyle(duration: const Duration(milliseconds: 300), style: TextStyle(fontSize: 14 * theme.fontScale, color: theme.subTextColor, fontFamily: 'Segoe UI'), child: const Text("Khởi tạo không gian làm việc mới hoặc kết nối với dự án đã có sẵn.")),
        const SizedBox(height: 40),

        Row(
          children: [
            Expanded(
              child: _buildActionCard(
                title: "Tạo Dự Án Mới", description: "Khởi tạo một hệ thống SAMS hoàn toàn mới. Trở thành người quản trị tối cao.", icon: Icons.add_business_rounded, isPrimary: true, theme: theme,
                onTap: () => setState(() => _isCreatingProject = true),
              ),
            ),
            const SizedBox(width: 30),
            Expanded(
              child: _buildActionCard(
                title: "Tham Gia Dự Án", description: "Gia nhập vào một hệ thống đã có sẵn bằng Mã dự án hoặc Quét mã QR.", icon: Icons.group_add_rounded, isPrimary: false, theme: theme,
                onTap: () => _showJoinProjectDialog(context, theme),
              ),
            ),
          ],
        ),
        const SizedBox(height: 50),

        Row(
          children: [
            AnimatedContainer(duration: const Duration(milliseconds: 300), child: Icon(Icons.inventory_2_rounded, color: theme.primaryColor, size: 20 * theme.fontScale)),
            const SizedBox(width: 10),
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 300),
              style: TextStyle(color: theme.textColor, fontSize: 15 * theme.fontScale, fontWeight: FontWeight.bold, letterSpacing: 1.2, fontFamily: 'Segoe UI'),
              child: const Text("KHO DỰ ÁN (ĐÃ TẠO & THAM GIA)"),
            ),
          ],
        ),
        const SizedBox(height: 25),

        _isLoadingProjects
            ? Center(child: CircularProgressIndicator(color: theme.primaryColor))
            : _projectList.isEmpty
            ? Padding(
          padding: const EdgeInsets.only(top: 20),
          child: Text("Chưa có dự án nào. Hãy tạo dự án đầu tiên của bạn!", style: TextStyle(color: theme.subTextColor, fontSize: 14 * theme.fontScale, fontStyle: FontStyle.italic)),
        )
            : Wrap(
          spacing: 20,
          runSpacing: 20,
          children: _projectList.map((proj) {
            return _buildProjectCard(
              proj['id'],
              proj['project_name'] ?? "Dự án Không Tên",
              proj['role'] ?? "Khách",
              proj['status'] ?? "Hoạt động",
              proj['project_type'] == 'Trường học' ? Icons.school_rounded : Icons.corporate_fare_rounded,
              proj['is_owner'] ?? false,
              theme,
            );
          }).toList(),
        )
      ],
    );
  }

  // ==============================================================
  // MÀN HÌNH 2: FORM TẠO DỰ ÁN MỚI
  // ==============================================================
  Widget _buildCreateProjectForm(AppTheme theme) {
    return Column(
      key: const ValueKey('CreateForm'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            IconButton(onPressed: () => setState(() => _isCreatingProject = false), icon: Icon(Icons.arrow_back_rounded, color: theme.textColor, size: 24 * theme.fontScale)),
            const SizedBox(width: 10),
            AnimatedDefaultTextStyle(duration: const Duration(milliseconds: 300), style: TextStyle(fontSize: 24 * theme.fontScale, fontWeight: FontWeight.w900, color: theme.textColor, fontFamily: 'Segoe UI'), child: const Text("Tạo Dự Án Mới")),
          ],
        ),
        const SizedBox(height: 30),

        AnimatedContainer(
          duration: const Duration(milliseconds: 400),
          padding: const EdgeInsets.all(30),
          decoration: BoxDecoration(color: theme.cardColor, borderRadius: BorderRadius.circular(20), border: Border.all(color: theme.borderColor), boxShadow: theme.isDarkMode ? [] : [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 15, offset: const Offset(0, 4))]),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionHeader(Icons.info_outline_rounded, "THÔNG TIN CƠ BẢN", theme),
              const SizedBox(height: 20),
              _buildTextField("Tên dự án", Icons.drive_file_rename_outline, "VD: Hệ thống SAMS Cơ sở 1", theme, onChanged: (v) => _projectName = v),
              const SizedBox(height: 25),

              AnimatedDefaultTextStyle(duration: const Duration(milliseconds: 300), style: TextStyle(color: theme.subTextColor, fontSize: 12 * theme.fontScale, fontWeight: FontWeight.bold, fontFamily: 'Segoe UI'), child: const Text("Loại hình hoạt động")),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(child: _buildRadioCard("Trường học", Icons.school_rounded, _projectType, (val) => setState(() => _projectType = val), theme)),
                  const SizedBox(width: 20),
                  Expanded(child: _buildRadioCard("Văn phòng", Icons.corporate_fare_rounded, _projectType, (val) => setState(() => _projectType = val), theme)),
                ],
              ),
              const SizedBox(height: 40),

              AnimatedSize(
                duration: const Duration(milliseconds: 400),
                curve: Curves.easeInOut,
                child: _projectType == 'Trường học' ? _buildSchoolForm(theme) : _buildOfficeForm(theme),
              ),

              const SizedBox(height: 50),
              Divider(color: theme.borderColor, thickness: 1),
              const SizedBox(height: 20),

              Align(
                alignment: Alignment.centerRight,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      if (_projectName.trim().isEmpty || _schoolName.trim().isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Vui lòng nhập Tên dự án và Tên đơn vị cơ sở!"), backgroundColor: Colors.orange));
                        return;
                      }

                      showDialog(
                          context: context, barrierDismissible: false,
                          builder: (c) => AlertDialog(backgroundColor: theme.cardColor, content: Row(children: [const CircularProgressIndicator(color: Colors.greenAccent), const SizedBox(width: 20), Expanded(child: Text("Đang khởi tạo Hệ thống SAMS và cấu trúc Cơ sở dữ liệu...", style: TextStyle(color: theme.textColor, fontSize: 13 * theme.fontScale)))]))
                      );

                      try {
                        List<Map<String, dynamic>> classesPayload = [];
                        for (var cls in _classes) {
                          List<Map<String, dynamic>> timetablePayload = [];
                          for (var day in cls.days) {
                            List<Map<String, dynamic>> subs = [];
                            subs.addAll(day.morningSubjects.where((s) => s.name.isNotEmpty).map((s) => {"name": s.name, "timeFrame": s.timeFrame}));
                            subs.addAll(day.afternoonSubjects.where((s) => s.name.isNotEmpty).map((s) => {"name": s.name, "timeFrame": s.timeFrame}));
                            if (subs.isNotEmpty) {
                              timetablePayload.add({"dayName": day.dayName, "subjects": subs});
                            }
                          }

                          classesPayload.add({
                            "class_name": cls.className.isEmpty ? "Lớp Chưa Tên" : cls.className,
                            "students": cls.parsedStudents ?? [],
                            "timetable": timetablePayload
                          });
                        }

                        Map<String, dynamic> payload = {
                          "user_id": globals.currentUserId,
                          "project_name": _projectName,
                          "project_type": _projectType,
                          "school_name": _schoolName,
                          "academic_year": _academicYear,
                          "session_type": _sessionType,
                          "morning_time": _globalTimeMorning,
                          "afternoon_time": _globalTimeAfternoon,
                          "attendance_mode": _attendanceMode,
                          "global_rule": _globalRule,
                          "classes": classesPayload
                        };

                        var response = await http.post(
                            Uri.parse('http://127.0.0.1:8000/api/create-project'),
                            headers: {"Content-Type": "application/json"},
                            body: jsonEncode(payload)
                        );

                        if (context.mounted) Navigator.pop(context);

                        if (response.statusCode == 200) {
                          var responseData = jsonDecode(response.body);
                          if (responseData['status'] == 'success') {
                            globals.currentProjectId = responseData['project_id'];
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Thành công! Dự án đã được mã hóa và lưu trữ an toàn."), backgroundColor: Colors.green));
                            Navigator.push(
                                context,
                                MaterialPageRoute(builder: (context) => const ProjectWorkspaceScreen(userRole: 'Super Admin'))
                            ).then((_) {
                              _fetchProjects();
                            });
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Lỗi Database: ${responseData['message']}"), backgroundColor: Colors.redAccent));
                          }
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Máy chủ từ chối kết nối. Mã lỗi: ${response.statusCode}"), backgroundColor: Colors.redAccent));
                        }
                      } catch (e) {
                        if (context.mounted) Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Không tìm thấy Server Python. Hãy kiểm tra lại! Lỗi: $e"), backgroundColor: Colors.redAccent));
                      }
                    },
                    icon: Icon(Icons.rocket_launch_rounded, color: Colors.white, size: 18 * theme.fontScale),
                    label: Text("HOÀN TẤT KHỞI TẠO DỰ ÁN", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 1.0, fontSize: 13 * theme.fontScale)),
                    style: ElevatedButton.styleFrom(backgroundColor: theme.primaryColor, padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                  ),
                ),
              )
            ],
          ),
        ),
      ],
    );
  }

  // ==============================================================
  // FORM TRƯỜNG HỌC LÕI
  // ==============================================================
  Widget _buildSchoolForm(AppTheme theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(Icons.account_balance_rounded, "THÔNG TIN TRƯỜNG HỌC", theme),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(child: _buildTextField("Tên trường", Icons.school_outlined, "Nhập tên trường học", theme, onChanged: (v) => _schoolName = v)),
            const SizedBox(width: 20),
            Expanded(child: _buildTextField("Năm học", Icons.calendar_month_rounded, "VD: 2026 - 2027", theme, onChanged: (v) => _academicYear = v)),
          ],
        ),
        const SizedBox(height: 30),

        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          padding: const EdgeInsets.all(25),
          decoration: BoxDecoration(color: theme.primaryColor.withOpacity(0.05), borderRadius: BorderRadius.circular(16), border: Border.all(color: theme.primaryColor.withOpacity(0.2))),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.rule_rounded, color: theme.primaryColor, size: 20 * theme.fontScale),
                  const SizedBox(width: 10),
                  AnimatedDefaultTextStyle(duration: const Duration(milliseconds: 300), style: TextStyle(color: theme.textColor, fontSize: 14 * theme.fontScale, fontWeight: FontWeight.bold, fontFamily: 'Segoe UI'), child: const Text("CẤU HÌNH ĐIỂM DANH CHUNG")),
                ],
              ),
              const SizedBox(height: 25),

              AnimatedDefaultTextStyle(duration: const Duration(milliseconds: 300), style: TextStyle(color: theme.subTextColor, fontSize: 12 * theme.fontScale, fontWeight: FontWeight.bold, fontFamily: 'Segoe UI'), child: const Text("Ca học của trường")),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(child: _buildOptionChip("Chỉ Buổi Sáng", _sessionType == 'Sáng', () => setState(() => _sessionType = 'Sáng'), theme)),
                  const SizedBox(width: 10),
                  Expanded(child: _buildOptionChip("Chỉ Buổi Chiều", _sessionType == 'Chiều', () => setState(() => _sessionType = 'Chiều'), theme)),
                  const SizedBox(width: 10),
                  Expanded(child: _buildOptionChip("Cả Sáng & Chiều", _sessionType == 'Sáng & Chiều', () => setState(() => _sessionType = 'Sáng & Chiều'), theme)),
                ],
              ),
              const SizedBox(height: 15),

              AnimatedSize(
                duration: const Duration(milliseconds: 300),
                child: Row(
                  children: [
                    if (_sessionType == 'Sáng' || _sessionType == 'Sáng & Chiều')
                      Expanded(child: _buildTextField("Thời gian khung Buổi Sáng", Icons.wb_twilight_rounded, "VD: 07:00 - 11:30", theme, onChanged: (v) => _globalTimeMorning = v)),
                    if (_sessionType == 'Sáng & Chiều') const SizedBox(width: 20),
                    if (_sessionType == 'Chiều' || _sessionType == 'Sáng & Chiều')
                      Expanded(child: _buildTextField("Thời gian khung Buổi Chiều", Icons.wb_sunny_rounded, "VD: 13:00 - 17:00", theme, onChanged: (v) => _globalTimeAfternoon = v)),
                  ],
                ),
              ),

              const SizedBox(height: 30),
              Divider(color: theme.primaryColor.withOpacity(0.2), thickness: 1),
              const SizedBox(height: 20),

              AnimatedDefaultTextStyle(duration: const Duration(milliseconds: 300), style: TextStyle(color: theme.subTextColor, fontSize: 12 * theme.fontScale, fontWeight: FontWeight.bold, fontFamily: 'Segoe UI'), child: const Text("Cơ chế ghi nhận điểm danh")),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(child: _buildOptionChip("Theo giờ quy định chung", _attendanceMode == 'Quy định chung', () => setState(() => _attendanceMode = 'Quy định chung'), theme)),
                  const SizedBox(width: 15),
                  Expanded(child: _buildOptionChip("Theo thời gian từng lớp/ngày", _attendanceMode == 'Theo từng ngày', () => setState(() => _attendanceMode = 'Theo từng ngày'), theme)),
                ],
              ),
              const SizedBox(height: 20),

              AnimatedSize(
                duration: const Duration(milliseconds: 400),
                child: _attendanceMode == 'Quy định chung'
                    ? _buildGlobalAttendanceLogic(theme)
                    : _buildDailyAttendanceLogic(theme),
              ),
            ],
          ),
        ),
        const SizedBox(height: 40),

        _buildSectionHeader(Icons.class_outlined, "QUẢN LÝ LỚP HỌC & THỜI KHÓA BIỂU", theme),
        const SizedBox(height: 20),
        ..._classes.asMap().entries.map((entry) => _buildClassBlock(entry.key, entry.value, theme)),
        const SizedBox(height: 10),
        Center(
          child: TextButton.icon(
            onPressed: () => setState(() => _classes.add(ClassModel())),
            icon: Icon(Icons.add_circle_outline_rounded, color: theme.primaryColor, size: 18 * theme.fontScale),
            label: Text("THÊM LỚP MỚI", style: TextStyle(color: theme.primaryColor, fontWeight: FontWeight.bold, fontSize: 13 * theme.fontScale)),
          ),
        )
      ],
    );
  }

  // ==========================================================
  // THUẬT TOÁN ĐỌC EXCEL (ĐÃ FIX CHUẨN 8 CỘT & LÀM SẠCH DATA)
  // ==========================================================
  Future<void> _processExcelFile(BuildContext context, ClassModel classModel, StateSetter setModalState) async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom, allowedExtensions: ['xlsx'], withData: true,
      );

      if (result != null && result.files.single.bytes != null && context.mounted) {
        String fileName = result.files.single.name;
        var fileBytes = result.files.single.bytes!;

        showDialog(context: context, barrierDismissible: false, builder: (c) => AlertDialog(backgroundColor: AppTheme.instance.cardColor, content: Row(children: [const CircularProgressIndicator(color: Colors.greenAccent), const SizedBox(width: 20), Expanded(child: Text("Đang bóc tách file $fileName...", style: TextStyle(color: AppTheme.instance.textColor)))])));

        var excel = ex.Excel.decodeBytes(fileBytes);
        var sheet = excel.tables[excel.tables.keys.first]!;
        List<Map<String, dynamic>> studentsData = [];

        String formatDate(dynamic rawValue) {
          if (rawValue == null) return "";
          if (rawValue is DateTime) return "${rawValue.day.toString().padLeft(2, '0')}/${rawValue.month.toString().padLeft(2, '0')}/${rawValue.year}";

          String str = rawValue.toString().trim();
          if (str.isEmpty) return "";
          if (str.contains("-") || str.contains("T")) {
            try {
              String datePart = str.split("T")[0].split(" ")[0];
              List<String> parts = datePart.split("-");
              if (parts.length == 3) return "${parts[2]}/${parts[1]}/${parts[0]}";
            } catch (e) { return str; }
          }
          return str;
        }

        String cleanNumber(dynamic rawValue) {
          if (rawValue == null) return "";
          String str = rawValue.toString().trim();
          if (str.endsWith(".0")) return str.substring(0, str.length - 2);
          return str;
        }

        for (int i = 0; i < sheet.rows.length; i++) {
          var row = sheet.rows[i];
          if (row.isEmpty || row[0]?.value == null) continue;

          String firstCell = row[0]?.value.toString().toLowerCase().trim() ?? "";
          String secondCell = row.length > 1 ? row[1]?.value.toString().toLowerCase().trim() ?? "" : "";
          if (firstCell == "stt" || secondCell == "họ và tên" || secondCell == "họ tên") continue;

          String stt = cleanNumber(row[0]?.value);
          String name = row.length > 1 ? row[1]?.value.toString() ?? "" : "Không tên";
          String gender = row.length > 2 ? row[2]?.value.toString() ?? "" : "";
          String dob = row.length > 3 ? formatDate(row[3]?.value) : "";
          String hometown = row.length > 4 ? row[4]?.value.toString() ?? "" : "";
          String phone = row.length > 5 ? cleanNumber(row[5]?.value) : "";

          String username = row.length > 6 && row[6]?.value != null ? row[6]!.value.toString() : "hs.${name.split(' ').last.toLowerCase()}${stt.isNotEmpty ? stt : i}";
          String password = row.length > 7 && row[7]?.value != null ? row[7]!.value.toString() : "123456";

          studentsData.add({
            "stt": stt,
            "name": name,
            "gender": gender,
            "dob": dob,
            "hometown": hometown,
            "phone": phone,
            "username": username,
            "password": password,
          });
        }

        if (context.mounted) Navigator.pop(context);

        if (studentsData.isNotEmpty) {
          _showExcelPreview(context, fileName, studentsData, AppTheme.instance, () {
            setModalState(() {
              classModel.uploadedExcelFile = "$fileName (${studentsData.length} HS)";
              classModel.parsedStudents = studentsData;
            });
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Dữ liệu đã được nạp thành công!"), backgroundColor: Colors.green));
          });
        } else {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("File Excel không hợp lệ hoặc rỗng!"), backgroundColor: Colors.redAccent));
        }
      }
    } catch (e) {
      if (context.mounted) Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Lỗi đọc file: Vui lòng đóng file Excel trước khi tải lên."), backgroundColor: Colors.redAccent));
    }
  }

  void _showExcelPreview(BuildContext context, String fileName, List<Map<String, dynamic>> data, AppTheme theme, Function onConfirm) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return Dialog(
          backgroundColor: theme.cardColor,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: theme.primaryColor.withOpacity(0.5))),
          child: Container(
            width: 950,
            padding: const EdgeInsets.all(30),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.visibility_rounded, color: theme.primaryColor, size: 24),
                    const SizedBox(width: 10),
                    Expanded(child: Text("Xem trước dữ liệu: $fileName", style: TextStyle(color: theme.textColor, fontSize: 18, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis)),
                  ],
                ),
                const SizedBox(height: 10),
                Text("Đã nhận diện ${data.length} thành viên. Vui lòng kiểm tra kỹ các thông tin dưới đây.", style: TextStyle(color: theme.subTextColor, fontSize: 13)),
                const SizedBox(height: 20),

                Container(
                  height: 400,
                  decoration: BoxDecoration(color: theme.textColor.withOpacity(0.02), borderRadius: BorderRadius.circular(12), border: Border.all(color: theme.borderColor)),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: SingleChildScrollView(
                        child: DataTable(
                          headingRowColor: WidgetStateProperty.all(theme.primaryColor.withOpacity(0.1)),
                          columns: [
                            DataColumn(label: Text("STT", style: TextStyle(color: theme.textColor, fontWeight: FontWeight.bold))),
                            DataColumn(label: Text("Họ và Tên", style: TextStyle(color: theme.textColor, fontWeight: FontWeight.bold))),
                            DataColumn(label: Text("Giới tính", style: TextStyle(color: theme.textColor, fontWeight: FontWeight.bold))),
                            DataColumn(label: Text("Ngày sinh", style: TextStyle(color: theme.textColor, fontWeight: FontWeight.bold))),
                            DataColumn(label: Text("Quê quán", style: TextStyle(color: theme.textColor, fontWeight: FontWeight.bold))),
                            DataColumn(label: Text("SĐT", style: TextStyle(color: theme.textColor, fontWeight: FontWeight.bold))),
                            const DataColumn(label: Text("Tài khoản", style: TextStyle(color: Colors.orangeAccent, fontWeight: FontWeight.bold))),
                            const DataColumn(label: Text("Mật khẩu", style: TextStyle(color: Colors.orangeAccent, fontWeight: FontWeight.bold))),
                          ],
                          rows: data.take(100).map((e) => DataRow(
                              cells: [
                                DataCell(Text(e['stt'] ?? "", style: TextStyle(color: theme.subTextColor, fontSize: 12 * theme.fontScale))),
                                DataCell(Text(e['name'] ?? "", style: TextStyle(color: theme.textColor, fontWeight: FontWeight.bold, fontSize: 13 * theme.fontScale))),
                                DataCell(Text(e['gender']?.toString() ?? "", style: TextStyle(color: theme.subTextColor))),
                                DataCell(Text(e['dob'] ?? "", style: TextStyle(color: theme.subTextColor, fontSize: 12 * theme.fontScale))),
                                DataCell(Text(e['hometown'] ?? "", style: TextStyle(color: theme.subTextColor, fontSize: 12 * theme.fontScale))),
                                DataCell(Text(e['phone'] ?? "", style: TextStyle(color: theme.subTextColor, fontSize: 12 * theme.fontScale))),
                                DataCell(Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: Colors.orangeAccent.withOpacity(0.1), borderRadius: BorderRadius.circular(6)), child: Text(e['username'] ?? "", style: TextStyle(color: Colors.orangeAccent, fontWeight: FontWeight.bold, fontSize: 12 * theme.fontScale)))),
                                DataCell(Text(e['password'] ?? "", style: TextStyle(color: Colors.orangeAccent, fontSize: 12 * theme.fontScale))),
                              ]
                          )).toList(),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 30),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(onPressed: () => Navigator.pop(context), child: Text("Hủy bỏ", style: TextStyle(color: theme.subTextColor))),
                    const SizedBox(width: 15),
                    ElevatedButton(
                      onPressed: () {
                        onConfirm();
                        Navigator.pop(context);
                      },
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                      child: const Text("Xác nhận & Lưu", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                  ],
                )
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildGlobalAttendanceLogic(AppTheme theme) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: theme.textColor.withOpacity(0.04), borderRadius: BorderRadius.circular(12), border: const Border(left: BorderSide(color: Colors.blueAccent, width: 3))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildDropdownField("Cài đặt điểm danh", Icons.rule_folder_rounded, _globalRule, ['Giờ đầu', 'Giờ cuối', 'Đầu và cuối'], (val) => setState(() => _globalRule = val!), theme),
          const SizedBox(height: 10),
          _buildHelperText(_getGlobalRuleHelperText(), theme),
        ],
      ),
    );
  }

  String _getGlobalRuleHelperText() {
    if (_sessionType == 'Sáng & Chiều') {
      if (_globalRule == 'Giờ đầu') return "Chú thích: Hệ thống sẽ tự động điểm danh vào giờ đầu của Buổi Sáng và giờ đầu của Buổi Chiều.";
      if (_globalRule == 'Giờ cuối') return "Chú thích: Hệ thống sẽ tự động điểm danh vào giờ cuối của Buổi Sáng và giờ cuối của Buổi Chiều.";
      return "Chú thích: Hệ thống sẽ điểm danh 4 lần/ngày: Đầu/cuối Buổi Sáng VÀ Đầu/cuối Buổi Chiều.";
    } else {
      if (_globalRule == 'Giờ đầu') return "Chú thích: Chỉ ghi nhận điểm danh một lần vào giờ bắt đầu khung thời gian.";
      if (_globalRule == 'Giờ cuối') return "Chú thích: Chỉ ghi nhận điểm danh một lần trước khi kết thúc khung thời gian.";
      return "Chú thích: Ghi nhận 2 lần (Check-in giờ đến và Check-out giờ về).";
    }
  }

  Widget _buildDailyAttendanceLogic(AppTheme theme) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: theme.textColor.withOpacity(0.04), borderRadius: BorderRadius.circular(12), border: const Border(left: BorderSide(color: Colors.orangeAccent, width: 3))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: _buildOptionChip("Theo từng Môn học", _dailyMode == 'Từng môn', () => setState(() => _dailyMode = 'Từng môn'), theme)),
              const SizedBox(width: 15),
              Expanded(child: _buildOptionChip("Theo tiết Đầu tiên", _dailyMode == 'Tiết đầu tiên', () => setState(() => _dailyMode = 'Tiết đầu tiên'), theme)),
            ],
          ),
          const SizedBox(height: 20),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: _dailyMode == 'Từng môn'
                ? Column(
              key: const ValueKey('TungMon'),
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildDropdownField("Chi tiết từng môn", Icons.book_rounded, _subjectRule, ['Đầu tiết', 'Cuối tiết', 'Cả đầu và cuối tiết'], (val) => setState(() => _subjectRule = val!), theme),
                const SizedBox(height: 10),
                _buildHelperText("Chú thích: Camera sẽ liên tục quét và phân tách dữ liệu cho mỗi khung giờ môn học đã được khai báo ở bảng Thời khóa biểu bên dưới.", theme),
              ],
            )
                : Column(
              key: const ValueKey('TietDau'),
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildDropdownField("Chi tiết tiết đầu", Icons.looks_one_rounded, _firstPeriodRule, ['Giờ đầu tiên', 'Đầu và cuối buổi'], (val) => setState(() => _firstPeriodRule = val!), theme),
                const SizedBox(height: 10),
                _buildHelperText(_sessionType == 'Sáng & Chiều' && _firstPeriodRule == 'Đầu và cuối buổi'
                    ? "Chú thích: Lấy khung giờ của tiết học đầu tiên (Sáng/Chiều) làm giờ vào, và khung giờ của tiết cuối cùng làm giờ ra."
                    : "Chú thích: Hệ thống sẽ dò tìm tiết học có thời gian sớm nhất trong ngày/buổi để chốt giờ có mặt.", theme),
              ],
            ),
          )
        ],
      ),
    );
  }

  // ==============================================================
  // KHỐI LỚP HỌC (CHỨA THỜI KHÓA BIỂU)
  // ==============================================================
  Widget _buildClassBlock(int classIndex, ClassModel classItem, AppTheme theme) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      margin: const EdgeInsets.only(bottom: 30),
      padding: const EdgeInsets.all(25),
      decoration: BoxDecoration(color: theme.cardColor, borderRadius: BorderRadius.circular(16), border: Border.all(color: theme.borderColor, width: 1.5)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(flex: 3, child: _buildTextField("Tên Lớp (VD: 10A1)", Icons.meeting_room_rounded, "Nhập tên lớp", theme, onChanged: (v) => classItem.className = v)),
              const SizedBox(width: 20),
              Expanded(
                flex: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(padding: const EdgeInsets.only(bottom: 6), child: AnimatedDefaultTextStyle(duration: const Duration(milliseconds: 300), style: TextStyle(color: theme.subTextColor, fontSize: 12 * theme.fontScale, fontWeight: FontWeight.bold, fontFamily: 'Segoe UI'), child: const Text("Danh sách học sinh"))),
                    SizedBox(
                      height: 45,
                      child: ElevatedButton.icon(
                        onPressed: () => _processExcelFile(context, classItem, setState),
                        icon: Icon(classItem.uploadedExcelFile != null ? Icons.check_circle_rounded : Icons.upload_file_rounded, color: classItem.uploadedExcelFile != null ? Colors.greenAccent : theme.textColor),
                        label: Text(classItem.uploadedExcelFile ?? "Tải Excel (.xlsx)", style: TextStyle(color: classItem.uploadedExcelFile != null ? Colors.greenAccent : theme.textColor)),
                        style: ElevatedButton.styleFrom(backgroundColor: classItem.uploadedExcelFile != null ? Colors.greenAccent.withOpacity(0.1) : theme.textColor.withOpacity(0.05), elevation: 0, alignment: Alignment.centerLeft, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                      ),
                    ),
                  ],
                ),
              ),
              if (_classes.length > 1) IconButton(onPressed: () => setState(() => _classes.removeAt(classIndex)), icon: Icon(Icons.delete_outline_rounded, color: Colors.redAccent.withOpacity(0.8))),
            ],
          ),
          const SizedBox(height: 25),
          AnimatedDefaultTextStyle(duration: const Duration(milliseconds: 300), style: TextStyle(color: theme.primaryColor, fontSize: 13 * theme.fontScale, fontWeight: FontWeight.bold, fontFamily: 'Segoe UI'), child: const Text("THỜI KHÓA BIỂU CỦA LỚP")),
          const SizedBox(height: 15),

          ...classItem.days.asMap().entries.map((dayEntry) => _buildDayBlock(classItem, dayEntry.key, dayEntry.value, theme)),

          const SizedBox(height: 5),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => setState(() => classItem.days.add(DayModel())),
              icon: Icon(Icons.add_rounded, color: theme.subTextColor, size: 16 * theme.fontScale),
              label: Text("Thêm Thứ học", style: TextStyle(color: theme.subTextColor, fontWeight: FontWeight.bold, fontSize: 12 * theme.fontScale)),
            ),
          )
        ],
      ),
    );
  }

  // ==============================================================
  // KHỐI THỨ (HIỂN THỊ MÔN HỌC THEO CA SÁNG / CHIỀU)
  // ==============================================================
  Widget _buildDayBlock(ClassModel classItem, int dayIndex, DayModel dayItem, AppTheme theme) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.only(bottom: 15, left: 15),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(color: theme.textColor.withOpacity(0.02), borderRadius: BorderRadius.circular(12), border: Border(left: BorderSide(color: theme.textColor.withOpacity(0.1), width: 3))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(flex: 2, child: _buildDropdownField("Thứ", Icons.today_rounded, dayItem.dayName, ['Thứ 2', 'Thứ 3', 'Thứ 4', 'Thứ 5', 'Thứ 6', 'Thứ 7', 'Chủ Nhật'], (val) => setState(() => dayItem.dayName = val!), theme)),
              const SizedBox(width: 20),
              Expanded(flex: 5, child: Container()),
              if (classItem.days.length > 1) IconButton(onPressed: () => setState(() => classItem.days.removeAt(dayIndex)), icon: Icon(Icons.close_rounded, color: Colors.redAccent.withOpacity(0.8), size: 18 * theme.fontScale)),
            ],
          ),
          const SizedBox(height: 15),

          if (_sessionType != 'Sáng & Chiều')
            _buildSubjectList(dayItem.morningSubjects, theme),

          if (_sessionType == 'Sáng & Chiều') ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(color: Colors.orangeAccent.withOpacity(0.15), borderRadius: BorderRadius.circular(8)),
              child: AnimatedDefaultTextStyle(duration: const Duration(milliseconds: 300), style: TextStyle(color: theme.isDarkMode ? Colors.orangeAccent : Colors.deepOrange, fontSize: 11 * theme.fontScale, fontWeight: FontWeight.bold, fontFamily: 'Segoe UI'), child: const Text("☀️ BUỔI SÁNG")),
            ),
            const SizedBox(height: 10),
            _buildSubjectList(dayItem.morningSubjects, theme),

            const SizedBox(height: 15),
            Divider(color: theme.borderColor),
            const SizedBox(height: 15),

            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(color: Colors.lightBlueAccent.withOpacity(0.15), borderRadius: BorderRadius.circular(8)),
              child: AnimatedDefaultTextStyle(duration: const Duration(milliseconds: 300), style: TextStyle(color: theme.isDarkMode ? Colors.lightBlueAccent : Colors.blueAccent, fontSize: 11 * theme.fontScale, fontWeight: FontWeight.bold, fontFamily: 'Segoe UI'), child: const Text("🌤️ BUỔI CHIỀU")),
            ),
            const SizedBox(height: 10),
            _buildSubjectList(dayItem.afternoonSubjects, theme),
          ]
        ],
      ),
    );
  }

  Widget _buildSubjectList(List<SubjectModel> subjects, AppTheme theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ...subjects.asMap().entries.map((subEntry) {
          int subIndex = subEntry.key;
          SubjectModel subItem = subEntry.value;
          return Padding(
            padding: const EdgeInsets.only(bottom: 10, left: 15),
            child: Row(
              children: [
                Icon(Icons.subdirectory_arrow_right_rounded, color: theme.subTextColor.withOpacity(0.5), size: 16 * theme.fontScale),
                const SizedBox(width: 10),
                Expanded(flex: 3, child: _buildTextFieldNoLabel(Icons.book_rounded, "Tên môn (VD: Toán)", theme, onChanged: (v) => subItem.name = v)),
                const SizedBox(width: 15),
                Expanded(flex: 2, child: _buildTextFieldNoLabel(Icons.access_time_rounded, "Giờ (VD: 07:00-08:30)", theme, onChanged: (v) => subItem.timeFrame = v)),
                const SizedBox(width: 10),
                if (subjects.length > 1) IconButton(onPressed: () => setState(() => subjects.removeAt(subIndex)), icon: Icon(Icons.remove_circle_outline_rounded, color: Colors.redAccent.withOpacity(0.6), size: 18 * theme.fontScale)),
              ],
            ),
          );
        }),
        Padding(
          padding: const EdgeInsets.only(left: 40, top: 5),
          child: GestureDetector(
            onTap: () => setState(() => subjects.add(SubjectModel())),
            child: Row(children: [Icon(Icons.add_rounded, color: theme.primaryColor, size: 16 * theme.fontScale), const SizedBox(width: 4), AnimatedDefaultTextStyle(duration: const Duration(milliseconds: 300), style: TextStyle(color: theme.primaryColor, fontSize: 11 * theme.fontScale, fontWeight: FontWeight.bold, fontFamily: 'Segoe UI'), child: const Text("Thêm Môn học"))]),
          ),
        )
      ],
    );
  }

  // ==============================================================
  // FORM VĂN PHÒNG LÕI (DOANH NGHIỆP)
  // ==============================================================
  Widget _buildOfficeForm(AppTheme theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(Icons.domain_rounded, "THÔNG TIN DOANH NGHIỆP", theme),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(child: _buildTextField("Tên công ty / Tổ chức", Icons.corporate_fare_rounded, "Nhập tên doanh nghiệp", theme, onChanged: (v) => _companyName = v)),
            const SizedBox(width: 20),
            Expanded(child: _buildTextField("Quy mô nhân sự", Icons.groups_rounded, "VD: 50 - 100 người", theme, onChanged: (v) => _companyScale = v)),
          ],
        ),
        const SizedBox(height: 30),

        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          padding: const EdgeInsets.all(25),
          decoration: BoxDecoration(color: theme.primaryColor.withOpacity(0.05), borderRadius: BorderRadius.circular(16), border: Border.all(color: theme.primaryColor.withOpacity(0.2))),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.rule_rounded, color: theme.primaryColor, size: 20 * theme.fontScale),
                  const SizedBox(width: 10),
                  AnimatedDefaultTextStyle(duration: const Duration(milliseconds: 300), style: TextStyle(color: theme.textColor, fontSize: 14 * theme.fontScale, fontWeight: FontWeight.bold, fontFamily: 'Segoe UI'), child: const Text("CẤU HÌNH ĐIỂM DANH CHUNG")),
                ],
              ),
              const SizedBox(height: 25),

              AnimatedDefaultTextStyle(duration: const Duration(milliseconds: 300), style: TextStyle(color: theme.subTextColor, fontSize: 12 * theme.fontScale, fontWeight: FontWeight.bold, fontFamily: 'Segoe UI'), child: const Text("Ca làm việc của công ty")),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(child: _buildOptionChip("Chỉ Buổi Sáng", _officeSessionType == 'Sáng', () => setState(() => _officeSessionType = 'Sáng'), theme)),
                  const SizedBox(width: 10),
                  Expanded(child: _buildOptionChip("Chỉ Buổi Chiều", _officeSessionType == 'Chiều', () => setState(() => _officeSessionType = 'Chiều'), theme)),
                  const SizedBox(width: 10),
                  Expanded(child: _buildOptionChip("Cả Sáng & Chiều", _officeSessionType == 'Sáng & Chiều', () => setState(() => _officeSessionType = 'Sáng & Chiều'), theme)),
                ],
              ),
              const SizedBox(height: 15),

              AnimatedSize(
                duration: const Duration(milliseconds: 300),
                child: Row(
                  children: [
                    if (_officeSessionType == 'Sáng' || _officeSessionType == 'Sáng & Chiều')
                      Expanded(child: _buildTextField("Giờ làm Buổi Sáng", Icons.wb_twilight_rounded, "VD: 08:00 - 12:00", theme, onChanged: (v) => _officeGlobalTimeMorning = v)),
                    if (_officeSessionType == 'Sáng & Chiều') const SizedBox(width: 20),
                    if (_officeSessionType == 'Chiều' || _officeSessionType == 'Sáng & Chiều')
                      Expanded(child: _buildTextField("Giờ làm Buổi Chiều", Icons.wb_sunny_rounded, "VD: 13:30 - 17:30", theme, onChanged: (v) => _officeGlobalTimeAfternoon = v)),
                  ],
                ),
              ),

              const SizedBox(height: 30),
              Divider(color: theme.primaryColor.withOpacity(0.2), thickness: 1),
              const SizedBox(height: 20),

              AnimatedDefaultTextStyle(duration: const Duration(milliseconds: 300), style: TextStyle(color: theme.subTextColor, fontSize: 12 * theme.fontScale, fontWeight: FontWeight.bold, fontFamily: 'Segoe UI'), child: const Text("Cơ chế ghi nhận điểm danh")),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(child: _buildOptionChip("Theo giờ quy định chung", _officeAttendanceMode == 'Quy định chung', () => setState(() => _officeAttendanceMode = 'Quy định chung'), theme)),
                  const SizedBox(width: 10),
                  Expanded(child: _buildOptionChip("Theo từng Ban/Phòng", _officeAttendanceMode == 'Theo phòng ban', () => setState(() => _officeAttendanceMode = 'Theo phòng ban'), theme)),
                  const SizedBox(width: 10),
                  Expanded(child: _buildOptionChip("Ghi nhận tự do (Flex)", _officeAttendanceMode == 'Ghi lại tự do', () => setState(() => _officeAttendanceMode = 'Ghi lại tự do'), theme)),
                ],
              ),
              const SizedBox(height: 20),

              AnimatedSize(
                duration: const Duration(milliseconds: 400),
                child: _buildOfficeAttendanceLogic(theme),
              ),
            ],
          ),
        ),
        const SizedBox(height: 40),

        _buildSectionHeader(Icons.meeting_room_rounded, "QUẢN LÝ BAN PHÒNG & LỊCH LÀM VIỆC", theme),
        const SizedBox(height: 20),
        ..._departments.asMap().entries.map((entry) => _buildDepartmentBlock(entry.key, entry.value, theme)),
        const SizedBox(height: 10),
        Center(
          child: TextButton.icon(
            onPressed: () => setState(() => _departments.add(DepartmentModel())),
            icon: Icon(Icons.add_circle_outline_rounded, color: theme.primaryColor, size: 18 * theme.fontScale),
            label: Text("THÊM BAN/PHÒNG MỚI", style: TextStyle(color: theme.primaryColor, fontWeight: FontWeight.bold, fontSize: 13 * theme.fontScale)),
          ),
        )
      ],
    );
  }

  Widget _buildOfficeAttendanceLogic(AppTheme theme) {
    if (_officeAttendanceMode == 'Quy định chung') {
      return Container(
        padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: theme.textColor.withOpacity(0.04), borderRadius: BorderRadius.circular(12), border: const Border(left: BorderSide(color: Colors.blueAccent, width: 3))),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDropdownField("Cài đặt điểm danh", Icons.rule_folder_rounded, _officeGlobalRule, ['Giờ đầu (Check-in)', 'Giờ cuối (Check-out)', 'Đầu và cuối'], (val) => setState(() => _officeGlobalRule = val!), theme),
            const SizedBox(height: 10),
            _buildHelperText("Hệ thống sẽ áp dụng khung giờ chung đã nhập ở trên cho toàn bộ nhân sự công ty.", theme),
          ],
        ),
      );
    } else if (_officeAttendanceMode == 'Theo phòng ban') {
      return Container(
        padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: theme.textColor.withOpacity(0.04), borderRadius: BorderRadius.circular(12), border: const Border(left: BorderSide(color: Colors.orangeAccent, width: 3))),
        child: _buildHelperText("Hệ thống sẽ áp dụng giờ điểm danh riêng được thiết lập cho từng Ban/Phòng ở bên dưới.", theme),
      );
    } else {
      return Container(
        padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: theme.textColor.withOpacity(0.04), borderRadius: BorderRadius.circular(12), border: const Border(left: BorderSide(color: Colors.greenAccent, width: 3))),
        child: _buildHelperText("Nhân viên có thể đến/về bất cứ lúc nào. Camera chỉ làm nhiệm vụ ghi nhận thời gian thực tế xuất hiện.", theme),
      );
    }
  }

  Widget _buildDepartmentBlock(int deptIndex, DepartmentModel deptItem, AppTheme theme) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      margin: const EdgeInsets.only(bottom: 30),
      padding: const EdgeInsets.all(25),
      decoration: BoxDecoration(color: theme.cardColor, borderRadius: BorderRadius.circular(16), border: Border.all(color: theme.borderColor, width: 1.5)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(flex: 3, child: _buildTextField("Tên Ban/Phòng (VD: Phòng Marketing)", Icons.supervised_user_circle_rounded, "Nhập tên Ban/Phòng", theme, onChanged: (v) => deptItem.deptName = v)),
              const SizedBox(width: 20),
              Expanded(
                flex: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(padding: const EdgeInsets.only(bottom: 6), child: AnimatedDefaultTextStyle(duration: const Duration(milliseconds: 300), style: TextStyle(color: theme.subTextColor, fontSize: 12 * theme.fontScale, fontWeight: FontWeight.bold, fontFamily: 'Segoe UI'), child: const Text("Danh sách nhân sự"))),
                    SizedBox(
                      height: 45,
                      child: ElevatedButton.icon(
                        onPressed: () => setState(() => deptItem.uploadedExcelFile = "nhan_su_phong.xlsx"),
                        icon: Icon(deptItem.uploadedExcelFile != null ? Icons.check_circle_rounded : Icons.upload_file_rounded, color: deptItem.uploadedExcelFile != null ? Colors.greenAccent : theme.textColor, size: 16 * theme.fontScale),
                        label: Text(deptItem.uploadedExcelFile ?? "Tải file Excel (.xlsx)", style: TextStyle(color: deptItem.uploadedExcelFile != null ? Colors.greenAccent : theme.textColor, fontWeight: FontWeight.bold, fontSize: 12 * theme.fontScale), overflow: TextOverflow.ellipsis),
                        style: ElevatedButton.styleFrom(backgroundColor: deptItem.uploadedExcelFile != null ? Colors.greenAccent.withOpacity(0.1) : theme.textColor.withOpacity(0.05), elevation: 0, alignment: Alignment.centerLeft, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                      ),
                    ),
                  ],
                ),
              ),
              if (_departments.length > 1) IconButton(onPressed: () => setState(() => _departments.removeAt(deptIndex)), icon: Icon(Icons.delete_outline_rounded, color: Colors.redAccent.withOpacity(0.8))),
            ],
          ),

          if (_officeAttendanceMode == 'Ghi lại tự do' || _officeAttendanceMode == 'Theo phòng ban') ...[
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
              decoration: BoxDecoration(color: theme.textColor.withOpacity(0.03), borderRadius: BorderRadius.circular(10)),
              child: Row(
                children: [
                  Expanded(
                    child: AnimatedDefaultTextStyle(
                        duration: const Duration(milliseconds: 300),
                        style: TextStyle(color: theme.textColor, fontSize: 13 * theme.fontScale, fontWeight: FontWeight.bold, fontFamily: 'Segoe UI'),
                        child: Text(_officeAttendanceMode == 'Ghi lại tự do'
                            ? "Yêu cầu ban này làm đúng giờ quy định (Kỷ luật riêng)"
                            : "Cho phép ban này điểm danh tự do (Không xét trễ/sớm)")
                    ),
                  ),
                  Switch(
                    value: deptItem.overrideRule,
                    activeColor: theme.primaryColor,
                    onChanged: (val) => setState(() => deptItem.overrideRule = val),
                  )
                ],
              ),
            ),
          ],

          const SizedBox(height: 25),
          AnimatedDefaultTextStyle(duration: const Duration(milliseconds: 300), style: TextStyle(color: theme.primaryColor, fontSize: 13 * theme.fontScale, fontWeight: FontWeight.bold, fontFamily: 'Segoe UI'), child: const Text("LỊCH LÀM VIỆC CỦA BAN")),
          const SizedBox(height: 15),

          ...deptItem.days.asMap().entries.map((dayEntry) => _buildOfficeDayBlock(deptItem, dayEntry.key, dayEntry.value, theme)),

          const SizedBox(height: 5),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => setState(() => deptItem.days.add(OfficeDayModel())),
              icon: Icon(Icons.add_rounded, color: theme.subTextColor, size: 16 * theme.fontScale),
              label: Text("Thêm Ngày làm việc", style: TextStyle(color: theme.subTextColor, fontWeight: FontWeight.bold, fontSize: 12 * theme.fontScale)),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildOfficeDayBlock(DepartmentModel deptItem, int dayIndex, OfficeDayModel dayItem, AppTheme theme) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.only(bottom: 15, left: 15),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(color: theme.textColor.withOpacity(0.02), borderRadius: BorderRadius.circular(12), border: Border(left: BorderSide(color: theme.textColor.withOpacity(0.1), width: 3))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(flex: 2, child: _buildDropdownField("Thứ", Icons.today_rounded, dayItem.dayName, ['Thứ 2', 'Thứ 3', 'Thứ 4', 'Thứ 5', 'Thứ 6', 'Thứ 7', 'Chủ Nhật'], (val) => setState(() => dayItem.dayName = val!), theme)),
              const SizedBox(width: 15),

              if (_officeSessionType == 'Sáng' || _officeSessionType == 'Sáng & Chiều')
                Expanded(flex: 3, child: _buildTextField("Giờ Sáng", Icons.access_time_rounded, "VD: 08:00-12:00", theme, onChanged: (v) => dayItem.timeFrameMorning = v)),

              if (_officeSessionType == 'Sáng & Chiều') const SizedBox(width: 15),

              if (_officeSessionType == 'Chiều' || _officeSessionType == 'Sáng & Chiều')
                Expanded(flex: 3, child: _buildTextField("Giờ Chiều", Icons.access_time_rounded, "VD: 13:30-17:30", theme, onChanged: (v) => dayItem.timeFrameAfternoon = v)),

              const SizedBox(width: 10),
              if (deptItem.days.length > 1)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: IconButton(onPressed: () => setState(() => deptItem.days.removeAt(dayIndex)), icon: Icon(Icons.remove_circle_outline_rounded, color: Colors.redAccent.withOpacity(0.8), size: 18 * theme.fontScale)),
                ),
            ],
          ),
        ],
      ),
    );
  }

  // --- CÁC HÀM TIỆN ÍCH DƯỚI CÙNG ---
  Widget _buildOptionChip(String label, bool isSelected, VoidCallback onTap, AppTheme theme) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300), padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(color: isSelected ? theme.primaryColor.withOpacity(0.1) : theme.textColor.withOpacity(0.03), borderRadius: BorderRadius.circular(10), border: Border.all(color: isSelected ? theme.primaryColor : Colors.transparent, width: 1.5)),
        child: Center(child: AnimatedDefaultTextStyle(duration: const Duration(milliseconds: 300), style: TextStyle(color: isSelected ? theme.primaryColor : theme.subTextColor, fontWeight: FontWeight.bold, fontSize: 12 * theme.fontScale, fontFamily: 'Segoe UI'), child: Text(label))),
      ),
    );
  }

  Widget _buildHelperText(String text, AppTheme theme) {
    return AnimatedDefaultTextStyle(duration: const Duration(milliseconds: 300), style: TextStyle(color: theme.subTextColor, fontSize: 11 * theme.fontScale, fontStyle: FontStyle.italic, fontFamily: 'Segoe UI'), child: Text(text));
  }

  Widget _buildRadioCard(String title, IconData icon, String groupValue, Function(String) onTap, AppTheme theme) {
    bool isSelected = groupValue == title;
    return GestureDetector(
      onTap: () => onTap(title),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300), padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 20),
        decoration: BoxDecoration(color: isSelected ? theme.primaryColor.withOpacity(0.1) : theme.cardColor, borderRadius: BorderRadius.circular(16), border: Border.all(color: isSelected ? theme.primaryColor : theme.borderColor, width: 1.5), boxShadow: theme.isDarkMode || isSelected ? [] : [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))]),
        child: Row(children: [Icon(icon, color: isSelected ? theme.primaryColor : theme.subTextColor, size: 24 * theme.fontScale), const SizedBox(width: 15), AnimatedDefaultTextStyle(duration: const Duration(milliseconds: 300), style: TextStyle(color: isSelected ? theme.textColor : theme.subTextColor, fontSize: 14 * theme.fontScale, fontWeight: FontWeight.bold, fontFamily: 'Segoe UI'), child: Text(title)), const Spacer(), if (isSelected) Icon(Icons.check_circle_rounded, color: theme.primaryColor, size: 20 * theme.fontScale)]),
      ),
    );
  }

  Widget _buildSectionHeader(IconData icon, String title, AppTheme theme) => Row(children: [AnimatedContainer(duration: const Duration(milliseconds: 300), child: Icon(icon, color: theme.primaryColor, size: 18 * theme.fontScale)), const SizedBox(width: 10), AnimatedDefaultTextStyle(duration: const Duration(milliseconds: 300), style: TextStyle(color: theme.textColor, fontSize: 14 * theme.fontScale, fontWeight: FontWeight.bold, letterSpacing: 1.2, fontFamily: 'Segoe UI'), child: Text(title))]);

  Widget _buildTextField(String label, IconData icon, String hint, AppTheme theme, {required Function(String) onChanged}) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Padding(padding: const EdgeInsets.only(bottom: 6), child: AnimatedDefaultTextStyle(duration: const Duration(milliseconds: 300), style: TextStyle(color: theme.subTextColor, fontSize: 12 * theme.fontScale, fontWeight: FontWeight.bold, fontFamily: 'Segoe UI'), child: Text(label))), _buildTextFieldNoLabel(icon, hint, theme, onChanged: onChanged)]);

  Widget _buildTextFieldNoLabel(IconData icon, String hint, AppTheme theme, {required Function(String) onChanged}) => SizedBox(height: 45, child: TextField(onChanged: onChanged, style: TextStyle(color: theme.textColor, fontSize: 13 * theme.fontScale), decoration: InputDecoration(contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 15), prefixIcon: Icon(icon, color: theme.primaryColor, size: 18 * theme.fontScale), hintText: hint, hintStyle: TextStyle(color: theme.subTextColor.withOpacity(0.5), fontSize: 13 * theme.fontScale), filled: true, fillColor: theme.textColor.withOpacity(0.04), enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: theme.borderColor)), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: theme.primaryColor, width: 1.5)))));

  Widget _buildDropdownField(String label, IconData icon, String currentValue, List<String> items, Function(String?) onChanged, AppTheme theme) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Padding(padding: const EdgeInsets.only(bottom: 6), child: AnimatedDefaultTextStyle(duration: const Duration(milliseconds: 300), style: TextStyle(color: theme.subTextColor, fontSize: 12 * theme.fontScale, fontWeight: FontWeight.bold, fontFamily: 'Segoe UI'), child: Text(label))), SizedBox(height: 45, child: DropdownButtonFormField<String>(value: currentValue, dropdownColor: theme.cardColor, style: TextStyle(color: theme.textColor, fontSize: 13 * theme.fontScale), icon: Icon(Icons.keyboard_arrow_down_rounded, color: theme.primaryColor, size: 18 * theme.fontScale), decoration: InputDecoration(contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 15), prefixIcon: Icon(icon, color: theme.primaryColor, size: 18 * theme.fontScale), filled: true, fillColor: theme.textColor.withOpacity(0.04), enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: theme.borderColor)), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: theme.primaryColor, width: 1.5))), items: items.map((String item) => DropdownMenuItem<String>(value: item, child: Text(item))).toList(), onChanged: onChanged))]);

  Widget _buildActionCard({required String title, required String description, required IconData icon, required bool isPrimary, required AppTheme theme, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300), padding: const EdgeInsets.all(35),
        decoration: BoxDecoration(gradient: isPrimary ? LinearGradient(colors: [theme.primaryColor.withOpacity(0.15), Colors.transparent], begin: Alignment.topLeft, end: Alignment.bottomRight) : null, color: isPrimary ? null : theme.cardColor, borderRadius: BorderRadius.circular(24), border: Border.all(color: isPrimary ? theme.primaryColor.withOpacity(0.5) : theme.borderColor, width: isPrimary ? 1.5 : 1.0), boxShadow: theme.isDarkMode ? [] : [if(isPrimary) BoxShadow(color: theme.primaryColor.withOpacity(0.1), blurRadius: 20, offset: const Offset(0, 10)) else BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 15, offset: const Offset(0, 5))]),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [AnimatedContainer(duration: const Duration(milliseconds: 300), padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: isPrimary ? theme.primaryColor : theme.primaryColor.withOpacity(0.1), borderRadius: BorderRadius.circular(16)), child: Icon(icon, color: isPrimary ? Colors.white : theme.primaryColor, size: 36 * theme.fontScale)), const SizedBox(height: 25), AnimatedDefaultTextStyle(duration: const Duration(milliseconds: 300), style: TextStyle(color: theme.textColor, fontSize: 20 * theme.fontScale, fontWeight: FontWeight.bold, fontFamily: 'Segoe UI'), child: Text(title)), const SizedBox(height: 10), AnimatedDefaultTextStyle(duration: const Duration(milliseconds: 300), style: TextStyle(color: theme.subTextColor, fontSize: 13 * theme.fontScale, height: 1.5, fontFamily: 'Segoe UI'), child: Text(description))]),
      ),
    );
  }

  // ==============================================================
  // CÁC HÀM GIAO DIỆN BỔ SUNG
  // ==============================================================
  Widget _buildProjectCard(int projectId, String name, String role, String status, IconData icon, bool isOwner, AppTheme theme) {
    bool isPending = status == "Đang xét duyệt";
    Color badgeColor = isOwner ? theme.primaryColor : (isPending ? Colors.grey : Colors.purpleAccent);
    String badgeText = isOwner ? "Dự án Đã Tạo" : "Dự án Tham Gia";

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300), width: 330, padding: const EdgeInsets.all(30),
      decoration: BoxDecoration(color: theme.cardColor, borderRadius: BorderRadius.circular(24), border: Border.all(color: badgeColor.withOpacity(0.5), width: 1.5), boxShadow: theme.isDarkMode ? [] : [BoxShadow(color: badgeColor.withOpacity(0.05), blurRadius: 20, offset: const Offset(0, 10))]),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, crossAxisAlignment: CrossAxisAlignment.start, children: [AnimatedContainer(duration: const Duration(milliseconds: 300), padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: badgeColor.withOpacity(0.15), borderRadius: BorderRadius.circular(14)), child: Icon(icon, color: badgeColor, size: 28 * theme.fontScale)), Column(crossAxisAlignment: CrossAxisAlignment.end, children: [Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5), decoration: BoxDecoration(color: badgeColor.withOpacity(0.15), borderRadius: BorderRadius.circular(8)), child: Text(badgeText, style: TextStyle(color: badgeColor, fontSize: 10 * theme.fontScale, fontWeight: FontWeight.bold))), const SizedBox(height: 6), Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5), decoration: BoxDecoration(color: isPending ? Colors.grey.withOpacity(0.2) : (status == "Hoạt động" ? Colors.green.withOpacity(0.15) : Colors.orange.withOpacity(0.15)), borderRadius: BorderRadius.circular(8)), child: Text(status, style: TextStyle(color: isPending ? Colors.grey : (status == "Hoạt động" ? Colors.green : Colors.orange), fontSize: 10 * theme.fontScale, fontWeight: FontWeight.bold)))])]),
          const SizedBox(height: 25), Text(name, style: TextStyle(color: theme.textColor, fontSize: 18 * theme.fontScale, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis), const SizedBox(height: 8), AnimatedDefaultTextStyle(duration: const Duration(milliseconds: 300), style: TextStyle(color: theme.subTextColor, fontSize: 13 * theme.fontScale, fontFamily: 'Segoe UI'), child: Text("Vai trò: $role")), const SizedBox(height: 25),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: isPending
                  ? () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Dự án đang chờ Quản trị viên duyệt! Vui lòng quay lại sau."), backgroundColor: Colors.orange))
                  : () {
                globals.currentProjectId = projectId;
                Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => ProjectWorkspaceScreen(userRole: role))
                ).then((_) {
                  _fetchProjects();
                });
              },
              style: ElevatedButton.styleFrom(backgroundColor: isPending ? theme.textColor.withOpacity(0.05) : badgeColor.withOpacity(0.15), foregroundColor: theme.textColor, elevation: 0, shadowColor: Colors.transparent, side: BorderSide(color: isPending ? theme.borderColor : badgeColor.withOpacity(0.5), width: 1), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), padding: const EdgeInsets.symmetric(vertical: 16)),
              child: Text(isPending ? "ĐANG CHỜ DUYỆT..." : "TRUY CẬP DỰ ÁN", style: TextStyle(color: isPending ? theme.subTextColor : theme.textColor, fontSize: 12 * theme.fontScale, fontWeight: FontWeight.bold, letterSpacing: 1.0)),
            ),
          )
        ],
      ),
    );
  }

  // 2. POPUP DIALOG THAM GIA DỰ ÁN
  void _showJoinProjectDialog(BuildContext context, AppTheme theme) {
    TextEditingController codeController = TextEditingController();
    bool isProcessing = false;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            bool isScanningQR = false;
            return Dialog(
              backgroundColor: theme.cardColor,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24), side: BorderSide(color: theme.borderColor)),
              child: Container(
                width: 450, padding: const EdgeInsets.all(35),
                child: Column(
                  mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text("Gia nhập hệ thống", style: TextStyle(color: theme.textColor, fontSize: 20 * theme.fontScale, fontWeight: FontWeight.w900)), IconButton(onPressed: () => Navigator.pop(context), icon: Icon(Icons.close_rounded, color: theme.subTextColor))]),
                    const SizedBox(height: 10), Text("Sử dụng mã định danh hoặc quét QR do Quản trị viên cung cấp.", style: TextStyle(color: theme.subTextColor, fontSize: 12 * theme.fontScale)), const SizedBox(height: 30),

                    AnimatedSwitcher(duration: const Duration(milliseconds: 300), child: !isScanningQR ? _buildEnterCodeUI(theme, codeController, isProcessing, setStateDialog) : _buildQRScannerUI(theme)),

                    const SizedBox(height: 30),
                    SizedBox(width: double.infinity, child: TextButton.icon(onPressed: () => setStateDialog(() => isScanningQR = !isScanningQR), icon: Icon(!isScanningQR ? Icons.qr_code_scanner_rounded : Icons.keyboard_rounded, color: theme.primaryColor, size: 18 * theme.fontScale), label: Text(!isScanningQR ? "Chuyển sang Quét mã QR" : "Chuyển sang Nhập mã tay", style: TextStyle(color: theme.primaryColor, fontWeight: FontWeight.bold, fontSize: 13 * theme.fontScale)))),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // 3. UI XÁC NHẬN MÃ TAY
  Widget _buildEnterCodeUI(AppTheme theme, TextEditingController controller, bool isProcessing, StateSetter setStateDialog) {
    return Column(
      key: const ValueKey('EnterCode'), crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("Mã Dự Án (Code)", style: TextStyle(color: theme.subTextColor, fontSize: 12 * theme.fontScale, fontWeight: FontWeight.bold)), const SizedBox(height: 8),
        SizedBox(height: 50, child: TextField(controller: controller, style: TextStyle(color: theme.textColor, fontSize: 14 * theme.fontScale, fontWeight: FontWeight.bold, letterSpacing: 2.0), decoration: InputDecoration(contentPadding: const EdgeInsets.symmetric(horizontal: 20), hintText: "VD: SAMS-2026-XYZ", hintStyle: TextStyle(color: theme.subTextColor.withOpacity(0.5), fontSize: 14 * theme.fontScale, letterSpacing: 0), filled: true, fillColor: theme.textColor.withOpacity(0.04), enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: theme.borderColor)), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: theme.primaryColor, width: 2.0))))),
        const SizedBox(height: 25),
        SizedBox(width: double.infinity, height: 48,
          child: ElevatedButton(
            onPressed: isProcessing ? null : () async {
              if (controller.text.trim().isEmpty) return;
              setStateDialog(() => isProcessing = true);

              try {
                var response = await http.post(
                    Uri.parse('http://127.0.0.1:8000/api/projects/join'),
                    headers: {"Content-Type": "application/json"},
                    body: jsonEncode({"project_code": controller.text.trim(), "user_id": globals.currentUserId})
                );

                if (response.statusCode == 200) {
                  var data = jsonDecode(response.body);
                  if (data['status'] == 'success') {

                    if (context.mounted) Navigator.pop(context);

                    setState(() {
                      _projectList.add(data['data']);
                    });

                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(data['message']), backgroundColor: Colors.green));
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(data['message']), backgroundColor: Colors.orange));
                  }
                }
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Lỗi Server!"), backgroundColor: Colors.redAccent));
              } finally { setStateDialog(() => isProcessing = false); }
            },
            style: ElevatedButton.styleFrom(backgroundColor: theme.primaryColor, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            child: isProcessing ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : Text("XÁC NHẬN MÃ", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 1.0, fontSize: 13 * theme.fontScale)),
          ),
        )
      ],
    );
  }

  // 4. UI cho phần Quét Camera (Bên trong Dialog)
  Widget _buildQRScannerUI(AppTheme theme) {
    return Column(
      key: const ValueKey('ScanQR'),
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: double.infinity,
          height: 200,
          decoration: BoxDecoration(
            color: Colors.black,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: theme.primaryColor.withOpacity(0.5), width: 2),
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Icon(Icons.qr_code_rounded, size: 100, color: Colors.white.withOpacity(0.1)),
              Container(width: 120, height: 120, decoration: BoxDecoration(border: Border.all(color: theme.primaryColor, width: 2), borderRadius: BorderRadius.circular(12))),
              Positioned(
                  top: 40,
                  child: Container(
                      width: 150,
                      height: 2,
                      decoration: const BoxDecoration(
                          color: Colors.greenAccent,
                          boxShadow: [BoxShadow(color: Colors.greenAccent, blurRadius: 10, spreadRadius: 2)]
                      )
                  )
              ),
            ],
          ),
        ),
        const SizedBox(height: 15),
        Text("Đang kết nối Camera...", style: TextStyle(color: Colors.green, fontSize: 12 * theme.fontScale, fontStyle: FontStyle.italic)),
        const SizedBox(height: 5),
        Text("Đưa mã QR của dự án vào giữa khung hình.", style: TextStyle(color: theme.subTextColor, fontSize: 12 * theme.fontScale)),
      ],
    );
  }
}