import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:excel/excel.dart' as ex;
import '../theme_manager.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../globals.dart' as globals;

class TempClass {
  String className = '';
  String? uploadedExcelFile;
  List<Map<String, String>> parsedStudents = [];
}

class ProjectInfoView extends StatefulWidget {
  final bool isSuperAdmin;
  final VoidCallback? onDataChanged;
  const ProjectInfoView({super.key, this.isSuperAdmin = true, this.onDataChanged}); // <--- THÊM VÀO ĐÂY

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
  String _morningTime = "";
  String _afternoonTime = "";

  int _totalStudents = 0;
  int _totalStaff = 0;
  String _lateRate = "0.0%";
  String _absentRate = "0.0%";
  List<dynamic> _chartData = [];

  @override
  void initState() {
    super.initState();
    _fetchProjectDetail();
  }

  Future<void> _fetchProjectDetail() async {
    try {
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
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
        animation: AppTheme.instance,
        builder: (context, child) {
          final theme = AppTheme.instance;

          String displayAttendanceMode = _attendanceMode == 'Quy định chung' ? "Quy định chung ($_globalRule)" : "$_attendanceMode ($_globalRule)";

          String displayTime = "";
          if (_sessionType == 'Sáng') displayTime = "Sáng: ${_morningTime.isNotEmpty ? _morningTime : 'Chưa cài đặt'}";
          else if (_sessionType == 'Chiều') displayTime = "Chiều: ${_afternoonTime.isNotEmpty ? _afternoonTime : 'Chưa cài đặt'}";
          else displayTime = "Sáng: ${_morningTime.isNotEmpty ? _morningTime : 'Chưa cài đặt'}\nChiều: ${_afternoonTime.isNotEmpty ? _afternoonTime : 'Chưa cài đặt'}";

          return LayoutBuilder(
              builder: (context, constraints) {
                double width = constraints.maxWidth;
                bool isSmallScreen = width < 1100;
                bool isMobile = width < 650;

                if (_isLoading) {
                  return Center(child: Padding(padding: const EdgeInsets.only(top: 100), child: CircularProgressIndicator(color: theme.primaryColor)));
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
                                AnimatedDefaultTextStyle(duration: const Duration(milliseconds: 300), style: TextStyle(fontSize: 28 * theme.fontScale, fontWeight: FontWeight.w900, color: theme.textColor, letterSpacing: 1.0, fontFamily: 'Segoe UI'), child: const Text("Tổng Quan Dự Án")), const SizedBox(height: 8),
                                AnimatedDefaultTextStyle(duration: const Duration(milliseconds: 300), style: TextStyle(fontSize: 14 * theme.fontScale, color: theme.subTextColor, fontFamily: 'Segoe UI'), child: const Text("Báo cáo chỉ số, thông tin hệ thống và quản lý cấu trúc lớp học.")),
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
                                  style: ElevatedButton.styleFrom(backgroundColor: theme.successColor, padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
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
                              width: double.infinity, padding: const EdgeInsets.all(30), decoration: BoxDecoration(color: theme.cardColor, borderRadius: BorderRadius.circular(20), border: Border.all(color: theme.borderColor)),
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
                                    Row(children: [Expanded(child: _buildInfoBox("Người khởi tạo", "Super Admin", Icons.shield_rounded, theme)), const SizedBox(width: 15), Expanded(child: _buildInfoBox("Trạng thái", "Đang Online", Icons.sensors_rounded, theme, isHighlight: true))]),
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
                                    padding: const EdgeInsets.all(30), decoration: BoxDecoration(color: theme.cardColor, borderRadius: BorderRadius.circular(20), border: Border.all(color: theme.borderColor)),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Wrap(alignment: WrapAlignment.spaceBetween, crossAxisAlignment: WrapCrossAlignment.center, runSpacing: 10, children: [_buildSectionHeader(Icons.bar_chart_rounded, "LƯU LƯỢNG TUẦN", theme), Wrap(crossAxisAlignment: WrapCrossAlignment.center, children: [Icon(Icons.circle, color: theme.primaryColor, size: 10 * theme.fontScale), const SizedBox(width: 5), Text("Đúng giờ", style: TextStyle(color: theme.subTextColor, fontSize: 11 * theme.fontScale)), const SizedBox(width: 15), Icon(Icons.circle, color: theme.warningColor, size: 10 * theme.fontScale), const SizedBox(width: 5), Text("Vi phạm", style: TextStyle(color: theme.subTextColor, fontSize: 11 * theme.fontScale))])]),
                                        const SizedBox(height: 30), _buildBarChart(theme),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 30),
                                  if (globals.currentUserRole != 'Học sinh' && globals.currentUserRole != 'Thành viên') ...[
                                    Container(
                                      padding: const EdgeInsets.all(30), decoration: BoxDecoration(color: theme.cardColor, borderRadius: BorderRadius.circular(20), border: Border.all(color: theme.primaryColor.withOpacity(0.5), width: 1.5), boxShadow: theme.isDarkMode ? [] : [BoxShadow(color: theme.primaryColor.withOpacity(0.1), blurRadius: 20, offset: const Offset(0, 10))]),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(children: [Icon(Icons.qr_code_2_rounded, color: theme.primaryColor, size: 24 * theme.fontScale), const SizedBox(width: 10), Expanded(child: AnimatedDefaultTextStyle(duration: const Duration(milliseconds: 300), style: TextStyle(color: theme.textColor, fontSize: 16 * theme.fontScale, fontWeight: FontWeight.bold, letterSpacing: 1.2, fontFamily: 'Segoe UI'), child: const Text("MÃ ĐỊNH DANH", overflow: TextOverflow.ellipsis)))]), const SizedBox(height: 15),

                                          GestureDetector(
                                            onTap: () {
                                              Clipboard.setData(ClipboardData(text: _projectCode));
                                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Đã copy Mã Dự Án vào khay nhớ tạm!"), backgroundColor: Colors.green));
                                            },
                                            child: Container(
                                                width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 15),
                                                decoration: BoxDecoration(color: theme.primaryColor.withOpacity(0.1), borderRadius: BorderRadius.circular(10), border: Border.all(color: theme.primaryColor.withOpacity(0.3))),
                                                child: Center(
                                                    child: Row(
                                                      mainAxisAlignment: MainAxisAlignment.center,
                                                      children: [
                                                        Text(_projectCode, style: TextStyle(color: theme.primaryColor, fontSize: 18 * theme.fontScale, fontWeight: FontWeight.w900, letterSpacing: 2.0), textAlign: TextAlign.center),
                                                        const SizedBox(width: 10),
                                                        Icon(Icons.copy_rounded, color: theme.primaryColor, size: 18)
                                                      ],
                                                    )
                                                )
                                            ),
                                          ),

                                          const SizedBox(height: 15),
                                          SizedBox(width: double.infinity, child: ElevatedButton.icon(onPressed: () {}, icon: Icon(Icons.share_rounded, color: Colors.white, size: 16 * theme.fontScale), label: Text("CHIA SẺ DỰ ÁN", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 1.0, fontSize: 13 * theme.fontScale), overflow: TextOverflow.ellipsis), style: ElevatedButton.styleFrom(backgroundColor: theme.primaryColor, padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)))))
                                        ],
                                      ),
                                    )
                                  ]
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

