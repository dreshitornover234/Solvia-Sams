import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../theme_manager.dart';
import '../globals.dart' as globals;
import 'dart:io';
import 'package:image_picker/image_picker.dart';

class AccountSettings extends StatefulWidget {
  const AccountSettings({super.key});

  @override
  State<AccountSettings> createState() => _AccountSettingsState();
}

class _AccountSettingsState extends State<AccountSettings> {
  bool _isEditing = false;
  bool _isLoading = true;

  int get _currentUserId => globals.currentUserId;

  String _name = "";
  String _dob = "";
  String _hometown = "";
  String _currentAddress = "";
  String _religion = "";
  String _email = "";
  String _phone = "";
  String _facebook = "";

  String? _selectedJobRole;
  String? _selectedDegree;
  String _school = "";

  String _dynamicField1 = "";
  String _dynamicField2 = "";
  String _dynamicField3 = "";

  String _avatarUrl = "";
  File? _selectedImage;

  final List<String> _jobRoles = ['Giáo viên', 'Giảng viên', 'Quản lý (Manager)', 'Phòng giám sát', 'Chuyên viên Kỹ thuật AI', 'Nhân sự (HR)'];
  final List<String> _degrees = ['Cử nhân', 'Thạc sĩ', 'Tiến sĩ', 'Giáo sư', 'Khác'];

  @override
  void initState() {
    super.initState();
    _fetchUserData();
  }

  Future<void> _fetchUserData() async {
    try {
      var response = await http.get(Uri.parse('http://127.0.0.1:8000/api/users/$_currentUserId'));
      if (response.statusCode == 200) {
        var responseBody = jsonDecode(utf8.decode(response.bodyBytes));
        if (responseBody['status'] == 'success') {
          var data = responseBody['data'];
          setState(() {
            _avatarUrl = data['avatar_url'] ?? "";
            _name = data['full_name'] ?? "";
            _email = data['email'] ?? "";
            _phone = data['phone'] ?? "";
            _selectedJobRole = data['position'] == "" ? null : data['position'];
            _dob = data['dob'] ?? "";
            _hometown = data['hometown'] ?? "";
            _currentAddress = data['current_address'] ?? "";
            _religion = data['religion'] ?? "";
            _facebook = data['facebook'] ?? "";
            _selectedDegree = data['degree'] == "" ? null : data['degree'];
            _school = data['graduated_from'] ?? "";
            _dynamicField1 = data['dynamic_1'] ?? "";
            _dynamicField2 = data['dynamic_2'] ?? "";
            _dynamicField3 = data['dynamic_3'] ?? "";
            _isLoading = false;
          });
        } else {
          setState(() => _isLoading = false);
          _showSnackBar("Lỗi từ Server: ${responseBody['message']}", Colors.redAccent);
        }
      } else {
        setState(() => _isLoading = false);
        _showSnackBar("Không kết nối được API. Mã lỗi: ${response.statusCode}", Colors.redAccent);
      }
    } catch (e) {
      setState(() => _isLoading = false);
      _showSnackBar("Mất kết nối với máy chủ Python!", Colors.redAccent);
    }
  }

