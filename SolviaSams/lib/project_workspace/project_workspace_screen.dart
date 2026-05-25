import 'package:flutter/material.dart';
import '../theme_manager.dart';
import 'project_info_view.dart';
import 'project_members_view.dart';
import 'class_management_view.dart';
import 'attendance_report_view.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../globals.dart' as globals;

class ProjectWorkspaceScreen extends StatefulWidget {
  // THÊM 2 BIẾN NÀY ĐỂ PHÂN QUYỀN TỪ MÀN HÌNH NGOÀI
  final String userRole; // 'Super Admin' hoặc 'Admin'
  final String? assignedUnit; // Ví dụ: 'Lớp 10A1' (Nếu là Admin)

  const ProjectWorkspaceScreen({
    super.key,
    this.userRole = 'Super Admin', // Mặc định để test là Super Admin
    this.assignedUnit,
  });

  @override
  State<ProjectWorkspaceScreen> createState() => _ProjectWorkspaceScreenState();
}

class _ProjectWorkspaceScreenState extends State<ProjectWorkspaceScreen> {
  String _activeMenuId = 'info';
  bool _isClassMenuExpanded = false;
  // ---> BIẾN LƯU DANH SÁCH LỚP THẬT
  List<dynamic> _classList = [];
  bool _isLoadingClasses = true;

  @override
  void initState() {
    super.initState();
    _fetchClassMenu(); // Gọi API kéo menu lớp
  }

