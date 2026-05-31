import 'package:flutter/material.dart';
import '../theme_manager.dart';
import '../shared/member_profile_dialog.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../globals.dart' as globals;

class ProjectMembersView extends StatefulWidget {
  final bool isSuperAdmin;
  const ProjectMembersView({super.key, required this.isSuperAdmin});

  @override
  State<ProjectMembersView> createState() => _ProjectMembersViewState();
}

class _ProjectMembersViewState extends State<ProjectMembersView> {
  int _currentTab = 0;
  bool _isLoading = true;
  List<dynamic> activeAdmins = [];
  List<dynamic> activeManagers = [];
  List<dynamic> pendingRequests = [];

  List<String> _availableClasses = [];
  Map<String, String> _teacherClassMap = {};

  // DANH SÁCH MÔN HỌC TIÊU CHUẨN ĐỂ TÌM KIẾM
  final List<String> _standardSubjects = [
    'Toán', 'Ngữ Văn', 'Tiếng Anh', 'Vật Lý', 'Hóa Học',
    'Sinh Học', 'Lịch Sử', 'Địa Lý', 'Giáo dục Công dân (GDCD)',
    'Tin Học', 'Công Nghệ', 'Thể Dục', 'Giáo dục Quốc phòng',
    'Khoa học Tự nhiên', 'Lịch sử và Địa lý', 'Nghệ thuật',
    'Hoạt động Trải nghiệm', 'Âm Nhạc', 'Mỹ Thuật'
  ];

  @override
  void initState() {
    super.initState();
    _fetchAllData();
  }

