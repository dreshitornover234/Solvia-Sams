import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:solviasams/theme_manager.dart';
import 'super_admin/super_admin_dashboard.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'globals.dart' as globals;

void main() {
  runApp(const SolviaSAMSApp());
}

class SolviaSAMSApp extends StatelessWidget {
  const SolviaSAMSApp({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: AppTheme.instance,
      builder: (context, child) {
        final theme = AppTheme.instance;
        return MaterialApp(
          title: 'Solvia SAMS',
          debugShowCheckedModeBanner: false,
          // Tự động nhận diện Đen/Trắng từ hệ thống Theme
          themeMode: theme.isDarkMode ? ThemeMode.dark : ThemeMode.light,

          // --- CHẾ ĐỘ NỀN TRẮNG ---
          theme: ThemeData(
            brightness: Brightness.light,
            scaffoldBackgroundColor: theme.backgroundColor,
            fontFamily: 'Segoe UI',
            useMaterial3: true,
            colorScheme: ColorScheme.light(primary: theme.primaryColor),
          ),

          // --- CHẾ ĐỘ NỀN ĐEN ---
          darkTheme: ThemeData(
            brightness: Brightness.dark,
            scaffoldBackgroundColor: theme.backgroundColor,
            fontFamily: 'Segoe UI',
            useMaterial3: true,
            colorScheme: ColorScheme.dark(primary: theme.primaryColor),
          ),
          home: const LandingPageScreen(),
        );
      },
    );
  }
}

// 1. Enum quản lý trạng thái hiển thị
enum ViewState { landing, login, register }

class LandingPageScreen extends StatefulWidget {
  const LandingPageScreen({super.key});

  @override
  State<LandingPageScreen> createState() => _LandingPageScreenState();
}

class _LandingPageScreenState extends State<LandingPageScreen> {
  ViewState currentView = ViewState.landing;
  String selectedRole = 'Thành viên';

  // BỘ ĐIỀU KHIỂN & LƯU LỖI
  final TextEditingController _regNameCtrl = TextEditingController();
  final TextEditingController _regEmailCtrl = TextEditingController();
  final TextEditingController _regPhoneCtrl = TextEditingController();
  final TextEditingController _regPassCtrl = TextEditingController();
  final TextEditingController _logUserCtrl = TextEditingController();
  final TextEditingController _logPassCtrl = TextEditingController();

  String? _logUserError;
  String? _logPassError;
  String? _nameError;
  String? _emailError;
  String? _phoneError;
  String? _passError;

  @override
  void dispose() {
    _regNameCtrl.dispose();
    _regEmailCtrl.dispose();
    _regPhoneCtrl.dispose();
    _regPassCtrl.dispose();
    _logUserCtrl.dispose();
    _logPassCtrl.dispose();
    super.dispose();
  }

  bool _validateRegistration() {
    bool isValid = true;
    setState(() {
      _nameError = null;
      _emailError = null;
      _phoneError = null;
      _passError = null;

      if (_regNameCtrl.text.trim().isEmpty) {
        _nameError = "Vui lòng nhập họ và tên của bạn.";
        isValid = false;
      }
      final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
      if (!emailRegex.hasMatch(_regEmailCtrl.text.trim())) {
        _emailError = "Định dạng email không hợp lệ (VD: abc@gmail.com).";
        isValid = false;
      }
      final phoneRegex = RegExp(r'^[0-9]{10,11}$');
      if (!phoneRegex.hasMatch(_regPhoneCtrl.text.trim())) {
        _phoneError = "Số điện thoại phải bao gồm 10-11 chữ số.";
        isValid = false;
      }
      final pass = _regPassCtrl.text;
      if (pass.length < 8 || !pass.contains(RegExp(r'[A-Z]')) || !pass.contains(RegExp(r'[0-9]')) || !pass.contains(RegExp(r'[!@#\$&*~%]'))) {
        _passError = "Mật khẩu >= 8 ký tự, phải chứa chữ IN HOA, số và ký tự đặc biệt.";
        isValid = false;
      }
    });
    return isValid;
  }

