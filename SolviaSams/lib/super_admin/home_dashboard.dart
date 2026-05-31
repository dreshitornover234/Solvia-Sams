import 'package:flutter/material.dart';
import '../theme_manager.dart';

class HomeDashboard extends StatelessWidget {
  const HomeDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
        animation: AppTheme.instance,
        builder: (context, child) {
          final theme = AppTheme.instance;

          return SingleChildScrollView(
            key: const ValueKey('HomeDashboard'),
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.all(35.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. HERO SECTION (Banner trên cùng)
                AnimatedContainer(
                  duration: const Duration(milliseconds: 400),
                  width: double.infinity,
                  padding: const EdgeInsets.all(30),
                  decoration: BoxDecoration(
                    // Hiệu ứng Gradient Sáng/Tối
                    gradient: theme.isDarkMode
                        ? const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF162A4E), Color(0xFF0A101E)])
                        : LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [theme.primaryColor.withOpacity(0.15), theme.cardColor]),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: theme.borderColor, width: 1.5),
                    boxShadow: theme.isDarkMode ? [] : [BoxShadow(color: theme.primaryColor.withOpacity(0.08), blurRadius: 20, offset: const Offset(0, 8))],
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 7,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 300),
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(color: theme.primaryColor.withOpacity(0.2), borderRadius: BorderRadius.circular(16)),
                              child: Text("TỔNG QUAN HỆ THỐNG", style: TextStyle(color: theme.primaryColor, fontSize: 10 * theme.fontScale, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                            ),
                            const SizedBox(height: 15),
                            AnimatedDefaultTextStyle(
                                duration: const Duration(milliseconds: 300),
                                style: TextStyle(fontSize: 28 * theme.fontScale, fontWeight: FontWeight.w900, color: theme.textColor, height: 1.2, fontFamily: 'Segoe UI'),
                                child: const Text("Chào mừng đến với\nSolvia SAMS Super Admin")
                            ),
                            const SizedBox(height: 12),
                            AnimatedDefaultTextStyle(
                                duration: const Duration(milliseconds: 300),
                                style: TextStyle(fontSize: 13 * theme.fontScale, color: theme.subTextColor, height: 1.6, fontFamily: 'Segoe UI'),
                                child: const Text("Trung tâm điều khiển và giám sát toàn bộ hệ sinh thái quản lý nhân sự thông minh. Tại đây, bạn có toàn quyền thiết lập AI, quản lý thiết bị đầu cuối, phân quyền tài khoản và theo dõi luồng dữ liệu thời gian thực.")
                            ),
                          ],
                        ),
                      ),
                      Expanded(flex: 3, child: Center(child: Icon(Icons.admin_panel_settings_rounded, size: 100 * theme.fontScale, color: theme.primaryColor.withOpacity(0.1)))),
                    ],
                  ),
                ),
                const SizedBox(height: 40),

                // 2. GIỚI THIỆU SẢN PHẨM & TÁC GIẢ SOLVIA
                _buildSectionHeader(Icons.lightbulb_outline_rounded, "VỀ SẢN PHẨM & ĐỘI NGŨ SOLVIA", theme),
                const SizedBox(height: 15),
                Row(
                  children: [
                    Expanded(child: _buildIntroCard(Icons.view_in_ar_rounded, "Sản phẩm Solvia SAMS", "Solvia SAMS (Smart Attendance Management System) là giải pháp đột phá trong việc tự động hóa điểm danh và quản lý nhân sự. Hệ thống xóa bỏ hoàn toàn thao tác vật lý truyền thống, thay bằng luồng nhận diện thông minh, vô hình và chính xác tuyệt đối.", theme)),
                    const SizedBox(width: 15),
                    Expanded(child: _buildIntroCard(Icons.group_work_rounded, "Tác giả - Thương hiệu Solvia", "Được kiến tạo bởi đội ngũ Solvia - những kỹ sư đam mê công nghệ vị nhân sinh. Chúng tôi tin rằng công nghệ vĩ đại nhất là công nghệ hoạt động lặng lẽ trong nền, nhường lại sự tiện nghi và quyền tự do cao nhất cho con người.", theme)),
                  ],
                ),
                const SizedBox(height: 40),

                // 3. CHỨC NĂNG CỐT LÕI
                _buildSectionHeader(Icons.auto_awesome_mosaic_rounded, "CHỨC NĂNG CỐT LÕI", theme),
                const SizedBox(height: 15),
                Row(
                  children: [
                    Expanded(child: _buildFeatureCard(Icons.face_retouching_natural_rounded, "Nhận diện AI Đa nền tảng", "Tích hợp công nghệ nhận diện khuôn mặt qua thiết bị chuyên dụng (Terminal) hoặc thiết bị thông minh di động một cách nhanh chóng.", theme)),
                    const SizedBox(width: 15),
                    Expanded(child: _buildFeatureCard(Icons.smart_toy_rounded, "Quản lý Thông Minh", "Tự động hóa hoàn toàn luồng xử lý dữ liệu nhân sự, không cần can thiệp vật lý, đảm bảo tính bảo mật và độ chính xác cao nhất.", theme)),
                    const SizedBox(width: 15),
                    Expanded(child: _buildFeatureCard(Icons.phonelink_ring_rounded, "Đồng bộ Đám mây", "Dữ liệu được xử lý tức thời và đồng bộ hóa lên hệ thống máy chủ, cho phép trích xuất báo cáo từ mọi thiết bị, mọi lúc mọi nơi.", theme)),
                  ],
                ),
                const SizedBox(height: 40),

                // 4. HƯỚNG DẪN SỬ DỤNG CHI TIẾT
                _buildSectionHeader(Icons.menu_book_rounded, "HƯỚNG DẪN VẬN HÀNH CHI TIẾT", theme),
                const SizedBox(height: 20),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 400),
                  padding: const EdgeInsets.all(30),
                  decoration: BoxDecoration(
                    color: theme.cardColor,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: theme.borderColor),
                    boxShadow: theme.isDarkMode ? [] : [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 15, offset: const Offset(0, 4))],
                  ),
                  child: Column(
                    children: [
                      _buildTimelineStep(stepNumber: "01", title: "Khởi tạo dự án đầu tiên", description: "Tạo một dự án mới trên không gian làm việc Super Admin. Thiết lập các thông số cơ bản, phòng ban và đưa danh sách nhân sự ban đầu vào hệ thống.", icon: Icons.create_new_folder_rounded, isLast: false, theme: theme),
                      _buildTimelineStep(stepNumber: "02", title: "Kết nối thiết bị điểm danh", description: "Thực hiện liên kết hệ thống trung tâm với các thiết bị điểm danh. Bạn có thể sử dụng thiết bị phần cứng riêng biệt của Solvia hoặc ứng dụng trên điện thoại thông minh.", icon: Icons.devices_other_rounded, isLast: false, theme: theme),
                      _buildTimelineStep(stepNumber: "03", title: "Quản lý qua Điện thoại & Máy tính", description: "Hệ thống đã sẵn sàng hoạt động. Ban quản trị có thể giám sát trạng thái, quản lý nhân sự và xuất báo cáo trực tiếp thông qua máy tính hoặc điện thoại bất cứ lúc nào.", icon: Icons.monitor_rounded, isLast: true, theme: theme),
                    ],
                  ),
                ),
                const SizedBox(height: 40),

                // 5. NHẬT KÝ CẬP NHẬT
                _buildSectionHeader(Icons.system_update_alt_rounded, "CẬP NHẬT MỚI NHẤT (CHANGELOG)", theme),
                const SizedBox(height: 15),
                _buildUpdateCard("Phiên bản v1.0.0 - Đang xây dựng & Phát triển", "27/02/2026", ["Khởi tạo kiến trúc dự án Solvia SAMS lõi.", "Phát triển giao diện hệ thống quản trị Super Admin Dashboard.", "Tích hợp luồng nhận diện AI qua thiết bị chuyên dụng và thiết bị thông minh.", "Xây dựng cơ sở dữ liệu nền tảng phục vụ quản lý thông minh."], theme),
                const SizedBox(height: 40),
              ],
            ),
          );
        }
    );
  }

  // --- CÁC HÀM WIDGET CON ĐƯỢC CHUYỂN QUA MÀU THÔNG MINH ---
  Widget _buildSectionHeader(IconData icon, String title, AppTheme theme) {
    return Row(
      children: [
        AnimatedContainer(duration: const Duration(milliseconds: 300), child: Icon(icon, color: theme.primaryColor, size: 18 * theme.fontScale)),
        const SizedBox(width: 10),
        AnimatedDefaultTextStyle(duration: const Duration(milliseconds: 300), style: TextStyle(color: theme.textColor, fontSize: 14 * theme.fontScale, fontWeight: FontWeight.bold, letterSpacing: 1.2, fontFamily: 'Segoe UI'), child: Text(title)),
      ],
    );
  }

  Widget _buildIntroCard(IconData icon, String title, String desc, AppTheme theme) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.borderColor),
        boxShadow: theme.isDarkMode ? [] : [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              AnimatedContainer(duration: const Duration(milliseconds: 300), padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: theme.primaryColor.withOpacity(0.15), borderRadius: BorderRadius.circular(10)), child: Icon(icon, color: theme.primaryColor, size: 20 * theme.fontScale)),
              const SizedBox(width: 12),
              Expanded(child: AnimatedDefaultTextStyle(duration: const Duration(milliseconds: 300), style: TextStyle(fontSize: 15 * theme.fontScale, fontWeight: FontWeight.bold, color: theme.textColor, fontFamily: 'Segoe UI'), child: Text(title))),
            ],
          ),
          const SizedBox(height: 15),
          AnimatedDefaultTextStyle(duration: const Duration(milliseconds: 300), style: TextStyle(fontSize: 13 * theme.fontScale, color: theme.subTextColor, height: 1.6, fontFamily: 'Segoe UI'), child: Text(desc)),
        ],
      ),
    );
  }

  Widget _buildFeatureCard(IconData icon, String title, String desc, AppTheme theme) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.borderColor),
        boxShadow: theme.isDarkMode ? [] : [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AnimatedContainer(duration: const Duration(milliseconds: 300), padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: theme.primaryColor.withOpacity(0.1), borderRadius: BorderRadius.circular(10)), child: Icon(icon, color: theme.primaryColor, size: 22 * theme.fontScale)),
          const SizedBox(height: 15),
          AnimatedDefaultTextStyle(duration: const Duration(milliseconds: 300), style: TextStyle(fontSize: 15 * theme.fontScale, fontWeight: FontWeight.bold, color: theme.textColor, fontFamily: 'Segoe UI'), child: Text(title)),
          const SizedBox(height: 8),
          AnimatedDefaultTextStyle(duration: const Duration(milliseconds: 300), style: TextStyle(fontSize: 13 * theme.fontScale, color: theme.subTextColor, height: 1.5, fontFamily: 'Segoe UI'), child: Text(desc)),
        ],
      ),
    );
  }

  Widget _buildTimelineStep({required String stepNumber, required String title, required String description, required IconData icon, required bool isLast, required AppTheme theme}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            AnimatedContainer(duration: const Duration(milliseconds: 300), width: 36 * theme.fontScale, height: 36 * theme.fontScale, decoration: BoxDecoration(color: theme.primaryColor, shape: BoxShape.circle, boxShadow: [BoxShadow(color: theme.primaryColor.withOpacity(0.4), blurRadius: 8, offset: const Offset(0, 3))]), child: Center(child: Text(stepNumber, style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 14 * theme.fontScale)))),
            if (!isLast) AnimatedContainer(duration: const Duration(milliseconds: 300), width: 2, height: 60 * theme.fontScale, color: theme.primaryColor.withOpacity(0.3), margin: const EdgeInsets.symmetric(vertical: 8))
          ],
        ),
        const SizedBox(width: 20),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [Icon(icon, color: theme.subTextColor, size: 16 * theme.fontScale), const SizedBox(width: 8), AnimatedDefaultTextStyle(duration: const Duration(milliseconds: 300), style: TextStyle(fontSize: 16 * theme.fontScale, fontWeight: FontWeight.bold, color: theme.textColor, fontFamily: 'Segoe UI'), child: Text(title))]),
              const SizedBox(height: 8), AnimatedDefaultTextStyle(duration: const Duration(milliseconds: 300), style: TextStyle(fontSize: 13 * theme.fontScale, color: theme.subTextColor, height: 1.6, fontFamily: 'Segoe UI'), child: Text(description)),
              if (!isLast) const SizedBox(height: 30),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildUpdateCard(String version, String date, List<String> changes, AppTheme theme) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: theme.cardColor,
          border: Border(left: BorderSide(color: theme.primaryColor, width: 4)),
          boxShadow: theme.isDarkMode ? [] : [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                AnimatedDefaultTextStyle(duration: const Duration(milliseconds: 300), style: TextStyle(fontSize: 14 * theme.fontScale, fontWeight: FontWeight.bold, color: theme.textColor, fontFamily: 'Segoe UI'), child: Text(version)),
                AnimatedContainer(duration: const Duration(milliseconds: 300), padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: theme.primaryColor.withOpacity(0.15), borderRadius: BorderRadius.circular(6)), child: Text(date, style: TextStyle(fontSize: 11 * theme.fontScale, color: theme.primaryColor, fontWeight: FontWeight.bold))),
              ],
            ),
            const SizedBox(height: 12),
            ...changes.map((change) => Padding(padding: const EdgeInsets.only(bottom: 6.0), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [AnimatedDefaultTextStyle(duration: const Duration(milliseconds: 300), style: TextStyle(color: theme.primaryColor, fontSize: 14 * theme.fontScale, fontFamily: 'Segoe UI'), child: const Text("• ")), Expanded(child: AnimatedDefaultTextStyle(duration: const Duration(milliseconds: 300), style: TextStyle(color: theme.subTextColor, fontSize: 13 * theme.fontScale, height: 1.5, fontFamily: 'Segoe UI'), child: Text(change)))]))),
          ],
        ),
      ),
    );
  }
}