  Future<void> _fetchAllData() async {
    setState(() => _isLoading = true);
    await Future.wait([
      _fetchClasses(),
      _fetchMembers(),
    ]);
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _fetchClasses() async {
    try {
      var response = await http.get(Uri.parse('http://127.0.0.1:8000/api/projects/${globals.currentProjectId}/classes'));
      if (response.statusCode == 200) {
        var data = jsonDecode(utf8.decode(response.bodyBytes));
        if (data['status'] == 'success') {
          List<dynamic> classes = data['data'] ?? [];
          _availableClasses = classes.map((c) => c['class_name'].toString()).toList();

          _teacherClassMap.clear();
          for (var c in classes) {
            String className = c['class_name'].toString();
            if (c['teacher_id'] != null) _teacherClassMap[c['teacher_id'].toString()] = className;
            if (c['teacher'] != null) {
              if (c['teacher']['user_id'] != null) _teacherClassMap[c['teacher']['user_id'].toString()] = className;
              if (c['teacher']['id'] != null) _teacherClassMap[c['teacher']['id'].toString()] = className;
            }
          }
        }
      }
    } catch (e) {}
  }

  Future<void> _fetchMembers() async {
    try {
      var response = await http.get(Uri.parse('http://127.0.0.1:8000/api/projects/${globals.currentProjectId}/members'));
      if (response.statusCode == 200) {
        var data = jsonDecode(utf8.decode(response.bodyBytes));
        if (data['status'] == 'success') {
          activeAdmins = data['data']['admins'] ?? [];
          activeManagers = data['data']['managers'] ?? [];
          pendingRequests = data['data']['pending'] ?? [];
        }
      }
    } catch (e) {}
  }

  Future<void> _deleteMember(int memberId) async {
    try {
      var response = await http.delete(Uri.parse('http://127.0.0.1:8000/api/members/$memberId'));
      if (response.statusCode == 200) {
        var data = jsonDecode(response.body);
        if (data['status'] == 'success') _fetchAllData();
      }
    } catch (e) {}
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
        animation: AppTheme.instance,
        builder: (context, child) {
          final theme = AppTheme.instance;
          if (_isLoading) return Center(child: Padding(padding: const EdgeInsets.only(top: 100), child: CircularProgressIndicator(color: theme.primaryColor)));
          return SingleChildScrollView(
            key: const ValueKey('ProjectMembers'), physics: const BouncingScrollPhysics(), padding: const EdgeInsets.all(50.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AnimatedDefaultTextStyle(duration: const Duration(milliseconds: 300), style: TextStyle(fontSize: 28 * theme.fontScale, fontWeight: FontWeight.w900, color: theme.textColor, letterSpacing: 1.0, fontFamily: 'Segoe UI'), child: const Text("Thành Viên & Phân Quyền")), const SizedBox(height: 8),
                AnimatedDefaultTextStyle(duration: const Duration(milliseconds: 300), style: TextStyle(fontSize: 14 * theme.fontScale, color: theme.subTextColor, fontFamily: 'Segoe UI'), child: const Text("Quản lý danh sách thành viên dự án và duyệt các yêu cầu tham gia mới.")), const SizedBox(height: 40),

                Container(
                  padding: const EdgeInsets.all(6), decoration: BoxDecoration(color: theme.textColor.withOpacity(0.02), borderRadius: BorderRadius.circular(16), border: Border.all(color: theme.borderColor)),
                  child: Row(
                    children: [
                      Expanded(child: _buildTabButton("THÀNH VIÊN HIỆN TẠI", Icons.people_alt_rounded, 0, theme)),
                      Expanded(child: _buildTabButton("YÊU CẦU XÉT DUYỆT", Icons.pending_actions_rounded, 1, theme, badgeCount: pendingRequests.length)),
                    ],
                  ),
                ), const SizedBox(height: 30),
                AnimatedSwitcher(duration: const Duration(milliseconds: 400), switchInCurve: Curves.easeInOut, switchOutCurve: Curves.easeInOut, child: _currentTab == 0 ? _buildMembersListTab(theme) : _buildPendingRequestsTab(theme))
              ],
            ),
          );
        }
    );
  }

  Widget _buildTabButton(String title, IconData icon, int tabIndex, AppTheme theme, {int? badgeCount}) {
    bool isSelected = _currentTab == tabIndex;
    return GestureDetector(
      onTap: () {
        setState(() => _currentTab = tabIndex);
        if (tabIndex == 1) _fetchAllData();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300), padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(color: isSelected ? theme.primaryColor.withOpacity(0.15) : Colors.transparent, borderRadius: BorderRadius.circular(12), border: Border.all(color: isSelected ? theme.primaryColor.withOpacity(0.5) : Colors.transparent)),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: isSelected ? theme.primaryColor : theme.subTextColor, size: 18 * theme.fontScale), const SizedBox(width: 10),
            AnimatedDefaultTextStyle(duration: const Duration(milliseconds: 300), style: TextStyle(color: isSelected ? theme.primaryColor : theme.subTextColor, fontWeight: FontWeight.bold, fontSize: 13 * theme.fontScale, letterSpacing: 1.0, fontFamily: 'Segoe UI'), child: Text(title)),
            if (badgeCount != null && badgeCount > 0) ...[const SizedBox(width: 8), Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2), decoration: BoxDecoration(color: theme.warningColor.withOpacity(0.2), borderRadius: BorderRadius.circular(10)), child: Text("$badgeCount", style: TextStyle(color: theme.warningColor, fontSize: 11 * theme.fontScale, fontWeight: FontWeight.bold)))]
          ],
        ),
      ),
    );
  }

  Widget _buildMembersListTab(AppTheme theme) {
    List<dynamic> allMembers = [...activeAdmins, ...activeManagers];

    // 1. LỌC DANH SÁCH GIÁO VIÊN CHỦ NHIỆM
    List<dynamic> homeroomTeachers = allMembers.where((m) {
      String id1 = m['id']?.toString() ?? "";
      String id2 = m['user_id']?.toString() ?? "";
      bool isAssigned = _teacherClassMap.containsKey(id1) || _teacherClassMap.containsKey(id2);
      bool hasRole = (m['role'] ?? '').toString().toLowerCase().contains('chủ nhiệm') || (m['role'] ?? '').toString().toLowerCase().contains('unit manager');
      return isAssigned || hasRole;
    }).toList();

    // 2. LỌC DANH SÁCH BỘ MÔN VÀ CHỨC VỤ KHÁC (Tách bạch các quyền)
    List<dynamic> otherTeachers = allMembers.where((m) {
      String roleStr = (m['role'] ?? '').toString();

      // Kiểm tra có dạy bộ môn không
      bool hasSubject = (m['teaching_subject'] != null && m['teaching_subject'].toString().trim().isNotEmpty) || roleStr.toLowerCase().contains('bộ môn');

      // Tách các role ra để xem có chức vụ "Khác" (VD: Bí thư, Giám thị...) không
      List<String> roleParts = roleStr.split('&').map((e) => e.trim()).toList();
      bool hasOtherRole = roleParts.any((r) =>
      r != 'Super Admin' &&
          r != 'Giáo viên bộ môn' &&
          r != 'GVCN' &&
          r != 'Thành viên' &&
          r.isNotEmpty
      );

      // Nếu có dạy Bộ môn HOẶC có Chức vụ khác -> Hiển thị ở mục này
      return hasSubject || hasOtherRole;
    }).toList();

    return Column(
      key: const ValueKey('TabMembers'), crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // KHỐI 1: SUPER ADMIN
        Container(
          padding: const EdgeInsets.all(30), decoration: BoxDecoration(color: theme.cardColor, borderRadius: BorderRadius.circular(20), border: Border.all(color: theme.borderColor), boxShadow: theme.isDarkMode ? [] : [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 20, offset: const Offset(0, 10))]),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [Icon(Icons.admin_panel_settings_rounded, color: theme.primaryColor, size: 24 * theme.fontScale), const SizedBox(width: 10), AnimatedDefaultTextStyle(duration: const Duration(milliseconds: 300), style: TextStyle(color: theme.textColor, fontSize: 16 * theme.fontScale, fontWeight: FontWeight.bold, letterSpacing: 1.2, fontFamily: 'Segoe UI'), child: const Text("QUẢN TRỊ VIÊN (SUPER ADMIN)"))]), const SizedBox(height: 20),
              if (activeAdmins.isEmpty) Text("Chưa có Quản trị viên nào.", style: TextStyle(color: theme.subTextColor, fontSize: 13 * theme.fontScale, fontStyle: FontStyle.italic))
              else ...activeAdmins.asMap().entries.map((entry) => _buildMemberItem(entry.value, theme, sectionType: 'admin'))
            ],
          ),
        ), const SizedBox(height: 30),

        // KHỐI 2: GIÁO VIÊN BỘ MÔN & KHÁC
        Container(
          padding: const EdgeInsets.all(30), decoration: BoxDecoration(color: theme.cardColor, borderRadius: BorderRadius.circular(20), border: Border.all(color: theme.borderColor), boxShadow: theme.isDarkMode ? [] : [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 20, offset: const Offset(0, 10))]),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [Icon(Icons.manage_accounts_rounded, color: theme.purpleColor, size: 24 * theme.fontScale), const SizedBox(width: 10), AnimatedDefaultTextStyle(duration: const Duration(milliseconds: 300), style: TextStyle(color: theme.textColor, fontSize: 16 * theme.fontScale, fontWeight: FontWeight.bold, letterSpacing: 1.2, fontFamily: 'Segoe UI'), child: const Text("GIÁO VIÊN BỘ MÔN & CHỨC VỤ KHÁC"))]), const SizedBox(height: 20),
              if (otherTeachers.isEmpty) Text("Chưa có giáo viên bộ môn hoặc chức vụ khác.", style: TextStyle(color: theme.subTextColor, fontSize: 13 * theme.fontScale, fontStyle: FontStyle.italic))
              else ...otherTeachers.asMap().entries.map((entry) => _buildMemberItem(entry.value, theme, sectionType: 'subject_other'))
            ],
          ),
        ), const SizedBox(height: 30),

        // KHỐI 3: GIÁO VIÊN CHỦ NHIỆM
        Container(
          padding: const EdgeInsets.all(30), decoration: BoxDecoration(color: theme.cardColor, borderRadius: BorderRadius.circular(20), border: Border.all(color: theme.borderColor), boxShadow: theme.isDarkMode ? [] : [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 20, offset: const Offset(0, 10))]),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [Icon(Icons.assignment_ind_rounded, color: theme.successColor, size: 24 * theme.fontScale), const SizedBox(width: 10), AnimatedDefaultTextStyle(duration: const Duration(milliseconds: 300), style: TextStyle(color: theme.textColor, fontSize: 16 * theme.fontScale, fontWeight: FontWeight.bold, letterSpacing: 1.2, fontFamily: 'Segoe UI'), child: const Text("GIÁO VIÊN CHỦ NHIỆM LỚP"))]), const SizedBox(height: 20),
              if (homeroomTeachers.isEmpty) Text("Chưa có ai được phân công chủ nhiệm. (Gán tại trang Quản lý lớp học)", style: TextStyle(color: theme.subTextColor, fontSize: 13 * theme.fontScale, fontStyle: FontStyle.italic))
              else ...homeroomTeachers.asMap().entries.map((entry) => _buildMemberItem(entry.value, theme, sectionType: 'homeroom'))
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMemberItem(dynamic member, AppTheme theme, {required String sectionType}) {
    Map<String, dynamic> m = (member != null && member is Map) ? Map<String, dynamic>.from(member) : {};
    if (m.isEmpty) return const SizedBox();

    String mId1 = m['id']?.toString() ?? "";
    String mId2 = m['user_id']?.toString() ?? "";
    String assignedClass = _teacherClassMap[mId1] ?? _teacherClassMap[mId2] ?? "";
    String originalRole = m["role"] ?? "Chưa phân công";
    String teachingSubject = m['teaching_subject']?.toString() ?? "";

    // XÁC ĐỊNH NGƯỜI NÀY CÓ QUYỀN ADMIN THỰC SỰ HAY KHÔNG (Dùng cho Dialog và Xóa/Sửa)
    bool isActuallyAdmin = activeAdmins.any((admin) => admin['id']?.toString() == mId1 || (admin['user_id'] != null && admin['user_id']?.toString() == mId2));

    String displayRole = "";
    Color badgeColor = theme.primaryColor;

    // =======================================================
    // KÍNH LỌC HIỂN THỊ: CHỈ HIỆN NHỮNG GÌ MỤC ĐÓ CẦN THẤY
    // =======================================================
    if (sectionType == 'admin') {
      displayRole = "Super Admin";
      badgeColor = theme.primaryColor;
    }
    else if (sectionType == 'homeroom') {
      displayRole = assignedClass.isNotEmpty ? "GVCN: $assignedClass" : "GVCN (Chưa gán lớp)";
      badgeColor = theme.successColor;
    }
    else if (sectionType == 'subject_other') {
      List<String> tags = [];

      if (teachingSubject.isNotEmpty) {
        tags.add("Bộ môn: $teachingSubject");
      } else if (originalRole.toLowerCase().contains('bộ môn')) {
        tags.add("Giáo viên bộ môn");
      }

      // Lọc lấy các chức vụ Khác (Bí thư, Giám thị...)
      List<String> roleParts = originalRole.split('&').map((e) => e.trim()).toList();
      List<String> customRoles = roleParts.where((r) =>
      r != 'Super Admin' &&
          r != 'Giáo viên bộ môn' &&
          r != 'GVCN' &&
          r != 'Thành viên' &&
          r.isNotEmpty
      ).toList();

      if (customRoles.isNotEmpty) tags.addAll(customRoles);

      displayRole = tags.join(" | ");
      if (displayRole.isEmpty) displayRole = "Giáo viên / Nhân sự";

      badgeColor = theme.purpleColor;
    }

    String avatarUrl = m["avatar_url"]?.toString() ?? "";

    return Container(
      margin: const EdgeInsets.only(bottom: 15), decoration: BoxDecoration(color: theme.textColor.withOpacity(0.02), borderRadius: BorderRadius.circular(16), border: Border.all(color: theme.borderColor)),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16), hoverColor: badgeColor.withOpacity(0.05),
          onTap: () {
            // Khi bấm vào Profile, vẫn hiển thị ĐẦY ĐỦ TẤT CẢ chức vụ
            String fullRoleDesc = originalRole;
            if (assignedClass.isNotEmpty && !originalRole.contains(assignedClass)) fullRoleDesc += " | CN: $assignedClass";
            if (teachingSubject.isNotEmpty && !originalRole.contains(teachingSubject)) fullRoleDesc += " | Dạy: $teachingSubject";

            showDialog(
              context: context,
              builder: (context) => MemberProfileDialog(
                isAdmin: isActuallyAdmin,
                memberData: {
                  "avatar_url": avatarUrl, "name": m["name"]?.toString() ?? "Không tên", "email": m["email"]?.toString() ?? "",
                  "role": fullRoleDesc, "dob": m["dob"] ?? "Chưa cập nhật", "phone": m["phone"] ?? "Chưa cập nhật",
                  "hometown": m["hometown"] ?? "Chưa cập nhật", "currentAddress": m["current_address"] ?? "Chưa cập nhật",
                  "religion": m["religion"] ?? "Chưa cập nhật", "facebook": m["facebook"] ?? "Chưa liên kết",
                  "jobRole": m["position"] ?? fullRoleDesc, "degree": m["degree"] ?? "---", "school": m["school"] ?? "---",
                  "dynamic_1": m["dynamic_1"]?.toString() ?? "", "dynamic_2": m["dynamic_2"]?.toString() ?? "", "dynamic_3": m["dynamic_3"]?.toString() ?? ""
                },
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                avatarUrl.isNotEmpty ? CircleAvatar(radius: 20 * theme.fontScale, backgroundImage: NetworkImage("http://127.0.0.1:8000$avatarUrl")) : CircleAvatar(radius: 20 * theme.fontScale, backgroundColor: badgeColor.withOpacity(0.2), child: Icon(Icons.person, color: badgeColor, size: 20 * theme.fontScale)), const SizedBox(width: 20),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(m["name"]?.toString() ?? "Không tên", style: TextStyle(color: theme.textColor, fontSize: 15 * theme.fontScale, fontWeight: FontWeight.bold)), const SizedBox(height: 4), Text(m["email"]?.toString() ?? "", style: TextStyle(color: theme.subTextColor, fontSize: 12 * theme.fontScale))])),

                // HIỂN THỊ HUY HIỆU ĐÃ ĐƯỢC LỌC GỌN GÀNG
                Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), decoration: BoxDecoration(color: badgeColor.withOpacity(0.1), borderRadius: BorderRadius.circular(8), border: Border.all(color: badgeColor.withOpacity(0.3))), child: Text(displayRole, style: TextStyle(color: badgeColor, fontSize: 12 * theme.fontScale, fontWeight: FontWeight.bold))),
                const SizedBox(width: 10),

                if (widget.isSuperAdmin)
                  PopupMenuButton<String>(
                    icon: Icon(Icons.more_vert_rounded, color: theme.subTextColor, size: 20 * theme.fontScale), color: theme.cardColor, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: theme.borderColor)),
                    onSelected: (value) {
                      if (value == 'edit') { _showAssignOrEditRoleDialog(context, m, theme, isEdit: true); }
                      else if (value == 'delete') { _showDeleteConfirmDialog(context, m['id'], m["name"]?.toString() ?? "Người dùng", theme); }
                    },
                    itemBuilder: (context) => [
                      PopupMenuItem(value: 'edit', child: Row(children: [Icon(Icons.edit_rounded, color: theme.textColor, size: 16 * theme.fontScale), const SizedBox(width: 10), Text("Đổi quyền / Vai trò", style: TextStyle(color: theme.textColor, fontSize: 13 * theme.fontScale))])), const PopupMenuDivider(),
                      PopupMenuItem(value: 'delete', child: Row(children: [Icon(Icons.delete_forever_rounded, color: theme.errorColor, size: 16 * theme.fontScale), const SizedBox(width: 10), Text("Xóa thành viên", style: TextStyle(color: theme.errorColor, fontSize: 13 * theme.fontScale))])),
                    ],
                  )
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPendingRequestsTab(AppTheme theme) {
    return Container(
      key: const ValueKey('TabPending'), padding: const EdgeInsets.all(30), decoration: BoxDecoration(color: theme.cardColor, borderRadius: BorderRadius.circular(20), border: Border.all(color: theme.borderColor), boxShadow: theme.isDarkMode ? [] : [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 20, offset: const Offset(0, 10))]),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(children: [Icon(Icons.pending_actions_rounded, color: theme.warningColor, size: 24 * theme.fontScale), const SizedBox(width: 10), AnimatedDefaultTextStyle(duration: const Duration(milliseconds: 300), style: TextStyle(color: theme.textColor, fontSize: 16 * theme.fontScale, fontWeight: FontWeight.bold, letterSpacing: 1.2, fontFamily: 'Segoe UI'), child: const Text("DANH SÁCH CHỜ DUYỆT"))]),
              IconButton(onPressed: _fetchAllData, icon: Icon(Icons.sync_rounded, color: theme.primaryColor), tooltip: "Làm mới yêu cầu")
            ],
          ),
          const SizedBox(height: 25),
          if (pendingRequests.isEmpty) Center(child: Padding(padding: const EdgeInsets.all(40.0), child: Text("Không có yêu cầu tham gia nào đang chờ.", style: TextStyle(color: theme.subTextColor, fontSize: 14 * theme.fontScale, fontStyle: FontStyle.italic))))
          else ...pendingRequests.asMap().entries.map((entry) => _buildRequestItem(entry.key, entry.value, theme))
        ],
      ),
    );
  }

  Widget _buildRequestItem(int index, dynamic req, AppTheme theme) {
    Map<String, dynamic> r = (req != null && req is Map) ? Map<String, dynamic>.from(req) : {};
    if (r.isEmpty) return const SizedBox();

    String avatarUrl = r["avatar_url"]?.toString() ?? "";

    return Container(
      margin: const EdgeInsets.only(bottom: 15), decoration: BoxDecoration(color: theme.textColor.withOpacity(0.02), borderRadius: BorderRadius.circular(16), border: Border.all(color: theme.borderColor)),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16), hoverColor: theme.warningColor.withOpacity(0.05),
          onTap: () {
            showDialog(context: context, builder: (context) => MemberProfileDialog(
                isAdmin: false,
                memberData: {
                  "avatar_url": avatarUrl, "name": r["name"]?.toString() ?? "Không tên", "email": r["email"]?.toString() ?? "",
                  "role": "Đang chờ duyệt", "dob": r["dob"] ?? "Chưa cập nhật", "phone": r["phone"] ?? "Chưa cập nhật",
                  "hometown": r["hometown"] ?? "Chưa cập nhật", "currentAddress": r["current_address"] ?? "Chưa cập nhật",
                  "religion": r["religion"] ?? "Chưa cập nhật", "facebook": r["facebook"] ?? "Chưa liên kết",
                  "jobRole": r["position"] ?? "Ứng viên", "degree": r["degree"] ?? "---", "school": r["school"] ?? "---",
                  "dynamic_1": r["dynamic_1"]?.toString() ?? "", "dynamic_2": r["dynamic_2"]?.toString() ?? "", "dynamic_3": r["dynamic_3"]?.toString() ?? ""
                }
            ));
          },
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                avatarUrl.isNotEmpty ? CircleAvatar(radius: 20 * theme.fontScale, backgroundImage: NetworkImage("http://127.0.0.1:8000$avatarUrl")) : CircleAvatar(radius: 20 * theme.fontScale, backgroundColor: theme.warningColor.withOpacity(0.2), child: Icon(Icons.person, color: theme.warningColor, size: 20 * theme.fontScale)), const SizedBox(width: 20),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(r["name"]?.toString() ?? "Không tên", style: TextStyle(color: theme.textColor, fontSize: 15 * theme.fontScale, fontWeight: FontWeight.bold)), const SizedBox(height: 4), Text("${r["email"] ?? ""}", style: TextStyle(color: theme.subTextColor, fontSize: 12 * theme.fontScale))])),

                // CHỈ SUPER ADMIN MỚI THẤY NÚT DUYỆT/TỪ CHỐI
                if (widget.isSuperAdmin) ...[
                  OutlinedButton.icon(onPressed: () => _deleteMember(r["id"]), icon: Icon(Icons.close_rounded, color: theme.errorColor, size: 16 * theme.fontScale), label: Text("Từ chối", style: TextStyle(color: theme.errorColor, fontSize: 12 * theme.fontScale, fontWeight: FontWeight.bold)), style: OutlinedButton.styleFrom(side: BorderSide(color: theme.errorColor.withOpacity(0.5)), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)))), const SizedBox(width: 15),
                  ElevatedButton.icon(onPressed: () => _showAssignOrEditRoleDialog(context, r, theme, isEdit: false), icon: Icon(Icons.check_rounded, color: Colors.white, size: 16 * theme.fontScale), label: Text("Cấp quyền", style: TextStyle(color: Colors.white, fontSize: 12 * theme.fontScale, fontWeight: FontWeight.bold)), style: ElevatedButton.styleFrom(backgroundColor: theme.successColor, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)))),
                ] else
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(color: theme.warningColor.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                    child: Text("Đang chờ Admin duyệt", style: TextStyle(color: theme.warningColor, fontWeight: FontWeight.bold, fontSize: 12 * theme.fontScale)),
                  )
              ],
            ),
          ),
        ),
      ),
    );
  }

  // WIDGET AUTOCOMPLETE TÌM KIẾM MÔN HỌC
  Widget _buildSubjectAutocomplete(String initial, Function(String) onChanged, AppTheme theme, List<String> options) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("Môn giảng dạy", style: TextStyle(color: theme.textColor, fontSize: 12 * theme.fontScale, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Autocomplete<String>(
          initialValue: TextEditingValue(text: initial),
          optionsBuilder: (TextEditingValue textEditingValue) {
            if (textEditingValue.text == '') {
              return options; // Mặc định xổ hết danh sách
            }
            return options.where((String option) {
              return option.toLowerCase().contains(textEditingValue.text.toLowerCase());
            });
          },
          onSelected: (String selection) {
            onChanged(selection);
          },
          fieldViewBuilder: (context, controller, focusNode, onEditingComplete) {
            controller.addListener(() {
              onChanged(controller.text);
            });
            return TextFormField(
              controller: controller,
              focusNode: focusNode,
              style: TextStyle(color: theme.textColor, fontSize: 13 * theme.fontScale),
              decoration: InputDecoration(
                hintText: "Gõ để tìm hoặc chọn môn học...",
                hintStyle: TextStyle(color: theme.subTextColor),
                filled: true,
                fillColor: theme.textColor.withOpacity(0.04),
                contentPadding: const EdgeInsets.symmetric(horizontal: 15),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: theme.borderColor)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: theme.primaryColor)),
                suffixIcon: Icon(Icons.arrow_drop_down, color: theme.primaryColor),
              ),
            );
          },
          optionsViewBuilder: (context, onSelected, options) {
            return Align(
              alignment: Alignment.topLeft,
              child: Material(
                elevation: 4.0,
                color: theme.cardColor,
                borderRadius: BorderRadius.circular(10),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 250, maxWidth: 430),
                  child: ListView.builder(
                    padding: EdgeInsets.zero,
                    shrinkWrap: true,
                    itemCount: options.length,
                    itemBuilder: (BuildContext context, int index) {
                      final String option = options.elementAt(index);
                      return InkWell(
                        onTap: () => onSelected(option),
                        child: Container(
                          padding: const EdgeInsets.all(16.0),
                          decoration: BoxDecoration(border: Border(bottom: BorderSide(color: theme.borderColor.withOpacity(0.5)))),
                          child: Text(option, style: TextStyle(color: theme.textColor, fontWeight: FontWeight.bold)),
                        ),
                      );
                    },
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  void _showAssignOrEditRoleDialog(BuildContext context, dynamic member, AppTheme theme, {required bool isEdit}) {
    showDialog(
        context: context,
        builder: (context) {
          String currentRoleStr = member['role'] ?? '';

          bool isSuperAdmin = currentRoleStr.contains('Admin');
          bool isSubjectTeacher = currentRoleStr.contains('bộ môn') || currentRoleStr.contains('Subject');

          bool isOtherRole = currentRoleStr.isNotEmpty && !isSuperAdmin && !isSubjectTeacher && !currentRoleStr.contains('Unit Manager') && !currentRoleStr.contains('Chủ nhiệm');

          bool wasHomeroomTeacher = currentRoleStr.contains('Unit Manager') || currentRoleStr.contains('Chủ nhiệm');

          String teachingSubject = member['teaching_subject'] ?? '';
          String customRole = isOtherRole ? currentRoleStr : '';

          return StatefulBuilder(
              builder: (context, setStateDialog) {
                return Dialog(
                  backgroundColor: theme.cardColor, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24), side: BorderSide(color: theme.borderColor)),
                  child: Container(
                    width: 500, padding: const EdgeInsets.all(35),
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      child: Column(
                        mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(isEdit ? "Chỉnh sửa quyền hạn" : "Gán quyền truy cập", style: TextStyle(color: theme.textColor, fontSize: 20 * theme.fontScale, fontWeight: FontWeight.w900)), const SizedBox(height: 10), Text("Tài khoản: ${member['name']}", style: TextStyle(color: theme.primaryColor, fontSize: 13 * theme.fontScale, fontWeight: FontWeight.bold)), const SizedBox(height: 30),

                          Text("CHỌN VAI TRÒ (Có thể chọn nhiều)", style: TextStyle(color: theme.subTextColor, fontWeight: FontWeight.bold, fontSize: 11 * theme.fontScale)),
                          const SizedBox(height: 10),

                          _buildRoleCheckboxCard("Quản trị viên (Super Admin)", "Quản lý toàn bộ hệ thống dự án.", isSuperAdmin, (v) => setStateDialog(() => isSuperAdmin = v!), theme),
                          const SizedBox(height: 15),

                          _buildRoleCheckboxCard("Giáo viên bộ môn", "Chỉ xem TKB và điểm danh môn mình dạy.", isSubjectTeacher, (v) => setStateDialog(() => isSubjectTeacher = v!), theme),
                          AnimatedSize(
                            duration: const Duration(milliseconds: 300),
                            // SỬ DỤNG AUTOCOMPLETE THÔNG MINH ĐỂ CHỌN MÔN HỌC
                            child: isSubjectTeacher
                                ? Padding(padding: const EdgeInsets.only(top: 15.0, bottom: 10), child: _buildSubjectAutocomplete(teachingSubject, (v) => teachingSubject = v, theme, _standardSubjects))
                                : const SizedBox.shrink(),
                          ),
                          const SizedBox(height: 15),

                          _buildRoleCheckboxCard("Chức vụ khác", "Thêm các vai trò tùy chỉnh khác.", isOtherRole, (v) => setStateDialog(() => isOtherRole = v!), theme),
                          AnimatedSize(
                            duration: const Duration(milliseconds: 300),
                            child: isOtherRole ? Padding(padding: const EdgeInsets.only(top: 15.0, bottom: 10), child: _buildDialogTextField("Nhập tên chức vụ (VD: Giám thị, Bí thư)", customRole, (v) => customRole = v, theme)) : const SizedBox.shrink(),
                          ),

                          const SizedBox(height: 40),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              TextButton(onPressed: () => Navigator.pop(context), child: Text("Hủy", style: TextStyle(color: theme.subTextColor, fontWeight: FontWeight.bold, fontSize: 13 * theme.fontScale))), const SizedBox(width: 15),
                              ElevatedButton(
                                onPressed: () async {
                                  if (isSubjectTeacher && teachingSubject.trim().isEmpty) {
                                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Vui lòng chọn hoặc nhập tên môn giảng dạy!"), backgroundColor: Colors.orange));
                                    return;
                                  }
                                  if (isOtherRole && customRole.trim().isEmpty) {
                                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Vui lòng nhập tên chức vụ khác!"), backgroundColor: Colors.orange));
                                    return;
                                  }

                                  List<String> combinedRoles = [];
                                  if (isSuperAdmin) combinedRoles.add("Super Admin");
                                  if (isSubjectTeacher) combinedRoles.add("Giáo viên bộ môn");
                                  if (isOtherRole) combinedRoles.add(customRole.trim());
                                  if (wasHomeroomTeacher && !combinedRoles.contains("Super Admin")) combinedRoles.add("GVCN");

                                  String finalRoleString = combinedRoles.isEmpty ? "Thành viên" : combinedRoles.join(" & ");

                                  try {
                                    Map<String, dynamic> payload = {
                                      "status": "Hoạt động",
                                      "role": finalRoleString,
                                      "teaching_subject": isSubjectTeacher ? teachingSubject.trim() : null
                                    };

                                    var response = await http.put(Uri.parse('http://127.0.0.1:8000/api/members/${member['id']}'), headers: {"Content-Type": "application/json"}, body: jsonEncode(payload));
                                    if (response.statusCode == 200) { _fetchAllData(); if (context.mounted) Navigator.pop(context); }
                                  } catch (e) {}
                                },
                                style: ElevatedButton.styleFrom(backgroundColor: theme.primaryColor, padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))), child: Text(isEdit ? "Cập nhật quyền" : "Xác nhận & Cấp quyền", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13 * theme.fontScale)),
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

  Widget _buildRoleCheckboxCard(String title, String desc, bool value, Function(bool?) onChanged, AppTheme theme) {
    return GestureDetector(
      onTap: () => onChanged(!value),
      child: AnimatedContainer(
          duration: const Duration(milliseconds: 300), padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(color: value ? theme.primaryColor.withOpacity(0.1) : Colors.transparent, borderRadius: BorderRadius.circular(12), border: Border.all(color: value ? theme.primaryColor : theme.borderColor)),
          child: Row(children: [
            Checkbox(value: value, activeColor: theme.primaryColor, onChanged: onChanged),
            const SizedBox(width: 10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: TextStyle(color: theme.textColor, fontSize: 14 * theme.fontScale, fontWeight: FontWeight.bold)), const SizedBox(height: 4), Text(desc, style: TextStyle(color: theme.subTextColor, fontSize: 12 * theme.fontScale))]))
          ])
      ),
    );
  }

  Widget _buildDialogTextField(String label, String value, Function(String) onChanged, AppTheme theme) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: TextStyle(color: theme.textColor, fontSize: 12 * theme.fontScale, fontWeight: FontWeight.bold)),
      const SizedBox(height: 8),
      TextFormField(initialValue: value, onChanged: onChanged, style: TextStyle(color: theme.textColor, fontSize: 13 * theme.fontScale), decoration: InputDecoration(filled: true, fillColor: theme.textColor.withOpacity(0.04), contentPadding: const EdgeInsets.symmetric(horizontal: 15), enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: theme.borderColor)), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: theme.primaryColor))))
    ]);
  }

  void _showDeleteConfirmDialog(BuildContext context, int memberId, String userName, AppTheme theme) {
    showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
            backgroundColor: theme.cardColor, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: theme.errorColor.withOpacity(0.5))),
            title: Row(children: [Icon(Icons.warning_amber_rounded, color: theme.errorColor, size: 24 * theme.fontScale), const SizedBox(width: 10), Text("Xóa thành viên", style: TextStyle(color: theme.textColor, fontSize: 18 * theme.fontScale, fontWeight: FontWeight.bold))]),
            content: Text("Bạn có chắc chắn muốn xóa '$userName' khỏi dự án này không? Họ sẽ mất toàn quyền truy cập hệ thống.", style: TextStyle(color: theme.subTextColor, fontSize: 13 * theme.fontScale, height: 1.5)),
            actionsPadding: const EdgeInsets.only(right: 20, bottom: 20),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: Text("Hủy bỏ", style: TextStyle(color: theme.subTextColor, fontWeight: FontWeight.bold, fontSize: 13 * theme.fontScale))),
              ElevatedButton(onPressed: () { _deleteMember(memberId); Navigator.pop(context); }, style: ElevatedButton.styleFrom(backgroundColor: theme.errorColor, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))), child: Text("Xóa ngay", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13 * theme.fontScale)))
            ],
          );
        }
    );
  }
}