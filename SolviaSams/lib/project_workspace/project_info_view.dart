import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:excel/excel.dart' as ex; // FIX LỖI: Đặt biệt danh 'ex' để không bị trùng lặp chữ 'Border'
import '../theme_manager.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../globals.dart' as globals;

class TempSubject { String name = ''; String timeFrame = ''; }
class TempDay { String dayName = 'Thứ 2'; List<TempSubject> subjects = [TempSubject()]; }
class TempClass { String className = ''; String? uploadedExcelFile; List<TempDay> days = [TempDay()]; }

class ProjectInfoView extends StatefulWidget {
  final bool isSuperAdmin;
  const ProjectInfoView({super.key, this.isSuperAdmin = true});

  @override
  State<ProjectInfoView> createState() => _ProjectInfoViewState();
}

class _ProjectInfoViewState extends State<ProjectInfoView> {
  bool _isLoading = true;

  String _projectName = "Đang tải...";
  String _schoolName = "Đang tải...";
  String _academicYear = "...";
  String _sessionType = "...";
  String _attendanceMode = "...";
  String _globalRule = "...";
  String _projectCode = "...";

  // === BIẾN DỮ LIỆU THỐNG KÊ ===
  int _totalStudents = 0;
  int _totalStaff = 0;
  String _lateRate = "0.0%";
  String _absentRate = "0.0%";
  List<dynamic> _chartData = [];
  // Phục hồi 2 biến này để Flutter không bị hoảng loạn gạch đỏ
  String _dailyMode = "";
  String _subjectRule = "";
  String _morningTime = "...";
  String _afternoonTime = "...";

  // === 2. GỌI API LẤY CHI TIẾT DỰ ÁN KHI VỪA MỞ TRANG ===
  @override
  void initState() {
    super.initState();
    _fetchProjectDetail();
  }

