import 'package:flutter/material.dart';
import '../theme_manager.dart';
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
// ignore: avoid_web_libraries_in_flutter
import 'dart:ui_web' as ui_web;
import 'package:http/http.dart' as http;
import 'dart:convert';

class MemberProfileDialog extends StatefulWidget {
  final Map<String, dynamic> memberData;
  final bool isAdmin;

  const MemberProfileDialog({
    super.key,
    required this.memberData,
    this.isAdmin = false,
  });

  @override
  State<MemberProfileDialog> createState() => _MemberProfileDialogState();
}

class _MemberProfileDialogState extends State<MemberProfileDialog> {
  late Map<String, dynamic> _data;
  bool _isEditingViolations = false;

  @override
  void initState() {
    super.initState();
    _data = Map<String, dynamic>.from(widget.memberData);
    if (_data['violationHistory'] != null) {
      _data['violationHistory'] = List<String>.from(_data['violationHistory']);
    }
  }

  @override
  Widget build(BuildContext context) {
    bool isStudent = _data['role']?.toString().contains('Học sinh') ?? false;

    return AnimatedBuilder(
        animation: AppTheme.instance,
        builder: (context, child) {
          final theme = AppTheme.instance;
          Color roleColor = widget.isAdmin ? theme.primaryColor : (isStudent ? Colors.lightBlueAccent : Colors.greenAccent);

          String avatarUrl = _data['avatar_url']?.toString() ?? "";

          return Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: const EdgeInsets.all(20),
            child: Container(
              width: 650,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: const Color(0xFF0A101E),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: _isEditingViolations ? Colors.redAccent.withOpacity(0.5) : roleColor.withOpacity(0.3), width: _isEditingViolations ? 2.0 : 1.5),
                boxShadow: [BoxShadow(color: _isEditingViolations ? Colors.redAccent.withOpacity(0.1) : roleColor.withOpacity(0.15), blurRadius: 30, spreadRadius: 5)],
              ),
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // 1. ẢNH BÌA & AVATAR
                    SizedBox(
                      height: 180 * theme.fontScale,
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Container(height: 120 * theme.fontScale, width: double.infinity, decoration: BoxDecoration(gradient: LinearGradient(colors: [_isEditingViolations ? Colors.redAccent.withOpacity(0.4) : roleColor.withOpacity(0.4), Colors.black], begin: Alignment.topLeft, end: Alignment.bottomRight)), child: Align(alignment: Alignment.topRight, child: IconButton(padding: const EdgeInsets.all(15), onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close_rounded, color: Colors.white)))),

                          Positioned(
                              bottom: 0, left: 40,
                              child: Container(
                                  width: 100 * theme.fontScale, height: 100 * theme.fontScale,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF101520), shape: BoxShape.circle, border: Border.all(color: roleColor, width: 3), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 10)],
                                    image: avatarUrl.isNotEmpty ? DecorationImage(image: NetworkImage("http://127.0.0.1:8000$avatarUrl"), fit: BoxFit.cover) : null,
                                  ),
                                  child: avatarUrl.isEmpty ? Icon(Icons.person_rounded, size: 50 * theme.fontScale, color: roleColor) : null
                              )
                          ),

                          Positioned(bottom: 20 * theme.fontScale, left: 160 * theme.fontScale, child: Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), decoration: BoxDecoration(color: roleColor.withOpacity(0.15), borderRadius: BorderRadius.circular(8), border: Border.all(color: roleColor.withOpacity(0.5))), child: AnimatedDefaultTextStyle(duration: const Duration(milliseconds: 300), style: TextStyle(color: roleColor, fontSize: 12 * theme.fontScale, fontWeight: FontWeight.bold, fontFamily: 'Segoe UI'), child: Text(_data['role']?.toString() ?? "Thành viên"))))
                        ],
                      ),
                    ),

                    // 2. NỘI DUNG CHI TIẾT
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 40.0, vertical: 10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          AnimatedDefaultTextStyle(duration: const Duration(milliseconds: 300), style: TextStyle(color: Colors.white, fontSize: 24 * theme.fontScale, fontWeight: FontWeight.w900, fontFamily: 'Segoe UI'), child: Text(_data['name']?.toString() ?? "Chưa cập nhật tên")), const SizedBox(height: 5),
                          Row(children: [Icon(Icons.email_outlined, color: Colors.white54, size: 16 * theme.fontScale), const SizedBox(width: 8), AnimatedDefaultTextStyle(duration: const Duration(milliseconds: 300), style: TextStyle(color: Colors.white70, fontSize: 13 * theme.fontScale, fontFamily: 'Segoe UI'), child: Text(_data['email']?.toString() ?? "Chưa cập nhật email"))]),
                          const SizedBox(height: 30), Divider(color: Colors.white.withOpacity(0.05), thickness: 1), const SizedBox(height: 25),

                          _buildSectionTitle("THÔNG TIN CÁ NHÂN", Icons.account_box_rounded, roleColor, theme), const SizedBox(height: 15),
                          Row(children: [Expanded(child: _buildInfoField("Ngày sinh", _data['dob']?.toString() ?? "Chưa cập nhật", theme)), Expanded(child: _buildInfoField("Tôn giáo", _data['religion']?.toString() ?? "Chưa cập nhật", theme))]), const SizedBox(height: 15),
                          Row(children: [Expanded(child: _buildInfoField("Quê quán", _data['hometown']?.toString() ?? "Chưa cập nhật", theme)), Expanded(child: _buildInfoField("Nơi ở hiện tại", _data['currentAddress']?.toString() ?? "Chưa cập nhật", theme))]), const SizedBox(height: 30),

                          _buildSectionTitle("THÔNG TIN LIÊN HỆ", Icons.contact_mail_rounded, roleColor, theme), const SizedBox(height: 15),
                          Row(children: [Expanded(child: _buildInfoField("Số điện thoại", _data['phone']?.toString() ?? "Chưa cập nhật", theme)), Expanded(child: _buildInfoField("Facebook", _data['facebook']?.toString() ?? "Chưa liên kết", theme, isLink: true))]), const SizedBox(height: 30),

                          _buildSectionTitle(isStudent ? "THÔNG TIN HỌC TẬP" : "THÔNG TIN CÔNG TÁC", isStudent ? Icons.school_rounded : Icons.work_outline_rounded, roleColor, theme), const SizedBox(height: 15),
                          Row(children: [Expanded(child: _buildInfoField(isStudent ? "Trạng thái" : "Chức vụ", _data['jobRole']?.toString() ?? "Chưa cập nhật", theme)), Expanded(child: _buildInfoField(isStudent ? "Khóa & Năm học" : "Bằng cấp", _data['degree']?.toString() ?? "Chưa cập nhật", theme))]), const SizedBox(height: 15),

                          _buildInfoField("Đơn vị / Cơ sở", _data['school']?.toString() ?? "Chưa cập nhật", theme, isFullWidth: true),

                          // GỌI HÀM VẼ TRƯỜNG ĐỘNG
                          _buildDynamicJobFields(theme),

                          // ==============================================================
                          // KHỐI LỊCH SỬ VI PHẠM & NGHỈ PHÉP
                          // ==============================================================
                          if (isStudent && _data['violationHistory'] != null) ...[
                            const SizedBox(height: 30), Divider(color: Colors.redAccent.withOpacity(0.2), thickness: 1), const SizedBox(height: 25),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                _buildSectionTitle("LỊCH SỬ ĐIỂM DANH & VI PHẠM", Icons.warning_amber_rounded, Colors.redAccent, theme),
                                if ((_data['violationHistory'] as List).isNotEmpty && widget.isAdmin)
                                  TextButton.icon(
                                      onPressed: () {
                                        setState(() { _data['lateCount'] = 0; _data['absentCount'] = 0; _data['excusedCount'] = 0; _data['violationHistory'] = <String>[]; });
                                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Đã xóa toàn bộ dữ liệu."), backgroundColor: Colors.green));
                                      },
                                      icon: Icon(Icons.cleaning_services_rounded, size: 14 * theme.fontScale, color: Colors.greenAccent),
                                      label: Text("Tẩy trắng dữ liệu", style: TextStyle(color: Colors.greenAccent, fontSize: 12 * theme.fontScale))
                                  )
                              ],
                            ),
                            const SizedBox(height: 15),

                            Container(
                              padding: const EdgeInsets.all(15), decoration: BoxDecoration(color: Colors.redAccent.withOpacity(0.05), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.redAccent.withOpacity(0.2))),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceAround,
                                children: [
                                  _buildViolationStat("ĐI TRỄ", _data['lateCount']?.toString() ?? "0", theme.warningColor, theme), Container(width: 1, height: 40, color: theme.errorColor.withOpacity(0.2)),
                                  _buildViolationStat("NGHỈ HỌC", _data['absentCount']?.toString() ?? "0", theme.errorColor, theme), Container(width: 1, height: 40, color: theme.errorColor.withOpacity(0.2)),
                                  _buildViolationStat("CÓ PHÉP", _data['excusedCount']?.toString() ?? "0", theme.infoColor, theme),
                                ],
                              ),
                            ),
                            const SizedBox(height: 20),

                            AnimatedDefaultTextStyle(duration: const Duration(milliseconds: 300), style: TextStyle(color: Colors.white54, fontSize: 12 * theme.fontScale, fontWeight: FontWeight.bold, fontFamily: 'Segoe UI'), child: const Text("CHI TIẾT (TỪNG MÔN / TỪNG NGÀY):")),
                            const SizedBox(height: 10),

                            Container(
                              padding: const EdgeInsets.all(15), decoration: BoxDecoration(color: _isEditingViolations ? Colors.redAccent.withOpacity(0.02) : Colors.transparent, borderRadius: BorderRadius.circular(12), border: Border.all(color: _isEditingViolations ? Colors.redAccent.withOpacity(0.3) : Colors.transparent)),
                              child: (_data['violationHistory'] as List).isEmpty
                                  ? Padding(padding: const EdgeInsets.symmetric(vertical: 10), child: Text("Học sinh đi học đầy đủ, không có vi phạm.", style: TextStyle(color: Colors.greenAccent.withOpacity(0.7), fontStyle: FontStyle.italic, fontSize: 13 * theme.fontScale)))
                                  : Column(
                                children: (_data['violationHistory'] as List<String>).asMap().entries.map((entry) {
                                  int idx = entry.key; String historyItem = entry.value;
                                  Color itemColor = historyItem.contains("phép") ? theme.infoColor : (historyItem.contains("Nghỉ") ? theme.errorColor : theme.warningColor);                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 8.0),
                                    child: Row(
                                      crossAxisAlignment: CrossAxisAlignment.center,
                                      children: [
                                        Icon(Icons.circle, size: 8 * theme.fontScale, color: itemColor), const SizedBox(width: 10),
                                        Expanded(child: Text(historyItem, style: TextStyle(color: Colors.white70, fontSize: 13 * theme.fontScale))),
                                        if (_isEditingViolations)
                                          IconButton(
                                            onPressed: () {
                                              setState(() {
                                                (_data['violationHistory'] as List).removeAt(idx);
                                                if (historyItem.contains("Đi trễ") && _data['lateCount'] > 0) _data['lateCount']--;
                                                if (historyItem.contains("Nghỉ") && !historyItem.contains("phép") && _data['absentCount'] > 0) _data['absentCount']--;
                                                if (historyItem.contains("phép") && _data['excusedCount'] > 0) _data['excusedCount']--;
                                              });
                                            },
                                            icon: Icon(Icons.delete_outline_rounded, size: 18 * theme.fontScale, color: Colors.redAccent),
                                          )
                                      ],
                                    ),
                                  );
                                }).toList(),
                              ),
                            ),
                          ],
                          const SizedBox(height: 30),

                          if (isStudent && widget.isAdmin) ...[
                            Divider(color: Colors.white.withOpacity(0.05), thickness: 1),
                            const SizedBox(height: 15),
                            Wrap(
                              alignment: WrapAlignment.end, spacing: 15, runSpacing: 15,
                              children: [
                                ElevatedButton.icon(
                                  onPressed: () => _showFaceEnrollmentDialog(context, theme),
                                  icon: Icon(Icons.face_retouching_natural_rounded, color: Colors.white, size: 18 * theme.fontScale),
                                  label: Text("Đăng ký khuôn mặt", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13 * theme.fontScale)),
                                  style: ElevatedButton.styleFrom(backgroundColor: theme.primaryColor, padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                                ),
                                OutlinedButton.icon(
                                  onPressed: () => _showAddLeaveDialog(context, theme),
                                  icon: Icon(Icons.event_available_rounded, color: Colors.lightBlueAccent, size: 18 * theme.fontScale),
                                  label: Text("Ghi nhận nghỉ phép", style: TextStyle(color: Colors.lightBlueAccent, fontWeight: FontWeight.bold, fontSize: 13 * theme.fontScale)),
                                  style: OutlinedButton.styleFrom(side: BorderSide(color: Colors.lightBlueAccent.withOpacity(0.5)), padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                                ),
                                ElevatedButton.icon(
                                  onPressed: () => setState(() => _isEditingViolations = !_isEditingViolations),
                                  icon: Icon(_isEditingViolations ? Icons.check_rounded : Icons.edit_note_rounded, color: Colors.white, size: 18 * theme.fontScale),
                                  label: Text(_isEditingViolations ? "Hoàn tất chỉnh sửa" : "Chỉnh sửa vi phạm", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13 * theme.fontScale)),
                                  style: ElevatedButton.styleFrom(backgroundColor: _isEditingViolations ? Colors.green : Colors.grey[800], padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                                )
                              ],
                            )
                          ],
                          const SizedBox(height: 20),
                        ],
                      ),
                    )
                  ],
                ),
              ),
            ),
          );
        }
    );
  }

  // --- HÀM HIỂN THỊ CÁC TRƯỜNG ĐỘNG (ĐÃ FIX TẬN GỐC LỖI NULL) ---
  Widget _buildDynamicJobFields(AppTheme theme) {
    String role = _data['jobRole']?.toString() ?? "";
    String d1 = _data['dynamic_1']?.toString() ?? "";
    String d2 = _data['dynamic_2']?.toString() ?? "";
    String d3 = _data['dynamic_3']?.toString() ?? "";

    if (role == 'Giáo viên' || role == 'Giảng viên') {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 15),
          Row(children: [Expanded(child: _buildInfoField("Môn giảng dạy chính", d1, theme)), const SizedBox(width: 20), Expanded(child: _buildInfoField("Số năm kinh nghiệm", d2, theme))]),
          const SizedBox(height: 15),
          _buildInfoField("Trường dạy", d3, theme, isFullWidth: true),
        ],
      );
    } else if (role == 'Quản lý (Manager)') {
      return Padding(padding: const EdgeInsets.only(top: 15), child: Row(children: [Expanded(child: _buildInfoField("Phòng ban quản lý", d1, theme)), const SizedBox(width: 20), Expanded(child: _buildInfoField("Số lượng nhân sự", d2, theme))]));
    } else if (role == 'Phòng giám sát') {
      return Padding(padding: const EdgeInsets.only(top: 15), child: Row(children: [Expanded(child: _buildInfoField("Khu vực phụ trách", d1, theme)), const SizedBox(width: 20), Expanded(child: _buildInfoField("Ca trực cố định", d2, theme))]));
    } else if (role == 'Chuyên viên Kỹ thuật AI') {
      return Padding(padding: const EdgeInsets.only(top: 15), child: Row(children: [Expanded(child: _buildInfoField("Ngôn ngữ / Framework", d1, theme)), const SizedBox(width: 20), Expanded(child: _buildInfoField("Dự án tham gia", d2, theme))]));
    } else if (role == 'Nhân sự (HR)') {
      return Padding(padding: const EdgeInsets.only(top: 15), child: Row(children: [Expanded(child: _buildInfoField("Mảng phụ trách", d1, theme)), const SizedBox(width: 20), Expanded(child: _buildInfoField("Phần mềm quản lý", d2, theme))]));
    }
    return const SizedBox.shrink();
  }

  void _showAddLeaveDialog(BuildContext context, AppTheme theme) {
    String leaveMode = 'Theo ngày';
    String startDate = "28/02/2026";
    String endDate = "02/03/2026";
    List<Map<String, String>> subjectLeaves = [{"date": "28/02/2026", "subject": "Toán"}];
    List<String> mockSubjects = ['Toán', 'Văn', 'Anh', 'Hóa', 'Lý', 'Sinh', 'Thể dục'];
    String reason = "";

    showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) {
          return StatefulBuilder(
              builder: (context, setStateDialog) {
                return Dialog(
                  backgroundColor: const Color(0xFF101520),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24), side: BorderSide(color: Colors.lightBlueAccent.withOpacity(0.5))),
                  child: Container(
                    width: 600,
                    padding: const EdgeInsets.all(30),
                    child: Column(
                      mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(children: [Icon(Icons.event_note_rounded, color: Colors.lightBlueAccent, size: 28 * theme.fontScale), const SizedBox(width: 15), Text("Cấp Phép Vắng Mặt", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20 * theme.fontScale))]),
                            IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close_rounded, color: Colors.white54))
                          ],
                        ),
                        const SizedBox(height: 10), Text("Hệ thống sẽ ghi nhận học sinh này vắng mặt hợp lệ và bỏ qua cảnh báo vi phạm tương ứng.", style: TextStyle(color: Colors.white54, fontSize: 13 * theme.fontScale)), const SizedBox(height: 30),

                        Row(
                          children: [
                            Expanded(child: _buildOptionChipDialog("Nghỉ theo ngày", leaveMode == 'Theo ngày', () => setStateDialog(() => leaveMode = 'Theo ngày'), theme, Colors.lightBlueAccent)), const SizedBox(width: 15),
                            Expanded(child: _buildOptionChipDialog("Nghỉ theo tiết", leaveMode == 'Theo tiết', () => setStateDialog(() => leaveMode = 'Theo tiết'), theme, Colors.lightBlueAccent)),
                          ],
                        ),
                        const SizedBox(height: 25),

                        Container(
                          constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.4),
                          child: SingleChildScrollView(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (leaveMode == 'Theo ngày') ...[
                                  Row(
                                    children: [
                                      Expanded(child: _buildDialogTextField("Từ ngày", startDate, (v) => startDate = v, theme, hint: "dd/mm/yyyy", icon: Icons.calendar_today_rounded)), const SizedBox(width: 20),
                                      Expanded(child: _buildDialogTextField("Đến ngày", endDate, (v) => endDate = v, theme, hint: "dd/mm/yyyy", icon: Icons.calendar_today_rounded)),
                                    ],
                                  )
                                ] else ...[
                                  ...subjectLeaves.asMap().entries.map((entry) {
                                    int idx = entry.key; Map<String, String> item = entry.value;
                                    return Padding(
                                      padding: const EdgeInsets.only(bottom: 15),
                                      child: Row(
                                        crossAxisAlignment: CrossAxisAlignment.end,
                                        children: [
                                          Expanded(flex: 2, child: _buildDialogTextField("Ngày vắng", item['date']!, (v) => item['date'] = v, theme, hint: "dd/mm/yyyy", icon: Icons.calendar_today_rounded)), const SizedBox(width: 15),
                                          Expanded(flex: 2, child: _buildDialogDropdown("Môn học xin nghỉ", item['subject']!, mockSubjects, (val) => setStateDialog(() => item['subject'] = val!), theme)), const SizedBox(width: 10),
                                          if (subjectLeaves.length > 1) Container(margin: const EdgeInsets.only(bottom: 5), child: IconButton(onPressed: () => setStateDialog(() => subjectLeaves.removeAt(idx)), icon: const Icon(Icons.remove_circle_outline, color: Colors.redAccent)))
                                        ],
                                      ),
                                    );
                                  }),
                                  TextButton.icon(onPressed: () => setStateDialog(() => subjectLeaves.add({"date": "28/02/2026", "subject": "Văn"})), icon: const Icon(Icons.add_rounded, color: Colors.lightBlueAccent), label: const Text("Thêm tiết nghỉ", style: TextStyle(color: Colors.lightBlueAccent, fontWeight: FontWeight.bold)))
                                ],

                                const SizedBox(height: 25),
                                _buildDialogTextField("Lý do vắng mặt", reason, (v) => reason = v, theme, hint: "VD: Đi khám bệnh, Việc gia đình..."),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 30),

                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            TextButton(onPressed: () => Navigator.pop(context), child: const Text("Hủy bỏ", style: TextStyle(color: Colors.white54))), const SizedBox(width: 15),
                            ElevatedButton(
                              onPressed: () {
                                setState(() {
                                  if (leaveMode == 'Theo ngày') {
                                    _data['excusedCount'] = (_data['excusedCount'] ?? 0) + 1;
                                    (_data['violationHistory'] as List).insert(0, "Từ $startDate đến $endDate: Nghỉ có phép (Lý do: ${reason.isEmpty ? 'Không có' : reason})");
                                  } else {
                                    for (var sub in subjectLeaves) {
                                      _data['excusedCount'] = (_data['excusedCount'] ?? 0) + 1;
                                      (_data['violationHistory'] as List).insert(0, "${sub['date']}: Nghỉ phép môn ${sub['subject']} (Lý do: ${reason.isEmpty ? 'Không có' : reason})");
                                    }
                                  }
                                });
                                Navigator.pop(context);
                                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Đã thiết lập trạng thái Nghỉ có phép cho học sinh."), backgroundColor: Colors.green));
                              },
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.lightBlueAccent, padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15)), child: const Text("Xác nhận cấp phép", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
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

  // --- CÁC HÀM TIỆN ÍCH UI ---
  Widget _buildSectionTitle(String title, IconData icon, Color color, AppTheme theme) => Row(children: [Icon(icon, color: color, size: 18 * theme.fontScale), const SizedBox(width: 8), AnimatedDefaultTextStyle(duration: const Duration(milliseconds: 300), style: TextStyle(color: Colors.white, fontSize: 13 * theme.fontScale, fontWeight: FontWeight.bold, letterSpacing: 1.0, fontFamily: 'Segoe UI'), child: Text(title))]);
  Widget _buildInfoField(String label, String value, AppTheme theme, {bool isFullWidth = false, bool isLink = false}) => Container(width: isFullWidth ? double.infinity : null, padding: const EdgeInsets.only(right: 20), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [AnimatedDefaultTextStyle(duration: const Duration(milliseconds: 300), style: TextStyle(color: Colors.white54, fontSize: 11 * theme.fontScale, fontWeight: FontWeight.bold, fontFamily: 'Segoe UI'), child: Text(label.toUpperCase())), const SizedBox(height: 6), Container(width: double.infinity, padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12), decoration: BoxDecoration(color: Colors.white.withOpacity(0.02), borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.white.withOpacity(0.04))), child: AnimatedDefaultTextStyle(duration: const Duration(milliseconds: 300), style: TextStyle(color: isLink && value != "Chưa liên kết" ? theme.primaryColor : Colors.white, fontSize: 13 * theme.fontScale, fontWeight: FontWeight.w500, fontFamily: 'Segoe UI', decoration: isLink && value != "Chưa liên kết" ? TextDecoration.underline : TextDecoration.none), child: Text(value))) ]));
  Widget _buildViolationStat(String label, String count, Color color, AppTheme theme) => Column(children: [Text(label, style: TextStyle(color: Colors.white54, fontSize: 11 * theme.fontScale, fontWeight: FontWeight.bold)), const SizedBox(height: 4), Text(count, style: TextStyle(color: color, fontSize: 20 * theme.fontScale, fontWeight: FontWeight.w900))]);

  Widget _buildOptionChipDialog(String label, bool isSelected, VoidCallback onTap, AppTheme theme, Color activeColor) => GestureDetector(onTap: onTap, child: AnimatedContainer(duration: const Duration(milliseconds: 300), padding: const EdgeInsets.symmetric(vertical: 12), decoration: BoxDecoration(color: isSelected ? activeColor.withOpacity(0.2) : Colors.white.withOpacity(0.03), borderRadius: BorderRadius.circular(10), border: Border.all(color: isSelected ? activeColor : Colors.white.withOpacity(0.1), width: 1.5)), child: Center(child: AnimatedDefaultTextStyle(duration: const Duration(milliseconds: 300), style: TextStyle(color: isSelected ? activeColor : Colors.white54, fontWeight: FontWeight.bold, fontSize: 13 * theme.fontScale, fontFamily: 'Segoe UI'), child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis)))));
  Widget _buildDialogTextField(String label, String value, Function(String) onChanged, AppTheme theme, {String? hint, IconData? icon}) { return Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [Text(label, style: TextStyle(color: Colors.white70, fontSize: 12 * theme.fontScale, fontWeight: FontWeight.bold)), const SizedBox(height: 8), TextFormField(initialValue: value, onChanged: onChanged, style: TextStyle(color: Colors.white, fontSize: 13 * theme.fontScale), decoration: InputDecoration(hintText: hint, hintStyle: const TextStyle(color: Colors.white24), filled: true, fillColor: Colors.black.withOpacity(0.3), border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)), suffixIcon: icon != null ? Icon(icon, color: Colors.white24, size: 18) : null))]); }
  Widget _buildDialogDropdown(String label, String value, List<String> items, Function(String?) onChanged, AppTheme theme) { return Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [Text(label, style: TextStyle(color: Colors.white70, fontSize: 12 * theme.fontScale, fontWeight: FontWeight.bold)), const SizedBox(height: 8), SizedBox(height: 52, child: DropdownButtonFormField<String>(value: value, dropdownColor: const Color(0xFF0A101E), style: TextStyle(color: Colors.white, fontSize: 13 * theme.fontScale), decoration: InputDecoration(contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 15), filled: true, fillColor: Colors.black.withOpacity(0.3), border: OutlineInputBorder(borderRadius: BorderRadius.circular(10))), items: items.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(), onChanged: onChanged))]); }

  void _showFaceEnrollmentDialog(BuildContext context, AppTheme theme) {
    String studentCode = _data['student_code']?.toString() ?? _data['role']?.toString().replaceAll("Học sinh ", "").trim() ?? "";

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return FaceEnrollmentDialog(
          studentCode: studentCode,
          theme: theme,
          onSuccess: (newAvatarUrl) {
            setState(() {
              _data['avatar_url'] = newAvatarUrl;
            });
          },
        );
      },
    );
  }
}

