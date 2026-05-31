import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../theme_manager.dart';
import '../globals.dart' as globals;
import '../main.dart'; // Import để gọi LandingPageScreen khi Đăng xuất

class SettingsView extends StatefulWidget {
  const SettingsView({super.key});

  @override
  State<SettingsView> createState() => _SettingsViewState();
}

class _SettingsViewState extends State<SettingsView> {
  int get _currentUserId => globals.currentUserId;
  String _selectedLanguage = globals.currentLanguage;
  String _selectedTimezone = globals.currentTimezone;

  bool _isChangingPassword = false;

  // BỘ ĐIỀU KHIỂN ĐỔI MẬT KHẨU
  final TextEditingController _oldPassCtrl = TextEditingController();
  final TextEditingController _newPassCtrl = TextEditingController();
  final TextEditingController _confirmPassCtrl = TextEditingController();

  // THAY THẾ DÒNG KHAI BÁO MÀU HIỆN TẠI BẰNG ĐOẠN NÀY
  final List<Color> _themeColors = [
    const Color(0xFF007AFF), // Apple Blue (Sang trọng)
    const Color(0xFF5856D6), // Apple Indigo (Học thuật)
    const Color(0xFF34C759), // Apple Green (Tươi mát)
    const Color(0xFFFF9500), // Apple Orange (Năng động)
    const Color(0xFF475569), // Slate Gray (Tối giản, quyền lực)
  ];

  @override
  void dispose() {
    _oldPassCtrl.dispose();
    _newPassCtrl.dispose();
    _confirmPassCtrl.dispose();
    super.dispose();
  }

  // =================================================================
  // 1. HÀM ĐỔI MẬT KHẨU
  // =================================================================
  Future<void> _changePassword() async {
    if (_oldPassCtrl.text.isEmpty || _newPassCtrl.text.isEmpty || _confirmPassCtrl.text.isEmpty) {
      _showSnackBar("Vui lòng điền đầy đủ các trường mật khẩu!", Colors.orange);
      return;
    }
    if (_newPassCtrl.text != _confirmPassCtrl.text) {
      _showSnackBar("Mật khẩu xác nhận không khớp!", Colors.redAccent);
      return;
    }

    showDialog(context: context, barrierDismissible: false, builder: (c) => const Center(child: CircularProgressIndicator(color: Colors.blueAccent)));

    try {
      Map<String, dynamic> payload = {
        "old_password": _oldPassCtrl.text,
        "new_password": _newPassCtrl.text,
      };

      var response = await http.put(
          Uri.parse('http://127.0.0.1:8000/api/users/$_currentUserId/password?role=${Uri.encodeComponent(globals.currentUserRole)}'),
          headers: {"Content-Type": "application/json"},
          body: jsonEncode(payload)
      );

      if (context.mounted) Navigator.pop(context); // Tắt loading

      var data = jsonDecode(response.body);
      if (response.statusCode == 200 && data['status'] == 'success') {
        setState(() {
          _isChangingPassword = false;
          _oldPassCtrl.clear();
          _newPassCtrl.clear();
          _confirmPassCtrl.clear();
        });
        _showSnackBar(data['message'], Colors.green);
      } else {
        _showSnackBar(data['message'], Colors.redAccent);
      }
    } catch (e) {
      if (context.mounted) Navigator.pop(context);
      _showSnackBar("Lỗi kết nối máy chủ!", Colors.redAccent);
    }
  }

  // =================================================================
  // 2. HÀM LƯU CÀI ĐẶT GIAO DIỆN
  // =================================================================
  Future<void> _saveSettings(AppTheme theme) async {
    showDialog(context: context, barrierDismissible: false, builder: (c) => const Center(child: CircularProgressIndicator(color: Colors.greenAccent)));

    try {
      // Chuyển màu thành chuỗi Hex để lưu DB
      String colorHex = "0x${theme.primaryColor.value.toRadixString(16).toUpperCase()}";

      Map<String, dynamic> payload = {
        "language": _selectedLanguage,
        "timezone": _selectedTimezone,
        "theme_color": colorHex,
        "font_scale": theme.fontSizeLevel,
      };

      var response = await http.put(
          Uri.parse('http://127.0.0.1:8000/api/users/$_currentUserId/settings?role=${Uri.encodeComponent(globals.currentUserRole)}'),
          headers: {"Content-Type": "application/json"},
          body: jsonEncode(payload)
      );

      if (context.mounted) Navigator.pop(context);

      var data = jsonDecode(response.body);
      if (response.statusCode == 200 && data['status'] == 'success') {
        globals.currentLanguage = _selectedLanguage;
        globals.currentTimezone = _selectedTimezone;
        _showSnackBar("Đã lưu cài đặt an toàn vào máy chủ!", Colors.green);
      } else {
        _showSnackBar("Lỗi lưu dữ liệu: ${data['message']}", Colors.redAccent);
      }
    } catch (e) {
      if (context.mounted) Navigator.pop(context);
      _showSnackBar("Mất kết nối với máy chủ!", Colors.redAccent);
    }
  }

