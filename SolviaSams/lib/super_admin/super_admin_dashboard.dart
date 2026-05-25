import 'package:flutter/material.dart';
import '../theme_manager.dart';
import 'home_dashboard.dart';
import 'account_settings.dart';
import 'products_view.dart';
import 'settings_view.dart';
import 'new_project_view.dart';
import 'support_view.dart';

class SuperAdminDashboardScreen extends StatefulWidget {
  const SuperAdminDashboardScreen({super.key});

  @override
  State<SuperAdminDashboardScreen> createState() => _SuperAdminDashboardScreenState();
}

class _SuperAdminDashboardScreenState extends State<SuperAdminDashboardScreen> {
  int _selectedIndex = 0;

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
      case 5: return const NewProjectView();
      default: return const HomeDashboard();
    }
  }

  // ================== THANH MENU TỰ ĐỘNG CHUYỂN MÀU ==================
  Widget _buildTopNavigationBar(AppTheme theme) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      height: 60,
      padding: const EdgeInsets.symmetric(horizontal: 30),
      decoration: BoxDecoration(
          color: theme.cardColor, // Nền Trắng/Đen
          border: Border(bottom: BorderSide(color: theme.borderColor, width: 1.0)),
          // Hiệu ứng đổ bóng chuẩn Apple (Chỉ hiện khi ở nền Trắng)
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
                // Chữ tự động chuyển Đen (Light Mode) / Trắng (Dark Mode)
                style: TextStyle(fontSize: 18 * theme.fontScale, fontWeight: FontWeight.w900, letterSpacing: 2, color: theme.textColor, fontFamily: 'Segoe UI'),
                child: const Text("SOLVIA SAMS"),
              ),
            ],
          ),
          Row(
            children: [
              _buildNavTextButton(0, "Trang chủ", theme),
              const SizedBox(width: 5),
              _buildNavTextButton(1, "Sản phẩm", theme),
              const SizedBox(width: 5),
              _buildNavTextButton(2, "Tài khoản", theme),
              const SizedBox(width: 5),
              _buildNavTextButton(3, "Cài đặt", theme),
              const SizedBox(width: 5),
              _buildNavTextButton(4, "Support", theme),
              const SizedBox(width: 20),

              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                child: ElevatedButton.icon(
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
            color: isActive ? theme.primaryColor : theme.subTextColor, // Nút không click sẽ xám mờ
            fontSize: 13 * theme.fontScale,
            fontWeight: isActive ? FontWeight.bold : FontWeight.w600,
            fontFamily: 'Segoe UI'
        ),
        child: Text(title),
      ),
    );
  }
}