  Alignment getBeginAlignment() {
    switch (currentView) {
      case ViewState.landing: return Alignment.topLeft;
      case ViewState.login: return Alignment.topRight;
      case ViewState.register: return Alignment.bottomLeft;
    }
  }

  Alignment getEndAlignment() {
    switch (currentView) {
      case ViewState.landing: return Alignment.bottomRight;
      case ViewState.login: return Alignment.bottomLeft;
      case ViewState.register: return Alignment.topRight;
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
        animation: AppTheme.instance,
        builder: (context, child) {
          final theme = AppTheme.instance;
          final List<double> randomOffsets = [-20.0, -280.0, -100.0, -350.0, -150.0];

          Widget buildTextTexture(bool isShadowLayer) {
            return ListView.builder(
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(vertical: 10),
              itemCount: 5,
              itemBuilder: (context, index) {
                return Transform.translate(
                  offset: Offset(randomOffsets[index % 5], -10),
                  child: Text(
                    "SAMS SAMS SAMS SAMS SAMS SAMS SAMS SAMS SAMS SAMS SAMS",
                    maxLines: 1, softWrap: false,
                    style: TextStyle(
                      fontSize: 220, fontWeight: FontWeight.w900,
                      color: isShadowLayer ? Colors.transparent : Colors.white, height: 0.85, letterSpacing: -2,
                      shadows: isShadowLayer ? [
                        Shadow(offset: const Offset(-2, -2), blurRadius: 2.0, color: Colors.white.withOpacity(0.04)),
                        Shadow(offset: const Offset(4, 4), blurRadius: 10.0, color: Colors.black.withOpacity(0.4)),
                      ] : null,
                    ),
                  ),
                );
              },
            );
          }

          return Scaffold(
            backgroundColor: theme.backgroundColor,
            body: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ================== PHẦN BÊN TRÁI (KHỐI BRANDING GIỮ NGUYÊN) ==================
                Expanded(
                  flex: 4,
                  child: TweenAnimationBuilder<Alignment>(
                    tween: AlignmentTween(begin: Alignment.topLeft, end: getBeginAlignment()),
                    duration: const Duration(milliseconds: 800), curve: Curves.easeInOutCubic,
                    builder: (context, beginAlign, child) {
                      return TweenAnimationBuilder<Alignment>(
                        tween: AlignmentTween(begin: Alignment.bottomRight, end: getEndAlignment()),
                        duration: const Duration(milliseconds: 800), curve: Curves.easeInOutCubic,
                        builder: (context, endAlign, child) {
                          final Gradient dynamicGradient = LinearGradient(
                            begin: beginAlign, end: endAlign,
                            colors: const [Color(0xFF162A4E), Color(0xFF010101)], stops: const [0.0, 0.8],
                          );

                          return Container(
                            margin: const EdgeInsets.all(15.0),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(24.0),
                              gradient: dynamicGradient,
                              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 30, offset: const Offset(0, 10))],
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(24.0),
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  Positioned.fill(child: Stack(children: [Positioned(top: 0, bottom: 0, left: 0, right: -2000, child: buildTextTexture(true))])),
                                  Positioned.fill(
                                    child: ShaderMask(
                                      shaderCallback: (bounds) => dynamicGradient.createShader(Rect.fromLTWH(0, 0, bounds.width, bounds.height)),
                                      blendMode: BlendMode.srcIn,
                                      child: Stack(children: [Positioned(top: 0, bottom: 0, left: 0, right: -2000, child: buildTextTexture(false))]),
                                    ),
                                  ),
                                  Center(
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.blur_on_rounded, size: 85, color: theme.primaryColor, shadows: const [Shadow(color: Colors.black45, blurRadius: 20, offset: Offset(0, 8))]),
                                        const SizedBox(height: 20),
                                        const Text("SOLVIA SAMS", style: TextStyle(fontSize: 42, fontWeight: FontWeight.w900, letterSpacing: 6, color: Colors.white, shadows: [Shadow(color: Colors.black87, blurRadius: 15, offset: Offset(0, 4))])),
                                        const SizedBox(height: 10),
                                        Text("SMART ATTENDANCE MANAGEMENT SYSTEM", style: TextStyle(color: theme.primaryColor, fontSize: 13, fontWeight: FontWeight.bold, letterSpacing: 2, shadows: const [Shadow(color: Colors.black, blurRadius: 10, offset: Offset(0, 2))])),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),

                // ================== PHẦN BÊN PHẢI (NỘI DUNG/FORM) ==================
                Expanded(
                  flex: 6,
                  child: Column(
                    children: [
                      _buildModernHeader(theme),
                      Expanded(
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 400),
                          child: _buildRightContent(theme),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }
    );
  }

  Widget _buildRightContent(AppTheme theme) {
    switch (currentView) {
      case ViewState.login: return _buildLoginForm(theme);
      case ViewState.register: return _buildRegisterForm(theme);
      case ViewState.landing: default: return _buildLandingContent(theme);
    }
  }

  // ================== 1. TRANG CHỦ (ĐÃ ÁP DỤNG APPLE STYLE) ==================
  Widget _buildLandingContent(AppTheme theme) {
    return SingleChildScrollView(
      key: const ValueKey('Landing'),
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 50.0, vertical: 30),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AnimatedDefaultTextStyle(duration: const Duration(milliseconds: 300), style: TextStyle(fontSize: 55, fontWeight: FontWeight.w900, height: 1.1, letterSpacing: -1.5, color: theme.textColor, fontFamily: 'Segoe UI'), child: const Text("Quản Lý Thông Minh.")),
          const SizedBox(height: 15),
          Text("Chúng tôi biến ý tưởng thành những giải pháp công nghệ thông minh và giá trị.", style: TextStyle(fontSize: 15, color: theme.primaryColor, fontWeight: FontWeight.w600)),
          const SizedBox(height: 40),
          _buildSectionTitle("KHỞI NGUYÊN & SỨ MỆNH", theme),
          const SizedBox(height: 12),
          AnimatedDefaultTextStyle(duration: const Duration(milliseconds: 300), style: TextStyle(fontSize: 14, color: theme.subTextColor, height: 1.6, fontFamily: 'Segoe UI'), child: const Text("Ra mắt vào năm 2026, được phát triển bởi SOLVIA. Solvia SAMS ra đời với mục tiêu chiến lược là giải phóng con người khỏi các rào cản vật lý trong công tác quản lý bằng cách loại bỏ thẻ từ, vân tay và các quy trình điểm danh thủ công rườm rà, kém hiệu quả. SAMS ứng dụng công nghệ nhận diện khuôn mặt có độ chính xác cao, tích hợp mô hình AI quản lý thông minh và chặt chẽ, cho phép tự động hóa quá trình kiểm soát theo thời gian thực, đảm bảo tính liền mạch và bảo mật, trở thành cánh tay đắc lực trong quản lý, đồng thời tối ưu hóa chi phí, thời gian, nhân công, nâng cao hiệu suất và góp phần định hình chuẩn mực quản lý mới trong thời đại chuyển đổi số.")),
          const SizedBox(height: 40),

          AnimatedContainer(
            duration: const Duration(milliseconds: 400),
            width: double.infinity, height: 160,
            decoration: BoxDecoration(color: theme.cardColor, borderRadius: BorderRadius.circular(16), border: Border.all(color: theme.borderColor), boxShadow: theme.isDarkMode ? [] : [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 15, offset: const Offset(0, 4))]),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.important_devices_rounded, color: theme.textColor.withOpacity(0.15), size: 30),
                  const SizedBox(height: 8),
                  Text("Không gian hiển thị Mockup Thiết bị ESP32 & Giao diện", style: TextStyle(color: theme.subTextColor.withOpacity(0.5), fontSize: 12, fontStyle: FontStyle.italic)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 50),

          _buildSectionTitle("ĐỘT PHÁ CÔNG NGHỆ VERSION 1.0", theme),
          const SizedBox(height: 20),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _buildFeatureItem(Icons.bolt_rounded, "Tối ưu thời gian", "Xử lý nhận diện khuôn mặt tốc độ cao, cập nhật nhanh chóng.", theme)),
              const SizedBox(width: 20),
              Expanded(child: _buildFeatureItem(Icons.verified_user_rounded, "Chính Xác 99.9%", "Kháng giả mạo (Anti-Spoofing) cấp độ cao, loại bỏ hoàn toàn rủi ro sử dụng hình ảnh hay video 2D.", theme)),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _buildFeatureItem(Icons.hub_rounded, "Tích hợp AI", "Tích hợp AI trong việc quản lí, tối ưu hóa thời gian.", theme)),
              const SizedBox(width: 20),
              Expanded(child: _buildFeatureItem(Icons.all_inclusive_rounded, "Tối ưu chi phí", "Hệ sinh thái đa dạng, có thể điểm danh qua thiết bị riêng của SAMS, hoặc điện thoại, máy tính.", theme)),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _buildFeatureItem(Icons.insights_rounded, "Báo Cáo Tự Động 24/7", "Bảng điều khiển tổng hợp dữ liệu thời gian thực, tự động trích xuất file quản trị.", theme)),
              const SizedBox(width: 20),
              Expanded(child: _buildFeatureItem(Icons.energy_savings_leaf_rounded, "Cloud AI, DATA", "Hệ thống triển khai trên server cloud, không tốn tài nguyên thiết bị bên ngoài, sử dụng ở mọi nơi.", theme)),
            ],
          ),
          const SizedBox(height: 50),

          _buildSectionTitle("HỆ SINH THÁI KHÉP KÍN", theme),
          const SizedBox(height: 15),
          Row(
            children: [
              Expanded(child: _buildProductCard("SAMS Terminal", "Thiết bị nhận diện", "Thiết bị nhỏ gọn, chi phí thấp, kết nối mạng không dây hoặc nội bộ.", Icons.camera_front_rounded, theme)),
              const SizedBox(width: 15),
              Expanded(child: _buildProductCard("SAMS Engine", "Bộ não AI", "Máy chủ xử lý thuật toán thông minh.", Icons.memory_rounded, theme)),
              const SizedBox(width: 15),
              Expanded(child: _buildProductCard("SAMS APP", "Phần mềm App", "Nền tảng quản lý thông minh trên di động và máy tính.", Icons.dashboard_customize_rounded, theme)),
            ],
          ),
          const SizedBox(height: 60),
          Divider(color: theme.borderColor, thickness: 1),
          const SizedBox(height: 30),

          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 60, height: 60,
                decoration: BoxDecoration(color: theme.textColor.withOpacity(0.05), borderRadius: BorderRadius.circular(12), border: Border.all(color: theme.borderColor)),
                child: Center(child: Text("LOGO\nSOLVIA", textAlign: TextAlign.center, style: TextStyle(fontSize: 9, color: theme.subTextColor))),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AnimatedDefaultTextStyle(duration: const Duration(milliseconds: 300), style: TextStyle(color: theme.textColor, fontWeight: FontWeight.bold, letterSpacing: 1.2, fontSize: 13, fontFamily: 'Segoe UI'), child: const Text("VỀ THƯƠNG HIỆU SOLVIA")),
                    const SizedBox(height: 6),
                    AnimatedDefaultTextStyle(duration: const Duration(milliseconds: 300), style: TextStyle(fontSize: 13, color: theme.subTextColor, height: 1.5, fontFamily: 'Segoe UI'), child: const Text("Chúng tôi là đội ngũ kiến tạo nên những giải pháp công nghệ thông minh. Solvia tin rằng, công nghệ vĩ đại nhất là công nghệ hoạt động lặng lẽ trong nền, nhường lại sự tiện nghi và quyền kiểm soát tuyệt đối cho con người.")),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 40),
          Center(child: Text("© 2026 Solvia SAMS Ecosystem", style: TextStyle(color: theme.subTextColor, fontSize: 11))),
        ],
      ),
    );
  }

  // ================== 2. FORM ĐĂNG NHẬP ==================
  Widget _buildLoginForm(AppTheme theme) {
    return SingleChildScrollView(
      key: const ValueKey('Login'),
      physics: const BouncingScrollPhysics(),
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 380),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("HỆ THỐNG QUẢN TRỊ", style: TextStyle(color: theme.primaryColor, fontWeight: FontWeight.bold, letterSpacing: 1.2, fontSize: 11)),
              const SizedBox(height: 8),
              AnimatedDefaultTextStyle(duration: const Duration(milliseconds: 300), style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: theme.textColor, fontFamily: 'Segoe UI'), child: const Text("Đăng Nhập")),
              const SizedBox(height: 35),

              _buildInputLabel("Email hoặc Tên đăng nhập", theme),
              _buildTextField(Icons.person_outline, "Nhập email của bạn", controller: _logUserCtrl, errorText: _logUserError, theme: theme),
              const SizedBox(height: 20),

              _buildInputLabel("Mật khẩu", theme),
              _buildTextField(Icons.lock_outline, "Nhập mật khẩu", isObscure: true, controller: _logPassCtrl, errorText: _logPassError, theme: theme),
              const SizedBox(height: 20),

              _buildInputLabel("Chọn quyền truy cập", theme),
              Row(
                children: [
                  _buildRoleOption("Thành viên", theme),
                  const SizedBox(width: 15),
                  _buildRoleOption("Admin", theme),
                ],
              ),
              const SizedBox(height: 35),

              SizedBox(
                width: double.infinity, height: 48,
                child: ElevatedButton(
                  onPressed: () async {
                    setState(() {
                      _logUserError = _logUserCtrl.text.trim().isEmpty ? "Vui lòng nhập tài khoản" : null;
                      _logPassError = _logPassCtrl.text.isEmpty ? "Vui lòng nhập mật khẩu" : null;
                    });

                    if (_logUserError == null && _logPassError == null) {
                      showDialog(context: context, barrierDismissible: false, builder: (c) => Center(child: CircularProgressIndicator(color: theme.primaryColor)));

                      try {
                        Map<String, dynamic> payload = {
                          "username": _logUserCtrl.text.trim(),
                          "password": _logPassCtrl.text,
                          "role": selectedRole,
                        };

                        var response = await http.post(
                            Uri.parse('http://127.0.0.1:8000/api/login'),
                            headers: {"Content-Type": "application/json"},
                            body: jsonEncode(payload)
                        );

                        if (context.mounted) Navigator.pop(context);

                        if (response.statusCode == 200) {
                          var data = jsonDecode(response.body);
                          if (data['status'] == 'success') {
                            globals.currentUserId = data['data']['user_id'];

                            String hexColor = data['data']['setting_theme_color'] ?? "0xFF448AFF";
                            double savedFontLevel = (data['data']['setting_font_scale'] ?? 2.0).toDouble();
                            if (savedFontLevel < 1.0) savedFontLevel = 1.0;
                            if (savedFontLevel > 3.0) savedFontLevel = 3.0;

                            globals.currentLanguage = data['data']['setting_language'] ?? 'Tiếng Việt';
                            globals.currentTimezone = data['data']['setting_timezone'] ?? 'UTC +07:00 (Hồ Chí Minh)';

                            AppTheme.instance.changeColor(Color(int.parse(hexColor)));
                            AppTheme.instance.changeFontSize(savedFontLevel);

                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(data['message']), backgroundColor: Colors.green));
                            Navigator.pushReplacement(context, appleTransition(const SuperAdminDashboardScreen()));
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(data['message']), backgroundColor: Colors.redAccent));
                          }
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Lỗi Server: ${response.statusCode}"), backgroundColor: Colors.redAccent));
                        }
                      } catch (e) {
                        if (context.mounted) Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Không kết nối được tới máy chủ!"), backgroundColor: Colors.redAccent));
                      }
                    }
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: theme.primaryColor, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)), elevation: 0),
                  child: const Text("XÁC NHẬN ĐĂNG NHẬP", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 1.2, fontSize: 13)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ================== 3. FORM ĐĂNG KÝ ==================
  Widget _buildRegisterForm(AppTheme theme) {
    return SingleChildScrollView(
      key: const ValueKey('Register'),
      physics: const BouncingScrollPhysics(),
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 380),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("GIA NHẬP HỆ THỐNG", style: TextStyle(color: theme.primaryColor, fontWeight: FontWeight.bold, letterSpacing: 1.2, fontSize: 11)),
              const SizedBox(height: 8),
              AnimatedDefaultTextStyle(duration: const Duration(milliseconds: 300), style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: theme.textColor, fontFamily: 'Segoe UI'), child: const Text("Đăng Ký")),
              const SizedBox(height: 35),

              _buildInputLabel("Họ và tên", theme),
              _buildTextField(Icons.badge_outlined, "Nhập họ và tên đầy đủ", controller: _regNameCtrl, errorText: _nameError, theme: theme),
              const SizedBox(height: 15),

              _buildInputLabel("Email", theme),
              _buildTextField(Icons.email_outlined, "Nhập địa chỉ email", controller: _regEmailCtrl, errorText: _emailError, theme: theme),
              const SizedBox(height: 15),

              _buildInputLabel("Số điện thoại", theme),
              _buildTextField(Icons.phone_outlined, "Nhập số điện thoại liên lạc", controller: _regPhoneCtrl, errorText: _phoneError, theme: theme),
              const SizedBox(height: 15),

              _buildInputLabel("Mật khẩu", theme),
              _buildTextField(Icons.lock_outline, "Tạo mật khẩu an toàn", isObscure: true, controller: _regPassCtrl, errorText: _passError, theme: theme),
              const SizedBox(height: 15),

              _buildInputLabel("Đăng ký phân quyền", theme),
              Row(
                children: [
                  _buildRoleOption("Thành viên", theme),
                  const SizedBox(width: 15),
                  _buildRoleOption("Admin", theme),
                ],
              ),
              const SizedBox(height: 8),

              Text("Lưu ý: Quyền Admin bao gồm Người quản lý và Super Admin.", style: TextStyle(color: theme.subTextColor, fontSize: 11, fontStyle: FontStyle.italic)),

              const SizedBox(height: 35),

              SizedBox(
                width: double.infinity, height: 48,
                child: ElevatedButton(
                  onPressed: () async {
                    if (_validateRegistration()) {
                      showDialog(context: context, barrierDismissible: false, builder: (c) => Center(child: CircularProgressIndicator(color: theme.primaryColor)));

                      try {
                        Map<String, dynamic> payload = {
                          "full_name": _regNameCtrl.text.trim(),
                          "email": _regEmailCtrl.text.trim(),
                          "phone": _regPhoneCtrl.text.trim(),
                          "password": _regPassCtrl.text,
                          "role": selectedRole,
                        };

                        var response = await http.post(
                            Uri.parse('http://127.0.0.1:8000/api/register'),
                            headers: {"Content-Type": "application/json"},
                            body: jsonEncode(payload)
                        );

                        if (context.mounted) Navigator.pop(context);

                        if (response.statusCode == 200) {
                          var data = jsonDecode(response.body);
                          if (data['status'] == 'success') {
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(data['message']), backgroundColor: Colors.green));
                            setState(() { currentView = ViewState.login; });
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(data['message']), backgroundColor: Colors.redAccent));
                          }
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Lỗi kết nối Server! Mã lỗi: ${response.statusCode}"), backgroundColor: Colors.redAccent));
                        }
                      } catch (e) {
                        if (context.mounted) Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Không tìm thấy Server Python. Hãy chắc chắn Server đang chạy!"), backgroundColor: Colors.redAccent));
                      }
                    }
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: theme.primaryColor, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)), elevation: 0),
                  child: const Text("TẠO TÀI KHOẢN MỚI", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 1.2, fontSize: 13)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ================== CÁC WIDGET BỔ TRỢ ==================

  Widget _buildModernHeader(AppTheme theme) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      height: 60,
      padding: const EdgeInsets.symmetric(horizontal: 30),
      decoration: BoxDecoration(
          color: theme.backgroundColor,
          border: Border(bottom: BorderSide(color: theme.borderColor, width: 1.0))
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          if (currentView != ViewState.landing)
            TextButton(
              onPressed: () => setState(() => currentView = ViewState.landing),
              child: Row(
                children: [
                  Icon(Icons.arrow_back_rounded, color: theme.subTextColor, size: 16),
                  const SizedBox(width: 6),
                  Text("Trang Chủ", style: TextStyle(color: theme.subTextColor, fontWeight: FontWeight.bold, fontSize: 13)),
                ],
              ),
            ),
          const Spacer(),
          TextButton(
            onPressed: () => setState(() => currentView = ViewState.login),
            child: AnimatedDefaultTextStyle(duration: const Duration(milliseconds: 300), style: TextStyle(color: currentView == ViewState.login ? theme.primaryColor : theme.subTextColor, fontWeight: currentView == ViewState.login ? FontWeight.bold : FontWeight.normal, fontSize: 13, fontFamily: 'Segoe UI'), child: const Text("Đăng Nhập")),
          ),
          const SizedBox(width: 15),
          TextButton(
            onPressed: () => setState(() => currentView = ViewState.register),
            child: AnimatedDefaultTextStyle(duration: const Duration(milliseconds: 300), style: TextStyle(color: currentView == ViewState.register ? theme.primaryColor : theme.subTextColor, fontWeight: currentView == ViewState.register ? FontWeight.bold : FontWeight.normal, fontSize: 13, fontFamily: 'Segoe UI'), child: const Text("Đăng Ký")),
          ),
        ],
      ),
    );
  }

  Widget _buildInputLabel(String text, AppTheme theme) {
    return Padding(padding: const EdgeInsets.only(bottom: 6), child: AnimatedDefaultTextStyle(duration: const Duration(milliseconds: 300), style: TextStyle(color: theme.textColor.withOpacity(0.8), fontSize: 12, fontWeight: FontWeight.bold, fontFamily: 'Segoe UI'), child: Text(text)));
  }

  Widget _buildTextField(IconData icon, String hint, {bool isObscure = false, TextEditingController? controller, String? errorText, required AppTheme theme}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 45,
          child: TextField(
            controller: controller,
            obscureText: isObscure,
            style: TextStyle(color: theme.textColor, fontSize: 13),
            decoration: InputDecoration(
              contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 15),
              prefixIcon: Icon(icon, color: theme.primaryColor, size: 18),
              hintText: hint,
              hintStyle: TextStyle(color: theme.subTextColor.withOpacity(0.5), fontSize: 13),
              filled: true,
              fillColor: theme.textColor.withOpacity(0.04), // Đổ nền xám nhạt theo nền chuẩn Apple
              enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: errorText != null ? Colors.redAccent : theme.borderColor)
              ),
              focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: errorText != null ? Colors.redAccent : theme.primaryColor, width: 1.5)
              ),
            ),
          ),
        ),
        if (errorText != null) ...[
          const SizedBox(height: 6),
          Row(
            children: [
              const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 12),
              const SizedBox(width: 4),
              Expanded(child: Text(errorText, style: const TextStyle(color: Colors.redAccent, fontSize: 11, fontStyle: FontStyle.italic))),
            ],
          )
        ]
      ],
    );
  }

  Widget _buildRoleOption(String role, AppTheme theme) {
    bool isSelected = selectedRole == role;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => selectedRole = role),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? theme.primaryColor.withOpacity(0.1) : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: isSelected ? theme.primaryColor : theme.borderColor, width: 1.2),
          ),
          child: Center(child: AnimatedDefaultTextStyle(duration: const Duration(milliseconds: 300), style: TextStyle(color: isSelected ? theme.primaryColor : theme.subTextColor, fontWeight: FontWeight.bold, fontSize: 13, fontFamily: 'Segoe UI'), child: Text(role))),
        ),
      ),
    );
  }

  Route appleTransition(Widget page) {
    return PageRouteBuilder(
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionDuration: const Duration(milliseconds: 600),
      reverseTransitionDuration: const Duration(milliseconds: 400),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        var curve = Curves.easeInOutCubic;
        var scaleTween = Tween(begin: 0.95, end: 1.0).chain(CurveTween(curve: curve));
        var fadeTween = Tween(begin: 0.0, end: 1.0).chain(CurveTween(curve: curve));
        var slideTween = Tween(begin: const Offset(0.0, 0.03), end: Offset.zero).chain(CurveTween(curve: curve));

        return FadeTransition(
          opacity: animation.drive(fadeTween),
          child: ScaleTransition(
            scale: animation.drive(scaleTween),
            child: SlideTransition(
              position: animation.drive(slideTween),
              child: child,
            ),
          ),
        );
      },
    );
  }

  Widget _buildSectionTitle(String title, AppTheme theme) => Text(title, style: TextStyle(color: theme.primaryColor, fontWeight: FontWeight.bold, letterSpacing: 1.2, fontSize: 12));

  Widget _buildProductCard(String t, String s, String d, IconData i, AppTheme theme) => AnimatedContainer(duration: const Duration(milliseconds: 400), padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: theme.cardColor, borderRadius: BorderRadius.circular(12), border: Border.all(color: theme.borderColor), boxShadow: theme.isDarkMode ? [] : [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))]), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [AnimatedContainer(duration: const Duration(milliseconds: 300), padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: theme.primaryColor.withOpacity(0.1), borderRadius: BorderRadius.circular(8)), child: Icon(i, color: theme.primaryColor, size: 22)), const SizedBox(height: 12), AnimatedDefaultTextStyle(duration: const Duration(milliseconds: 300), style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: theme.textColor, fontFamily: 'Segoe UI'), child: Text(t)), const SizedBox(height: 4), Text(s, style: TextStyle(fontSize: 11, color: theme.primaryColor)), const SizedBox(height: 8), AnimatedDefaultTextStyle(duration: const Duration(milliseconds: 300), style: TextStyle(fontSize: 11, color: theme.subTextColor, height: 1.5, fontFamily: 'Segoe UI'), child: Text(d))]));

  Widget _buildFeatureItem(IconData i, String t, String d, AppTheme theme) => Row(crossAxisAlignment: CrossAxisAlignment.start, children: [AnimatedContainer(duration: const Duration(milliseconds: 400), padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: theme.cardColor, borderRadius: BorderRadius.circular(8), border: Border.all(color: theme.borderColor), boxShadow: theme.isDarkMode ? [] : [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 5, offset: const Offset(0, 2))]), child: Icon(i, color: theme.primaryColor, size: 18)), const SizedBox(width: 12), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [AnimatedDefaultTextStyle(duration: const Duration(milliseconds: 300), style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: theme.textColor, fontFamily: 'Segoe UI'), child: Text(t)), const SizedBox(height: 4), AnimatedDefaultTextStyle(duration: const Duration(milliseconds: 300), style: TextStyle(fontSize: 12, color: theme.subTextColor, height: 1.5, fontFamily: 'Segoe UI'), child: Text(d))]))]);
}