  Future<void> _fetchProjectDetail() async {
    try {
      // Lấy ID dự án bạn vừa bấm từ biến toàn cục
      var response = await http.get(Uri.parse('http://127.0.0.1:8000/api/projects/${globals.currentProjectId}'));
      if (response.statusCode == 200) {
        var data = jsonDecode(utf8.decode(response.bodyBytes));
        if (data['status'] == 'success') {
          setState(() {
            _projectName = data['data']['project_name'] ?? "";
            _schoolName = data['data']['school_name'] ?? "";
            _academicYear = data['data']['academic_year'] ?? "";
            _sessionType = data['data']['session_type'] ?? "";
            _attendanceMode = data['data']['attendance_mode'] ?? "";
            _globalRule = data['data']['global_rule'] ?? "";
            _projectCode = data['data']['project_code'] ?? "SAMS-...";
            _morningTime = data['data']['morning_time'] ?? "";
            _afternoonTime = data['data']['afternoon_time'] ?? "";
            _totalStudents = data['data']['total_students'] ?? 0;
            _totalStaff = data['data']['total_staff'] ?? 0;
            _lateRate = data['data']['late_rate'] ?? "0.0%";
            _absentRate = data['data']['absent_rate'] ?? "0.0%";
            _chartData = data['data']['chart_data'] ?? [];
            _isLoading = false; // Tắt trạng thái loading
          });
        }
      }
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  // === 3. RENDER GIAO DIỆN CHÍNH ===
  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
        animation: AppTheme.instance,
        builder: (context, child) {
          final theme = AppTheme.instance;

          // ĐÃ FIX: Logic xử lý chữ hiển thị an toàn với dữ liệu từ Database
          String displayAttendanceMode = _attendanceMode == 'Quy định chung'
              ? "Quy định chung ($_globalRule)"
              : "$_attendanceMode ($_globalRule)";
          // ĐÃ FIX: Logic xử lý chữ hiển thị an toàn
          // ---> BỔ SUNG LOGIC GỘP CHỮ GIỜ HỌC:
          String displayTime = "";
          if (_sessionType == 'Sáng') displayTime = "Sáng: $_morningTime";
          else if (_sessionType == 'Chiều') displayTime = "Chiều: $_afternoonTime";
          else displayTime = "Sáng: $_morningTime\nChiều: $_afternoonTime";

          return LayoutBuilder(
              builder: (context, constraints) {
                double width = constraints.maxWidth;
                bool isSmallScreen = width < 1100;
                bool isMobile = width < 650;

                // NẾU ĐANG TẢI DỮ LIỆU THÌ HIỆN VÒNG QUAY LOADING
                if (_isLoading) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 100),
                      child: CircularProgressIndicator(color: theme.primaryColor),
                    ),
                  );
                }

                return SingleChildScrollView(
                  key: const ValueKey('ProjectInfo'),
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.all(40.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        alignment: WrapAlignment.spaceBetween, crossAxisAlignment: WrapCrossAlignment.end, runSpacing: 20,
                        children: [
                          SizedBox(
                            width: isSmallScreen ? double.infinity : 450,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                AnimatedDefaultTextStyle(duration: const Duration(milliseconds: 300), style: TextStyle(fontSize: 28 * theme.fontScale, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 1.0, fontFamily: 'Segoe UI'), child: const Text("Tổng Quan Dự Án")), const SizedBox(height: 8),
                                AnimatedDefaultTextStyle(duration: const Duration(milliseconds: 300), style: TextStyle(fontSize: 14 * theme.fontScale, color: Colors.grey[400], fontFamily: 'Segoe UI'), child: const Text("Báo cáo chỉ số, thông tin hệ thống và quản lý cấu trúc lớp học.")),
                              ],
                            ),
                          ),
                          if (widget.isSuperAdmin)
                            Wrap(
                              spacing: 15, runSpacing: 15,
                              children: [
                                OutlinedButton.icon(
                                  onPressed: () => _showEditProjectDialog(theme),
                                  icon: Icon(Icons.settings_suggest_rounded, color: theme.primaryColor, size: 18 * theme.fontScale), label: Text("Cấu hình Dự án", style: TextStyle(color: theme.primaryColor, fontWeight: FontWeight.bold, fontSize: 13 * theme.fontScale)),
                                  style: OutlinedButton.styleFrom(side: BorderSide(color: theme.primaryColor.withOpacity(0.5)), padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                                ),
                                ElevatedButton.icon(
                                  onPressed: () => _showCreateClassDialog(context, theme),
                                  icon: Icon(Icons.add_business_rounded, color: Colors.white, size: 18 * theme.fontScale), label: Text("TẠO LỚP MỚI", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13 * theme.fontScale, letterSpacing: 1.0)),
                                  style: ElevatedButton.styleFrom(backgroundColor: Colors.green, padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                                ),
                              ],
                            )
                        ],
                      ),
                      const SizedBox(height: 40),
                      _buildStatCardsResponsive(width, theme),
                      const SizedBox(height: 40),

                      Flex(
                        direction: isSmallScreen ? Axis.vertical : Axis.horizontal,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Flexible(
                            flex: isSmallScreen ? 0 : 6,
                            child: Container(
                              width: double.infinity, padding: const EdgeInsets.all(30), decoration: BoxDecoration(color: Colors.white.withOpacity(0.015), borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.white.withOpacity(0.05))),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildSectionHeader(Icons.article_rounded, "HỒ SƠ & CẤU HÌNH HỆ THỐNG", theme), const SizedBox(height: 25),
                                  if (isMobile) ...[
                                    _buildInfoBox("Tên dự án", _projectName, Icons.corporate_fare_rounded, theme), const SizedBox(height: 15),
                                    _buildInfoBox("Tên cơ sở", _schoolName, Icons.domain_rounded, theme), const SizedBox(height: 15),
                                    _buildInfoBox("Năm học", _academicYear, Icons.calendar_month_rounded, theme), const SizedBox(height: 15),
                                    _buildInfoBox("Ca học", _sessionType, Icons.wb_sunny_rounded, theme), const SizedBox(height: 15),
                                    _buildInfoBox("Khung giờ hoạt động", displayTime, Icons.access_time_rounded, theme), const SizedBox(height: 15),
                                    _buildInfoBox("Điểm danh", displayAttendanceMode, Icons.rule_rounded, theme), const SizedBox(height: 15),
                                    _buildInfoBox("Trạng thái", "Đang Online", Icons.sensors_rounded, theme, isHighlight: true),
                                  ] else ...[
                                    Row(children: [Expanded(child: _buildInfoBox("Tên dự án", _projectName, Icons.corporate_fare_rounded, theme)), const SizedBox(width: 15), Expanded(child: _buildInfoBox("Tên cơ sở / Trường", _schoolName, Icons.domain_rounded, theme))]), const SizedBox(height: 15),
                                    Row(children: [Expanded(child: _buildInfoBox("Năm học vận hành", _academicYear, Icons.calendar_month_rounded, theme)), const SizedBox(width: 15), Expanded(child: _buildInfoBox("Ca học áp dụng", _sessionType, Icons.wb_sunny_rounded, theme))]), const SizedBox(height: 15),
                                    Row(children: [Expanded(child: _buildInfoBox("Khung giờ hoạt động", displayTime, Icons.access_time_rounded, theme)), const SizedBox(width: 15), Expanded(child: _buildInfoBox("Cơ chế điểm danh", displayAttendanceMode, Icons.rule_rounded, theme))]), const SizedBox(height: 15),
                                    Row(children: [Expanded(child: _buildInfoBox("Cơ chế điểm danh", displayAttendanceMode, Icons.rule_rounded, theme)), const SizedBox(width: 15), Expanded(child: _buildInfoBox("Trạng thái", "Đang Online", Icons.sensors_rounded, theme, isHighlight: true))]), const SizedBox(height: 15),
                                    Row(children: [Expanded(child: _buildInfoBox("Người khởi tạo", "Super Admin", Icons.shield_rounded, theme)), const SizedBox(width: 15), Expanded(child: _buildInfoBox("Ngày tạo dự án", "27/02/2026", Icons.date_range_rounded, theme))]),
                                  ]
                                ],
                              ),
                            ),
                          ),
                          if (!isSmallScreen) const SizedBox(width: 30),
                          if (isSmallScreen) const SizedBox(height: 30),

                          Flexible(
                            flex: isSmallScreen ? 0 : 4,
                            child: SizedBox(
                              width: double.infinity,
                              child: Column(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(30), decoration: BoxDecoration(color: Colors.white.withOpacity(0.015), borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.white.withOpacity(0.05))),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Wrap(alignment: WrapAlignment.spaceBetween, crossAxisAlignment: WrapCrossAlignment.center, runSpacing: 10, children: [_buildSectionHeader(Icons.bar_chart_rounded, "LƯU LƯỢNG TUẦN", theme), Wrap(crossAxisAlignment: WrapCrossAlignment.center, children: [Icon(Icons.circle, color: theme.primaryColor, size: 10 * theme.fontScale), const SizedBox(width: 5), Text("Đúng giờ", style: TextStyle(color: Colors.white54, fontSize: 11 * theme.fontScale)), const SizedBox(width: 15), Icon(Icons.circle, color: Colors.orangeAccent, size: 10 * theme.fontScale), const SizedBox(width: 5), Text("Vi phạm", style: TextStyle(color: Colors.white54, fontSize: 11 * theme.fontScale))])]),
                                        const SizedBox(height: 30), _buildBarChart(theme),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 30),
                                  Container(
                                    padding: const EdgeInsets.all(30), decoration: BoxDecoration(gradient: LinearGradient(colors: [theme.primaryColor.withOpacity(0.2), Colors.transparent], begin: Alignment.topLeft, end: Alignment.bottomRight), borderRadius: BorderRadius.circular(20), border: Border.all(color: theme.primaryColor.withOpacity(0.5), width: 1.5), boxShadow: [BoxShadow(color: theme.primaryColor.withOpacity(0.1), blurRadius: 20, offset: const Offset(0, 10))]),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(children: [Icon(Icons.qr_code_2_rounded, color: theme.primaryColor, size: 24 * theme.fontScale), const SizedBox(width: 10), Expanded(child: AnimatedDefaultTextStyle(duration: const Duration(milliseconds: 300), style: TextStyle(color: Colors.white, fontSize: 16 * theme.fontScale, fontWeight: FontWeight.bold, letterSpacing: 1.2, fontFamily: 'Segoe UI'), child: const Text("MÃ ĐỊNH DANH", overflow: TextOverflow.ellipsis)))]), const SizedBox(height: 15),
                                        Container(width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 15), decoration: BoxDecoration(color: Colors.black.withOpacity(0.3), borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.white.withOpacity(0.1))), child: Center(child: Center(child: Text(_projectCode, style: TextStyle(color: theme.primaryColor, fontSize: 18 * theme.fontScale, fontWeight: FontWeight.w900, letterSpacing: 2.0), textAlign: TextAlign.center)))), const SizedBox(height: 15),
                                        SizedBox(width: double.infinity, child: ElevatedButton.icon(onPressed: () => _showQRCodeDialog(context, theme), icon: Icon(Icons.share_rounded, color: Colors.white, size: 16 * theme.fontScale), label: Text("TẠO MÃ CHIA SẺ", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 1.0, fontSize: 13 * theme.fontScale), overflow: TextOverflow.ellipsis), style: ElevatedButton.styleFrom(backgroundColor: theme.primaryColor, padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)))))
                                      ],
                                    ),
                                  )
                                ],
                              ),
                            ),
                          )
                        ],
                      )
                    ],
                  ),
                );
              }
          );
        }
    );
  }

  // --- WIDGET CHIA CỘT THỐNG KÊ ---
  Widget _buildStatCardsResponsive(double width, AppTheme theme) {
    Widget card1 = _buildStatCard("TỔNG HỌC SINH", "$_totalStudents", Icons.school_rounded, Colors.blueAccent, theme);
    Widget card2 = _buildStatCard("TỔNG NHÂN SỰ", "$_totalStaff", Icons.manage_accounts_rounded, Colors.purpleAccent, theme);
    Widget card3 = _buildStatCard("TỈ LỆ ĐI TRỄ", _lateRate, Icons.trending_up_rounded, Colors.orangeAccent, theme);
    Widget card4 = _buildStatCard("TỈ LỆ NGHỈ HỌC", _absentRate, Icons.trending_down_rounded, Colors.redAccent, theme);

    if (width >= 1300) { return Row(children: [Expanded(child: card1), const SizedBox(width: 20), Expanded(child: card2), const SizedBox(width: 20), Expanded(child: card3), const SizedBox(width: 20), Expanded(child: card4)]); }
    else if (width >= 750) { return Column(children: [Row(children: [Expanded(child: card1), const SizedBox(width: 20), Expanded(child: card2)]), const SizedBox(height: 20), Row(children: [Expanded(child: card3), const SizedBox(width: 20), Expanded(child: card4)])]); }
    else { return Column(children: [card1, const SizedBox(height: 20), card2, const SizedBox(height: 20), card3, const SizedBox(height: 20), card4]); }
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color, AppTheme theme) { return Container(padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 20), decoration: BoxDecoration(color: Colors.white.withOpacity(0.02), borderRadius: BorderRadius.circular(20), border: Border.all(color: color.withOpacity(0.3), width: 1.5), boxShadow: [BoxShadow(color: color.withOpacity(0.05), blurRadius: 15, offset: const Offset(0, 5))]), child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(14)), child: Icon(icon, color: color, size: 24 * theme.fontScale)), const SizedBox(width: 15), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [Text(title, style: TextStyle(color: Colors.white54, fontSize: 11 * theme.fontScale, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis), const SizedBox(height: 5), Text(value, style: TextStyle(color: Colors.white, fontSize: 20 * theme.fontScale, fontWeight: FontWeight.w900), maxLines: 1, overflow: TextOverflow.ellipsis)]))])); }
  Widget _buildInfoBox(String label, String value, IconData icon, AppTheme theme, {bool isHighlight = false}) { Color valColor = isHighlight ? Colors.greenAccent : Colors.white; return Container(padding: const EdgeInsets.all(15), decoration: BoxDecoration(color: Colors.white.withOpacity(0.02), borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white.withOpacity(0.04))), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Icon(icon, color: theme.primaryColor.withOpacity(0.8), size: 18 * theme.fontScale), const SizedBox(width: 12), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [Text(label.toUpperCase(), style: TextStyle(color: Colors.white54, fontSize: 11 * theme.fontScale, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis), const SizedBox(height: 6), Text(value, style: TextStyle(color: valColor, fontSize: 13 * theme.fontScale, fontWeight: FontWeight.w600, height: 1.4), maxLines: 2, overflow: TextOverflow.ellipsis)]))])); }
  Widget _buildSectionHeader(IconData icon, String title, AppTheme theme) => Wrap(crossAxisAlignment: WrapCrossAlignment.center, children: [AnimatedContainer(duration: const Duration(milliseconds: 300), child: Icon(icon, color: theme.primaryColor, size: 18 * theme.fontScale)), const SizedBox(width: 10), AnimatedDefaultTextStyle(duration: const Duration(milliseconds: 300), style: TextStyle(color: Colors.white, fontSize: 14 * theme.fontScale, fontWeight: FontWeight.bold, letterSpacing: 1.2, fontFamily: 'Segoe UI'), child: Text(title, overflow: TextOverflow.ellipsis))]);
  Widget _buildBarChart(AppTheme theme) {
    List<dynamic> chartData = _chartData.isNotEmpty ? _chartData : [{'day': 'T2', 'ok': 0.0, 'late': 0.0}, {'day': 'T3', 'ok': 0.0, 'late': 0.0}, {'day': 'T4', 'ok': 0.0, 'late': 0.0}, {'day': 'T5', 'ok': 0.0, 'late': 0.0}, {'day': 'T6', 'ok': 0.0, 'late': 0.0}, {'day': 'T7', 'ok': 0.0, 'late': 0.0}];

    return SizedBox(height: 200, child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, crossAxisAlignment: CrossAxisAlignment.end, children: chartData.map((data) {
      // Ép cột cao tối thiểu 2px để UI không bị văng khi thông số bằng 0
      double okHeight = (data['ok'] as num).toDouble();
      double lateHeight = (data['late'] as num).toDouble();
      if(okHeight == 0) okHeight = 2.0;
      if(lateHeight == 0) lateHeight = 2.0;

      return Column(mainAxisSize: MainAxisSize.min, mainAxisAlignment: MainAxisAlignment.end, children: [Row(crossAxisAlignment: CrossAxisAlignment.end, children: [Container(width: 12 * theme.fontScale, height: okHeight, decoration: BoxDecoration(color: theme.primaryColor, borderRadius: const BorderRadius.vertical(top: Radius.circular(6)))), const SizedBox(width: 4), Container(width: 12 * theme.fontScale, height: lateHeight, decoration: BoxDecoration(color: Colors.orangeAccent, borderRadius: const BorderRadius.vertical(top: Radius.circular(6))))]), const SizedBox(height: 10), Text(data['day'].toString(), style: TextStyle(color: Colors.white54, fontSize: 12 * theme.fontScale, fontWeight: FontWeight.bold))]);
    }).toList()));
  }

  // --- BẬT BẢNG CẤU HÌNH DỰ ÁN (FULL CHỨC NĂNG) ---
  void _showEditProjectDialog(AppTheme theme) {
    // 1. Gán dữ liệu hiện tại vào các biến tạm để chỉnh sửa
    String tempName = _projectName;
    String tempSchool = _schoolName;
    String tempYear = _academicYear;
    String tempSession = _sessionType;
    String tempMode = _attendanceMode;
    String tempRule = _globalRule;
    String tempMorning = _morningTime;
    String tempAfternoon = _afternoonTime;
    // ==========================================================
    // BỘ LỌC AN TOÀN: Ép dữ liệu từ DB phải khớp với Dropdown
    // ==========================================================
    if (!['Sáng', 'Chiều', 'Sáng & Chiều'].contains(tempSession)) {
      tempSession = 'Sáng & Chiều';
    }
    if (!['Quy định chung', 'Theo từng ngày', 'Ghi lại tự do'].contains(tempMode)) {
      tempMode = 'Quy định chung';
    }

    // Ép biến Chi tiết quy định (tempRule) khớp với Cơ chế (tempMode)
    if (tempMode == 'Quy định chung' && !['Giờ đầu', 'Giờ cuối', 'Đầu và cuối'].contains(tempRule)) {
      tempRule = 'Giờ đầu';
    } else if (tempMode == 'Theo từng ngày' && !['Từng môn', 'Tiết đầu tiên'].contains(tempRule)) {
      tempRule = 'Từng môn';
    } else if (tempMode == 'Ghi lại tự do') {
      tempRule = 'Không xét đúng/trễ';
    }
    showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) {
          // StatefulBuilder giúp bảng Dialog có thể tự đổi UI khi chọn Dropdown
          return StatefulBuilder(
              builder: (context, setStateDialog) {
                return Dialog(
                  backgroundColor: const Color(0xFF101520),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: theme.primaryColor.withOpacity(0.5))),
                  child: Container(
                    width: 600, padding: const EdgeInsets.all(30),
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      child: Column(
                        mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text("Cấu hình chi tiết Dự án", style: TextStyle(color: Colors.white, fontSize: 18 * theme.fontScale, fontWeight: FontWeight.bold)),
                                IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close_rounded, color: Colors.white54))
                              ]
                          ),
                          const SizedBox(height: 25),

                          // CÁC TRƯỜNG NHẬP LIỆU CƠ BẢN
                          Row(children: [Expanded(child: _buildDialogTextField("Tên dự án", tempName, (v) => tempName = v, theme)), const SizedBox(width: 15), Expanded(child: _buildDialogTextField("Tên cơ sở / Trường", tempSchool, (v) => tempSchool = v, theme))]),
                          const SizedBox(height: 15),
                          Row(children: [Expanded(child: _buildDialogTextField("Năm học vận hành", tempYear, (v) => tempYear = v, theme)), const SizedBox(width: 15), Expanded(child: _buildDialogDropdown("Ca học áp dụng", tempSession, ['Sáng', 'Chiều', 'Sáng & Chiều'], (v) => setStateDialog(() => tempSession = v!), theme))]),
                          const SizedBox(height: 15),
                          AnimatedSize(
                            duration: const Duration(milliseconds: 300),
                            child: Row(
                              children: [
                                if (tempSession == 'Sáng' || tempSession == 'Sáng & Chiều')
                                  Expanded(child: _buildDialogTextField("Giờ Sáng", tempMorning, (v) => tempMorning = v, theme)),
                                if (tempSession == 'Sáng & Chiều') const SizedBox(width: 15),
                                if (tempSession == 'Chiều' || tempSession == 'Sáng & Chiều')
                                  Expanded(child: _buildDialogTextField("Giờ Chiều", tempAfternoon, (v) => tempAfternoon = v, theme)),
                              ],
                            ),
                          ),
                          const SizedBox(height: 15),

                          Divider(color: Colors.white.withOpacity(0.05)),
                          const SizedBox(height: 15),

                          // DROPDOWN LIÊN KẾT LOGIC CHO ĐIỂM DANH
                          _buildDialogDropdown("Cơ chế điểm danh chung", tempMode, ['Quy định chung', 'Theo từng ngày', 'Ghi lại tự do'], (v) {
                            setStateDialog(() {
                              tempMode = v!;
                              // Chốt chặn an toàn: Tự đổi Quy định khi Cơ chế bị đổi để tránh lỗi Crash Dropdown
                              if (tempMode == 'Quy định chung' && !['Giờ đầu', 'Giờ cuối', 'Đầu và cuối'].contains(tempRule)) tempRule = 'Giờ đầu';
                              if (tempMode == 'Theo từng ngày' && !['Từng môn', 'Tiết đầu tiên'].contains(tempRule)) tempRule = 'Từng môn';
                              if (tempMode == 'Ghi lại tự do') tempRule = 'Không xét đúng/trễ';
                            });
                          }, theme),
                          const SizedBox(height: 15),

                          if (tempMode == 'Quy định chung')
                            _buildDialogDropdown("Chi tiết quy định", tempRule, ['Giờ đầu', 'Giờ cuối', 'Đầu và cuối'], (v) => setStateDialog(() => tempRule = v!), theme)
                          else if (tempMode == 'Theo từng ngày')
                            _buildDialogDropdown("Chi tiết quy định", tempRule, ['Từng môn', 'Tiết đầu tiên'], (v) => setStateDialog(() => tempRule = v!), theme)
                          else if (tempMode == 'Ghi lại tự do')
                              _buildDialogTextField("Chi tiết quy định", tempRule, (v) {}, theme), // Ô nhập chữ mờ không cho sửa

                          const SizedBox(height: 35),

                          // NÚT HÀNH ĐỘNG
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              TextButton(onPressed: () => Navigator.pop(context), child: const Text("Hủy bỏ", style: TextStyle(color: Colors.white54))),
                              const SizedBox(width: 15),
                              ElevatedButton.icon(
                                  onPressed: () async {
                                    // Bật loading mờ nếu cần
                                    Map<String, dynamic> payload = {
                                      "project_name": tempName,
                                      "school_name": tempSchool,
                                      "academic_year": tempYear,
                                      "session_type": tempSession,
                                      "attendance_mode": tempMode,
                                      "global_rule": tempRule,
                                      "morning_time": tempMorning,
                                      "afternoon_time": tempAfternoon
                                    };

                                    try {
                                      var response = await http.put(
                                          Uri.parse('http://127.0.0.1:8000/api/projects/${globals.currentProjectId}'),
                                          headers: {"Content-Type": "application/json"},
                                          body: jsonEncode(payload)
                                      );

                                      if (response.statusCode == 200) {
                                        var data = jsonDecode(response.body);
                                        if(data['status'] == 'success') {
                                          // 1. Đóng Popup
                                          if (context.mounted) Navigator.pop(context);
                                          // 2. Ép Màn hình chính vẽ lại với dữ liệu mới
                                          setState(() {
                                            _projectName = tempName;
                                            _schoolName = tempSchool;
                                            _academicYear = tempYear;
                                            _sessionType = tempSession;
                                            _attendanceMode = tempMode;
                                            _globalRule = tempRule;
                                            _morningTime = tempMorning;
                                            _afternoonTime = tempAfternoon;
                                          });
                                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Lưu cấu hình an toàn vào hệ thống!"), backgroundColor: Colors.green));
                                        }
                                      }
                                    } catch (e) {
                                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Lỗi kết nối Server!"), backgroundColor: Colors.redAccent));
                                    }
                                  },
                                  icon: const Icon(Icons.save_rounded, color: Colors.white, size: 18),
                                  label: const Text("LƯU THAY ĐỔI", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                  style: ElevatedButton.styleFrom(backgroundColor: theme.primaryColor, padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15))
                              )
                            ],
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
  // DIALOG TẠO LỚP & LOGIC ĐỌC FILE EXCEL THẬT
  // ==========================================================
  void _showCreateClassDialog(BuildContext context, AppTheme theme) {
    TempClass newClass = TempClass();

    showDialog(context: context, barrierDismissible: false, builder: (context) {
      return StatefulBuilder(builder: (context, setStateDialog) {
        return Dialog(backgroundColor: const Color(0xFF101520), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24), side: BorderSide(color: Colors.green.withOpacity(0.5), width: 2)),
            child: Container(width: 850, constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85), child: Column(mainAxisSize: MainAxisSize.min, children: [
              Container(padding: const EdgeInsets.all(25), decoration: BoxDecoration(color: Colors.green.withOpacity(0.1)), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Row(children: [Icon(Icons.add_business_rounded, color: Colors.greenAccent, size: 28 * theme.fontScale), const SizedBox(width: 15), Text("Khởi Tạo Lớp Mới", style: TextStyle(color: Colors.greenAccent, fontSize: 22 * theme.fontScale, fontWeight: FontWeight.bold))]), IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close_rounded, color: Colors.white))])),
              Flexible(child: SingleChildScrollView(padding: const EdgeInsets.all(40), child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Expanded(flex: 3, child: _buildDialogTextFieldWithIcon("Tên Lớp (VD: 10A1)", Icons.meeting_room_rounded, "Nhập tên lớp", (v) => newClass.className = v, theme)),
                  const SizedBox(width: 20),
                  Expanded(
                      flex: 2,
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                        Text("Danh sách học sinh", style: TextStyle(color: Colors.white70, fontSize: 12 * theme.fontScale, fontWeight: FontWeight.bold)), const SizedBox(height: 8),
                        SizedBox(
                            height: 45, width: double.infinity,
                            // ===============================================
                            // XỬ LÝ MỞ THƯ MỤC VÀ ĐỌC FILE EXCEL BẰNG CODE THUẦN
                            // ===============================================
                            child: ElevatedButton.icon(
                                onPressed: () async {
                                  try {
                                    // 1. Mở Cửa sổ File Explorer
                                    FilePickerResult? result = await FilePicker.platform.pickFiles(
                                      type: FileType.custom,
                                      allowedExtensions: ['xlsx'],
                                      withData: true,
                                    );

                                    if (result != null && result.files.single.bytes != null && context.mounted) {
                                      String realFileName = result.files.single.name;
                                      var fileBytes = result.files.single.bytes!;

                                      showDialog(
                                          context: context, barrierDismissible: false,
                                          builder: (loadingContext) => AlertDialog(
                                            backgroundColor: const Color(0xFF101520),
                                            content: Row(children: [const CircularProgressIndicator(color: Colors.greenAccent), const SizedBox(width: 20), Expanded(child: Text("Đang đọc file '$realFileName'...", style: TextStyle(color: Colors.white, fontSize: 14 * theme.fontScale)))]),
                                          )
                                      );

                                      // SỬ DỤNG BIỆT DANH 'ex' ĐỂ TRÁNH LỖI BORDER
                                      List<Map<String, String>> parsedData = [];
                                      var excel = ex.Excel.decodeBytes(fileBytes);

                                      var sheet = excel.tables[excel.tables.keys.first]!;

                                      for (int i = 1; i < sheet.rows.length; i++) {
                                        var row = sheet.rows[i];
                                        if (row.isEmpty || row[0]?.value == null) continue;

                                        String name = row.length > 1 ? row[1]?.value.toString() ?? "" : "Không tên";
                                        String dob = row.length > 2 ? row[2]?.value.toString() ?? "" : "";
                                        String hometown = row.length > 3 ? row[3]?.value.toString() ?? "" : "";
                                        String phone = row.length > 4 ? row[4]?.value.toString() ?? "" : "";

                                        String user = "hs.${name.split(' ').last.toLowerCase()}${i.toString().padLeft(2, '0')}";

                                        parsedData.add({
                                          "stt": i.toString(),
                                          "name": name,
                                          "dob": dob,
                                          "hometown": hometown,
                                          "phone": phone,
                                          "user": user,
                                          "pass": "Sams@123"
                                        });
                                      }

                                      if (context.mounted) Navigator.pop(context);

                                      if (parsedData.isNotEmpty) {
                                        setStateDialog(() => newClass.uploadedExcelFile = realFileName);
                                        _showExcelPreviewDialog(context, theme, setStateDialog, newClass, realFileName, parsedData);
                                      } else {
                                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("File Excel rỗng hoặc không đúng định dạng!"), backgroundColor: Colors.redAccent));
                                      }
                                    }
                                  } catch (e) {
                                    if (context.mounted) Navigator.pop(context);
                                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Lỗi đọc file: File Excel bị khóa hoặc hỏng."), backgroundColor: Colors.redAccent));
                                  }
                                },
                                icon: Icon(newClass.uploadedExcelFile != null ? Icons.check_circle_rounded : Icons.upload_file_rounded, color: newClass.uploadedExcelFile != null ? Colors.greenAccent : Colors.white, size: 16 * theme.fontScale),
                                label: Text(newClass.uploadedExcelFile ?? "Tải Excel (.xlsx)", style: TextStyle(color: newClass.uploadedExcelFile != null ? Colors.greenAccent : Colors.white, fontWeight: FontWeight.bold, fontSize: 12 * theme.fontScale), overflow: TextOverflow.ellipsis),
                                style: ElevatedButton.styleFrom(backgroundColor: newClass.uploadedExcelFile != null ? Colors.greenAccent.withOpacity(0.1) : Colors.white.withOpacity(0.1), alignment: Alignment.centerLeft, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)))
                            )
                        )
                      ])
                  )
                ]),
                const SizedBox(height: 40),

                Text("THIẾT KẾ THỜI KHÓA BIỂU", style: TextStyle(color: theme.primaryColor, fontSize: 14 * theme.fontScale, fontWeight: FontWeight.bold, letterSpacing: 1.0)), const SizedBox(height: 20), ...newClass.days.asMap().entries.map((dayEntry) { int dIndex = dayEntry.key; TempDay dModel = dayEntry.value; return Container(margin: const EdgeInsets.only(bottom: 20), padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: Colors.white.withOpacity(0.02), borderRadius: BorderRadius.circular(16), border: const Border(left: BorderSide(color: Colors.white30, width: 4))), child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [Row(children: [Expanded(flex: 2, child: _buildDialogDropdown("Thứ", dModel.dayName, ['Thứ 2', 'Thứ 3', 'Thứ 4', 'Thứ 5', 'Thứ 6', 'Thứ 7', 'Chủ Nhật'], (val) => setStateDialog(() => dModel.dayName = val!), theme)), const Spacer(flex: 5), if (newClass.days.length > 1) IconButton(onPressed: () => setStateDialog(() => newClass.days.removeAt(dIndex)), icon: Icon(Icons.close_rounded, color: Colors.redAccent.withOpacity(0.8), size: 20 * theme.fontScale))]), const SizedBox(height: 20), ...dModel.subjects.asMap().entries.map((subEntry) { int sIndex = subEntry.key; TempSubject sModel = subEntry.value; return Padding(padding: const EdgeInsets.only(bottom: 12, left: 20), child: Row(children: [Icon(Icons.subdirectory_arrow_right_rounded, color: Colors.white24, size: 20 * theme.fontScale), const SizedBox(width: 15), Expanded(flex: 3, child: _buildDialogTextFieldNoLabel("Tên môn", sModel.name, (v) => sModel.name = v, theme)), const SizedBox(width: 15), Expanded(flex: 2, child: _buildDialogTextFieldNoLabel("Giờ (07:00-08:30)", sModel.timeFrame, (v) => sModel.timeFrame = v, theme)), const SizedBox(width: 10), if (dModel.subjects.length > 1) IconButton(onPressed: () => setStateDialog(() => dModel.subjects.removeAt(sIndex)), icon: Icon(Icons.remove_circle_outline_rounded, color: Colors.redAccent.withOpacity(0.6), size: 20 * theme.fontScale))])); }), Padding(padding: const EdgeInsets.only(left: 50, top: 10), child: TextButton.icon(onPressed: () => setStateDialog(() => dModel.subjects.add(TempSubject())), icon: Icon(Icons.add_rounded, color: theme.primaryColor, size: 16 * theme.fontScale), label: Text("Thêm Môn học", style: TextStyle(color: theme.primaryColor, fontWeight: FontWeight.bold))))])); }), Align(alignment: Alignment.centerLeft, child: TextButton.icon(onPressed: () => setStateDialog(() => newClass.days.add(TempDay())), icon: Icon(Icons.add_circle_outline_rounded, color: Colors.white70, size: 18 * theme.fontScale), label: Text("Thêm Thứ học", style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold, fontSize: 13 * theme.fontScale))))])),), Container(padding: const EdgeInsets.all(25), decoration: BoxDecoration(color: Colors.white.withOpacity(0.02)), child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [TextButton(onPressed: () => Navigator.pop(context), child: Text("Hủy bỏ", style: TextStyle(color: Colors.white54, fontSize: 14 * theme.fontScale))), const SizedBox(width: 20), ElevatedButton.icon(onPressed: () { Navigator.pop(context); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Đã khởi tạo Lớp mới thành công!"), backgroundColor: Colors.green)); }, icon: const Icon(Icons.rocket_launch_rounded, color: Colors.white), label: const Text("HOÀN TẤT TẠO LỚP", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)), style: ElevatedButton.styleFrom(backgroundColor: Colors.green, padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16)))]))])));});});
  }

  // ==========================================================
  // BẢNG PREVIEW EXCEL (HIỂN THỊ DỮ LIỆU ĐÃ ĐỌC THẬT)
  // ==========================================================
  void _showExcelPreviewDialog(BuildContext parentContext, AppTheme theme, StateSetter parentSetState, TempClass newClass, String fileName, List<Map<String, String>> parsedData) {
    showDialog(
        context: parentContext, barrierDismissible: false,
        builder: (context) {
          return Dialog(
            backgroundColor: const Color(0xFF0A101E),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: Colors.greenAccent.withOpacity(0.5))),
            child: Container(
              width: 900, padding: const EdgeInsets.all(30),
              child: Column(
                mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.visibility_rounded, color: Colors.greenAccent, size: 24 * theme.fontScale), const SizedBox(width: 10),
                      Expanded(child: Text("Xem trước Dữ liệu từ file: $fileName", style: TextStyle(color: Colors.white, fontSize: 16 * theme.fontScale, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis)),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text("Hệ thống đã nhận diện được ${parsedData.length} dòng hợp lệ. Tài khoản và mật khẩu đã được tự động cấp. Vui lòng kiểm tra dữ liệu.", style: TextStyle(color: Colors.white70, fontSize: 13 * theme.fontScale)),
                  const SizedBox(height: 20),

                  // GIỚI HẠN HIỂN THỊ TỐI ĐA 100 DÒNG ĐỂ TRÁNH LAG NẾU FILE QUÁ LỚN
                  Container(
                    width: double.infinity, height: 350, decoration: BoxDecoration(color: Colors.white.withOpacity(0.02), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white.withOpacity(0.1))),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: SingleChildScrollView(
                          child: DataTable(
                            headingRowColor: WidgetStateProperty.all(Colors.greenAccent.withOpacity(0.1)),
                            columns: [
                              DataColumn(label: Text("STT", style: TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold, fontSize: 12 * theme.fontScale))),
                              DataColumn(label: Text("Họ và Tên", style: TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold, fontSize: 12 * theme.fontScale))),
                              DataColumn(label: Text("Ngày sinh", style: TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold, fontSize: 12 * theme.fontScale))),
                              DataColumn(label: Text("Quê quán", style: TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold, fontSize: 12 * theme.fontScale))),
                              DataColumn(label: Text("Số điện thoại", style: TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold, fontSize: 12 * theme.fontScale))),
                              DataColumn(label: Text("Tài khoản (Tự sinh)", style: TextStyle(color: Colors.orangeAccent, fontWeight: FontWeight.bold, fontSize: 12 * theme.fontScale))),
                              DataColumn(label: Text("Mật khẩu", style: TextStyle(color: Colors.orangeAccent, fontWeight: FontWeight.bold, fontSize: 12 * theme.fontScale))),
                            ],
                            rows: parsedData.take(100).map((e) => DataRow(cells: [
                              DataCell(Text(e['stt']!, style: TextStyle(color: Colors.white70, fontSize: 12 * theme.fontScale))),
                              DataCell(Text(e['name']!, style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13 * theme.fontScale))),
                              DataCell(Text(e['dob']!, style: TextStyle(color: Colors.white70, fontSize: 12 * theme.fontScale))),
                              DataCell(Text(e['hometown']!, style: TextStyle(color: Colors.white70, fontSize: 12 * theme.fontScale))),
                              DataCell(Text(e['phone']!, style: TextStyle(color: Colors.white70, fontSize: 12 * theme.fontScale))),
                              DataCell(Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: Colors.orangeAccent.withOpacity(0.1), borderRadius: BorderRadius.circular(6)), child: Text(e['user']!, style: TextStyle(color: Colors.orangeAccent, fontWeight: FontWeight.bold, fontSize: 12 * theme.fontScale)))),
                              DataCell(Text(e['pass']!, style: TextStyle(color: Colors.orangeAccent, fontSize: 12 * theme.fontScale))),
                            ])).toList(),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 30),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(onPressed: () { parentSetState(() => newClass.uploadedExcelFile = null); Navigator.pop(context); }, child: const Text("Hủy file này", style: TextStyle(color: Colors.redAccent))),
                      const SizedBox(width: 15),
                      ElevatedButton.icon(
                          onPressed: () { Navigator.pop(context); },
                          icon: const Icon(Icons.check_circle_rounded, color: Colors.white),
                          label: const Text("Xác nhận Nhập dữ liệu", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.green)
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

  void _showQRCodeDialog(BuildContext context, AppTheme theme) { /*... giữ nguyên ...*/ }
  Widget _buildOptionChip(String label, bool isSelected, VoidCallback onTap, AppTheme theme) => GestureDetector(onTap: onTap, child: AnimatedContainer(duration: const Duration(milliseconds: 300), padding: const EdgeInsets.symmetric(vertical: 12), decoration: BoxDecoration(color: isSelected ? theme.primaryColor.withOpacity(0.2) : Colors.white.withOpacity(0.03), borderRadius: BorderRadius.circular(10), border: Border.all(color: isSelected ? theme.primaryColor : Colors.transparent, width: 1.5)), child: Center(child: AnimatedDefaultTextStyle(duration: const Duration(milliseconds: 300), style: TextStyle(color: isSelected ? theme.primaryColor : Colors.white54, fontWeight: FontWeight.bold, fontSize: 11 * theme.fontScale, fontFamily: 'Segoe UI'), child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis)))));
  Widget _buildDialogTextField(String label, String value, Function(String) onChanged, AppTheme theme) { return Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [Text(label, style: TextStyle(color: Colors.white70, fontSize: 12 * theme.fontScale, fontWeight: FontWeight.bold)), const SizedBox(height: 8), TextFormField(initialValue: value, onChanged: onChanged, style: TextStyle(color: Colors.white, fontSize: 13 * theme.fontScale), decoration: InputDecoration(filled: true, fillColor: Colors.black.withOpacity(0.3), border: OutlineInputBorder(borderRadius: BorderRadius.circular(10))))]); }
  Widget _buildDialogTextFieldWithIcon(String label, IconData icon, String hint, Function(String) onChanged, AppTheme theme) { return Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [Text(label, style: TextStyle(color: Colors.white70, fontSize: 12 * theme.fontScale, fontWeight: FontWeight.bold)), const SizedBox(height: 8), SizedBox(height: 45, child: TextFormField(onChanged: onChanged, style: TextStyle(color: Colors.white, fontSize: 13 * theme.fontScale), decoration: InputDecoration(contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 15), prefixIcon: Icon(icon, color: theme.primaryColor, size: 18 * theme.fontScale), hintText: hint, hintStyle: const TextStyle(color: Colors.white24), filled: true, fillColor: Colors.black.withOpacity(0.3), enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.white.withOpacity(0.05))), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: theme.primaryColor)))))]); }
  Widget _buildDialogTextFieldNoLabel(String hint, String value, Function(String) onChanged, AppTheme theme) { return SizedBox(height: 45, child: TextFormField(initialValue: value, onChanged: onChanged, style: TextStyle(color: Colors.white, fontSize: 13 * theme.fontScale), decoration: InputDecoration(contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 15), hintText: hint, hintStyle: const TextStyle(color: Colors.white24), filled: true, fillColor: Colors.black.withOpacity(0.3), enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.white.withOpacity(0.05))), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: theme.primaryColor))))); }
  Widget _buildDialogDropdown(String label, String value, List<String> items, Function(String?) onChanged, AppTheme theme) { return Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [Text(label, style: TextStyle(color: Colors.white70, fontSize: 12 * theme.fontScale, fontWeight: FontWeight.bold)), const SizedBox(height: 8), SizedBox(height: 45, child: DropdownButtonFormField<String>(value: value, dropdownColor: const Color(0xFF0A101E), style: TextStyle(color: Colors.white, fontSize: 13 * theme.fontScale), decoration: InputDecoration(contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 15), filled: true, fillColor: Colors.black.withOpacity(0.3), enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.white.withOpacity(0.05))), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: theme.primaryColor))), items: items.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(), onChanged: onChanged))]); }
}