  Future<void> _saveUserData() async {
    showDialog(context: context, barrierDismissible: false, builder: (c) => const Center(child: CircularProgressIndicator(color: Colors.greenAccent)));
    try {
      Map<String, dynamic> payload = {
        "full_name": _name, "dob": _dob, "hometown": _hometown, "current_address": _currentAddress,
        "religion": _religion, "email": _email, "phone": _phone, "facebook": _facebook,
        "position": _selectedJobRole, "degree": _selectedDegree, "graduated_from": _school,
        "dynamic_1": _dynamicField1, "dynamic_2": _dynamicField2, "dynamic_3": _dynamicField3,
      };

      var response = await http.put(Uri.parse('http://127.0.0.1:8000/api/users/$_currentUserId'), headers: {"Content-Type": "application/json"}, body: jsonEncode(payload));
      if (context.mounted) Navigator.pop(context);

      if (response.statusCode == 200) {
        setState(() => _isEditing = false);
        _showSnackBar("Cập nhật thông tin thành công!", Colors.green);
      } else {
        _showSnackBar("Lỗi khi lưu dữ liệu: ${response.statusCode}", Colors.redAccent);
      }
    } catch (e) {
      if (context.mounted) Navigator.pop(context);
      _showSnackBar("Mất kết nối với máy chủ!", Colors.redAccent);
    }
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

        if (_isLoading) return Center(child: CircularProgressIndicator(color: theme.primaryColor));

        return SingleChildScrollView(
          key: const ValueKey('AccountSettings'),
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 40.0, vertical: 30.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AnimatedDefaultTextStyle(duration: const Duration(milliseconds: 300), style: TextStyle(fontSize: 28 * theme.fontScale, fontWeight: FontWeight.w900, color: theme.textColor, letterSpacing: 1.0, fontFamily: 'Segoe UI'), child: const Text("Hồ Sơ Của Bạn")),
                      const SizedBox(height: 8),
                      AnimatedDefaultTextStyle(duration: const Duration(milliseconds: 300), style: TextStyle(fontSize: 14 * theme.fontScale, color: theme.subTextColor, fontFamily: 'Segoe UI'), child: const Text("Quản lý thông định danh và quyền hạn trên hệ thống.")),
                    ],
                  ),
                  if (!_isEditing)
                    ElevatedButton.icon(
                      onPressed: () => setState(() => _isEditing = true),
                      icon: Icon(Icons.edit_rounded, color: Colors.white, size: 16 * theme.fontScale),
                      label: Text("Chỉnh sửa hồ sơ", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13 * theme.fontScale)),
                      style: ElevatedButton.styleFrom(backgroundColor: theme.primaryColor, padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)), elevation: 0),
                    ),
                ],
              ),
              const SizedBox(height: 30),

              AnimatedContainer(
                duration: const Duration(milliseconds: 400),
                padding: const EdgeInsets.all(30),
                decoration: BoxDecoration(
                  color: theme.cardColor, borderRadius: BorderRadius.circular(20), border: Border.all(color: theme.borderColor),
                  boxShadow: theme.isDarkMode ? [] : [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 15, offset: const Offset(0, 4))],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 300), width: 80 * theme.fontScale, height: 80 * theme.fontScale,
                          decoration: BoxDecoration(
                            color: theme.primaryColor.withOpacity(0.1), shape: BoxShape.circle, border: Border.all(color: theme.primaryColor, width: 2),
                            image: _selectedImage != null ? DecorationImage(image: FileImage(_selectedImage!), fit: BoxFit.cover) : (_avatarUrl.isNotEmpty ? DecorationImage(image: NetworkImage('http://127.0.0.1:8000$_avatarUrl'), fit: BoxFit.cover) : null),
                          ),
                          child: _selectedImage == null && _avatarUrl.isEmpty ? Center(child: Icon(Icons.person_rounded, size: 40 * theme.fontScale, color: theme.primaryColor)) : null,
                        ),
                        const SizedBox(width: 25),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            AnimatedDefaultTextStyle(duration: const Duration(milliseconds: 300), style: TextStyle(color: theme.textColor, fontSize: 16 * theme.fontScale, fontWeight: FontWeight.bold, fontFamily: 'Segoe UI'), child: const Text("Ảnh đại diện")), const SizedBox(height: 6),
                            AnimatedDefaultTextStyle(duration: const Duration(milliseconds: 300), style: TextStyle(color: theme.subTextColor, fontSize: 12 * theme.fontScale, fontFamily: 'Segoe UI'), child: const Text("Định dạng JPG, PNG. Dung lượng tối đa 5MB.")), const SizedBox(height: 10),
                            if (_isEditing)
                              Row(
                                children: [
                                  AnimatedContainer(duration: const Duration(milliseconds: 300), child: ElevatedButton(onPressed: _pickImage, style: ElevatedButton.styleFrom(backgroundColor: theme.primaryColor, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)), padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10)), child: Text("Tải ảnh lên", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12 * theme.fontScale)))), const SizedBox(width: 10),
                                  TextButton(onPressed: () {}, child: Text("Xóa ảnh", style: TextStyle(color: Colors.redAccent, fontSize: 12 * theme.fontScale))),
                                ],
                              )
                          ],
                        )
                      ],
                    ),
                    const SizedBox(height: 35), Divider(color: theme.borderColor, thickness: 1), const SizedBox(height: 30),

                    _buildSectionHeader(Icons.account_box_rounded, "THÔNG TIN CÁ NHÂN", theme), const SizedBox(height: 20),
                    Row(children: [Expanded(child: _buildField("Họ và tên", Icons.badge_outlined, _name, (v) => _name = v, theme)), const SizedBox(width: 20), Expanded(child: _buildField("Ngày/tháng/năm sinh", Icons.calendar_today_rounded, _dob, (v) => _dob = v, theme))]), const SizedBox(height: 15),
                    Row(children: [Expanded(child: _buildField("Quê quán", Icons.map_outlined, _hometown, (v) => _hometown = v, theme)), const SizedBox(width: 20), Expanded(child: _buildField("Nơi ở hiện tại", Icons.home_outlined, _currentAddress, (v) => _currentAddress = v, theme))]), const SizedBox(height: 15),
                    Row(children: [Expanded(child: _buildField("Tôn giáo", Icons.self_improvement_rounded, _religion, (v) => _religion = v, theme)), const SizedBox(width: 20), const Expanded(child: SizedBox())]), const SizedBox(height: 40),

                    _buildSectionHeader(Icons.contact_mail_rounded, "THÔNG TIN LIÊN HỆ", theme), const SizedBox(height: 20),
                    Row(children: [Expanded(child: _buildField("Địa chỉ Email", Icons.email_outlined, _email, (v) => _email = v, theme)), const SizedBox(width: 20), Expanded(child: _buildField("Số điện thoại", Icons.phone_outlined, _phone, (v) => _phone = v, theme))]), const SizedBox(height: 15),
                    Row(children: [Expanded(child: _buildField("Facebook (Tùy chọn)", Icons.facebook_rounded, _facebook, (v) => _facebook = v, theme)), const SizedBox(width: 20), const Expanded(child: SizedBox())]), const SizedBox(height: 40),

                    _buildSectionHeader(Icons.work_outline_rounded, "THÔNG TIN CÔNG TÁC", theme), const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(child: _buildDropdownField("Chức vụ đảm nhiệm", Icons.cases_rounded, _selectedJobRole, _jobRoles, (val) { setState(() { _selectedJobRole = val; _dynamicField1 = ""; _dynamicField2 = ""; _dynamicField3 = ""; }); }, theme)), const SizedBox(width: 20),
                        Expanded(child: _buildDropdownField("Bằng cấp cao nhất", Icons.workspace_premium_rounded, _selectedDegree, _degrees, (val) => setState(() => _selectedDegree = val), theme)),
                      ],
                    ),
                    const SizedBox(height: 15),
                    Row(children: [Expanded(child: _buildField("Tốt nghiệp tại cơ sở", Icons.account_balance_rounded, _school, (v) => _school = v, theme)), const SizedBox(width: 20), const Expanded(child: SizedBox())]),

                    AnimatedSize(duration: const Duration(milliseconds: 400), curve: Curves.easeInOut, child: _buildDynamicJobFields(theme)),

                    if (_isEditing) ...[
                      const SizedBox(height: 50), Divider(color: theme.borderColor, thickness: 1), const SizedBox(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(onPressed: () { setState(() { _isEditing = false; _fetchUserData(); }); }, style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14)), child: Text("Hủy bỏ", style: TextStyle(color: theme.subTextColor, fontWeight: FontWeight.bold, fontSize: 13 * theme.fontScale))), const SizedBox(width: 15),
                          AnimatedContainer(duration: const Duration(milliseconds: 300), child: ElevatedButton.icon(onPressed: _saveUserData, icon: Icon(Icons.save_rounded, color: Colors.white, size: 18 * theme.fontScale), label: Text("LƯU THAY ĐỔI", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 1.0, fontSize: 13 * theme.fontScale)), style: ElevatedButton.styleFrom(backgroundColor: theme.primaryColor, padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))))),
                        ],
                      )
                    ]
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildField(String label, IconData icon, String value, Function(String) onChanged, AppTheme theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(padding: const EdgeInsets.only(bottom: 6), child: AnimatedDefaultTextStyle(duration: const Duration(milliseconds: 300), style: TextStyle(color: theme.textColor.withOpacity(0.7), fontSize: 12 * theme.fontScale, fontWeight: FontWeight.bold, fontFamily: 'Segoe UI'), child: Text(label))),
        if (!_isEditing) Container(width: double.infinity, padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12), decoration: BoxDecoration(color: theme.textColor.withOpacity(0.02), borderRadius: BorderRadius.circular(10), border: Border.all(color: theme.borderColor)), child: Row(children: [AnimatedContainer(duration: const Duration(milliseconds: 300), child: Icon(icon, color: theme.primaryColor.withOpacity(0.5), size: 16 * theme.fontScale)), const SizedBox(width: 10), Expanded(child: AnimatedDefaultTextStyle(duration: const Duration(milliseconds: 300), style: TextStyle(color: value.isEmpty ? theme.subTextColor : theme.textColor, fontSize: 13 * theme.fontScale, fontWeight: FontWeight.w500, fontFamily: 'Segoe UI'), child: Text(value.isEmpty ? "Chưa cập nhật" : value)))]))
        else SizedBox(height: 45, child: TextFormField(initialValue: value, onChanged: onChanged, style: TextStyle(color: theme.textColor, fontSize: 13 * theme.fontScale), decoration: InputDecoration(contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 15), prefixIcon: Icon(icon, color: theme.primaryColor, size: 18 * theme.fontScale), hintText: "Nhập dữ liệu...", hintStyle: TextStyle(color: theme.subTextColor, fontSize: 13 * theme.fontScale), filled: true, fillColor: theme.textColor.withOpacity(0.03), enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: theme.borderColor)), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: theme.primaryColor, width: 1.5))))),
      ],
    );
  }

  Widget _buildDropdownField(String label, IconData icon, String? currentValue, List<String> items, Function(String?) onChanged, AppTheme theme) {
    String? validValue = items.contains(currentValue) ? currentValue : null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(padding: const EdgeInsets.only(bottom: 6), child: AnimatedDefaultTextStyle(duration: const Duration(milliseconds: 300), style: TextStyle(color: theme.textColor.withOpacity(0.7), fontSize: 12 * theme.fontScale, fontWeight: FontWeight.bold, fontFamily: 'Segoe UI'), child: Text(label))),
        if (!_isEditing) Container(width: double.infinity, padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12), decoration: BoxDecoration(color: theme.textColor.withOpacity(0.02), borderRadius: BorderRadius.circular(10), border: Border.all(color: theme.borderColor)), child: Row(children: [AnimatedContainer(duration: const Duration(milliseconds: 300), child: Icon(icon, color: theme.primaryColor.withOpacity(0.5), size: 16 * theme.fontScale)), const SizedBox(width: 10), Expanded(child: AnimatedDefaultTextStyle(duration: const Duration(milliseconds: 300), style: TextStyle(color: validValue == null ? theme.subTextColor : theme.textColor, fontSize: 13 * theme.fontScale, fontWeight: FontWeight.w500, fontFamily: 'Segoe UI'), child: Text(validValue ?? "Chưa cập nhật")))]))
        else SizedBox(height: 45, child: DropdownButtonFormField<String>(value: validValue, dropdownColor: theme.cardColor, style: TextStyle(color: theme.textColor, fontSize: 13 * theme.fontScale), icon: Icon(Icons.keyboard_arrow_down_rounded, color: theme.primaryColor, size: 18 * theme.fontScale), decoration: InputDecoration(contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 15), prefixIcon: Icon(icon, color: theme.primaryColor, size: 18 * theme.fontScale), filled: true, fillColor: theme.textColor.withOpacity(0.03), enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: theme.borderColor)), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: theme.primaryColor, width: 1.5))), items: items.map((String item) => DropdownMenuItem<String>(value: item, child: Text(item, overflow: TextOverflow.ellipsis))).toList(), onChanged: onChanged)),
      ],
    );
  }

  Widget _buildDynamicJobFields(AppTheme theme) {
    if (_selectedJobRole == null) return const SizedBox.shrink();
    Widget content = const SizedBox.shrink();
    if (_selectedJobRole == 'Giáo viên' || _selectedJobRole == 'Giảng viên') { content = Row(children: [Expanded(child: _buildField("Môn giảng dạy chính", Icons.menu_book_rounded, _dynamicField1, (v) => _dynamicField1 = v, theme)), const SizedBox(width: 20), Expanded(child: _buildField("Số năm kinh nghiệm", Icons.timeline_rounded, _dynamicField2, (v) => _dynamicField2 = v, theme)), const SizedBox(width: 20), Expanded(child: _buildField("Trường dạy", Icons.school_rounded, _dynamicField3, (v) => _dynamicField3 = v, theme))]); }
    else if (_selectedJobRole == 'Quản lý (Manager)') { content = Row(children: [Expanded(child: _buildField("Phòng ban quản lý", Icons.corporate_fare_rounded, _dynamicField1, (v) => _dynamicField1 = v, theme)), const SizedBox(width: 20), Expanded(child: _buildField("Số lượng nhân sự phụ trách", Icons.groups_rounded, _dynamicField2, (v) => _dynamicField2 = v, theme))]); }
    else if (_selectedJobRole == 'Phòng giám sát') { content = Row(children: [Expanded(child: _buildField("Khu vực / Tòa nhà phụ trách", Icons.location_on_rounded, _dynamicField1, (v) => _dynamicField1 = v, theme)), const SizedBox(width: 20), Expanded(child: _buildField("Ca trực cố định", Icons.access_time_filled_rounded, _dynamicField2, (v) => _dynamicField2 = v, theme))]); }
    else if (_selectedJobRole == 'Chuyên viên Kỹ thuật AI') { content = Row(children: [Expanded(child: _buildField("Ngôn ngữ / Framework AI", Icons.code_rounded, _dynamicField1, (v) => _dynamicField1 = v, theme)), const SizedBox(width: 20), Expanded(child: _buildField("Dự án đang tham gia", Icons.memory_rounded, _dynamicField2, (v) => _dynamicField2 = v, theme))]); }
    else if (_selectedJobRole == 'Nhân sự (HR)') { content = Row(children: [Expanded(child: _buildField("Mảng phụ trách", Icons.handshake_rounded, _dynamicField1, (v) => _dynamicField1 = v, theme)), const SizedBox(width: 20), Expanded(child: _buildField("Phần mềm quản lý đang dùng", Icons.laptop_mac_rounded, _dynamicField2, (v) => _dynamicField2 = v, theme))]); }
    if (content is SizedBox) return content;
    return Padding(padding: const EdgeInsets.only(top: 15.0), child: content);
  }

  Widget _buildSectionHeader(IconData icon, String title, AppTheme theme) => Row(children: [AnimatedContainer(duration: const Duration(milliseconds: 300), child: Icon(icon, color: theme.primaryColor, size: 18 * theme.fontScale)), const SizedBox(width: 10), AnimatedDefaultTextStyle(duration: const Duration(milliseconds: 300), style: TextStyle(color: theme.textColor, fontSize: 14 * theme.fontScale, fontWeight: FontWeight.bold, letterSpacing: 1.2, fontFamily: 'Segoe UI'), child: Text(title))]);

  Future<void> _pickImage() async {
    final pickedFile = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() { _selectedImage = File(pickedFile.path); });
      _uploadAvatar();
    }
  }

  Future<void> _uploadAvatar() async {
    if (_selectedImage == null) return;
    showDialog(context: context, barrierDismissible: false, builder: (c) => const Center(child: CircularProgressIndicator(color: Colors.blueAccent)));
    try {
      var request = http.MultipartRequest('POST', Uri.parse('http://127.0.0.1:8000/api/users/$_currentUserId/avatar'));
      request.files.add(await http.MultipartFile.fromPath('file', _selectedImage!.path));
      var response = await request.send();
      var responseData = await response.stream.bytesToString();
      var data = jsonDecode(responseData);
      if (context.mounted) Navigator.pop(context);
      if (response.statusCode == 200 && data['status'] == 'success') {
        setState(() { _avatarUrl = data['avatar_url']; });
        _showSnackBar("Tải ảnh lên thành công!", Colors.green);
      } else { _showSnackBar("Lỗi từ server: ${data['message']}", Colors.redAccent); }
    } catch (e) {
      if (context.mounted) Navigator.pop(context);
      _showSnackBar("Lỗi kết nối khi tải ảnh!", Colors.redAccent);
    }
  }
}