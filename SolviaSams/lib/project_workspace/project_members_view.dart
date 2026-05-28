import 'package:flutter/material.dart';
import '../theme_manager.dart';
import '../shared/member_profile_dialog.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../globals.dart' as globals;

class ProjectMembersView extends StatefulWidget {
  const ProjectMembersView({super.key});

  @override
  State<ProjectMembersView> createState() => _ProjectMembersViewState();
}

class _ProjectMembersViewState extends State<ProjectMembersView> {
  int _currentTab = 0;
  bool _isLoading = true;
  List<dynamic> activeAdmins = [];
  List<dynamic> activeManagers = [];
  List<dynamic> pendingRequests = [];
  List<String> _availableClasses = ['Lớp 10A1', 'Lớp 10A2'];

  @override
  void initState() {
    super.initState();
    _fetchMembers();
    _fetchClasses();
  }

  Future<void> _fetchMembers() async {
    try {
      var response = await http.get(Uri.parse('http://127.0.0.1:8000/api/projects/${globals.currentProjectId}/members'));
      if (response.statusCode == 200) {
        var data = jsonDecode(utf8.decode(response.bodyBytes));
        if (data['status'] == 'success') {
          if (mounted) {
            setState(() {
              activeAdmins = data['data']['admins'] ?? [];
              activeManagers = data['data']['managers'] ?? [];
              pendingRequests = data['data']['pending'] ?? [];
              _isLoading = false;
            });
          }
          return;
        }
      }
    } catch (e) {
      debugPrint("Lỗi: $e");
    }
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _fetchClasses() async {
    try {
      var response = await http.get(Uri.parse('http://127.0.0.1:8000/api/projects/${globals.currentProjectId}/classes'));
      if (response.statusCode == 200) {
        var data = jsonDecode(utf8.decode(response.bodyBytes));
        if (data['status'] == 'success' && mounted) {
          setState(() {
            if ((data['data'] as List).isNotEmpty) {
              _availableClasses = (data['data'] as List).map((c) => c['class_name'].toString()).toList();
            }
          });
        }
      }
    } catch (e) {}
  }

  Future<void> _deleteMember(int memberId) async {
    try {
      var response = await http.delete(Uri.parse('http://127.0.0.1:8000/api/members/$memberId'));
      if (response.statusCode == 200) {
        var data = jsonDecode(response.body);
        if (data['status'] == 'success') _fetchMembers();
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
                  padding: const EdgeInsets.all(6), decoration: BoxDecoration(color: theme.isDarkMode ? Colors.white.withOpacity(0.02) : theme.textColor.withOpacity(0.03), borderRadius: BorderRadius.circular(16), border: Border.all(color: theme.isDarkMode ? Colors.white.withOpacity(0.05) : theme.borderColor)),
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
      onTap: () => setState(() => _currentTab = tabIndex),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300), padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(color: isSelected ? theme.primaryColor.withOpacity(0.15) : Colors.transparent, borderRadius: BorderRadius.circular(12), border: Border.all(color: isSelected ? theme.primaryColor.withOpacity(0.5) : Colors.transparent)),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: isSelected ? theme.primaryColor : (theme.isDarkMode ? Colors.white54 : Colors.black54), size: 18 * theme.fontScale), const SizedBox(width: 10),
            AnimatedDefaultTextStyle(duration: const Duration(milliseconds: 300), style: TextStyle(color: isSelected ? theme.primaryColor : (theme.isDarkMode ? Colors.white54 : Colors.black54), fontWeight: FontWeight.bold, fontSize: 13 * theme.fontScale, letterSpacing: 1.0, fontFamily: 'Segoe UI'), child: Text(title)),
            if (badgeCount != null && badgeCount > 0) ...[const SizedBox(width: 8), Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2), decoration: BoxDecoration(color: Colors.orangeAccent.withOpacity(0.2), borderRadius: BorderRadius.circular(10)), child: Text("$badgeCount", style: TextStyle(color: Colors.orangeAccent, fontSize: 11 * theme.fontScale, fontWeight: FontWeight.bold)))]
          ],
        ),
      ),
    );
  }

  Widget _buildMembersListTab(AppTheme theme) {
    return Column(
      key: const ValueKey('TabMembers'), crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(30), decoration: BoxDecoration(color: theme.isDarkMode ? Colors.white.withOpacity(0.015) : theme.cardColor, borderRadius: BorderRadius.circular(20), border: Border.all(color: theme.isDarkMode ? Colors.white.withOpacity(0.05) : theme.borderColor)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [Icon(Icons.admin_panel_settings_rounded, color: theme.primaryColor, size: 24 * theme.fontScale), const SizedBox(width: 10), AnimatedDefaultTextStyle(duration: const Duration(milliseconds: 300), style: TextStyle(color: theme.textColor, fontSize: 16 * theme.fontScale, fontWeight: FontWeight.bold, letterSpacing: 1.2, fontFamily: 'Segoe UI'), child: const Text("QUẢN TRỊ VIÊN (SUPER ADMIN)"))]), const SizedBox(height: 20),
              ...activeAdmins.asMap().entries.map((entry) => _buildMemberItem(entry.key, entry.value, true, theme))
            ],
          ),
        ), const SizedBox(height: 30),
        Container(
          padding: const EdgeInsets.all(30), decoration: BoxDecoration(color: theme.isDarkMode ? Colors.white.withOpacity(0.015) : theme.cardColor, borderRadius: BorderRadius.circular(20), border: Border.all(color: theme.isDarkMode ? Colors.white.withOpacity(0.05) : theme.borderColor)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [Icon(Icons.manage_accounts_rounded, color: Colors.greenAccent, size: 24 * theme.fontScale), const SizedBox(width: 10), AnimatedDefaultTextStyle(duration: const Duration(milliseconds: 300), style: TextStyle(color: theme.textColor, fontSize: 16 * theme.fontScale, fontWeight: FontWeight.bold, letterSpacing: 1.2, fontFamily: 'Segoe UI'), child: const Text("THÀNH VIÊN QUẢN LÝ (PHÂN KHU)"))]), const SizedBox(height: 20),
              if (activeManagers.isEmpty) Text("Chưa có thành viên quản lý nào.", style: TextStyle(color: theme.subTextColor, fontSize: 13 * theme.fontScale, fontStyle: FontStyle.italic))
              else ...activeManagers.asMap().entries.map((entry) => _buildMemberItem(entry.key, entry.value, false, theme))
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMemberItem(int index, dynamic member, bool isAdmin, AppTheme theme) {
    // BỌC THÉP LỚP 1: Ép kiểu an toàn để m KHÔNG BAO GIỜ bị Null
    Map<String, dynamic> m = (member != null && member is Map) ? Map<String, dynamic>.from(member) : {};
    if (m.isEmpty) return const SizedBox();

    Color badgeColor = isAdmin ? theme.primaryColor : Colors.greenAccent;
    String roleDesc = isAdmin ? (m["role"] ?? "Super Admin") : "Quản lý: ${m['unit'] ?? 'Chưa phân công'}";
    String avatarUrl = m["avatar_url"]?.toString() ?? "";

    return Container(
      margin: const EdgeInsets.only(bottom: 15), decoration: BoxDecoration(color: theme.isDarkMode ? Colors.white.withOpacity(0.03) : theme.cardColor, borderRadius: BorderRadius.circular(16), border: Border.all(color: theme.isDarkMode ? Colors.white.withOpacity(0.05) : theme.borderColor)),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16), hoverColor: badgeColor.withOpacity(0.05),
          onTap: () {
            showDialog(
              context: context,
              builder: (context) => MemberProfileDialog(
                isAdmin: isAdmin,
                memberData: {
                  "avatar_url": avatarUrl,
                  "name": m["name"]?.toString() ?? "Không tên",
                  "email": m["email"]?.toString() ?? "",
                  "role": roleDesc,
                  "dob": (m["dob"] != null && m["dob"].toString().isNotEmpty) ? m["dob"] : "Chưa cập nhật",
                  "phone": (m["phone"] != null && m["phone"].toString().isNotEmpty) ? m["phone"] : "Chưa cập nhật",
                  "hometown": (m["hometown"] != null && m["hometown"].toString().isNotEmpty) ? m["hometown"] : "Chưa cập nhật",
                  "currentAddress": (m["current_address"] != null && m["current_address"].toString().isNotEmpty) ? m["current_address"] : "Chưa cập nhật",
                  "religion": (m["religion"] != null && m["religion"].toString().isNotEmpty) ? m["religion"] : "Chưa cập nhật",
                  "facebook": (m["facebook"] != null && m["facebook"].toString().isNotEmpty) ? m["facebook"] : "Chưa liên kết",
                  "jobRole": (m["position"] != null && m["position"].toString().isNotEmpty) ? m["position"] : (isAdmin ? "Quản trị viên" : "Quản lý"),
                  "degree": (m["degree"] != null && m["degree"].toString().isNotEmpty) ? m["degree"] : "---",
                  "school": (m["school"] != null && m["school"].toString().isNotEmpty) ? m["school"] : "---",

                  // BỌC THÉP LỚP 2: Lấy dynamic an toàn tuyệt đối
                  "dynamic_1": m["dynamic_1"]?.toString() ?? "",
                  "dynamic_2": m["dynamic_2"]?.toString() ?? "",
                  "dynamic_3": m["dynamic_3"]?.toString() ?? ""
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
                Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), decoration: BoxDecoration(color: badgeColor.withOpacity(0.1), borderRadius: BorderRadius.circular(8), border: Border.all(color: badgeColor.withOpacity(0.3))), child: Text(roleDesc, style: TextStyle(color: badgeColor, fontSize: 12 * theme.fontScale, fontWeight: FontWeight.bold))), const SizedBox(width: 10),
                PopupMenuButton<String>(
                  icon: Icon(Icons.more_vert_rounded, color: theme.isDarkMode ? Colors.white54 : Colors.black54, size: 20 * theme.fontScale), color: const Color(0xFF101520), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: theme.primaryColor.withOpacity(0.3))),
                  onSelected: (value) {
                    if (value == 'edit') { _showEditRoleDialog(context, m, isAdmin, theme); }
                    else if (value == 'delete') { _showDeleteConfirmDialog(context, m['id'], m["name"]?.toString() ?? "Người dùng", theme); }
                  },
                  itemBuilder: (context) => [
                    PopupMenuItem(value: 'edit', child: Row(children: [Icon(Icons.edit_rounded, color: Colors.white70, size: 16 * theme.fontScale), const SizedBox(width: 10), Text("Đổi vai trò", style: TextStyle(color: Colors.white, fontSize: 13 * theme.fontScale))])), const PopupMenuDivider(),
                    PopupMenuItem(value: 'delete', child: Row(children: [Icon(Icons.delete_forever_rounded, color: Colors.redAccent, size: 16 * theme.fontScale), const SizedBox(width: 10), Text("Xóa thành viên", style: TextStyle(color: Colors.redAccent, fontSize: 13 * theme.fontScale))])),
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
      key: const ValueKey('TabPending'), padding: const EdgeInsets.all(30), decoration: BoxDecoration(color: theme.isDarkMode ? Colors.white.withOpacity(0.015) : theme.cardColor, borderRadius: BorderRadius.circular(20), border: Border.all(color: theme.isDarkMode ? Colors.white.withOpacity(0.05) : theme.borderColor)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [Icon(Icons.pending_actions_rounded, color: Colors.orangeAccent, size: 24 * theme.fontScale), const SizedBox(width: 10), AnimatedDefaultTextStyle(duration: const Duration(milliseconds: 300), style: TextStyle(color: theme.textColor, fontSize: 16 * theme.fontScale, fontWeight: FontWeight.bold, letterSpacing: 1.2, fontFamily: 'Segoe UI'), child: const Text("DANH SÁCH CHỜ DUYỆT"))]), const SizedBox(height: 25),
          if (pendingRequests.isEmpty) Center(child: Padding(padding: const EdgeInsets.all(40.0), child: Text("Không có yêu cầu tham gia nào đang chờ.", style: TextStyle(color: theme.subTextColor, fontSize: 14 * theme.fontScale, fontStyle: FontStyle.italic))))
          else ...pendingRequests.asMap().entries.map((entry) => _buildRequestItem(entry.key, entry.value, theme))
        ],
      ),
    );
  }

  Widget _buildRequestItem(int index, dynamic req, AppTheme theme) {
    // BỌC THÉP LỚP 1
    Map<String, dynamic> r = (req != null && req is Map) ? Map<String, dynamic>.from(req) : {};
    if (r.isEmpty) return const SizedBox();

    String avatarUrl = r["avatar_url"]?.toString() ?? "";

    return Container(
      margin: const EdgeInsets.only(bottom: 15), decoration: BoxDecoration(color: theme.isDarkMode ? Colors.white.withOpacity(0.03) : theme.cardColor, borderRadius: BorderRadius.circular(16), border: Border.all(color: theme.isDarkMode ? Colors.white.withOpacity(0.05) : theme.borderColor)),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16), hoverColor: Colors.orangeAccent.withOpacity(0.05),
          onTap: () {
            showDialog(context: context, builder: (context) => MemberProfileDialog(
                isAdmin: false,
                memberData: {
                  "avatar_url": avatarUrl,
                  "name": r["name"]?.toString() ?? "Không tên",
                  "email": r["email"]?.toString() ?? "",
                  "role": "Đang chờ duyệt",
                  "dob": (r["dob"] != null && r["dob"].toString().isNotEmpty) ? r["dob"] : "Chưa cập nhật",
                  "phone": (r["phone"] != null && r["phone"].toString().isNotEmpty) ? r["phone"] : "Chưa cập nhật",
                  "hometown": (r["hometown"] != null && r["hometown"].toString().isNotEmpty) ? r["hometown"] : "Chưa cập nhật",
                  "currentAddress": (r["current_address"] != null && r["current_address"].toString().isNotEmpty) ? r["current_address"] : "Chưa cập nhật",
                  "religion": (r["religion"] != null && r["religion"].toString().isNotEmpty) ? r["religion"] : "Chưa cập nhật",
                  "facebook": (r["facebook"] != null && r["facebook"].toString().isNotEmpty) ? r["facebook"] : "Chưa liên kết",
                  "jobRole": (r["position"] != null && r["position"].toString().isNotEmpty) ? r["position"] : "Ứng viên",
                  "degree": (r["degree"] != null && r["degree"].toString().isNotEmpty) ? r["degree"] : "---",
                  "school": (r["school"] != null && r["school"].toString().isNotEmpty) ? r["school"] : "---",

                  // BỌC THÉP LỚP 2
                  "dynamic_1": r["dynamic_1"]?.toString() ?? "",
                  "dynamic_2": r["dynamic_2"]?.toString() ?? "",
                  "dynamic_3": r["dynamic_3"]?.toString() ?? ""
                }
            ));
          },
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                avatarUrl.isNotEmpty ? CircleAvatar(radius: 20 * theme.fontScale, backgroundImage: NetworkImage("http://127.0.0.1:8000$avatarUrl")) : CircleAvatar(radius: 20 * theme.fontScale, backgroundColor: Colors.orangeAccent.withOpacity(0.2), child: Icon(Icons.person, color: Colors.orangeAccent, size: 20 * theme.fontScale)), const SizedBox(width: 20),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(r["name"]?.toString() ?? "Không tên", style: TextStyle(color: theme.textColor, fontSize: 15 * theme.fontScale, fontWeight: FontWeight.bold)), const SizedBox(height: 4), Text("${r["email"] ?? ""}", style: TextStyle(color: theme.subTextColor, fontSize: 12 * theme.fontScale))])),
                OutlinedButton.icon(onPressed: () => _deleteMember(r["id"]), icon: Icon(Icons.close_rounded, color: Colors.redAccent, size: 16 * theme.fontScale), label: Text("Từ chối", style: TextStyle(color: Colors.redAccent, fontSize: 12 * theme.fontScale, fontWeight: FontWeight.bold)), style: OutlinedButton.styleFrom(side: BorderSide(color: Colors.redAccent.withOpacity(0.5)), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)))), const SizedBox(width: 15),
                ElevatedButton.icon(onPressed: () => _showAssignRoleDialog(context, r, theme), icon: Icon(Icons.check_rounded, color: Colors.white, size: 16 * theme.fontScale), label: Text("Chấp nhận", style: TextStyle(color: Colors.white, fontSize: 12 * theme.fontScale, fontWeight: FontWeight.bold)), style: ElevatedButton.styleFrom(backgroundColor: Colors.greenAccent.shade700, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)))),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showAssignRoleDialog(BuildContext context, dynamic req, AppTheme theme) {
    showDialog(
        context: context,
        builder: (context) {
          String selectedRole = 'Admin';
          String selectedUnit = _availableClasses.isNotEmpty ? _availableClasses.first : 'Chưa có lớp';
          return StatefulBuilder(
              builder: (context, setStateDialog) {
                return Dialog(
                  backgroundColor: const Color(0xFF101520), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24), side: BorderSide(color: theme.primaryColor.withOpacity(0.3))),
                  child: Container(
                    width: 450, padding: const EdgeInsets.all(35),
                    child: Column(
                      mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("Gán quyền truy cập", style: TextStyle(color: Colors.white, fontSize: 20 * theme.fontScale, fontWeight: FontWeight.w900)), const SizedBox(height: 10), Text("Tài khoản: ${req['name']}", style: TextStyle(color: Colors.greenAccent, fontSize: 13 * theme.fontScale, fontWeight: FontWeight.bold)), const SizedBox(height: 30),
                        GestureDetector(onTap: () => setStateDialog(() => selectedRole = 'Admin'), child: Container(padding: const EdgeInsets.all(15), decoration: BoxDecoration(color: selectedRole == 'Admin' ? theme.primaryColor.withOpacity(0.15) : Colors.transparent, borderRadius: BorderRadius.circular(12), border: Border.all(color: selectedRole == 'Admin' ? theme.primaryColor : Colors.white.withOpacity(0.1))), child: Row(children: [Radio(value: 'Admin', groupValue: selectedRole, activeColor: theme.primaryColor, onChanged: (v) => setStateDialog(() => selectedRole = v.toString())), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text("Quản trị viên (Super Admin)", style: TextStyle(color: Colors.white, fontSize: 14 * theme.fontScale, fontWeight: FontWeight.bold)), const SizedBox(height: 4), Text("Quản lý toàn bộ hệ thống.", style: TextStyle(color: Colors.grey[500], fontSize: 12 * theme.fontScale))]))]))), const SizedBox(height: 15),
                        GestureDetector(onTap: () => setStateDialog(() => selectedRole = 'Unit Manager'), child: Container(padding: const EdgeInsets.all(15), decoration: BoxDecoration(color: selectedRole == 'Unit Manager' ? theme.primaryColor.withOpacity(0.15) : Colors.transparent, borderRadius: BorderRadius.circular(12), border: Border.all(color: selectedRole == 'Unit Manager' ? theme.primaryColor : Colors.white.withOpacity(0.1))), child: Row(children: [Radio(value: 'Unit Manager', groupValue: selectedRole, activeColor: theme.primaryColor, onChanged: (v) => setStateDialog(() => selectedRole = v.toString())), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text("Thành viên quản lý (Phân khu)", style: TextStyle(color: Colors.white, fontSize: 14 * theme.fontScale, fontWeight: FontWeight.bold)), const SizedBox(height: 4), Text("Chỉ có quyền xem và điểm danh khu vực được giao.", style: TextStyle(color: Colors.grey[500], fontSize: 12 * theme.fontScale))]))]))),
                        if (selectedRole == 'Unit Manager') Padding(padding: const EdgeInsets.only(top: 20.0), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text("Chỉ định Lớp quản lý", style: TextStyle(color: Colors.white70, fontSize: 12 * theme.fontScale, fontWeight: FontWeight.bold)), const SizedBox(height: 8), SizedBox(height: 45, child: DropdownButtonFormField<String>(value: selectedUnit, dropdownColor: const Color(0xFF0A101E), style: TextStyle(color: Colors.white, fontSize: 13 * theme.fontScale), icon: Icon(Icons.expand_more_rounded, color: theme.primaryColor), decoration: InputDecoration(contentPadding: const EdgeInsets.symmetric(horizontal: 15), filled: true, fillColor: Colors.black.withOpacity(0.3), enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.white.withOpacity(0.1))), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: theme.primaryColor))), items: (_availableClasses.isEmpty ? ['Chưa có lớp'] : _availableClasses).map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(), onChanged: (v) => setStateDialog(() => selectedUnit = v!)))])),
                        const SizedBox(height: 40),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            TextButton(onPressed: () => Navigator.pop(context), child: Text("Hủy", style: TextStyle(color: Colors.white54, fontWeight: FontWeight.bold, fontSize: 13 * theme.fontScale))), const SizedBox(width: 15),
                            ElevatedButton(
                              onPressed: () async {
                                try {
                                  var response = await http.put(Uri.parse('http://127.0.0.1:8000/api/members/${req['id']}'), headers: {"Content-Type": "application/json"}, body: jsonEncode({"status": "Hoạt động", "role": selectedRole, "unit": selectedRole == 'Unit Manager' ? selectedUnit : null}));
                                  if (response.statusCode == 200) { _fetchMembers(); if (context.mounted) Navigator.pop(context); }
                                } catch (e) {}
                              },
                              style: ElevatedButton.styleFrom(backgroundColor: theme.primaryColor, padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))), child: Text("Xác nhận & Cấp quyền", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13 * theme.fontScale)),
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

  void _showEditRoleDialog(BuildContext context, dynamic member, bool isCurrentlyAdmin, AppTheme theme) {
    showDialog(
        context: context,
        builder: (context) {
          String selectedRole = isCurrentlyAdmin ? 'Admin' : 'Unit Manager';
          String fallbackUnit = _availableClasses.isNotEmpty ? _availableClasses.first : 'Chưa có lớp';
          String selectedUnit = isCurrentlyAdmin ? fallbackUnit : (member['unit'] ?? fallbackUnit);
          if (!_availableClasses.contains(selectedUnit)) selectedUnit = fallbackUnit;

          return StatefulBuilder(
              builder: (context, setStateDialog) {
                return Dialog(
                  backgroundColor: const Color(0xFF101520), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24), side: BorderSide(color: theme.primaryColor.withOpacity(0.3))),
                  child: Container(
                    width: 450, padding: const EdgeInsets.all(35),
                    child: Column(
                      mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("Chỉnh sửa quyền hạn", style: TextStyle(color: Colors.white, fontSize: 20 * theme.fontScale, fontWeight: FontWeight.w900)), const SizedBox(height: 10), Text("Tài khoản: ${member['name']}", style: TextStyle(color: theme.primaryColor, fontSize: 13 * theme.fontScale, fontWeight: FontWeight.bold)), const SizedBox(height: 30),
                        GestureDetector(onTap: () => setStateDialog(() => selectedRole = 'Admin'), child: Container(padding: const EdgeInsets.all(15), decoration: BoxDecoration(color: selectedRole == 'Admin' ? theme.primaryColor.withOpacity(0.15) : Colors.transparent, borderRadius: BorderRadius.circular(12), border: Border.all(color: selectedRole == 'Admin' ? theme.primaryColor : Colors.white.withOpacity(0.1))), child: Row(children: [Radio(value: 'Admin', groupValue: selectedRole, activeColor: theme.primaryColor, onChanged: (v) => setStateDialog(() => selectedRole = v.toString())), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text("Quản trị viên (Super Admin)", style: TextStyle(color: Colors.white, fontSize: 14 * theme.fontScale, fontWeight: FontWeight.bold)), const SizedBox(height: 4), Text("Quản lý toàn bộ hệ thống.", style: TextStyle(color: Colors.grey[500], fontSize: 12 * theme.fontScale))]))]))), const SizedBox(height: 15),
                        GestureDetector(onTap: () => setStateDialog(() => selectedRole = 'Unit Manager'), child: Container(padding: const EdgeInsets.all(15), decoration: BoxDecoration(color: selectedRole == 'Unit Manager' ? theme.primaryColor.withOpacity(0.15) : Colors.transparent, borderRadius: BorderRadius.circular(12), border: Border.all(color: selectedRole == 'Unit Manager' ? theme.primaryColor : Colors.white.withOpacity(0.1))), child: Row(children: [Radio(value: 'Unit Manager', groupValue: selectedRole, activeColor: theme.primaryColor, onChanged: (v) => setStateDialog(() => selectedRole = v.toString())), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text("Thành viên quản lý (Phân khu)", style: TextStyle(color: Colors.white, fontSize: 14 * theme.fontScale, fontWeight: FontWeight.bold)), const SizedBox(height: 4), Text("Chỉ có quyền xem và điểm danh khu vực được giao.", style: TextStyle(color: Colors.grey[500], fontSize: 12 * theme.fontScale))]))]))),
                        if (selectedRole == 'Unit Manager') Padding(padding: const EdgeInsets.only(top: 20.0), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text("Chỉ định Lớp quản lý", style: TextStyle(color: Colors.white70, fontSize: 12 * theme.fontScale, fontWeight: FontWeight.bold)), const SizedBox(height: 8), SizedBox(height: 45, child: DropdownButtonFormField<String>(value: selectedUnit, dropdownColor: const Color(0xFF0A101E), style: TextStyle(color: Colors.white, fontSize: 13 * theme.fontScale), icon: Icon(Icons.expand_more_rounded, color: theme.primaryColor), decoration: InputDecoration(contentPadding: const EdgeInsets.symmetric(horizontal: 15), filled: true, fillColor: Colors.black.withOpacity(0.3), enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.white.withOpacity(0.1))), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: theme.primaryColor))), items: (_availableClasses.isEmpty ? ['Chưa có lớp'] : _availableClasses).map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(), onChanged: (v) => setStateDialog(() => selectedUnit = v!)))])),
                        const SizedBox(height: 40),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            TextButton(onPressed: () => Navigator.pop(context), child: Text("Hủy", style: TextStyle(color: Colors.white54, fontWeight: FontWeight.bold, fontSize: 13 * theme.fontScale))), const SizedBox(width: 15),
                            ElevatedButton(
                              onPressed: () async {
                                try {
                                  var response = await http.put(Uri.parse('http://127.0.0.1:8000/api/members/${member['id']}'), headers: {"Content-Type": "application/json"}, body: jsonEncode({"status": "Hoạt động", "role": selectedRole, "unit": selectedRole == 'Unit Manager' ? selectedUnit : null}));
                                  if (response.statusCode == 200) { _fetchMembers(); if (context.mounted) Navigator.pop(context); }
                                } catch (e) {}
                              },
                              style: ElevatedButton.styleFrom(backgroundColor: theme.primaryColor, padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))), child: Text("Cập nhật quyền", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13 * theme.fontScale)),
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

  void _showDeleteConfirmDialog(BuildContext context, int memberId, String userName, AppTheme theme) {
    showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
            backgroundColor: const Color(0xFF101520), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: Colors.redAccent.withOpacity(0.5))),
            title: Row(children: [Icon(Icons.warning_amber_rounded, color: Colors.redAccent, size: 24 * theme.fontScale), const SizedBox(width: 10), Text("Xóa thành viên", style: TextStyle(color: Colors.white, fontSize: 18 * theme.fontScale, fontWeight: FontWeight.bold))]),
            content: Text("Bạn có chắc chắn muốn xóa '$userName' khỏi dự án này không? Họ sẽ mất toàn quyền truy cập hệ thống.", style: TextStyle(color: Colors.white70, fontSize: 13 * theme.fontScale, height: 1.5)),
            actionsPadding: const EdgeInsets.only(right: 20, bottom: 20),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: Text("Hủy bỏ", style: TextStyle(color: Colors.white54, fontWeight: FontWeight.bold, fontSize: 13 * theme.fontScale))),
              ElevatedButton(onPressed: () { _deleteMember(memberId); Navigator.pop(context); }, style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))), child: Text("Xóa ngay", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13 * theme.fontScale)))
            ],
          );
        }
    );
  }
}