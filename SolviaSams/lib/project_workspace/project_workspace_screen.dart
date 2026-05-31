import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../theme_manager.dart';
import '../globals.dart' as globals;

// MÓC NỐI TẤT CẢ CÁC TRANG CỦA BẠN
import 'project_info_view.dart';
import 'project_members_view.dart';
import 'unified_timetable_view.dart';
import 'attendance_report_view.dart';
import 'class_management_view.dart';
import 'camera_ai_view.dart';
import 'camera_ai_view.dart';

class ProjectWorkspaceScreen extends StatefulWidget {
  final String userRole;
  const ProjectWorkspaceScreen({super.key, required this.userRole});

  @override
  State<ProjectWorkspaceScreen> createState() => _ProjectWorkspaceScreenState();
}

class _ProjectWorkspaceScreenState extends State<ProjectWorkspaceScreen> {
  String _selectedRoute = 'project_info';
  bool _isLoadingRoles = true;

  bool _isSuperAdmin = false;
  bool _isHomeroom = false;
  bool _isSubject = false;
  String _currentUserName = "";

  List<dynamic> _allClasses = [];
  List<dynamic> _homeroomClasses = [];
  List<dynamic> _teachingClasses = [];

  @override
  void initState() {
    super.initState();
    _checkUserPermissions();
  }

