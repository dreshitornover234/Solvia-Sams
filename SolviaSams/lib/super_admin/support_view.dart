import 'package:flutter/material.dart';
import '../theme_manager.dart';

class SupportView extends StatefulWidget {
  const SupportView({super.key});

  @override
  State<SupportView> createState() => _SupportViewState();
}

class _SupportViewState extends State<SupportView> {
  String _selectedTopic = 'Lỗi kỹ thuật / Thiết bị';
  final List<String> _supportTopics = ['Lỗi kỹ thuật / Thiết bị', 'Hướng dẫn sử dụng', 'Nâng cấp / Thanh toán', 'Góp ý phát triển', 'Khác'];
  final List<bool> _faqExpanded = [false, false, false];

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: AppTheme.instance,
      builder: (context, child) {
        final theme = AppTheme.instance;

        return SingleChildScrollView(
          key: const ValueKey('SupportView'),
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 40.0, vertical: 30.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // === HEADER ===
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 300),
                style: TextStyle(fontSize: 28 * theme.fontScale, fontWeight: FontWeight.w900, color: theme.textColor, letterSpacing: 1.0, fontFamily: 'Segoe UI'),
                child: const Text("Trung Tâm Hỗ Trợ & CSKH"),
              ),
              const SizedBox(height: 8),
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 300),
                style: TextStyle(fontSize: 14 * theme.fontScale, color: theme.subTextColor, fontFamily: 'Segoe UI'),
                child: const Text("Chúng tôi luôn ở đây để giúp bạn giải quyết mọi vấn đề với hệ thống Solvia SAMS."),
              ),
              const SizedBox(height: 30),

              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // --- CỘT TRÁI ---
                  Expanded(
                    flex: 45,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSectionHeader(Icons.contact_support_rounded, "LIÊN HỆ TRỰC TIẾP", theme),
                        const SizedBox(height: 20),
                        Row(
                          children: [
                            Expanded(child: _buildContactCard(Icons.headset_mic_rounded, "Tổng đài Hotline", "1900 8888 (24/7)", theme)),
                            const SizedBox(width: 15),
                            Expanded(child: _buildContactCard(Icons.email_rounded, "Email Hỗ trợ", "support@solvia.com", theme)),
                          ],
                        ),
                        const SizedBox(height: 15),
                        _buildContactCard(Icons.groups_rounded, "Cộng đồng Solvia Việt Nam", "Tham gia Group Facebook hoặc Zalo để thảo luận.", theme, isFullWidth: true),

                        const SizedBox(height: 40),

                        _buildSectionHeader(Icons.help_outline_rounded, "CÂU HỎI THƯỜNG GẶP", theme),
                        const SizedBox(height: 20),
                        _buildFaqItem(0, "Làm sao để kết nối Camera mới vào hệ thống?", "Để kết nối Camera, bạn vào tab 'Sản phẩm', chọn 'Thêm Terminal' và nhập địa chỉ IP của thiết bị ESP32 tương ứng. Hãy đảm bảo Camera và máy chủ dùng chung một lớp mạng.", theme),
                        _buildFaqItem(1, "Hệ thống báo 'Không nhận diện được khuôn mặt'?", "Hãy kiểm tra lại độ sáng tại khu vực đặt Camera. Để AI InsightFace hoạt động tốt nhất, góc mặt nhân viên cần nhìn thẳng, không bị chói sáng ngược hoặc đeo khẩu trang quá kín.", theme),
                        _buildFaqItem(2, "Tôi có thể trích xuất báo cáo ra Excel không?", "Hoàn toàn được. Ở mục 'Quản lý Sản phẩm', sẽ có nút 'Xuất báo cáo (Export)'. Bạn có thể chọn khoảng thời gian tùy ý để tải file định dạng .xlsx về máy.", theme),
                      ],
                    ),
                  ),

                  const SizedBox(width: 40),

                  // --- CỘT PHẢI ---
                  Expanded(
                    flex: 55,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 400),
                      padding: const EdgeInsets.all(30),
                      decoration: BoxDecoration(
                        color: theme.cardColor, borderRadius: BorderRadius.circular(20), border: Border.all(color: theme.borderColor),
                        boxShadow: theme.isDarkMode ? [] : [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 15, offset: const Offset(0, 4))],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildSectionHeader(Icons.send_rounded, "GỬI YÊU CẦU CHO CHÚNG TÔI", theme),
                          const SizedBox(height: 25),
                          Row(
                            children: [
                              Expanded(child: _buildTextField("Họ và tên người gửi", Icons.person_outline, "Nguyễn Văn A (Mặc định)", theme, isReadOnly: true)),
                              const SizedBox(width: 20),
                              Expanded(child: _buildTextField("Mã định danh dự án", Icons.qr_code_rounded, "SAMS-PRO-001", theme, isReadOnly: true)),
                            ],
                          ),
                          const SizedBox(height: 20),
                          _buildDropdownField("Chủ đề cần hỗ trợ", Icons.topic_outlined, _selectedTopic, _supportTopics, (val) { setState(() { _selectedTopic = val!; }); }, theme),
                          const SizedBox(height: 20),
                          _buildTextArea("Nội dung chi tiết", Icons.edit_note_rounded, "Hãy mô tả chi tiết vấn đề bạn đang gặp phải, bao gồm cả mã lỗi (nếu có)...", theme),
                          const SizedBox(height: 30),
                          Align(
                            alignment: Alignment.centerRight,
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 300),
                              child: ElevatedButton.icon(
                                onPressed: () {},
                                icon: Icon(Icons.send_rounded, color: Colors.white, size: 16 * theme.fontScale),
                                label: Text("GỬI YÊU CẦU HỖ TRỢ", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 1.0, fontSize: 13 * theme.fontScale)),
                                style: ElevatedButton.styleFrom(backgroundColor: theme.primaryColor, padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                              ),
                            ),
                          )
                        ],
                      ),
                    ),
                  )
                ],
              )
            ],
          ),
        );
      },
    );
  }

  Widget _buildSectionHeader(IconData icon, String title, AppTheme theme) {
    return Row(
      children: [
        AnimatedContainer(duration: const Duration(milliseconds: 300), child: Icon(icon, color: theme.primaryColor, size: 18 * theme.fontScale)), const SizedBox(width: 10),
        AnimatedDefaultTextStyle(duration: const Duration(milliseconds: 300), style: TextStyle(color: theme.textColor, fontSize: 14 * theme.fontScale, fontWeight: FontWeight.bold, letterSpacing: 1.2, fontFamily: 'Segoe UI'), child: Text(title)),
      ],
    );
  }

  Widget _buildContactCard(IconData icon, String title, String value, AppTheme theme, {bool isFullWidth = false}) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      width: isFullWidth ? double.infinity : null, padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: theme.cardColor, borderRadius: BorderRadius.circular(16), border: Border.all(color: theme.borderColor), boxShadow: theme.isDarkMode ? [] : [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))]),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AnimatedContainer(duration: const Duration(milliseconds: 300), padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: theme.primaryColor.withOpacity(0.15), borderRadius: BorderRadius.circular(10)), child: Icon(icon, color: theme.primaryColor, size: 20 * theme.fontScale)),
          const SizedBox(height: 15), AnimatedDefaultTextStyle(duration: const Duration(milliseconds: 300), style: TextStyle(color: theme.subTextColor, fontSize: 11 * theme.fontScale, fontWeight: FontWeight.bold, fontFamily: 'Segoe UI'), child: Text(title.toUpperCase())),
          const SizedBox(height: 6), AnimatedDefaultTextStyle(duration: const Duration(milliseconds: 300), style: TextStyle(color: theme.textColor, fontSize: 14 * theme.fontScale, fontWeight: FontWeight.bold, fontFamily: 'Segoe UI'), child: Text(value)),
        ],
      ),
    );
  }

  Widget _buildDropdownField(String label, IconData icon, String currentValue, List<String> items, Function(String?) onChanged, AppTheme theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(padding: const EdgeInsets.only(bottom: 6), child: AnimatedDefaultTextStyle(duration: const Duration(milliseconds: 300), style: TextStyle(color: theme.textColor.withOpacity(0.7), fontSize: 12 * theme.fontScale, fontWeight: FontWeight.bold, fontFamily: 'Segoe UI'), child: Text(label))),
        SizedBox(
          height: 45,
          child: DropdownButtonFormField<String>(
            value: currentValue, dropdownColor: theme.cardColor, style: TextStyle(color: theme.textColor, fontSize: 13 * theme.fontScale), icon: Icon(Icons.keyboard_arrow_down_rounded, color: theme.primaryColor, size: 18 * theme.fontScale),
            decoration: InputDecoration(contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 15), prefixIcon: Icon(icon, color: theme.primaryColor, size: 18 * theme.fontScale), filled: true, fillColor: theme.textColor.withOpacity(0.03), enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: theme.borderColor)), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: theme.primaryColor, width: 1.5))),
            items: items.map((String item) => DropdownMenuItem<String>(value: item, child: Text(item))).toList(), onChanged: onChanged,
          ),
        ),
      ],
    );
  }

  Widget _buildTextField(String label, IconData icon, String hint, AppTheme theme, {bool isReadOnly = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(padding: const EdgeInsets.only(bottom: 6), child: AnimatedDefaultTextStyle(duration: const Duration(milliseconds: 300), style: TextStyle(color: theme.textColor.withOpacity(0.7), fontSize: 12 * theme.fontScale, fontWeight: FontWeight.bold, fontFamily: 'Segoe UI'), child: Text(label))),
        SizedBox(
          height: 45,
          child: TextField(
            readOnly: isReadOnly, style: TextStyle(color: isReadOnly ? theme.subTextColor : theme.textColor, fontSize: 13 * theme.fontScale),
            decoration: InputDecoration(contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 15), prefixIcon: Icon(icon, color: isReadOnly ? theme.subTextColor.withOpacity(0.5) : theme.primaryColor, size: 18 * theme.fontScale), hintText: hint, hintStyle: TextStyle(color: theme.subTextColor.withOpacity(0.5), fontSize: 13 * theme.fontScale), filled: true, fillColor: isReadOnly ? Colors.transparent : theme.textColor.withOpacity(0.03), enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: theme.borderColor)), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: theme.primaryColor, width: 1.5))),
          ),
        ),
      ],
    );
  }

  Widget _buildTextArea(String label, IconData icon, String hint, AppTheme theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(padding: const EdgeInsets.only(bottom: 6), child: AnimatedDefaultTextStyle(duration: const Duration(milliseconds: 300), style: TextStyle(color: theme.textColor.withOpacity(0.7), fontSize: 12 * theme.fontScale, fontWeight: FontWeight.bold, fontFamily: 'Segoe UI'), child: Text(label))),
        TextField(
          maxLines: 6, style: TextStyle(color: theme.textColor, fontSize: 13 * theme.fontScale),
          decoration: InputDecoration(contentPadding: const EdgeInsets.symmetric(vertical: 15, horizontal: 15), hintText: hint, hintStyle: TextStyle(color: theme.subTextColor.withOpacity(0.5), fontSize: 13 * theme.fontScale), filled: true, fillColor: theme.textColor.withOpacity(0.03), enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: theme.borderColor)), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: theme.primaryColor, width: 1.5))),
        ),
      ],
    );
  }

  Widget _buildFaqItem(int index, String question, String answer, AppTheme theme) {
    bool isExpanded = _faqExpanded[index];
    return GestureDetector(
      onTap: () { setState(() { _faqExpanded[index] = !isExpanded; }); },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300), margin: const EdgeInsets.only(bottom: 12), padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(color: isExpanded ? theme.primaryColor.withOpacity(0.05) : theme.cardColor, borderRadius: BorderRadius.circular(12), border: Border.all(color: isExpanded ? theme.primaryColor.withOpacity(0.5) : theme.borderColor), boxShadow: (theme.isDarkMode || isExpanded) ? [] : [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 5, offset: const Offset(0, 2))]),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: AnimatedDefaultTextStyle(duration: const Duration(milliseconds: 300), style: TextStyle(color: isExpanded ? theme.primaryColor : theme.textColor, fontSize: 13 * theme.fontScale, fontWeight: FontWeight.bold, fontFamily: 'Segoe UI'), child: Text(question))),
                AnimatedRotation(turns: isExpanded ? 0.5 : 0, duration: const Duration(milliseconds: 300), child: Icon(Icons.keyboard_arrow_down_rounded, color: isExpanded ? theme.primaryColor : theme.subTextColor, size: 20 * theme.fontScale)),
              ],
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: 300), curve: Curves.easeInOut,
              child: isExpanded ? Padding(padding: const EdgeInsets.only(top: 12.0), child: AnimatedDefaultTextStyle(duration: const Duration(milliseconds: 300), style: TextStyle(color: theme.subTextColor, fontSize: 12 * theme.fontScale, height: 1.5, fontFamily: 'Segoe UI'), child: Text(answer))) : const SizedBox.shrink(),
            )
          ],
        ),
      ),
    );
  }
}