  // --- WIDGET CHIA CỘT THỐNG KÊ (ĐÃ FIX MÀU TEXT) ---
  Widget _buildStatCardsResponsive(double width, AppTheme theme) {
    Widget card1 = _buildStatCard("TỔNG HỌC SINH", "$_totalStudents", Icons.school_rounded, theme.infoColor, theme);
    Widget card2 = _buildStatCard("TỔNG NHÂN SỰ", "$_totalStaff", Icons.manage_accounts_rounded, theme.purpleColor, theme);
    Widget card3 = _buildStatCard("TỈ LỆ ĐI TRỄ", _lateRate, Icons.trending_up_rounded, theme.warningColor, theme);
    Widget card4 = _buildStatCard("TỈ LỆ NGHỈ HỌC", _absentRate, Icons.trending_down_rounded, theme.errorColor, theme);

    if (width >= 1300) { return Row(children: [Expanded(child: card1), const SizedBox(width: 20), Expanded(child: card2), const SizedBox(width: 20), Expanded(child: card3), const SizedBox(width: 20), Expanded(child: card4)]); }
    else if (width >= 750) { return Column(children: [Row(children: [Expanded(child: card1), const SizedBox(width: 20), Expanded(child: card2)]), const SizedBox(height: 20), Row(children: [Expanded(child: card3), const SizedBox(width: 20), Expanded(child: card4)])]); }
    else { return Column(children: [card1, const SizedBox(height: 20), card2, const SizedBox(height: 20), card3, const SizedBox(height: 20), card4]); }
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color, AppTheme theme) { return Container(padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 20), decoration: BoxDecoration(color: theme.cardColor, borderRadius: BorderRadius.circular(20), border: Border.all(color: color.withOpacity(0.3), width: 1.5), boxShadow: theme.isDarkMode ? [] : [BoxShadow(color: color.withOpacity(0.05), blurRadius: 15, offset: const Offset(0, 5))]), child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(14)), child: Icon(icon, color: color, size: 24 * theme.fontScale)), const SizedBox(width: 15), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [Text(title, style: TextStyle(color: theme.subTextColor, fontSize: 11 * theme.fontScale, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis), const SizedBox(height: 5), Text(value, style: TextStyle(color: theme.textColor, fontSize: 20 * theme.fontScale, fontWeight: FontWeight.w900), maxLines: 1, overflow: TextOverflow.ellipsis)]))])); }
  Widget _buildInfoBox(String label, String value, IconData icon, AppTheme theme, {bool isHighlight = false}) { Color valColor = isHighlight ? theme.successColor : theme.textColor; return Container(padding: const EdgeInsets.all(15), decoration: BoxDecoration(color: theme.textColor.withOpacity(0.02), borderRadius: BorderRadius.circular(16), border: Border.all(color: theme.borderColor)), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Icon(icon, color: theme.primaryColor.withOpacity(0.8), size: 18 * theme.fontScale), const SizedBox(width: 12), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [Text(label.toUpperCase(), style: TextStyle(color: theme.subTextColor, fontSize: 11 * theme.fontScale, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis), const SizedBox(height: 6), Text(value, style: TextStyle(color: valColor, fontSize: 13 * theme.fontScale, fontWeight: FontWeight.w600, height: 1.4), maxLines: 2, overflow: TextOverflow.ellipsis)]))])); }
  Widget _buildSectionHeader(IconData icon, String title, AppTheme theme) => Wrap(crossAxisAlignment: WrapCrossAlignment.center, children: [AnimatedContainer(duration: const Duration(milliseconds: 300), child: Icon(icon, color: theme.primaryColor, size: 18 * theme.fontScale)), const SizedBox(width: 10), AnimatedDefaultTextStyle(duration: const Duration(milliseconds: 300), style: TextStyle(color: theme.textColor, fontSize: 14 * theme.fontScale, fontWeight: FontWeight.bold, letterSpacing: 1.2, fontFamily: 'Segoe UI'), child: Text(title, overflow: TextOverflow.ellipsis))]);
  Widget _buildBarChart(AppTheme theme) {
    List<dynamic> chartData = _chartData.isNotEmpty ? _chartData : [{'day': 'T2', 'ok': 0.0, 'late': 0.0}, {'day': 'T3', 'ok': 0.0, 'late': 0.0}, {'day': 'T4', 'ok': 0.0, 'late': 0.0}, {'day': 'T5', 'ok': 0.0, 'late': 0.0}, {'day': 'T6', 'ok': 0.0, 'late': 0.0}, {'day': 'T7', 'ok': 0.0, 'late': 0.0}];

    return SizedBox(height: 200, child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, crossAxisAlignment: CrossAxisAlignment.end, children: chartData.map((data) {
      double okHeight = (data['ok'] as num).toDouble();
      double lateHeight = (data['late'] as num).toDouble();
      if(okHeight == 0) okHeight = 2.0;
      if(lateHeight == 0) lateHeight = 2.0;

      return Column(mainAxisSize: MainAxisSize.min, mainAxisAlignment: MainAxisAlignment.end, children: [Row(crossAxisAlignment: CrossAxisAlignment.end, children: [Container(width: 12 * theme.fontScale, height: okHeight, decoration: BoxDecoration(color: theme.primaryColor, borderRadius: const BorderRadius.vertical(top: Radius.circular(6)))), const SizedBox(width: 4), Container(width: 12 * theme.fontScale, height: lateHeight, decoration: BoxDecoration(color: theme.warningColor, borderRadius: const BorderRadius.vertical(top: Radius.circular(6))))]), const SizedBox(height: 10), Text(data['day'].toString(), style: TextStyle(color: theme.subTextColor, fontSize: 12 * theme.fontScale, fontWeight: FontWeight.bold))]);
    }).toList()));
  }

  // --- BẬT BẢNG CẤU HÌNH DỰ ÁN ---
  void _showEditProjectDialog(AppTheme theme) {
    String tempName = _projectName; String tempSchool = _schoolName; String tempYear = _academicYear; String tempSession = _sessionType; String tempMode = _attendanceMode; String tempRule = _globalRule; String tempMorning = _morningTime; String tempAfternoon = _afternoonTime;

    if (!['Sáng', 'Chiều', 'Sáng & Chiều'].contains(tempSession)) tempSession = 'Sáng & Chiều';
    if (!['Quy định chung', 'Theo từng ngày', 'Ghi lại tự do'].contains(tempMode)) tempMode = 'Quy định chung';
    if (tempMode == 'Quy định chung' && !['Giờ đầu', 'Giờ cuối', 'Đầu và cuối'].contains(tempRule)) tempRule = 'Giờ đầu';
    else if (tempMode == 'Theo từng ngày' && !['Từng môn', 'Tiết đầu tiên'].contains(tempRule)) tempRule = 'Từng môn';
    else if (tempMode == 'Ghi lại tự do') tempRule = 'Không xét đúng/trễ';

    showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) {
          return StatefulBuilder(
              builder: (context, setStateDialog) {
                return Dialog(
                  backgroundColor: theme.cardColor, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: theme.borderColor)),
                  child: Container(
                    width: 600, padding: const EdgeInsets.all(30),
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      child: Column(
                        mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text("Cấu hình chi tiết Dự án", style: TextStyle(color: theme.textColor, fontSize: 18 * theme.fontScale, fontWeight: FontWeight.bold)), IconButton(onPressed: () => Navigator.pop(context), icon: Icon(Icons.close_rounded, color: theme.subTextColor))]), const SizedBox(height: 25),
                          Row(children: [Expanded(child: _buildDialogTextField("Tên dự án", tempName, (v) => tempName = v, theme)), const SizedBox(width: 15), Expanded(child: _buildDialogTextField("Tên cơ sở / Trường", tempSchool, (v) => tempSchool = v, theme))]), const SizedBox(height: 15),
                          Row(children: [Expanded(child: _buildDialogTextField("Năm học vận hành", tempYear, (v) => tempYear = v, theme)), const SizedBox(width: 15), Expanded(child: _buildDialogDropdown("Ca học áp dụng", tempSession, ['Sáng', 'Chiều', 'Sáng & Chiều'], (v) => setStateDialog(() => tempSession = v!), theme))]), const SizedBox(height: 15),
                          AnimatedSize(duration: const Duration(milliseconds: 300), child: Row(children: [if (tempSession == 'Sáng' || tempSession == 'Sáng & Chiều') Expanded(child: _buildDialogTextField("Khung Giờ Sáng (VD: 07:00-11:30)", tempMorning, (v) => tempMorning = v, theme)), if (tempSession == 'Sáng & Chiều') const SizedBox(width: 15), if (tempSession == 'Chiều' || tempSession == 'Sáng & Chiều') Expanded(child: _buildDialogTextField("Khung Giờ Chiều", tempAfternoon, (v) => tempAfternoon = v, theme))])), const SizedBox(height: 15), Divider(color: theme.borderColor), const SizedBox(height: 15),
                          _buildDialogDropdown("Cơ chế điểm danh chung", tempMode, ['Quy định chung', 'Theo từng ngày', 'Ghi lại tự do'], (v) { setStateDialog(() { tempMode = v!; if (tempMode == 'Quy định chung' && !['Giờ đầu', 'Giờ cuối', 'Đầu và cuối'].contains(tempRule)) tempRule = 'Giờ đầu'; if (tempMode == 'Theo từng ngày' && !['Từng môn', 'Tiết đầu tiên'].contains(tempRule)) tempRule = 'Từng môn'; if (tempMode == 'Ghi lại tự do') tempRule = 'Không xét đúng/trễ'; }); }, theme), const SizedBox(height: 15),
                          if (tempMode == 'Quy định chung') _buildDialogDropdown("Chi tiết quy định", tempRule, ['Giờ đầu', 'Giờ cuối', 'Đầu và cuối'], (v) => setStateDialog(() => tempRule = v!), theme)
                          else if (tempMode == 'Theo từng ngày') _buildDialogDropdown("Chi tiết quy định", tempRule, ['Từng môn', 'Tiết đầu tiên'], (v) => setStateDialog(() => tempRule = v!), theme)
                          else if (tempMode == 'Ghi lại tự do') _buildDialogTextField("Chi tiết quy định", tempRule, (v) {}, theme),
                          const SizedBox(height: 35),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              TextButton(onPressed: () => Navigator.pop(context), child: Text("Hủy bỏ", style: TextStyle(color: theme.subTextColor))), const SizedBox(width: 15),
                              ElevatedButton.icon(
                                  onPressed: () async {
                                    Map<String, dynamic> payload = { "project_name": tempName, "school_name": tempSchool, "academic_year": tempYear, "session_type": tempSession, "attendance_mode": tempMode, "global_rule": tempRule, "morning_time": tempMorning, "afternoon_time": tempAfternoon };
                                    try {
                                      var response = await http.put(Uri.parse('http://127.0.0.1:8000/api/projects/${globals.currentProjectId}'), headers: {"Content-Type": "application/json"}, body: jsonEncode(payload));
                                      if (response.statusCode == 200) {
                                        var data = jsonDecode(response.body);
                                        if(data['status'] == 'success') {
                                          if (context.mounted) Navigator.pop(context);
                                          setState(() { _projectName = tempName; _schoolName = tempSchool; _academicYear = tempYear; _sessionType = tempSession; _attendanceMode = tempMode; _globalRule = tempRule; _morningTime = tempMorning; _afternoonTime = tempAfternoon; });
                                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Lưu cấu hình an toàn vào hệ thống!"), backgroundColor: Colors.green));
                                        }
                                      }
                                    } catch (e) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Lỗi kết nối Server!"), backgroundColor: Colors.redAccent)); }
                                  },
                                  icon: const Icon(Icons.save_rounded, color: Colors.white, size: 18), label: const Text("LƯU THAY ĐỔI", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)), style: ElevatedButton.styleFrom(backgroundColor: theme.primaryColor, padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15))
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
  // DIALOG TẠO LỚP ĐỘC LẬP (ĐÃ NÂNG CẤP CÓ THỂ THÊM NHIỀU LỚP CÙNG LÚC)
  // ==========================================================
  void _showCreateClassDialog(BuildContext context, AppTheme theme) {
    List<TempClass> _newClasses = [TempClass()]; // Bắt đầu với 1 lớp trống

    showDialog(context: context, barrierDismissible: false, builder: (context) {
      return StatefulBuilder(builder: (context, setStateDialog) {
        return Dialog(
            backgroundColor: theme.cardColor, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24), side: BorderSide(color: theme.successColor.withOpacity(0.5), width: 2)),
            child: Container(
                width: 650, constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
                child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(padding: const EdgeInsets.all(25), decoration: BoxDecoration(color: theme.successColor.withOpacity(0.1), borderRadius: const BorderRadius.vertical(top: Radius.circular(22))), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Row(children: [Icon(Icons.add_business_rounded, color: theme.successColor, size: 28 * theme.fontScale), const SizedBox(width: 15), Text("Khởi Tạo Lớp Mới", style: TextStyle(color: theme.successColor, fontSize: 20 * theme.fontScale, fontWeight: FontWeight.bold))]), IconButton(onPressed: () => Navigator.pop(context), icon: Icon(Icons.close_rounded, color: theme.subTextColor))])),

                      Flexible(
                          child: SingleChildScrollView(
                              padding: const EdgeInsets.all(40),
                              child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min,
                                  children: [
                                    // VÒNG LẶP RENDER CÁC LỚP ĐANG TẠO
                                    ..._newClasses.asMap().entries.map((entry) {
                                      int idx = entry.key; TempClass cls = entry.value;
                                      return Container(
                                          margin: const EdgeInsets.only(bottom: 25), padding: const EdgeInsets.all(20),
                                          decoration: BoxDecoration(color: theme.textColor.withOpacity(0.02), borderRadius: BorderRadius.circular(16), border: Border.all(color: theme.borderColor)),
                                          child: Row(
                                              crossAxisAlignment: CrossAxisAlignment.end,
                                              children: [
                                                Expanded(flex: 3, child: _buildDialogTextFieldWithIcon("Tên Lớp (VD: 10A1)", Icons.meeting_room_rounded, "Nhập tên lớp", (v) => cls.className = v, theme)),
                                                const SizedBox(width: 20),
                                                Expanded(
                                                    flex: 2,
                                                    child: Column(
                                                        crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min,
                                                        children: [
                                                          Text("Danh sách học sinh", style: TextStyle(color: theme.textColor, fontSize: 12 * theme.fontScale, fontWeight: FontWeight.bold)), const SizedBox(height: 8),
                                                          SizedBox(
                                                              height: 45, width: double.infinity,
                                                              child: ElevatedButton.icon(
                                                                  onPressed: () => _processExcelFile(context, cls, setStateDialog, theme),
                                                                  icon: Icon(cls.uploadedExcelFile != null ? Icons.check_circle_rounded : Icons.upload_file_rounded, color: cls.uploadedExcelFile != null ? theme.successColor : Colors.white, size: 16 * theme.fontScale),
                                                                  label: Text(cls.uploadedExcelFile ?? "Tải Excel (.xlsx)", style: TextStyle(color: cls.uploadedExcelFile != null ? theme.successColor : Colors.white, fontWeight: FontWeight.bold, fontSize: 12 * theme.fontScale), overflow: TextOverflow.ellipsis),
                                                                  style: ElevatedButton.styleFrom(backgroundColor: cls.uploadedExcelFile != null ? theme.successColor.withOpacity(0.1) : theme.primaryColor, alignment: Alignment.centerLeft, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)))
                                                              )
                                                          )
                                                        ]
                                                    )
                                                ),
                                                if (_newClasses.length > 1)
                                                  Padding(
                                                    padding: const EdgeInsets.only(left: 10, bottom: 5),
                                                    child: IconButton(onPressed: () => setStateDialog(() => _newClasses.removeAt(idx)), icon: Icon(Icons.remove_circle_outline_rounded, color: theme.errorColor)),
                                                  )
                                              ]
                                          )
                                      );
                                    }).toList(),

                                    // NÚT THÊM LỚP MỚI VÀO DANH SÁCH
                                    TextButton.icon(
                                        onPressed: () => setStateDialog(() => _newClasses.add(TempClass())),
                                        icon: Icon(Icons.add_circle_outline_rounded, color: theme.primaryColor),
                                        label: Text("Thêm khung lớp", style: TextStyle(color: theme.primaryColor, fontWeight: FontWeight.bold))
                                    )
                                  ]
                              )
                          )
                      ),

                      // FOOTER BẤM LƯU TẤT CẢ
                      Container(
                          padding: const EdgeInsets.all(25), decoration: BoxDecoration(color: theme.textColor.withOpacity(0.02), border: Border(top: BorderSide(color: theme.borderColor))),
                          child: Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                TextButton(onPressed: () => Navigator.pop(context), child: Text("Hủy bỏ", style: TextStyle(color: theme.subTextColor, fontSize: 14 * theme.fontScale))),
                                const SizedBox(width: 20),
                                ElevatedButton.icon(
                                    onPressed: () async {
                                      bool hasError = false;
                                      for (var cls in _newClasses) {
                                        if (cls.className.trim().isEmpty) hasError = true;
                                      }

                                      if (hasError) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Vui lòng nhập tên cho tất cả các lớp!"), backgroundColor: Colors.orange)); return; }

                                      showDialog(context: context, barrierDismissible: false, builder: (c) => Center(child: CircularProgressIndicator(color: theme.successColor)));

                                      try {
                                        // GỬI LẦN LƯỢT TỪNG LỚP LÊN SERVER
                                        for (var cls in _newClasses) {
                                          Map<String, dynamic> payload = { "class_name": cls.className, "students": cls.parsedStudents };
                                          await http.post(Uri.parse('http://127.0.0.1:8000/api/projects/${globals.currentProjectId}/classes'), headers: {"Content-Type": "application/json"}, body: jsonEncode(payload));
                                        }

                                        if (context.mounted) Navigator.pop(context); // Tắt loading
                                        if (context.mounted) Navigator.pop(context); // Tắt Dialog tạo lớp
                                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Đã tạo thành công ${_newClasses.length} lớp!"), backgroundColor: theme.successColor));
                                        widget.onDataChanged?.call();
                                      } catch(e) {
                                        if (context.mounted) Navigator.pop(context);
                                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Lỗi: $e"), backgroundColor: theme.errorColor));
                                      }
                                    },
                                    icon: const Icon(Icons.check_rounded, color: Colors.white), label: const Text("TẠO TẤT CẢ", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                    style: ElevatedButton.styleFrom(backgroundColor: theme.successColor, padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16))
                                )
                              ]
                          )
                      )
                    ]
                )
            )
        );
      });
    });
  }

  // ==========================================================
  // THUẬT TOÁN ĐỌC EXCEL THÔNG MINH (TỰ TÌM DÒNG BẮT ĐẦU VÀ CHỐNG CRASH)
  // ==========================================================
  Future<void> _processExcelFile(BuildContext context, TempClass classModel, StateSetter setModalState, AppTheme theme) async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['xlsx'], withData: true);

      if (result != null && result.files.single.bytes != null && context.mounted) {
        String fileName = result.files.single.name;
        var fileBytes = result.files.single.bytes!;

        showDialog(context: context, barrierDismissible: false, builder: (c) => AlertDialog(backgroundColor: theme.cardColor, content: Row(children: [CircularProgressIndicator(color: theme.successColor), const SizedBox(width: 20), Expanded(child: Text("Đang bóc tách file $fileName...", style: TextStyle(color: theme.textColor)))])));

        var excel = ex.Excel.decodeBytes(fileBytes);
        var sheet = excel.tables[excel.tables.keys.first]!;
        List<Map<String, String>> studentsData = [];

        // Hàm hỗ trợ format
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

        bool foundHeader = false;
        int currentStudentIndex = _totalStudents + 1;

        // Vòng lặp quét dòng siêu an toàn
        for (int i = 0; i < sheet.rows.length; i++) {
          var row = sheet.rows[i];
          if (row.isEmpty) continue;

          String colA = row.isNotEmpty && row[0]?.value != null ? row[0]!.value.toString().toLowerCase().trim() : "";
          String colB = row.length > 1 && row[1]?.value != null ? row[1]!.value.toString().toLowerCase().trim() : "";

          if (!foundHeader) {
            if (colA == "stt" || colB == "họ và tên" || colB == "họ tên") foundHeader = true;
            continue;
          }

          if (int.tryParse(colA) == null) continue;

          String fullName = row.length > 1 ? (row[1]?.value?.toString() ?? "") : "";
          String gender = row.length > 2 ? (row[2]?.value?.toString() ?? "Nam") : "Nam";

          String rawDob = row.length > 3 ? (row[3]?.value?.toString() ?? "") : "";
          String dob = row.length > 3 ? formatDate(row[3]?.value) : "";
          if (dob.isEmpty) dob = rawDob;

          String hometown = row.length > 4 ? (row[4]?.value?.toString() ?? "") : "";
          String phone = row.length > 5 ? cleanNumber(row[5]?.value) : "";
          String email = row.length > 6 ? (row[6]?.value?.toString() ?? "") : "";

          // TỰ ĐỘNG TẠO MÃ ID VÀ MẬT KHẨU TỪ THUẬT TOÁN
          String generatedId = _generateStudentId(fullName, dob, currentStudentIndex);
          String autoPassword = _generateAutoPassword(fullName, dob);

          currentStudentIndex++; // Tăng stt cho người tiếp theo

          studentsData.add({
            "stt": generatedId, // Backend sẽ lưu mã này vào cột ID/Student_code
            "name": fullName,
            "gender": gender,
            "dob": dob,
            "hometown": hometown,
            "phone": phone,
            "user": email.isNotEmpty ? email.trim() : "hs$generatedId@edu.vn",
            "pass_": autoPassword
          });
        }

        if (context.mounted) Navigator.pop(context);

        if (studentsData.isNotEmpty) {
          _showExcelPreviewDialog(context, theme, setModalState, classModel, fileName, studentsData);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: const Text("File Excel không hợp lệ hoặc rỗng!"), backgroundColor: theme.errorColor));
        }
      }
    } catch (e) {
      if (context.mounted) Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Lỗi đọc file: ${e.toString()}"), backgroundColor: theme.errorColor));
    }
  }
  // ==========================================================
  // BẢNG PREVIEW EXCEL (ĐÃ CĂN CHỈNH ĐẸP MẮT)
  // ==========================================================
  void _showExcelPreviewDialog(BuildContext parentContext, AppTheme theme, StateSetter parentSetState, TempClass newClass, String fileName, List<Map<String, String>> parsedData) {
    showDialog(
        context: parentContext, barrierDismissible: false,
        builder: (context) {
          return Dialog(
            backgroundColor: theme.cardColor, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: theme.successColor.withOpacity(0.5))),
            child: Container(
              width: 900, padding: const EdgeInsets.all(30),
              child: Column(
                mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [Icon(Icons.visibility_rounded, color: theme.successColor, size: 24 * theme.fontScale), const SizedBox(width: 10), Expanded(child: Text("Xem trước Dữ liệu: $fileName", style: TextStyle(color: theme.textColor, fontSize: 16 * theme.fontScale, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis))]),
                  const SizedBox(height: 10), Text("Đã nhận diện ${parsedData.length} dòng. Tài khoản tự sinh.", style: TextStyle(color: theme.subTextColor, fontSize: 13 * theme.fontScale)), const SizedBox(height: 20),

                  Container(
                    width: double.infinity, height: 350, decoration: BoxDecoration(color: theme.textColor.withOpacity(0.02), borderRadius: BorderRadius.circular(12), border: Border.all(color: theme.borderColor)),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal, child: SingleChildScrollView(
                        child: DataTable(
                          headingRowColor: WidgetStateProperty.all(theme.successColor.withOpacity(0.1)),
                          columns: [
                            DataColumn(label: Text("STT", style: TextStyle(color: theme.successColor, fontWeight: FontWeight.bold))),
                            DataColumn(label: Text("Họ Tên", style: TextStyle(color: theme.successColor, fontWeight: FontWeight.bold))),
                            DataColumn(label: Text("Giới tính", style: TextStyle(color: theme.successColor, fontWeight: FontWeight.bold))),
                            DataColumn(label: Text("Ngày sinh", style: TextStyle(color: theme.successColor, fontWeight: FontWeight.bold))),
                            DataColumn(label: Text("Quê quán", style: TextStyle(color: theme.successColor, fontWeight: FontWeight.bold))),
                            DataColumn(label: Text("Tài khoản", style: TextStyle(color: theme.warningColor, fontWeight: FontWeight.bold))),
                            DataColumn(label: Text("Mật khẩu", style: TextStyle(color: theme.warningColor, fontWeight: FontWeight.bold)))
                          ],
                          rows: parsedData.take(100).map((e) => DataRow(cells: [
                            DataCell(Text(e['stt']!, style: TextStyle(color: theme.subTextColor))),
                            DataCell(Text(e['name']!, style: TextStyle(color: theme.textColor, fontWeight: FontWeight.bold))),
                            DataCell(Text(e['gender']!, style: TextStyle(color: theme.subTextColor))),
                            DataCell(Text(e['dob']!, style: TextStyle(color: theme.subTextColor))),
                            DataCell(Text(e['hometown']!, style: TextStyle(color: theme.subTextColor))),
                            DataCell(Text(e['user']!, style: TextStyle(color: theme.warningColor, fontWeight: FontWeight.bold))),
                            DataCell(Text(e['pass_']!, style: TextStyle(color: theme.warningColor)))
                          ])).toList(),
                        ),
                      ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 30),

                  Row(mainAxisAlignment: MainAxisAlignment.end, children: [TextButton(onPressed: () { parentSetState(() => newClass.uploadedExcelFile = null); Navigator.pop(context); }, child: Text("Hủy file", style: TextStyle(color: theme.errorColor))), const SizedBox(width: 15), ElevatedButton.icon(onPressed: () { parentSetState(() => newClass.parsedStudents = parsedData); Navigator.pop(context); }, icon: const Icon(Icons.check_circle_rounded, color: Colors.white), label: const Text("Xác nhận", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)), style: ElevatedButton.styleFrom(backgroundColor: theme.successColor))])
                ],
              ),
            ),
          );
        }
    );
  }
  // Hàm tạo mật khẩu tự động: "Huỳnh Văn Thiên Sinh" + "03/04/2007" -> "sinh03042007"