  Future<void> _checkUserPermissions() async {
    setState(() => _isLoadingRoles = true);

    // ===========================================
    // NẾU LÀ HỌC SINH -> KHÔNG QUÉT QUYỀN GIÁO VIÊN
    // ===========================================
    if (widget.userRole == 'Học sinh' || widget.userRole == 'Thành viên') {
      _isSuperAdmin = false;
      _isHomeroom = false;
      _isSubject = false;
      if (_selectedRoute == 'project_info') _selectedRoute = 'class_${globals.currentClassId}';
      setState(() => _isLoadingRoles = false);
      return;
    }

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
          List<dynamic> classes = dataClasses['data'] ?? [];
          List<dynamic> tempAll = [];
          List<dynamic> tempHome = [];
          List<dynamic> tempSubj = [];

          for (var c in classes) {
            tempAll.add(c);

            var resDetail = await http.get(Uri.parse('http://127.0.0.1:8000/api/classes/${c['id']}'));
            if (resDetail.statusCode == 200) {
              var cDetail = jsonDecode(utf8.decode(resDetail.bodyBytes))['data'];

              bool isHome = false;
              bool isSubj = false;

              String tIdStr = "";
              if (cDetail['teacher'] != null && cDetail['teacher']['user_id'] != null) {
                tIdStr = cDetail['teacher']['user_id'].toString();
              }
              if (tIdStr == globals.currentUserId.toString()) {
                isHome = true;
                _isHomeroom = true;
              }

              List<dynamic> timetable = cDetail['timetable'] ?? [];
              String myNameLower = _currentUserName.toLowerCase();

              for (var day in timetable) {
                for (var sub in day['subjects'] ?? []) {
                  String subTeacherName = (sub['teacher_name'] ?? "").toString().toLowerCase();
                  if (myNameLower.isNotEmpty && subTeacherName.contains(myNameLower)) {
                    isSubj = true;
                    _isSubject = true;
                  }
                }
              }

              if (isHome) tempHome.add(c);
              if (isSubj) tempSubj.add(c);
            }
          }

          _allClasses = tempAll;
          _homeroomClasses = tempHome;
          _teachingClasses = tempSubj;
        }
      }
    } catch (e) {}

    if (widget.userRole.contains("Admin")) _isSuperAdmin = true;
    if (mounted) setState(() => _isLoadingRoles = false);
  }

  Widget _getSelectedPage() {
    if (_isLoadingRoles) return Center(child: CircularProgressIndicator(color: AppTheme.instance.primaryColor));

    if (_selectedRoute.startsWith('class_')) {
      int cId = int.parse(_selectedRoute.split('_').last);
      String cName = "Lớp học";
      try {
        cName = _allClasses.firstWhere((c) => c['id'] == cId)['class_name'];
      } catch(e) {
        if (widget.userRole == 'Học sinh') cName = "Lớp của mình";
      }
      return ClassManagementView(key: ValueKey('Class_$cId'), classId: cId, className: cName, isSuperAdmin: _isSuperAdmin, onDataChanged: _checkUserPermissions);
    }

    if (_selectedRoute.startsWith('subject_')) {
      int cId = int.parse(_selectedRoute.split('_').last);
      String cName = _allClasses.firstWhere((c) => c['id'] == cId)['class_name'];
      return ClassManagementView(key: ValueKey('Subject_$cId'), classId: cId, className: cName, isSuperAdmin: false, onDataChanged: _checkUserPermissions);
    }

    switch (_selectedRoute) {
      case 'project_info': return ProjectInfoView(isSuperAdmin: _isSuperAdmin, onDataChanged: _checkUserPermissions);
      case 'members': return ProjectMembersView(isSuperAdmin: _isSuperAdmin);
      case 'timetable': return UnifiedTimetableView(isSuperAdmin: _isSuperAdmin, onDataChanged: _checkUserPermissions);
      case 'camera': return const CameraAiView();
      case 'attendance': return const AttendanceReportView();
      default: return const Center(child: Text("Đang phát triển..."));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.instance;

    List<Widget> teacherOps = [];
    if (_homeroomClasses.isNotEmpty) {
      teacherOps.add(
          _buildSubExpansionMenu(
              Icons.star_outline_rounded,
              "LỚP CHỦ NHIỆM",
              _homeroomClasses.map((c) => _buildMenuItem('class_${c['id']}', Icons.star_rounded, c['class_name'], theme, isHighlight: true, iconColor: theme.successColor)).toList(),
              theme
          )
      );
    }
    if (_teachingClasses.isNotEmpty) {
      teacherOps.add(
          _buildSubExpansionMenu(
              Icons.class_outlined,
              "LỚP BỘ MÔN",
              _teachingClasses.map((c) => _buildMenuItem('subject_${c['id']}', Icons.class_rounded, c['class_name'], theme, isHighlight: true, iconColor: theme.purpleColor)).toList(),
              theme
          )
      );
    }

    return Scaffold(
      backgroundColor: theme.backgroundColor,
      body: Row(
        children: [
          Container(
            width: 260 * theme.fontScale,
            color: theme.cardColor,
            child: Column(
              children: [
                const SizedBox(height: 20),
                ListTile(
                  leading: Icon(Icons.arrow_back_ios_new_rounded, color: theme.subTextColor, size: 16),
                  title: Text("Về bảng điều khiển", style: TextStyle(color: theme.subTextColor, fontWeight: FontWeight.bold, fontSize: 12 * theme.fontScale)),
                  onTap: () => Navigator.pop(context),
                ),
                const SizedBox(height: 20),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("SAMS Cơ sở 1", style: TextStyle(color: theme.textColor, fontWeight: FontWeight.w900, fontSize: 18 * theme.fontScale)),
                      const SizedBox(height: 4),
                      Text("Trường học • ${widget.userRole == 'Học sinh' ? 'Học sinh' : _currentUserName}", style: TextStyle(color: theme.primaryColor, fontSize: 12 * theme.fontScale, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                Expanded(
                  child: ListView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    children: widget.userRole == 'Học sinh' || widget.userRole == 'Thành viên'

                    // ==========================================
                    // 1. MENU CHỈ DÀNH CHO HỌC SINH
                    // ==========================================
                        ? [
                      const Padding(padding: EdgeInsets.only(left: 15, top: 10, bottom: 5), child: Text("KHU VỰC HỌC TẬP", style: TextStyle(color: Colors.grey, fontSize: 10, fontWeight: FontWeight.bold))),
                      _buildMenuItem('project_info', Icons.info_outline_rounded, "Thông tin chung dự án", theme),
                      _buildMenuItem('timetable', Icons.calendar_month_rounded, "Thời khóa biểu chung", theme),
                      _buildMenuItem('class_${globals.currentClassId}', Icons.local_library_rounded, "Lớp của mình", theme, isHighlight: true),
                      _buildMenuItem('attendance', Icons.bar_chart_rounded, "Báo cáo điểm danh", theme),
                    ]

                    // ==========================================
                    // 2. MENU CỦA GIÁO VIÊN (Giữ nguyên)
                    // ==========================================
                        : [
                      _buildMenuItem('project_info', Icons.info_outline_rounded, "Thông tin dự án", theme),
                      _buildMenuItem('members', Icons.admin_panel_settings_rounded, "Thành viên quản trị", theme),
                      _buildMenuItem('timetable', Icons.calendar_month_rounded, "Thời khóa biểu chung", theme),

                      const Padding(padding: EdgeInsets.only(left: 15, top: 15, bottom: 5), child: Text("ĐIỀU HÀNH LỚP HỌC", style: TextStyle(color: Colors.grey, fontSize: 10, fontWeight: FontWeight.bold))),

                      if (teacherOps.isNotEmpty)
                        _buildExpansionMenu(Icons.local_library_rounded, "Nghiệp vụ Giáo viên", teacherOps, theme),

                      if (_isSuperAdmin)
                        _buildExpansionMenu(
                            Icons.apartment_rounded,
                            "Quản trị Hệ thống",
                            _allClasses.map((c) => _buildMenuItem('class_${c['id']}', Icons.meeting_room_rounded, "Lớp ${c['class_name']}", theme)).toList(),
                            theme
                        ),

                      const Padding(padding: EdgeInsets.only(left: 15, top: 15, bottom: 5), child: Text("GIÁM SÁT TRỰC TIẾP", style: TextStyle(color: Colors.grey, fontSize: 10, fontWeight: FontWeight.bold))),

                      if (_isSuperAdmin)
                        _buildMenuItem('camera', Icons.videocam_rounded, "Thiết bị Camera AI", theme),

                      _buildMenuItem('attendance', Icons.bar_chart_rounded, "Báo cáo điểm danh", theme),
                    ],
                  ),
                )
              ],
            ),
          ),

          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: theme.backgroundColor,
                borderRadius: const BorderRadius.only(topLeft: Radius.circular(30), bottomLeft: Radius.circular(30)),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 20, spreadRadius: 5)],
              ),
              child: ClipRRect(
                borderRadius: const BorderRadius.only(topLeft: Radius.circular(30), bottomLeft: Radius.circular(30)),

                // ========================================================
                // ĐÃ FIX: GIỮ CAMERA CHẠY NGẦM BẰNG STACK VÀ OFFSTAGE
                // ========================================================
                child: Stack(
                  children: [
                    // 1. Camera luôn được giữ trong bộ nhớ, chỉ "tàng hình" khi qua tab khác
                    Offstage(
                      offstage: _selectedRoute != 'camera',
                      child: const CameraAiView(),
                    ),

                    // 2. Các trang khác (Báo cáo, Học sinh...) đè lên trên
                    if (_selectedRoute != 'camera')
                      _getSelectedPage(),
                  ],
                ),
                // ========================================================

              ),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildMenuItem(String routeId, IconData icon, String title, AppTheme theme, {bool isHighlight = false, Color? iconColor}) {
    bool isSelected = _selectedRoute == routeId;
    return Container(
      margin: const EdgeInsets.only(bottom: 5),
      child: ListTile(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        tileColor: isSelected
            ? (isHighlight ? theme.successColor.withOpacity(0.15) : theme.primaryColor.withOpacity(0.15))
            : Colors.transparent,
        leading: Icon(icon, color: isSelected
            ? (isHighlight ? theme.successColor : theme.primaryColor)
            : (iconColor ?? theme.subTextColor), size: 20 * theme.fontScale),
        title: Text(title, style: TextStyle(
            color: isSelected ? (isHighlight ? theme.successColor : theme.primaryColor) : theme.textColor,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            fontSize: 13 * theme.fontScale
        )),
        onTap: () {
          if (_isLoadingRoles) return;
          setState(() => _selectedRoute = routeId);
        },
      ),
    );
  }

  Widget _buildExpansionMenu(IconData icon, String title, List<Widget> children, AppTheme theme) {
    List<Widget> displayChildren = children.isEmpty
        ? [const Padding(padding: EdgeInsets.symmetric(vertical: 10, horizontal: 20), child: Text("Chưa có lớp học nào.", style: TextStyle(color: Colors.grey, fontSize: 11, fontStyle: FontStyle.italic)))]
        : children;

    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        initiallyExpanded: true,
        leading: Icon(icon, color: theme.primaryColor, size: 20 * theme.fontScale),
        title: Text(title, style: TextStyle(color: theme.textColor, fontWeight: FontWeight.bold, fontSize: 13 * theme.fontScale)),
        iconColor: theme.primaryColor,
        collapsedIconColor: theme.primaryColor,
        tilePadding: const EdgeInsets.symmetric(horizontal: 15),
        childrenPadding: const EdgeInsets.only(left: 10),
        children: displayChildren,
      ),
    );
  }

  Widget _buildSubExpansionMenu(IconData icon, String title, List<Widget> children, AppTheme theme) {
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        initiallyExpanded: true,
        leading: Icon(icon, color: theme.subTextColor, size: 16 * theme.fontScale),
        title: Text(title, style: TextStyle(color: theme.subTextColor, fontWeight: FontWeight.bold, fontSize: 11 * theme.fontScale, letterSpacing: 1.0)),
        iconColor: theme.subTextColor,
        collapsedIconColor: theme.subTextColor,
        tilePadding: const EdgeInsets.only(left: 15, right: 15),
        childrenPadding: const EdgeInsets.only(left: 20),
        children: children,
      ),
    );
  }
}