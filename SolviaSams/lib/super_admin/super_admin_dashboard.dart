import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../theme_manager.dart';
import '../globals.dart' as globals;

import 'home_dashboard.dart';
import 'account_settings.dart';
import 'products_view.dart';
import 'settings_view.dart';
import 'new_project_view.dart';
import 'support_view.dart';
import '../project_workspace/project_workspace_screen.dart'; // Import để có thể nhảy thẳng vào lớp

class SuperAdminDashboardScreen extends StatefulWidget {
  const SuperAdminDashboardScreen({super.key});

  @override
  State<SuperAdminDashboardScreen> createState() => _SuperAdminDashboardScreenState();
}

class _SuperAdminDashboardScreenState extends State<SuperAdminDashboardScreen> {
  int _selectedIndex = 0;

  bool _isLoadingStudentInfo = false;
  Map<String, dynamic>? _studentData;

  @override
  void initState() {
    super.initState();
    // PHÂN LUỒNG NGAY TỪ LÚC VÀO APP: NẾU LÀ HỌC SINH THÌ KÉO DỮ LIỆU LỚP
    if (globals.currentUserRole == 'Học sinh' || globals.currentUserRole == 'Thành viên') {
      _fetchStudentDashboard();
    }
  }

  Future<void> _fetchStudentDashboard() async {
    setState(() => _isLoadingStudentInfo = true);
    try {
      var response = await http.get(Uri.parse('http://127.0.0.1:8000/api/students/${globals.currentUserId}/dashboard'));
      if (response.statusCode == 200) {
        var resBody = jsonDecode(utf8.decode(response.bodyBytes));
        if (resBody['status'] == 'success' && mounted) {
          setState(() {
            _studentData = resBody['data'];
            // Lưu ngầm ID dự án và ID lớp để truyền cho các trang bên trong
            globals.currentProjectId = _studentData!['project_id'];
            globals.currentClassId = _studentData!['class_id'];
          });
        }
      }
    } catch (e) {
      debugPrint("Lỗi lấy thông tin học sinh: $e");
    }
    if (mounted) setState(() => _isLoadingStudentInfo = false);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: AppTheme.instance,
      builder: (context, child) {
        final theme = AppTheme.instance;

        return Scaffold(
          // NỀN TỰ ĐỘNG ĐỔI MÀU
          backgroundColor: theme.backgroundColor,
          body: Column(
            children: [
              _buildTopNavigationBar(theme),

              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: _buildWorkspaceContent(),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildWorkspaceContent() {
    switch (_selectedIndex) {
      case 0: return const HomeDashboard();
      case 1: return const ProductsView();
      case 2: return const AccountSettings();
      case 3: return const SettingsView();
      case 4: return const SupportView();
      case 5: return const NewProjectView(); // Nút này giờ chỉ dành cho Giáo viên
      default: return const HomeDashboard();
    }
  }

  // ================== THANH MENU ĐÃ PHÂN LUỒNG ==================
  Widget _buildTopNavigationBar(AppTheme theme) {
    bool isStudent = globals.currentUserRole == 'Học sinh' || globals.currentUserRole == 'Thành viên';

    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      height: 60,
      padding: const EdgeInsets.symmetric(horizontal: 30),
      decoration: BoxDecoration(
          color: theme.cardColor, // Nền Trắng/Đen
          border: Border(bottom: BorderSide(color: theme.borderColor, width: 1.0)),
          boxShadow: theme.isDarkMode ? [] : [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 2))]
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                child: Icon(Icons.blur_on_rounded, color: theme.primaryColor, size: 32 * theme.fontScale),
              ),
              const SizedBox(width: 12),
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 300),
                style: TextStyle(fontSize: 18 * theme.fontScale, fontWeight: FontWeight.w900, letterSpacing: 2, color: theme.textColor, fontFamily: 'Segoe UI'),
                child: Text(isStudent ? "SAMS STUDENT" : "SOLVIA SAMS"), // Đổi Logo
              ),
            ],
          ),
          Row(
            children: [
              _buildNavTextButton(0, "Trang chủ phần mềm", theme),
              const SizedBox(width: 5),

              // 1. CHẶN KHÔNG CHO HỌC SINH THẤY NÚT SẢN PHẨM
              if (!isStudent) ...[
                _buildNavTextButton(1, "Sản phẩm", theme),
                const SizedBox(width: 5),
              ],

              _buildNavTextButton(2, "Tài khoản", theme),
              const SizedBox(width: 5),
              _buildNavTextButton(3, "Cài đặt", theme),
              const SizedBox(width: 5),
              _buildNavTextButton(4, "Support", theme),
              const SizedBox(width: 20),

              // 2. NÚT KẾT NỐI VÀO DỰ ÁN TÙY CHỈNH THEO QUYỀN
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                child: isStudent
                // --- NẾU LÀ HỌC SINH: BẤM LÀ XUYÊN TƯỜNG VÀO LỚP LUÔN ---
                    ? ElevatedButton.icon(
                  onPressed: () {
                    if (_studentData != null) {
                      Navigator.push(context, MaterialPageRoute(builder: (context) => const ProjectWorkspaceScreen(userRole: 'Học sinh')));
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Chưa có thông tin lớp học. Bạn đã được thêm vào lớp chưa?"), backgroundColor: Colors.orange));
                    }
                  },
                  icon: Icon(Icons.school_rounded, size: 16 * theme.fontScale, color: Colors.white),
                  label: Text(
                      _isLoadingStudentInfo ? "Đang tải..." : (_studentData != null ? "Vào lớp ${_studentData!['class_name']}" : "Chưa có lớp"),
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 0.5, fontSize: 12 * theme.fontScale)
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.successColor,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                )
                // --- NẾU LÀ GIÁO VIÊN: VẪN HIỆN NÚT TẠO DỰ ÁN NHƯ CŨ ---
                    : ElevatedButton.icon(
                  onPressed: () => setState(() => _selectedIndex = 5),
                  icon: Icon(Icons.add_rounded, size: 16 * theme.fontScale, color: Colors.white),
                  label: Text("Dự án mới", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 0.5, fontSize: 12 * theme.fontScale)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.primaryColor,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNavTextButton(int index, String title, AppTheme theme) {
    bool isActive = _selectedIndex == index;
    return TextButton(
      onPressed: () => setState(() => _selectedIndex = index),
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        backgroundColor: isActive ? theme.primaryColor.withOpacity(0.1) : Colors.transparent,
      ),
      child: AnimatedDefaultTextStyle(
        duration: const Duration(milliseconds: 300),
        style: TextStyle(
            color: isActive ? theme.primaryColor : theme.subTextColor,
            fontSize: 13 * theme.fontScale,
            fontWeight: isActive ? FontWeight.bold : FontWeight.w600,
            fontFamily: 'Segoe UI'
        ),
        child: Text(title),
      ),
    );
  }
}