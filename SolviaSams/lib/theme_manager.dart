import 'package:flutter/material.dart';

// Kho lưu trữ Theme toàn cục (Global State)
class AppTheme extends ChangeNotifier {
  static final AppTheme instance = AppTheme._internal();
  AppTheme._internal();

  // MẶC ĐỊNH LÀ NỀN TRẮNG (FALSE)
  bool _isDarkMode = false;
  bool get isDarkMode => _isDarkMode;

  // 1. MÀU NỀN CƠ BẢN (Apple Style)
  Color get backgroundColor => _isDarkMode ? const Color(0xFF000000) : const Color(0xFFF5F5F7);
  Color get cardColor => _isDarkMode ? const Color(0xFF1C1C1E) : const Color(0xFFFFFFFF);
  Color get textColor => _isDarkMode ? const Color(0xFFFFFFFF) : const Color(0xFF1D1D1F);
  Color get subTextColor => const Color(0xFF86868B); // Màu xám chuẩn iOS
  Color get borderColor => _isDarkMode ? Colors.white.withOpacity(0.1) : const Color(0xFFE5E5EA);

  // 2. MÀU TRẠNG THÁI (Tự động đậm lên ở nền Trắng, sáng lên ở nền Đen)
  Color get successColor => _isDarkMode ? const Color(0xFF32D74B) : const Color(0xFF34C759); // Xanh lá
  Color get warningColor => _isDarkMode ? const Color(0xFFFF9F0A) : const Color(0xFFFF9500); // Cam
  Color get errorColor   => _isDarkMode ? const Color(0xFFFF453A) : const Color(0xFFFF3B30); // Đỏ
  Color get infoColor    => _isDarkMode ? const Color(0xFF64D2FF) : const Color(0xFF007AFF); // Xanh dương
  Color get purpleColor  => _isDarkMode ? const Color(0xFFBF5AF2) : const Color(0xFFAF52DE); // Tím

  // 3. MÀU CHỦ ĐẠO TÙY CHỌN
  Color _primaryColor = const Color(0xFF007AFF); // Mặc định là Apple Blue
  double _fontSizeLevel = 2.0;

  Color get primaryColor => _primaryColor;
  double get fontSizeLevel => _fontSizeLevel;
  double get fontScale => 1.0 + (_fontSizeLevel - 2.0) * 0.15;

  // --- CÁC HÀM XỬ LÝ (KÍCH HOẠT HIỆU ỨNG MƯỢT MÀ) ---
  void toggleTheme() {
    _isDarkMode = !_isDarkMode;
    notifyListeners();
  }

  void changeColor(Color color) {
    _primaryColor = color;
    notifyListeners();
  }

  void changeFontSize(double level) {
    _fontSizeLevel = level;
    notifyListeners();
  }

  void reset() {
    _isDarkMode = false;
    _primaryColor = const Color(0xFF007AFF);
    _fontSizeLevel = 2.0;
    notifyListeners();
  }
}