class FaceEnrollmentDialog extends StatefulWidget {
  final String studentCode;
  final AppTheme theme;
  final Function(String) onSuccess;

  const FaceEnrollmentDialog({
    super.key,
    required this.studentCode,
    required this.theme,
    required this.onSuccess,
  });

  @override
  State<FaceEnrollmentDialog> createState() => _FaceEnrollmentDialogState();
}

class _FaceEnrollmentDialogState extends State<FaceEnrollmentDialog> {
  html.VideoElement? _videoElement;
  String _viewType = '';
  html.MediaStream? _localStream;
  bool _hasError = false;
  bool _isCapturing = false;

  @override
  void initState() {
    super.initState();
    _viewType = 'enroll-webcam-${DateTime.now().millisecondsSinceEpoch}';
    _videoElement = html.VideoElement()
      ..style.width = '100%'
      ..style.height = '100%'
      ..autoplay = true
      ..style.objectFit = 'cover'
      ..style.borderRadius = '16px';

    // ignore: undefined_prefixed_name
    ui_web.platformViewRegistry.registerViewFactory(_viewType, (int viewId) => _videoElement!);

    _startCamera();
  }

  Future<void> _startCamera() async {
    try {
      final stream = await html.window.navigator.mediaDevices?.getUserMedia({'video': true});
      if (stream != null) {
        _localStream = stream;
        _videoElement?.srcObject = stream;
      }
    } catch (e) {
      setState(() {
        _hasError = true;
      });
    }
  }

