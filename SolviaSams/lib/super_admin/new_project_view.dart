import 'package:flutter/material.dart';
import 'package:solviasams/globals.dart' as globals;
import '../theme_manager.dart';
import '../project_workspace/project_workspace_screen.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class BellPeriodModel {
  String name;
  String startTime;
  String endTime;
  BellPeriodModel({required this.name, required this.startTime, required this.endTime});
}

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

  // ==============================================================
  // ĐÃ FIX: CÁC BIẾN CƠ CHẾ ĐIỂM DANH THEO ĐÚNG THIẾT KẾ MỚI
  // ==============================================================
  String _attendanceMode = 'Quy định chung toàn trường';
  String _globalRule = 'Đầu và cuối (In/Out)';
  String _dailyMode = 'Từng tiết riêng lẻ';
  String _subjectRule = 'Cả vào và ra';
  String _firstPeriodRule = 'Vào tiết đầu - Ra tiết cuối';

  String _morningIn = '';
  String _morningOut = '';
  String _afternoonIn = '';
  String _afternoonOut = '';

  List<BellPeriodModel> _bellSchedule = [
    BellPeriodModel(name: "Tiết 1", startTime: "07:00", endTime: "07:45"),
    BellPeriodModel(name: "Tiết 2", startTime: "07:45", endTime: "08:30"),
  ];

  List<dynamic> _projectList = [];
  bool _isLoadingProjects = true;

  Map<String, dynamic>? _studentData;

  @override
  void initState() {
    super.initState();
    if (globals.currentUserRole == 'Học sinh' || globals.currentUserRole == 'Thành viên') {
      _fetchStudentDashboard();
    } else {
      _fetchProjects();
    }
  }

  Future<void> _fetchProjects() async {
    if (!mounted) return;
    setState(() => _isLoadingProjects = true);

    try {
      var response = await http.get(Uri.parse('http://127.0.0.1:8000/api/users/${globals.currentUserId}/projects'));
      if (response.statusCode == 200) {
        var responseBody = jsonDecode(utf8.decode(response.bodyBytes));
        if (responseBody['status'] == 'success' && mounted) {
          setState(() { _projectList = responseBody['data'] ?? []; _isLoadingProjects = false; });
          return;
        }
      }
    } catch (e) { debugPrint("Lỗi kéo dự án: $e"); }

    if (mounted) setState(() => _isLoadingProjects = false);
  }

  Future<void> _fetchStudentDashboard() async {
    if (!mounted) return;
    setState(() => _isLoadingProjects = true);

    try {
      var response = await http.get(Uri.parse('http://127.0.0.1:8000/api/students/${globals.currentUserId}/dashboard'));
      if (response.statusCode == 200) {
        var resBody = jsonDecode(utf8.decode(response.bodyBytes));
        if (resBody['status'] == 'success' && mounted) {
          setState(() {
            _studentData = resBody['data'];
            globals.currentProjectId = _studentData!['project_id'];
            globals.currentClassId = _studentData!['class_id'];
          });
        }
      }
    } catch (e) { debugPrint("Lỗi kéo dashboard hs: $e"); }
    if (mounted) setState(() => _isLoadingProjects = false);
  }

  String _formatTime(String input) {
    String clean = input.replaceAll(RegExp(r'[^0-9:]'), '');
    if (!clean.contains(':') && clean.isNotEmpty) return "${clean.padLeft(2, '0')}:00";
    List<String> parts = clean.split(':');
    if (parts.length >= 2) return "${parts[0].padLeft(2, '0')}:${parts[1].padLeft(2, '0')}";
    return clean;
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: AppTheme.instance,
      builder: (context, child) {
        final theme = AppTheme.instance;

        return SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 40.0, vertical: 30.0),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 400),
            switchInCurve: Curves.easeInOut,
            switchOutCurve: Curves.easeInOut,
            child: !_isCreatingProject
                ? ((globals.currentUserRole == 'Học sinh' || globals.currentUserRole == 'Thành viên')
                ? _buildStudentOverview(theme)
                : _buildOverviewScreen(theme))
                : _buildCreateProjectForm(theme),
          ),
        );
      },
    );
  }

  Widget _buildStudentOverview(AppTheme theme) {
    String schoolName = _studentData != null ? _studentData!['project_name'] : "Trường của bạn";
    String className = _studentData != null ? _studentData!['class_name'] : "Đang tải...";

    return Column(
      key: const ValueKey('StudentOverview'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AnimatedDefaultTextStyle(duration: const Duration(milliseconds: 300), style: TextStyle(fontSize: 28 * theme.fontScale, fontWeight: FontWeight.w900, color: theme.textColor, letterSpacing: 1.0, fontFamily: 'Segoe UI'), child: const Text("Trang Chủ Phần Mềm")),
        const SizedBox(height: 8),
        AnimatedDefaultTextStyle(duration: const Duration(milliseconds: 300), style: TextStyle(fontSize: 14 * theme.fontScale, color: theme.subTextColor, fontFamily: 'Segoe UI'), child: const Text("Hệ thống điểm danh và quản lý lịch học thông minh.")),
        const SizedBox(height: 40),

        if (_isLoadingProjects)
          Center(child: CircularProgressIndicator(color: theme.primaryColor))
        else ...[
          Row(
            children: [
              Expanded(child: _buildActionCard(title: "$schoolName - Lớp $className", description: "Truy cập thẳng vào không gian học tập, thời khóa biểu và báo cáo điểm danh.", icon: Icons.school_rounded, isPrimary: true, theme: theme, onTap: () { if (_studentData != null) { Navigator.push(context, MaterialPageRoute(builder: (context) => const ProjectWorkspaceScreen(userRole: 'Học sinh'))); } })),
              const SizedBox(width: 30),
              Expanded(child: _buildActionCard(title: "Tài khoản", description: "Quản lý hồ sơ cá nhân", icon: Icons.person_rounded, isPrimary: false, theme: theme, onTap: () { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Tính năng Tài khoản đang được cập nhật."))); })),
            ],
          ),
          const SizedBox(height: 30),
          Row(
            children: [
              Expanded(child: _buildActionCard(title: "Cài đặt", description: "Thay đổi giao diện, ngôn ngữ", icon: Icons.settings_rounded, isPrimary: false, theme: theme, onTap: () { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Tính năng Cài đặt đang được cập nhật."))); })),
              const SizedBox(width: 30),
              Expanded(child: _buildActionCard(title: "Support", description: "Hỗ trợ từ Giáo viên / Hệ thống", icon: Icons.support_agent_rounded, isPrimary: false, theme: theme, onTap: () { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Chức năng Support đang được cập nhật."))); })),
            ],
          ),
        ]
      ],
    );
  }

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
            Expanded(child: _buildActionCard(title: "Tạo Dự Án Mới", description: "Khởi tạo một hệ thống SAMS hoàn toàn mới. Trở thành người quản trị tối cao.", icon: Icons.add_business_rounded, isPrimary: true, theme: theme, onTap: () => setState(() => _isCreatingProject = true))),
            const SizedBox(width: 30),
            Expanded(child: _buildActionCard(title: "Tham Gia Dự Án", description: "Gia nhập vào hệ thống bằng Mã dự án hoặc Quét mã QR do Admin cung cấp.", icon: Icons.group_add_rounded, isPrimary: false, theme: theme, onTap: () => _showJoinProjectDialog(theme))),
          ],
        ),
        const SizedBox(height: 50),

        _buildSectionHeader(Icons.inventory_2_rounded, "KHO DỰ ÁN (ĐÃ TẠO & THAM GIA)", theme),
        const SizedBox(height: 25),

        _isLoadingProjects
            ? Center(child: CircularProgressIndicator(color: theme.primaryColor))
            : _projectList.isEmpty
            ? Padding(padding: const EdgeInsets.only(top: 20), child: Text("Chưa có dự án nào. Hãy tạo dự án đầu tiên của bạn!", style: TextStyle(color: theme.subTextColor, fontSize: 14 * theme.fontScale, fontStyle: FontStyle.italic)))
            : Wrap(
          spacing: 20, runSpacing: 20,
          children: _projectList.map((proj) {
            return _buildProjectCard(proj['id'], proj['project_name'] ?? "Không Tên", proj['role'] ?? "Khách", proj['status'] ?? "Hoạt động", proj['project_type'] == 'Trường học' ? Icons.school_rounded : Icons.corporate_fare_rounded, proj['is_owner'] ?? false, theme);
          }).toList(),
        )
      ],
    );
  }

  Widget _buildCreateProjectForm(AppTheme theme) {
    return Column(
      key: const ValueKey('CreateForm'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            IconButton(onPressed: () => setState(() => _isCreatingProject = false), icon: Icon(Icons.arrow_back_rounded, color: theme.textColor, size: 24 * theme.fontScale)),
            const SizedBox(width: 10),
            AnimatedDefaultTextStyle(duration: const Duration(milliseconds: 300), style: TextStyle(fontSize: 24 * theme.fontScale, fontWeight: FontWeight.w900, color: theme.textColor, fontFamily: 'Segoe UI'), child: const Text("Tạo Cấu Trúc Dự Án Lõi")),
          ],
        ),
        const SizedBox(height: 30),

        Container(
          padding: const EdgeInsets.all(40),
          decoration: BoxDecoration(color: theme.cardColor, borderRadius: BorderRadius.circular(24), border: Border.all(color: theme.borderColor), boxShadow: theme.isDarkMode ? [] : [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 20, offset: const Offset(0, 5))]),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionHeader(Icons.info_outline_rounded, "THÔNG TIN CƠ BẢN", theme),
              const SizedBox(height: 25),
              Row(
                children: [
                  Expanded(child: _buildTextField("Tên dự án", Icons.drive_file_rename_outline, "VD: Hệ thống SAMS Cơ sở 1", theme, onChanged: (v) => _projectName = v)),
                  const SizedBox(width: 20),
                  Expanded(child: _buildTextField("Tên Đơn vị / Trường học", Icons.account_balance_rounded, "VD: Trường THPT Chuyên", theme, onChanged: (v) => _schoolName = v)),
                ],
              ),
              const SizedBox(height: 25),

              Text("Loại hình hoạt động", style: TextStyle(color: theme.subTextColor, fontSize: 12 * theme.fontScale, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(child: _buildRadioCard("Trường học", Icons.school_rounded, _projectType, (val) => setState(() => _projectType = val), theme)),
                  const SizedBox(width: 20),
                  Expanded(child: _buildRadioCard("Văn phòng", Icons.corporate_fare_rounded, _projectType, (val) => setState(() => _projectType = val), theme)),
                ],
              ),
              const SizedBox(height: 40),
              Divider(color: theme.borderColor),
              const SizedBox(height: 40),

              _buildSectionHeader(Icons.rule_folder_rounded, "CẤU HÌNH CA HỌC & ĐIỂM DANH CHUNG", theme),
              const SizedBox(height: 25),

              Container(
                padding: const EdgeInsets.all(25),
                decoration: BoxDecoration(color: theme.textColor.withOpacity(0.02), borderRadius: BorderRadius.circular(16), border: Border.all(color: theme.borderColor)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("1. Ca hoạt động chính", style: TextStyle(color: theme.primaryColor, fontWeight: FontWeight.bold, fontSize: 13 * theme.fontScale)),
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
                    const SizedBox(height: 20),

                    AnimatedSize(
                      duration: const Duration(milliseconds: 300),
                      child: Column(
                        children: [
                          if (_sessionType == 'Sáng' || _sessionType == 'Sáng & Chiều') ...[
                            Row(
                              children: [
                                SizedBox(width: 120, child: Text("Khung giờ Sáng:", style: TextStyle(color: theme.textColor, fontWeight: FontWeight.bold))),
                                Expanded(child: _buildSimpleInput(_morningIn, "Giờ vào (VD: 07:00)", (v) { _morningIn = _formatTime(v); setState((){}); }, theme, isTime: true)),
                                const SizedBox(width: 15),
                                Expanded(child: _buildSimpleInput(_morningOut, "Giờ về (VD: 11:30)", (v) { _morningOut = _formatTime(v); setState((){}); }, theme, isTime: true)),
                              ],
                            ),
                            const SizedBox(height: 15),
                          ],
                          if (_sessionType == 'Chiều' || _sessionType == 'Sáng & Chiều') ...[
                            Row(
                              children: [
                                SizedBox(width: 120, child: Text("Khung giờ Chiều:", style: TextStyle(color: theme.textColor, fontWeight: FontWeight.bold))),
                                Expanded(child: _buildSimpleInput(_afternoonIn, "Giờ vào (VD: 13:00)", (v) { _afternoonIn = _formatTime(v); setState((){}); }, theme, isTime: true)),
                                const SizedBox(width: 15),
                                Expanded(child: _buildSimpleInput(_afternoonOut, "Giờ về (VD: 17:00)", (v) { _afternoonOut = _formatTime(v); setState((){}); }, theme, isTime: true)),
                              ],
                            )
                          ]
                        ],
                      ),
                    ),

                    const SizedBox(height: 25), Divider(color: theme.borderColor), const SizedBox(height: 25),

                    // ==============================================================
                    // ĐÃ FIX: GIAO DIỆN ĐIỂM DANH MỚI CHUẨN UX CỦA BẠN
                    // ==============================================================
                    Text("2. Cơ chế điểm danh", style: TextStyle(color: theme.primaryColor, fontWeight: FontWeight.bold, fontSize: 13 * theme.fontScale)),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(child: _buildOptionChip("Quy định chung toàn trường", _attendanceMode == 'Quy định chung toàn trường', () => setState((){ _attendanceMode = 'Quy định chung toàn trường'; _globalRule = 'Đầu và cuối (In/Out)'; }), theme)),
                        const SizedBox(width: 10),
                        Expanded(child: _buildOptionChip("Theo từng Tiết học", _attendanceMode == 'Theo từng Tiết học', () => setState((){ _attendanceMode = 'Theo từng Tiết học'; }), theme)),
                        const SizedBox(width: 10),
                        Expanded(child: _buildOptionChip("Ghi lại tự do (Flex)", _attendanceMode == 'Ghi lại tự do (Flex)', () => setState((){ _attendanceMode = 'Ghi lại tự do (Flex)'; _globalRule = 'Không xét đúng/trễ'; }), theme)),
                      ],
                    ),
                    const SizedBox(height: 15),

                    AnimatedSize(
                      duration: const Duration(milliseconds: 300),
                      child: _attendanceMode == 'Quy định chung toàn trường'
                          ? Row(
                        children: [
                          Text("Chi tiết quy định:", style: TextStyle(color: theme.textColor)), const SizedBox(width: 15),
                          Expanded(child: _buildOptionChip("Giờ đầu", _globalRule == 'Giờ đầu', () => setState(() => _globalRule = 'Giờ đầu'), theme)), const SizedBox(width: 10),
                          Expanded(child: _buildOptionChip("Giờ cuối", _globalRule == 'Giờ cuối', () => setState(() => _globalRule = 'Giờ cuối'), theme)), const SizedBox(width: 10),
                          Expanded(child: _buildOptionChip("Đầu và cuối (In/Out)", _globalRule == 'Đầu và cuối (In/Out)', () => setState(() => _globalRule = 'Đầu và cuối (In/Out)'), theme)),
                        ],
                      )
                          : (_attendanceMode == 'Theo từng Tiết học' ? Column(
                        children: [
                          Row(
                            children: [
                              Text("Phân bổ kiểm tra:", style: TextStyle(color: theme.textColor)), const SizedBox(width: 15),
                              Expanded(child: _buildOptionChip("Từng tiết riêng lẻ", _dailyMode == 'Từng tiết riêng lẻ', () => setState(() => _dailyMode = 'Từng tiết riêng lẻ'), theme)), const SizedBox(width: 10),
                              Expanded(child: _buildOptionChip("Tiết đầu / Tiết cuối buổi", _dailyMode == 'Tiết đầu / Tiết cuối buổi', () => setState(() => _dailyMode = 'Tiết đầu / Tiết cuối buổi'), theme)),
                            ],
                          ),
                          const SizedBox(height: 15),
                          Row(
                            children: [
                              Text("Chi tiết quy định:", style: TextStyle(color: theme.textColor)), const SizedBox(width: 15),
                              if (_dailyMode == 'Từng tiết riêng lẻ') ...[
                                Expanded(child: _buildOptionChip("Vào tiết", _subjectRule == 'Vào tiết', () => setState(() => _subjectRule = 'Vào tiết'), theme)), const SizedBox(width: 10),
                                Expanded(child: _buildOptionChip("Ra tiết", _subjectRule == 'Ra tiết', () => setState(() => _subjectRule = 'Ra tiết'), theme)), const SizedBox(width: 10),
                                Expanded(child: _buildOptionChip("Cả vào và ra", _subjectRule == 'Cả vào và ra', () => setState(() => _subjectRule = 'Cả vào và ra'), theme)),
                              ] else ...[
                                Expanded(child: _buildOptionChip("Vào tiết đầu tiên", _firstPeriodRule == 'Vào tiết đầu tiên', () => setState(() => _firstPeriodRule = 'Vào tiết đầu tiên'), theme)), const SizedBox(width: 10),
                                Expanded(child: _buildOptionChip("Ra tiết cuối cùng", _firstPeriodRule == 'Ra tiết cuối cùng', () => setState(() => _firstPeriodRule = 'Ra tiết cuối cùng'), theme)), const SizedBox(width: 10),
                                Expanded(child: _buildOptionChip("Vào tiết đầu - Ra tiết cuối", _firstPeriodRule == 'Vào tiết đầu - Ra tiết cuối', () => setState(() => _firstPeriodRule = 'Vào tiết đầu - Ra tiết cuối'), theme)),
                              ]
                            ],
                          )
                        ],
                      ) : Row(
                        children: [
                          Icon(Icons.info_outline_rounded, color: theme.successColor, size: 18), const SizedBox(width: 10),
                          Expanded(child: Text("Hệ thống chỉ làm nhiệm vụ ghi nhận lại thời gian xuất hiện của học sinh, không tự động đánh giá Đi trễ/Về sớm.", style: TextStyle(color: theme.subTextColor, fontSize: 12 * theme.fontScale))),
                        ],
                      )),
                    )
                  ],
                ),
              ),

              const SizedBox(height: 40),
              Divider(color: theme.borderColor),
              const SizedBox(height: 40),

              _buildSectionHeader(Icons.access_time_filled_rounded, "ĐỊNH NGHĨA CÁC TIẾT HỌC / CA LÀM", theme),
              const SizedBox(height: 10),
              Text("Định nghĩa trước các khung giờ (Tiết 1, Giải lao...). Sau này xếp TKB chỉ cần chọn tên tiết.", style: TextStyle(color: theme.subTextColor, fontSize: 13 * theme.fontScale, fontStyle: FontStyle.italic)),
              const SizedBox(height: 25),

              Container(
                padding: const EdgeInsets.all(25),
                decoration: BoxDecoration(color: theme.textColor.withOpacity(0.02), borderRadius: BorderRadius.circular(16), border: Border.all(color: theme.borderColor)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(flex: 3, child: Text("Tên Tiết/Ca", style: TextStyle(color: theme.primaryColor, fontWeight: FontWeight.bold, fontSize: 12 * theme.fontScale))),
                        const SizedBox(width: 15),
                        Expanded(flex: 2, child: Text("Giờ Bắt đầu", style: TextStyle(color: theme.primaryColor, fontWeight: FontWeight.bold, fontSize: 12 * theme.fontScale))),
                        const SizedBox(width: 15),
                        Expanded(flex: 2, child: Text("Giờ Kết thúc", style: TextStyle(color: theme.primaryColor, fontWeight: FontWeight.bold, fontSize: 12 * theme.fontScale))),
                        const SizedBox(width: 40),
                      ],
                    ),
                    const SizedBox(height: 15),

                    ..._bellSchedule.asMap().entries.map((entry) {
                      int idx = entry.key;
                      BellPeriodModel period = entry.value;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Row(
                          children: [
                            Expanded(flex: 3, child: _buildSimpleInput(period.name, "VD: Tiết 1, Giải lao...", (v) => period.name = v, theme)),
                            const SizedBox(width: 15),
                            Expanded(flex: 2, child: _buildSimpleInput(period.startTime, "07:00", (v) { period.startTime = _formatTime(v); setState((){}); }, theme, isTime: true)),
                            const SizedBox(width: 15),
                            Expanded(flex: 2, child: _buildSimpleInput(period.endTime, "07:45", (v) { period.endTime = _formatTime(v); setState((){}); }, theme, isTime: true)),
                            const SizedBox(width: 10),
                            IconButton(onPressed: () => setState(() => _bellSchedule.removeAt(idx)), icon: Icon(Icons.remove_circle_outline_rounded, color: theme.errorColor)),
                          ],
                        ),
                      );
                    }),
                    const SizedBox(height: 10),
                    TextButton.icon(
                        onPressed: () => setState(() => _bellSchedule.add(BellPeriodModel(name: "Tiết ${_bellSchedule.length + 1}", startTime: "", endTime: ""))),
                        icon: Icon(Icons.add_circle_outline_rounded, color: theme.primaryColor),
                        label: Text("Thêm Khung Giờ", style: TextStyle(color: theme.primaryColor, fontWeight: FontWeight.bold))
                    )
                  ],
                ),
              ),

              const SizedBox(height: 50),

              Align(
                alignment: Alignment.centerRight,
                child: ElevatedButton.icon(
                  onPressed: _submitProject,
                  icon: const Icon(Icons.rocket_launch_rounded, color: Colors.white),
                  label: Text("TẠO VÀ VÀO DỰ ÁN", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 1.0, fontSize: 13 * theme.fontScale)),
                  style: ElevatedButton.styleFrom(backgroundColor: theme.successColor, padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 20), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                ),
              )
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _submitProject() async {
    if (_projectName.trim().isEmpty || _schoolName.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Vui lòng nhập Tên dự án và Tên đơn vị cơ sở!"), backgroundColor: Colors.orange));
      return;
    }

    showDialog(context: context, barrierDismissible: false, builder: (c) => Dialog(backgroundColor: AppTheme.instance.cardColor, child: Padding(padding: const EdgeInsets.all(30), child: Row(mainAxisSize: MainAxisSize.min, children: [CircularProgressIndicator(color: AppTheme.instance.primaryColor), const SizedBox(width: 20), Text("Đang khởi tạo cấu trúc gốc...", style: TextStyle(color: AppTheme.instance.textColor))]))));

    try {
      List<Map<String, dynamic>> bellPayload = _bellSchedule.map((p) => {"name": p.name, "start_time": p.startTime, "end_time": p.endTime}).toList();

      String finalMorningTime = _morningIn.isNotEmpty && _morningOut.isNotEmpty ? "$_morningIn - $_morningOut" : "";
      String finalAfternoonTime = _afternoonIn.isNotEmpty && _afternoonOut.isNotEmpty ? "$_afternoonIn - $_afternoonOut" : "";

      // ==============================================================
      // ĐÃ FIX: ĐÓNG GÓI PAYLOAD GLOBAL RULE ĐÚNG CHUẨN
      // ==============================================================
      String finalGlobalRule = _globalRule;
      if (_attendanceMode == 'Theo từng Tiết học') {
        finalGlobalRule = _dailyMode == 'Từng tiết riêng lẻ' ? '$_dailyMode - $_subjectRule' : '$_dailyMode - $_firstPeriodRule';
      } else if (_attendanceMode == 'Ghi lại tự do (Flex)') {
        finalGlobalRule = 'Không xét đúng/trễ';
      }

      Map<String, dynamic> payload = {
        "user_id": globals.currentUserId,
        "project_name": _projectName,
        "school_name": _schoolName,
        "academic_year": "2026-2027",
        "project_type": _projectType,
        "session_type": _sessionType,
        "attendance_mode": _attendanceMode,
        "global_rule": finalGlobalRule,
        "morning_time": finalMorningTime,
        "afternoon_time": finalAfternoonTime,
        "bell_schedule": bellPayload
      };

      var response = await http.post(Uri.parse('http://127.0.0.1:8000/api/create-project'), headers: {"Content-Type": "application/json"}, body: jsonEncode(payload));
      if (context.mounted) Navigator.pop(context);

      if (response.statusCode == 200) {
        var responseData = jsonDecode(response.body);
        if (responseData['status'] == 'success') {
          globals.currentProjectId = responseData['project_id'];
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Dự án Core đã được tạo thành công!"), backgroundColor: Colors.green));

          Navigator.push(context, MaterialPageRoute(builder: (context) => const ProjectWorkspaceScreen(userRole: 'Super Admin'))).then((_) => _fetchProjects());
        } else {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Lỗi: ${responseData['message']}"), backgroundColor: Colors.redAccent));
        }
      }
    } catch (e) {
      if (context.mounted) Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Lỗi Server. Vui lòng kiểm tra lại."), backgroundColor: Colors.redAccent));
    }
  }

  // --- UI UTILS ---
  Widget _buildSectionHeader(IconData icon, String title, AppTheme theme) => Row(children: [Icon(icon, color: theme.primaryColor, size: 24 * theme.fontScale), const SizedBox(width: 12), Text(title, style: TextStyle(color: theme.textColor, fontSize: 16 * theme.fontScale, fontWeight: FontWeight.bold, letterSpacing: 1.0))]);

  Widget _buildTextField(String label, IconData icon, String hint, AppTheme theme, {required Function(String) onChanged}) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(label, style: TextStyle(color: theme.subTextColor, fontSize: 12 * theme.fontScale, fontWeight: FontWeight.bold)), const SizedBox(height: 8), SizedBox(height: 48, child: TextField(onChanged: onChanged, style: TextStyle(color: theme.textColor, fontSize: 14 * theme.fontScale), decoration: InputDecoration(prefixIcon: Icon(icon, color: theme.primaryColor), hintText: hint, hintStyle: TextStyle(color: theme.subTextColor.withOpacity(0.5)), filled: true, fillColor: theme.textColor.withOpacity(0.02), enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: theme.borderColor)), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: theme.primaryColor, width: 1.5)))))]);

  Widget _buildSimpleInput(String initialVal, String hint, Function(String) onChanged, AppTheme theme, {bool isTime = false}) => SizedBox(height: 45, child: TextFormField(initialValue: initialVal, onChanged: onChanged, textAlign: isTime ? TextAlign.center : TextAlign.left, style: TextStyle(color: theme.textColor, fontSize: 14 * theme.fontScale, fontWeight: isTime ? FontWeight.bold : FontWeight.normal), decoration: InputDecoration(hintText: hint, hintStyle: TextStyle(color: theme.subTextColor.withOpacity(0.5)), filled: true, fillColor: theme.textColor.withOpacity(0.03), contentPadding: const EdgeInsets.symmetric(horizontal: 15), enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: theme.borderColor)), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: theme.primaryColor)))));

  Widget _buildRadioCard(String title, IconData icon, String groupValue, Function(String) onTap, AppTheme theme) {
    bool isSelected = groupValue == title;
    return GestureDetector(
      onTap: () => onTap(title),
      child: AnimatedContainer(duration: const Duration(milliseconds: 300), padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 20), decoration: BoxDecoration(color: isSelected ? theme.primaryColor.withOpacity(0.1) : theme.cardColor, borderRadius: BorderRadius.circular(16), border: Border.all(color: isSelected ? theme.primaryColor : theme.borderColor, width: 1.5)), child: Row(children: [Icon(icon, color: isSelected ? theme.primaryColor : theme.subTextColor, size: 24 * theme.fontScale), const SizedBox(width: 15), Text(title, style: TextStyle(color: isSelected ? theme.textColor : theme.subTextColor, fontSize: 14 * theme.fontScale, fontWeight: FontWeight.bold)), const Spacer(), if (isSelected) Icon(Icons.check_circle_rounded, color: theme.primaryColor)])),
    );
  }

  Widget _buildOptionChip(String label, bool isSelected, VoidCallback onTap, AppTheme theme) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300), padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(color: isSelected ? theme.primaryColor.withOpacity(0.15) : theme.textColor.withOpacity(0.02), borderRadius: BorderRadius.circular(10), border: Border.all(color: isSelected ? theme.primaryColor : theme.borderColor, width: 1.5)),
        child: Center(child: Text(label, textAlign: TextAlign.center, style: TextStyle(color: isSelected ? theme.primaryColor : theme.subTextColor, fontWeight: FontWeight.bold, fontSize: 12 * theme.fontScale))),
      ),
    );
  }

  Widget _buildActionCard({required String title, required String description, required IconData icon, required bool isPrimary, required AppTheme theme, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(duration: const Duration(milliseconds: 300), padding: const EdgeInsets.all(35), decoration: BoxDecoration(gradient: isPrimary ? LinearGradient(colors: [theme.primaryColor.withOpacity(0.1), Colors.transparent], begin: Alignment.topLeft, end: Alignment.bottomRight) : null, color: isPrimary ? null : theme.cardColor, borderRadius: BorderRadius.circular(24), border: Border.all(color: isPrimary ? theme.primaryColor.withOpacity(0.5) : theme.borderColor, width: isPrimary ? 1.5 : 1.0), boxShadow: theme.isDarkMode ? [] : [BoxShadow(color: isPrimary ? theme.primaryColor.withOpacity(0.1) : Colors.black.withOpacity(0.02), blurRadius: 20, offset: const Offset(0, 10))]), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: isPrimary ? theme.primaryColor : theme.primaryColor.withOpacity(0.1), borderRadius: BorderRadius.circular(16)), child: Icon(icon, color: isPrimary ? Colors.white : theme.primaryColor, size: 36 * theme.fontScale)), const SizedBox(height: 25), Text(title, style: TextStyle(color: theme.textColor, fontSize: 20 * theme.fontScale, fontWeight: FontWeight.bold)), const SizedBox(height: 10), Text(description, style: TextStyle(color: theme.subTextColor, fontSize: 13 * theme.fontScale, height: 1.5))])),
    );
  }

  Widget _buildProjectCard(int projectId, String name, String role, String status, IconData icon, bool isOwner, AppTheme theme) {
    bool isPending = status == "Đang xét duyệt";
    Color badgeColor = isOwner ? theme.primaryColor : (isPending ? theme.subTextColor : theme.purpleColor);
    return Container(width: 330, padding: const EdgeInsets.all(30), decoration: BoxDecoration(color: theme.cardColor, borderRadius: BorderRadius.circular(24), border: Border.all(color: badgeColor.withOpacity(0.5), width: 1.5), boxShadow: theme.isDarkMode ? [] : [BoxShadow(color: badgeColor.withOpacity(0.05), blurRadius: 20, offset: const Offset(0, 10))]), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, crossAxisAlignment: CrossAxisAlignment.start, children: [Container(padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: badgeColor.withOpacity(0.15), borderRadius: BorderRadius.circular(14)), child: Icon(icon, color: badgeColor, size: 28 * theme.fontScale)), Column(crossAxisAlignment: CrossAxisAlignment.end, children: [Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5), decoration: BoxDecoration(color: badgeColor.withOpacity(0.15), borderRadius: BorderRadius.circular(8)), child: Text(isOwner ? "Dự án Đã Tạo" : "Dự án Tham Gia", style: TextStyle(color: badgeColor, fontSize: 10 * theme.fontScale, fontWeight: FontWeight.bold))), const SizedBox(height: 6), Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5), decoration: BoxDecoration(color: isPending ? theme.subTextColor.withOpacity(0.2) : (status == "Hoạt động" ? theme.successColor.withOpacity(0.15) : theme.warningColor.withOpacity(0.15)), borderRadius: BorderRadius.circular(8)), child: Text(status, style: TextStyle(color: isPending ? theme.subTextColor : (status == "Hoạt động" ? theme.successColor : theme.warningColor), fontSize: 10 * theme.fontScale, fontWeight: FontWeight.bold)))])]), const SizedBox(height: 25), Text(name, style: TextStyle(color: theme.textColor, fontSize: 18 * theme.fontScale, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis), const SizedBox(height: 8), Text("Vai trò: $role", style: TextStyle(color: theme.subTextColor, fontSize: 13 * theme.fontScale)), const SizedBox(height: 25), SizedBox(width: double.infinity, child: ElevatedButton(onPressed: isPending ? null : () { globals.currentProjectId = projectId; Navigator.push(context, MaterialPageRoute(builder: (context) => ProjectWorkspaceScreen(userRole: role))).then((_) => _fetchProjects()); }, style: ElevatedButton.styleFrom(backgroundColor: isPending ? theme.textColor.withOpacity(0.05) : badgeColor.withOpacity(0.15), foregroundColor: theme.textColor, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), padding: const EdgeInsets.symmetric(vertical: 16)), child: Text(isPending ? "ĐANG CHỜ DUYỆT..." : "TRUY CẬP DỰ ÁN", style: TextStyle(color: isPending ? theme.subTextColor : theme.textColor, fontSize: 12 * theme.fontScale, fontWeight: FontWeight.bold))))]));
  }

  void _showJoinProjectDialog(AppTheme theme) {
    String projectCode = "";

    showDialog(
        context: context,
        builder: (context) {
          return Dialog(
              backgroundColor: theme.cardColor,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24), side: BorderSide(color: theme.borderColor)),
              child: Container(
                  width: 450, padding: const EdgeInsets.all(30),
                  child: Column(
                      mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text("Tham Gia Dự Án", style: TextStyle(color: theme.textColor, fontSize: 18 * theme.fontScale, fontWeight: FontWeight.bold)),
                            IconButton(onPressed: () => Navigator.pop(context), icon: Icon(Icons.close_rounded, color: theme.subTextColor))
                          ],
                        ),
                        const SizedBox(height: 15),
                        Text("Vui lòng nhập Mã Định Danh (Project Code) do Admin cung cấp để yêu cầu tham gia vào hệ thống.", style: TextStyle(color: theme.subTextColor, fontSize: 13 * theme.fontScale, height: 1.5)),
                        const SizedBox(height: 25),

                        TextField(
                          style: TextStyle(color: theme.primaryColor, fontWeight: FontWeight.w900, letterSpacing: 2.0, fontSize: 16),
                          textAlign: TextAlign.center,
                          onChanged: (v) => projectCode = v,
                          decoration: InputDecoration(
                              hintText: "SAMS-XXXXX",
                              hintStyle: TextStyle(color: theme.subTextColor.withOpacity(0.5), letterSpacing: 0),
                              filled: true, fillColor: theme.textColor.withOpacity(0.04),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: theme.primaryColor, width: 1.5))
                          ),
                        ),
                        const SizedBox(height: 30),

                        SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                                onPressed: () async {
                                  if (projectCode.trim().isEmpty) return;
                                  showDialog(context: context, barrierDismissible: false, builder: (c) => Center(child: CircularProgressIndicator(color: theme.primaryColor)));

                                  try {
                                    Map<String, dynamic> payload = { "project_code": projectCode.trim(), "user_id": globals.currentUserId };
                                    var response = await http.post(Uri.parse('http://127.0.0.1:8000/api/projects/join'), headers: {"Content-Type": "application/json"}, body: jsonEncode(payload));
                                    if (context.mounted) Navigator.pop(context);

                                    if (response.statusCode == 200) {
                                      var data = jsonDecode(response.body);
                                      if (data['status'] == 'success') {
                                        if (context.mounted) Navigator.pop(context);
                                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(data['message']), backgroundColor: Colors.green));
                                      } else { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(data['message']), backgroundColor: Colors.redAccent)); }
                                    }
                                  } catch (e) {
                                    if (context.mounted) Navigator.pop(context);
                                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Lỗi kết nối máy chủ!"), backgroundColor: Colors.redAccent));
                                  }
                                },
                                icon: const Icon(Icons.login_rounded, color: Colors.white),
                                label: const Text("XÁC NHẬN THAM GIA", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 1.0)),
                                style: ElevatedButton.styleFrom(backgroundColor: theme.primaryColor, padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)))
                            )
                        )
                      ]
                  )
              )
          );
        }
    );
  }
}