  // =================================================================
  // 3. HÀM ĐĂNG XUẤT
  // =================================================================
  void _logOut() {
    // 1. Xóa ID tài khoản toàn cục
    globals.currentUserId = 0;

    // 2. Chuyển thẳng ra màn hình Landing (Bỏ qua tất cả các trang cũ)
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const LandingPageScreen()),
          (route) => false, // Xóa sạch lịch sử màn hình
    );
  }

  void _showSnackBar(String message, Color color) {
    if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), backgroundColor: color));
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: AppTheme.instance,
      builder: (context, child) {
        final theme = AppTheme.instance;

        return SingleChildScrollView(
          key: const ValueKey('SettingsView'),
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 40.0, vertical: 30.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // HEADER CHỨA NÚT ĐĂNG XUẤT
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AnimatedDefaultTextStyle(duration: const Duration(milliseconds: 300), style: TextStyle(fontSize: 28 * theme.fontScale, fontWeight: FontWeight.w900, color: theme.textColor, letterSpacing: 1.0, fontFamily: 'Segoe UI'), child: const Text("Cài Đặt Hệ Thống")),
                      const SizedBox(height: 8),
                      AnimatedDefaultTextStyle(duration: const Duration(milliseconds: 300), style: TextStyle(fontSize: 14 * theme.fontScale, color: theme.subTextColor, fontFamily: 'Segoe UI'), child: const Text("Tùy biến giao diện, màu sắc và bảo mật của không gian quản trị.")),
                    ],
                  ),

                  // NÚT ĐĂNG XUẤT ĐỎ NỔI BẬT
                  ElevatedButton.icon(
                    onPressed: _logOut,
                    icon: Icon(Icons.logout_rounded, color: Colors.white, size: 16 * theme.fontScale),
                    label: Text("Đăng xuất", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13 * theme.fontScale)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.redAccent.withOpacity(0.8),
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      elevation: 0,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 30),

              Container(
                padding: const EdgeInsets.all(30),
                decoration: BoxDecoration(color: theme.cardColor, borderRadius: BorderRadius.circular(20), border: Border.all(color: theme.borderColor)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSectionHeader(Icons.palette_rounded, "GIAO DIỆN & TRẢI NGHIỆM", theme),
                    const SizedBox(height: 25),
                    _buildSettingRow(
                        "Chế độ hiển thị",
                        "Bật/tắt Giao diện tối (Dark Mode).",
                        Switch.adaptive(
                          value: theme.isDarkMode,
                          activeColor: theme.primaryColor,
                          onChanged: (val) {
                            theme.toggleTheme(); // Gọi hàm đổi màu mượt mà
                          },
                        ),
                        theme
                    ),
                    _buildDivider(theme),

                    _buildSettingRow("Ngôn ngữ hiển thị", "Chọn ngôn ngữ chính cho bảng điều khiển.", _buildDropdown(_selectedLanguage, ['Tiếng Việt', 'English (US)', '日本語 (Nhật)'], (val) => setState(() => _selectedLanguage = val!), theme), theme),
                    _buildDivider(theme),
                    _buildSettingRow(
                        "Kích cỡ văn bản", "Điều chỉnh độ lớn của font chữ để dễ đọc hơn.",
                        SizedBox(
                          width: 200,
                          child: Row(
                            children: [
                              Text("A", style: TextStyle(color: theme.subTextColor, fontSize: 12 * theme.fontScale)),
                              Expanded(
                                child: SliderTheme(
                                  data: SliderThemeData(activeTrackColor: theme.primaryColor, inactiveTrackColor: theme.textColor.withOpacity(0.1), thumbColor: theme.primaryColor, overlayColor: theme.primaryColor.withOpacity(0.2), trackHeight: 4.0),
                                  child: Slider(value: theme.fontSizeLevel, min: 1.0, max: 3.0, divisions: 2, onChanged: (val) => theme.changeFontSize(val)),
                                ),
                              ),
                              Text("A", style: TextStyle(color: theme.textColor, fontSize: 18 * theme.fontScale, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ), theme
                    ),
                    _buildDivider(theme),
                    _buildSettingRow("Màu sắc chủ đạo", "Cá nhân hóa dải màu nổi bật theo sở thích.", Row(mainAxisSize: MainAxisSize.min, children: _themeColors.map((color) => _buildColorSwatch(color, theme)).toList()), theme),
                    const SizedBox(height: 40),

                    _buildSectionHeader(Icons.settings_suggest_rounded, "CẤU HÌNH HỆ THỐNG", theme),
                    const SizedBox(height: 25),
                    _buildSettingRow("Múi giờ khu vực", "Đồng bộ thời gian hiển thị điểm danh.", _buildDropdown(_selectedTimezone, ['UTC +07:00 (Hồ Chí Minh)', 'UTC +09:00 (Tokyo)', 'UTC -08:00 (Pacific Time)'], (val) => setState(() => _selectedTimezone = val!), theme, width: 220), theme),
                    const SizedBox(height: 40),

                    _buildSectionHeader(Icons.security_rounded, "BẢO MẬT TÀI KHOẢN", theme),
                    const SizedBox(height: 25),
                    _buildSettingRow(
                        "Mật khẩu đăng nhập", "Cập nhật mật khẩu định kỳ để bảo đảm an toàn.",
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          child: ElevatedButton.icon(
                            onPressed: () => setState(() => _isChangingPassword = !_isChangingPassword),
                            icon: Icon(_isChangingPassword ? Icons.close_rounded : Icons.lock_reset_rounded, size: 16 * theme.fontScale),
                            label: Text(_isChangingPassword ? "Hủy thao tác" : "Đổi mật khẩu", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12 * theme.fontScale)),
                            style: ElevatedButton.styleFrom(backgroundColor: _isChangingPassword ? theme.textColor.withOpacity(0.1) : theme.primaryColor.withOpacity(0.1), foregroundColor: _isChangingPassword ? theme.textColor : theme.primaryColor, elevation: 0, padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                          ),
                        ), theme
                    ),

                    AnimatedSize(
                      duration: const Duration(milliseconds: 400), curve: Curves.easeInOut,
                      child: !_isChangingPassword ? const SizedBox.shrink() : Padding(
                        padding: const EdgeInsets.only(top: 20, bottom: 10),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          padding: const EdgeInsets.all(25), decoration: BoxDecoration(color: theme.textColor.withOpacity(0.05), borderRadius: BorderRadius.circular(16), border: Border.all(color: theme.primaryColor.withOpacity(0.3))),
                          child: Column(
                            children: [
                              _buildPasswordField("Mật khẩu hiện tại", "Nhập mật khẩu cũ", _oldPassCtrl, theme), const SizedBox(height: 15),
                              Row(children: [Expanded(child: _buildPasswordField("Mật khẩu mới", "Tạo mật khẩu mới", _newPassCtrl, theme)), const SizedBox(width: 20), Expanded(child: _buildPasswordField("Xác nhận mật khẩu", "Nhập lại mật khẩu mới", _confirmPassCtrl, theme))]),
                              const SizedBox(height: 20),
                              Align(
                                alignment: Alignment.centerRight,
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 300),
                                  child: ElevatedButton(
                                    onPressed: _changePassword, // GỌI API ĐỔI MẬT KHẨU
                                    style: ElevatedButton.styleFrom(backgroundColor: theme.primaryColor, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)), padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12)),
                                    child: Text("Cập nhật mật khẩu", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12 * theme.fontScale)),
                                  ),
                                ),
                              )
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 50),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(onPressed: () => theme.reset(), style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14)), child: Text("Khôi phục mặc định", style: TextStyle(color: theme.subTextColor, fontWeight: FontWeight.bold, fontSize: 13 * theme.fontScale))),
                        const SizedBox(width: 15),
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          child: ElevatedButton.icon(
                            onPressed: () => _saveSettings(theme), // GỌI API LƯU CÀI ĐẶT
                            icon: Icon(Icons.check_circle_rounded, color: Colors.white, size: 18 * theme.fontScale), label: Text("ÁP DỤNG THAY ĐỔI", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 1.0, fontSize: 13 * theme.fontScale)),
                            style: ElevatedButton.styleFrom(backgroundColor: theme.primaryColor, padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                          ),
                        ),
                      ],
                    )
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSectionHeader(IconData icon, String title, AppTheme theme) => Row(children: [AnimatedContainer(duration: const Duration(milliseconds: 300), child: Icon(icon, color: theme.primaryColor, size: 18 * theme.fontScale)), const SizedBox(width: 10), AnimatedDefaultTextStyle(duration: const Duration(milliseconds: 300), style: TextStyle(color: theme.textColor, fontSize: 14 * theme.fontScale, fontWeight: FontWeight.bold, letterSpacing: 1.2, fontFamily: 'Segoe UI'), child: Text(title))]);

  Widget _buildSettingRow(String title, String description, Widget trailing, AppTheme theme) => Padding(padding: const EdgeInsets.symmetric(vertical: 15.0), child: Row(children: [Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [AnimatedDefaultTextStyle(duration: const Duration(milliseconds: 300), style: TextStyle(color: theme.textColor, fontSize: 14 * theme.fontScale, fontWeight: FontWeight.bold, fontFamily: 'Segoe UI'), child: Text(title)), const SizedBox(height: 6), AnimatedDefaultTextStyle(duration: const Duration(milliseconds: 300), style: TextStyle(color: theme.subTextColor, fontSize: 12 * theme.fontScale, height: 1.4, fontFamily: 'Segoe UI'), child: Text(description))])), const SizedBox(width: 30), trailing]));

  Widget _buildDivider(AppTheme theme) => Divider(color: theme.borderColor, thickness: 1, height: 1);

  Widget _buildColorSwatch(Color color, AppTheme theme) {
    bool isSelected = theme.primaryColor == color;
    return GestureDetector(
      onTap: () => theme.changeColor(color),
      child: AnimatedContainer(duration: const Duration(milliseconds: 300), margin: const EdgeInsets.only(left: 12), width: 32, height: 32, decoration: BoxDecoration(color: color.withOpacity(0.2), shape: BoxShape.circle, border: Border.all(color: color, width: isSelected ? 2 : 1), boxShadow: isSelected ? [BoxShadow(color: color.withOpacity(0.4), blurRadius: 8, offset: const Offset(0, 2))] : []), child: isSelected ? Icon(Icons.check_rounded, color: color, size: 18) : Center(child: Container(width: 16, height: 16, decoration: BoxDecoration(color: color, shape: BoxShape.circle)))),
    );
  }

  Widget _buildDropdown(String value, List<String> items, Function(String?) onChanged, AppTheme theme, {double width = 160}) => SizedBox(width: width, height: 40, child: DropdownButtonFormField<String>(value: value, dropdownColor: theme.cardColor, style: TextStyle(color: theme.textColor, fontSize: 12 * theme.fontScale), icon: Icon(Icons.expand_more_rounded, color: theme.textColor.withOpacity(0.5), size: 16), decoration: InputDecoration(contentPadding: const EdgeInsets.symmetric(horizontal: 15), filled: true, fillColor: theme.textColor.withOpacity(0.03), enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: theme.borderColor)), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: theme.primaryColor, width: 1.0))), items: items.map((i) => DropdownMenuItem<String>(value: i, child: Text(i, overflow: TextOverflow.ellipsis))).toList(), onChanged: onChanged));

  Widget _buildPasswordField(String label, String hint, TextEditingController controller, AppTheme theme) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Padding(padding: const EdgeInsets.only(bottom: 6), child: AnimatedDefaultTextStyle(duration: const Duration(milliseconds: 300), style: TextStyle(color: theme.textColor.withOpacity(0.7), fontSize: 12 * theme.fontScale, fontWeight: FontWeight.bold, fontFamily: 'Segoe UI'), child: Text(label))), SizedBox(height: 40, child: TextField(controller: controller, obscureText: true, style: TextStyle(color: theme.textColor, fontSize: 13 * theme.fontScale), decoration: InputDecoration(contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 15), prefixIcon: Icon(Icons.lock_outline, color: theme.primaryColor, size: 18 * theme.fontScale), hintText: hint, hintStyle: TextStyle(color: theme.textColor.withOpacity(0.24), fontSize: 13 * theme.fontScale), filled: true, fillColor: theme.textColor.withOpacity(0.05), enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: theme.borderColor)), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: theme.primaryColor, width: 1.5)))))]);
}