  Future<void> _captureAndRegister() async {
    if (_videoElement == null || _localStream == null || _isCapturing) return;

    setState(() {
      _isCapturing = true;
    });

    try {
      final width = _videoElement!.videoWidth > 0 ? _videoElement!.videoWidth : 640;
      final height = _videoElement!.videoHeight > 0 ? _videoElement!.videoHeight : 480;
      
      final canvas = html.CanvasElement(width: width, height: height);
      final ctx = canvas.context2D;
      ctx.drawImage(_videoElement!, 0, 0);
      
      final dataUrl = canvas.toDataUrl('image/jpeg', 0.9);

      final response = await http.post(
        Uri.parse('http://127.0.0.1:8000/api/students/${widget.studentCode}/register-face'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'image_base64': dataUrl}),
      );

      if (response.statusCode == 200) {
        final resData = jsonDecode(utf8.decode(response.bodyBytes));
        if (resData['status'] == 'success') {
          widget.onSuccess(resData['avatar_url']);
          if (mounted) {
            Navigator.pop(context);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text("Đăng ký khuôn mặt học sinh thành công!"),
                backgroundColor: Colors.green,
              ),
            );
          }
        } else {
          _showError(resData['message'] ?? "Lỗi Backend");
        }
      } else {
        _showError("Lỗi kết nối server (HTTP ${response.statusCode})");
      }
    } catch (e) {
      _showError("Lỗi xử lý camera: $e");
    } finally {
      if (mounted) {
        setState(() {
          _isCapturing = false;
        });
      }
    }
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.redAccent),
    );
  }

  @override
  void dispose() {
    _localStream?.getTracks().forEach((track) {
      track.stop();
    });
    _videoElement?.srcObject = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = widget.theme;

    return Dialog(
      backgroundColor: const Color(0xFF101520),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(color: theme.primaryColor.withOpacity(0.5)),
      ),
      child: Container(
        width: 550,
        padding: const EdgeInsets.all(30),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.face_retouching_natural_rounded, color: theme.primaryColor, size: 26),
                    const SizedBox(width: 12),
                    const Text(
                      "Quét Đăng Ký Khuôn Mặt",
                      style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold, fontFamily: 'Segoe UI'),
                    ),
                  ],
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded, color: Colors.white54),
                )
              ],
            ),
            const SizedBox(height: 10),
            Text(
              "Mã học sinh: ${widget.studentCode}",
              style: TextStyle(color: theme.primaryColor, fontSize: 13, fontWeight: FontWeight.bold, fontFamily: 'Segoe UI'),
            ),
            const SizedBox(height: 20),
            
            Container(
              height: 350,
              width: double.infinity,
              decoration: BoxDecoration(
                color: const Color(0xFF070B14),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withOpacity(0.08)),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: _hasError
                    ? const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.videocam_off_rounded, color: Colors.redAccent, size: 50),
                            SizedBox(height: 12),
                            Text(
                              "Không tìm thấy Webcam hoặc chưa cấp quyền!",
                              style: TextStyle(color: Colors.white54, fontSize: 13),
                            ),
                          ],
                        ),
                      )
                    : Stack(
                        children: [
                          HtmlElementView(viewType: _viewType),
                          
                          Positioned.fill(
                            child: Container(
                              decoration: BoxDecoration(
                                border: Border.all(color: theme.primaryColor.withOpacity(0.3), width: 1.5),
                              ),
                              child: Stack(
                                children: [
                                  _buildCorner(0, 0, top: 40, left: 40, color: theme.primaryColor),
                                  _buildCorner(1, 0, top: 40, right: 40, color: theme.primaryColor),
                                  _buildCorner(0, 1, bottom: 40, left: 40, color: theme.primaryColor),
                                  _buildCorner(1, 1, bottom: 40, right: 40, color: theme.primaryColor),
                                  
                                  if (_isCapturing)
                                    Container(
                                      color: Colors.black.withOpacity(0.5),
                                      child: const Center(
                                        child: CircularProgressIndicator(),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          )
                        ],
                      ),
              ),
            ),
            const SizedBox(height: 30),
            
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("Hủy bỏ", style: TextStyle(color: Colors.white54, fontFamily: 'Segoe UI')),
                ),
                const SizedBox(width: 15),
                ElevatedButton.icon(
                  onPressed: _hasError || _isCapturing ? null : _captureAndRegister,
                  icon: const Icon(Icons.camera_alt_rounded, color: Colors.white),
                  label: Text(
                    _isCapturing ? "Đang đăng ký..." : "Chụp & Đăng ký",
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontFamily: 'Segoe UI'),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 15),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ],
            )
          ],
        ),
      ),
    );
  }

  Widget _buildCorner(int horizontal, int vertical, {double? top, double? bottom, double? left, double? right, required Color color}) {
    const size = 30.0;
    const thickness = 3.0;

    return Positioned(
      top: top,
      bottom: bottom,
      left: left,
      right: right,
      child: SizedBox(
        width: size,
        height: size,
        child: Stack(
          children: [
            Positioned(
              top: vertical == 0 ? 0 : null,
              bottom: vertical == 1 ? 0 : null,
              left: 0,
              right: 0,
              child: Container(height: thickness, color: color),
            ),
            Positioned(
              left: horizontal == 0 ? 0 : null,
              right: horizontal == 1 ? 0 : null,
              top: 0,
              bottom: 0,
              child: Container(width: thickness, color: color),
            ),
          ],
        ),
      ),
    );
  }
}