// Hàm tạo mã ID (Chỉ lấy chữ cái đầu của Họ và Tên. VD: Huỳnh Văn Thiên Sinh 2007 -> 07HS005)
  String _generateStudentId(String fullName, String dob, int globalIndex) {
    if (fullName.isEmpty) return "HS${globalIndex.toString().padLeft(3, '0')}";

    // 1. Lấy 2 số cuối năm sinh
    String yearSuffix = "00";
    if (dob.isNotEmpty && dob.contains('/')) {
      List<String> parts = dob.split('/');
      if (parts.length >= 3) {
        String year = parts.last.trim();
        if (year.length >= 2) yearSuffix = year.substring(year.length - 2);
      }
    }

    // 2. CHỈ LẤY CHỮ CÁI ĐẦU CỦA HỌ VÀ TÊN (Bỏ chữ lót)
    String initials = "";
    List<String> words = fullName.trim().split(RegExp(r'\s+'));
    if (words.isNotEmpty) {
      initials += words.first[0].toUpperCase(); // Chữ đầu của Họ
      if (words.length > 1) {
        initials += words.last[0].toUpperCase(); // Chữ đầu của Tên
      }
    }

    const withDia = 'ÁÀẢÃẠĂẮẰẲẴẶÂẤẦẨẪẬÉÈẺẼẸÊẾỀỂỄỆÍÌỈĨỊÓÒỎÕỌÔỐỒỔỖỘƠỚỜỞỠỢÚÙỦŨỤƯỨỪỬỮỰÝỲỶỸỴĐ';
    const withoutDia = 'AAAAAAAAAAAAAAAAAEEEEEEEEEEEIIIIIOOOOOOOOOOOOOOOOOUUUUUUUUUUUYYYYYD';
    for (int i = 0; i < withDia.length; i++) {
      initials = initials.replaceAll(withDia[i], withoutDia[i]);
    }

    // 3. Số thứ tự toàn dự án
    String indexStr = globalIndex.toString().padLeft(3, '0');

    return "$yearSuffix$initials$indexStr";
  }
  String _generateAutoPassword(String fullName, String dob) {
    if (fullName.isEmpty || dob.isEmpty) return "12345678";

    // 1. Lấy tên cuối cùng và viết thường
    String firstName = fullName.trim().split(' ').last.toLowerCase();

    // 2. Xóa dấu tiếng Việt (ĐÃ CHUẨN HÓA LẠI ĐỘ DÀI CHUỖI)
    const withDia = 'áàảãạăắằẳẵặâấầẩẫậéèẻẽẹêếềểễệíìỉĩịóòỏõọôốồổỗộơớờởỡợúùủũụưứừửữựýỳỷỹỵđ';
    const withoutDia = 'aaaaaaaaaaaaaaaaaeeeeeeeeeeeiiiiiooooooooooooooooouuuuuuuuuuuyyyyyd';

    for (int i = 0; i < withDia.length; i++) {
      firstName = firstName.replaceAll(withDia[i], withoutDia[i]);
    }

    // 3. Chuẩn hóa ngày sinh (Xóa dấu / và -)
    String cleanDob = dob.replaceAll('/', '').replaceAll('-', '').replaceAll(' ', '');

    return "$firstName$cleanDob";
  }
  // --- UI UTILS ---
  Widget _buildDialogTextField(String label, String value, Function(String) onChanged, AppTheme theme) { return Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [Text(label, style: TextStyle(color: theme.textColor, fontSize: 12 * theme.fontScale, fontWeight: FontWeight.bold)), const SizedBox(height: 8), TextFormField(initialValue: value, onChanged: onChanged, style: TextStyle(color: theme.textColor, fontSize: 13 * theme.fontScale), decoration: InputDecoration(filled: true, fillColor: theme.textColor.withOpacity(0.04), contentPadding: const EdgeInsets.symmetric(horizontal: 15), enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: theme.borderColor)), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: theme.primaryColor))))]); }
  Widget _buildDialogTextFieldWithIcon(String label, IconData icon, String hint, Function(String) onChanged, AppTheme theme) { return Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [Text(label, style: TextStyle(color: theme.textColor, fontSize: 12 * theme.fontScale, fontWeight: FontWeight.bold)), const SizedBox(height: 8), SizedBox(height: 45, child: TextFormField(onChanged: onChanged, style: TextStyle(color: theme.textColor, fontSize: 13 * theme.fontScale), decoration: InputDecoration(contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 15), prefixIcon: Icon(icon, color: theme.primaryColor, size: 18 * theme.fontScale), hintText: hint, hintStyle: TextStyle(color: theme.subTextColor.withOpacity(0.5)), filled: true, fillColor: theme.textColor.withOpacity(0.02), enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: theme.borderColor)), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: theme.primaryColor)))))]); }
  Widget _buildDialogDropdown(String label, String value, List<String> items, Function(String?) onChanged, AppTheme theme) { return Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [Text(label, style: TextStyle(color: theme.textColor, fontSize: 12 * theme.fontScale, fontWeight: FontWeight.bold)), const SizedBox(height: 8), SizedBox(height: 45, child: DropdownButtonFormField<String>(value: value, dropdownColor: theme.cardColor, style: TextStyle(color: theme.textColor, fontSize: 13 * theme.fontScale), decoration: InputDecoration(contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 15), filled: true, fillColor: theme.textColor.withOpacity(0.04), enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: theme.borderColor)), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: theme.primaryColor))), items: items.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(), onChanged: onChanged))]); }
}