  Future<void> _fetchClassMenu() async {
    try {
      var response = await http.get(Uri.parse('http://127.0.0.1:8000/api/projects/${globals.currentProjectId}/classes'));
      if (response.statusCode == 200) {
        var data = jsonDecode(utf8.decode(response.bodyBytes));
        if (data['status'] == 'success') {
          setState(() {
            _classList = data['data'];
            _isLoadingClasses = false;
          });
        }
      }
    } catch (e) {
      setState(() => _isLoadingClasses = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: AppTheme.instance,
      builder: (context, child) {
        final theme = AppTheme.instance;
        bool isSuperAdmin = widget.userRole == 'Super Admin';

        return Scaffold(
          backgroundColor: const Color(0xFF050505),
          body: Row(
            children: [
              // ==========================================
              // MENU DỌC BÊN TRÁI (SIDEBAR ĐỘNG THEO QUYỀN)
              // ==========================================
              Container(
                width: 280 * theme.fontScale,
                decoration: BoxDecoration(color: const Color(0xFF0A101E).withOpacity(0.5), border: Border(right: BorderSide(color: Colors.white.withOpacity(0.08)))),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: InkWell(
                        onTap: () => Navigator.pop(context),
                        child: Row(children: [Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white54, size: 16 * theme.fontScale), const SizedBox(width: 10), AnimatedDefaultTextStyle(duration: const Duration(milliseconds: 300), style: TextStyle(color: Colors.white54, fontSize: 13 * theme.fontScale, fontWeight: FontWeight.bold, fontFamily: 'Segoe UI'), child: const Text("Về bảng điều khiển"))]),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Padding(padding: const EdgeInsets.symmetric(horizontal: 25.0), child: AnimatedDefaultTextStyle(duration: const Duration(milliseconds: 300), style: TextStyle(color: Colors.white, fontSize: 18 * theme.fontScale, fontWeight: FontWeight.w900, fontFamily: 'Segoe UI'), child: const Text("SAMS Cơ sở 1"))),
                    Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 25.0, vertical: 5.0),
                        child: AnimatedDefaultTextStyle(
                            duration: const Duration(milliseconds: 300),
                            // Đổi màu chữ dưới tên dự án để nhận biết quyền
                            style: TextStyle(color: isSuperAdmin ? theme.primaryColor : Colors.greenAccent, fontSize: 12 * theme.fontScale, fontWeight: FontWeight.bold, fontFamily: 'Segoe UI'),
                            child: Text(isSuperAdmin ? "Trường học • Super Admin" : "Trường học • ${widget.assignedUnit ?? 'Admin'}")
                        )
                    ),
                    const SizedBox(height: 30),

                    // 1. INFO: Ai cũng được xem
                    _buildSidebarItem(Icons.info_outline_rounded, "Thông tin dự án", 'info', theme),

                    // 2. THÀNH VIÊN: CHỈ SUPER ADMIN ĐƯỢC XEM
                    if (isSuperAdmin)
                      _buildSidebarItem(Icons.manage_accounts_rounded, "Thành viên quản trị", 'members', theme),

                    // 3. QUẢN LÝ LỚP HỌC
                    if (isSuperAdmin || widget.userRole == 'Khách truy cập')
                      _buildExpandableClassMenu(theme)
                    else
                      _buildSidebarItem(Icons.meeting_room_rounded, "Lớp của tôi (${widget.assignedUnit})", 'class_${widget.assignedUnit}', theme),

                    // 4. CAMERA & BÁO CÁO: Ai cũng được thao tác
                    _buildSidebarItem(Icons.devices_other_rounded, "Thiết bị Camera", 'devices', theme),
                    _buildSidebarItem(Icons.bar_chart_rounded, "Báo cáo điểm danh", 'reports', theme),
                  ],
                ),
              ),

              // ==========================================
              // KHU VỰC HIỂN THỊ BÊN PHẢI (CONTENT)
              // ==========================================
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: _buildWorkspaceContent(isSuperAdmin),
                ),
              )
            ],
          ),
        );
      },
    );
  }

  // Khung điều hướng nội dung có truyền cờ `isSuperAdmin`
  // Khung điều hướng nội dung có truyền cờ `isSuperAdmin`
  Widget _buildWorkspaceContent(bool isSuperAdmin) {
    // NẾU MENU ĐANG CHỌN LÀ LỚP HỌC
    if (_activeMenuId.startsWith('class_')) {
      int classId = int.parse(_activeMenuId.split('_')[1]);
      String className = "Đang tải...";

      // Tìm tên lớp từ danh sách
      for (var cls in _classList) {
        if (cls['id'] == classId) {
          className = cls['class_name'];
          break;
        }
      }

      // BẮT BUỘC PHẢI CÓ CHỮ "return" ĐỂ GIAO DIỆN HIỆN RA
      return ClassManagementView(
        classId: classId,
        className: className,
        isSuperAdmin: isSuperAdmin,
      );
    }

    // NẾU LÀ CÁC MENU KHÁC
    switch (_activeMenuId) {
      case 'info':
        return ProjectInfoView(isSuperAdmin: isSuperAdmin);
      case 'members':
        return const ProjectMembersView();
      case 'reports':
        return const AttendanceReportView();
      case 'devices':
        return const Center(child: Text("MÀN HÌNH THIẾT BỊ CAMERA\n(Sẽ thiết kế ở bước tiếp theo)", textAlign: TextAlign.center, style: TextStyle(color: Colors.white, fontSize: 20)));
      default:
        return const Center(child: Text("Tính năng đang phát triển...", style: TextStyle(color: Colors.white)));
    }
  }

  Widget _buildSidebarItem(IconData icon, String title, String menuId, AppTheme theme) {
    bool isSelected = _activeMenuId == menuId;
    return InkWell(
      onTap: () {
        setState(() {
          _activeMenuId = menuId;
          _isClassMenuExpanded = false;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300), margin: const EdgeInsets.symmetric(horizontal: 15, vertical: 4), padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
        decoration: BoxDecoration(color: isSelected ? theme.primaryColor.withOpacity(0.15) : Colors.transparent, borderRadius: BorderRadius.circular(12), border: Border.all(color: isSelected ? theme.primaryColor.withOpacity(0.5) : Colors.transparent)),
        child: Row(children: [Icon(icon, color: isSelected ? theme.primaryColor : Colors.white54, size: 20 * theme.fontScale), const SizedBox(width: 15), Expanded(child: AnimatedDefaultTextStyle(duration: const Duration(milliseconds: 300), style: TextStyle(color: isSelected ? theme.primaryColor : Colors.white70, fontSize: 13 * theme.fontScale, fontWeight: isSelected ? FontWeight.bold : FontWeight.w600, fontFamily: 'Segoe UI'), child: Text(title)))]),
      ),
    );
  }

  Widget _buildExpandableClassMenu(AppTheme theme) {
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        leading: Icon(Icons.meeting_room_rounded, color: theme.primaryColor),
        title: Text("Quản lý Lớp học", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13 * theme.fontScale)),
        iconColor: theme.primaryColor,
        collapsedIconColor: Colors.white54,
        children: [
          if (_isLoadingClasses)
            const Padding(padding: EdgeInsets.all(15.0), child: Center(child: CircularProgressIndicator(strokeWidth: 2))),

          if (!_isLoadingClasses && _classList.isEmpty)
            Padding(padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 20), child: Text("Chưa có lớp nào", style: TextStyle(color: Colors.white54, fontSize: 12 * theme.fontScale, fontStyle: FontStyle.italic))),

          // VÒNG LẶP RENDER LỚP THẬT (GỌN GÀNG, KHÔNG LỖI)
          ..._classList.map((cls) {
            String menuKey = 'class_${cls['id']}';

            return _buildSubMenuItem(
                cls['class_name'], // 1. Tên lớp
                menuKey,           // 2. Mã menu ID
                theme              // 3. Theme (TRUYỀN TRỰC TIẾP, KHÔNG DÙNG HÀM NỮA)
            );
          }).toList(),
        ],
      ),
    );
  }

  Widget _buildSubMenuItem(String title, String menuId, AppTheme theme) {
    bool isSelected = _activeMenuId == menuId;
    return InkWell(
      onTap: () {
        setState(() => _activeMenuId = menuId);
        // Tự động đóng menu nếu màn hình nhỏ (Mobile)
        if (MediaQuery.of(context).size.width < 850) {
          Navigator.pop(context);
        }
      },
      child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          width: double.infinity,
          padding: const EdgeInsets.only(left: 70, top: 12, bottom: 12),
          color: isSelected ? theme.primaryColor.withOpacity(0.05) : Colors.transparent,
          child: Row(children: [
            Container(width: 6, height: 6, decoration: BoxDecoration(shape: BoxShape.circle, color: isSelected ? theme.primaryColor : Colors.white24)),
            const SizedBox(width: 15),
            Text(title, style: TextStyle(color: isSelected ? theme.primaryColor : Colors.white54, fontSize: 13 * theme.fontScale, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal))
          ])
      ),
    );
  }
}