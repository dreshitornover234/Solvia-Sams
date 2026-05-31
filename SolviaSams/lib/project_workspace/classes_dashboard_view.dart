import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../theme_manager.dart';
import '../globals.dart' as globals;
import 'class_management_view.dart'; // Để gọi trang chi tiết lớp học

class ClassesDashboardView extends StatefulWidget {
  const ClassesDashboardView({super.key});

  @override
  State<ClassesDashboardView> createState() => _ClassesDashboardViewState();
}

class _ClassesDashboardViewState extends State<ClassesDashboardView> {
  bool _isLoading = true;
  List<dynamic> _classesData = [];

  @override
  void initState() {
    super.initState();
    _fetchClasses();
  }

  Future<void> _fetchClasses() async {
    setState(() => _isLoading = true);
    try {
      var resClasses = await http.get(Uri.parse('http://127.0.0.1:8000/api/projects/${globals.currentProjectId}/classes'));
      if (resClasses.statusCode == 200) {
        var dataClasses = jsonDecode(utf8.decode(resClasses.bodyBytes));
        if (dataClasses['status'] == 'success') {
          List<dynamic> classList = dataClasses['data'];
          List<dynamic> fullClassesData = [];

          // Lấy thêm thông tin Sĩ số và GVCN cho từng lớp
          for (var cls in classList) {
            var resDetail = await http.get(Uri.parse('http://127.0.0.1:8000/api/classes/${cls['id']}'));
            if (resDetail.statusCode == 200) {
              var dataDetail = jsonDecode(utf8.decode(resDetail.bodyBytes));
              if (dataDetail['status'] == 'success') {
                var clsData = dataDetail['data'];
                clsData['id'] = cls['id'];
                fullClassesData.add(clsData);
              }
            }
          }

          if (mounted) {
            setState(() {
              _classesData = fullClassesData;
              _isLoading = false;
            });
          }
        }
      }
    } catch (e) {
      debugPrint("Lỗi tải lớp học: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.instance;

    if (_isLoading) {
      return Center(child: CircularProgressIndicator(color: theme.primaryColor));
    }

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(50.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AnimatedDefaultTextStyle(duration: const Duration(milliseconds: 300), style: TextStyle(fontSize: 28 * theme.fontScale, fontWeight: FontWeight.w900, color: theme.textColor, letterSpacing: 1.0, fontFamily: 'Segoe UI'), child: const Text("Quản Lý Lớp Học Tổng")),
                  const SizedBox(height: 8),
                  AnimatedDefaultTextStyle(duration: const Duration(milliseconds: 300), style: TextStyle(fontSize: 14 * theme.fontScale, color: theme.subTextColor, fontFamily: 'Segoe UI'), child: const Text("Khởi tạo lớp mới và điều phối toàn bộ các lớp trong hệ thống.")),
                ],
              ),
              Row(
                children: [
                  IconButton(onPressed: _fetchClasses, icon: Icon(Icons.sync_rounded, color: theme.primaryColor), tooltip: "Làm mới dữ liệu"),
                  const SizedBox(width: 15),
                  ElevatedButton.icon(
                    onPressed: () {
                      // Tạm thời hiển thị popup thông báo (Có thể phát triển form tạo lớp sau)
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Tính năng Tạo lớp hàng loạt bằng Excel đang phát triển!")));
                    },
                    icon: const Icon(Icons.add_business_rounded, color: Colors.white),
                    label: const Text("TẠO LỚP MỚI", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(backgroundColor: theme.successColor, padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                  )
                ],
              )
            ],
          ),
          const SizedBox(height: 40),

          if (_classesData.isEmpty)
            Center(child: Padding(padding: const EdgeInsets.only(top: 50), child: Text("Dự án hiện chưa có lớp học nào.", style: TextStyle(color: theme.subTextColor, fontSize: 16 * theme.fontScale, fontStyle: FontStyle.italic))))
          else
            Wrap(
              spacing: 25, runSpacing: 25,
              children: _classesData.map((cls) => _buildClassCard(cls, theme)).toList(),
            )
        ],
      ),
    );
  }

  Widget _buildClassCard(Map<String, dynamic> cls, AppTheme theme) {
    List<dynamic> students = cls['students'] ?? [];
    String teacherName = cls['teacher']['name'] ?? 'Chưa phân công';

    return Container(
      width: 350 * theme.fontScale,
      padding: const EdgeInsets.all(25),
      decoration: BoxDecoration(color: theme.cardColor, borderRadius: BorderRadius.circular(20), border: Border.all(color: theme.borderColor), boxShadow: theme.isDarkMode ? [] : [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 15, offset: const Offset(0, 5))]),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(cls['class_name'], style: TextStyle(color: theme.textColor, fontSize: 24 * theme.fontScale, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 6),
                  Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: theme.purpleColor.withOpacity(0.1), borderRadius: BorderRadius.circular(6)), child: Text("Niên khóa: ${cls['course_start_year']} - ${cls['course_end_year']}", style: TextStyle(color: theme.purpleColor, fontSize: 11 * theme.fontScale, fontWeight: FontWeight.bold))),
                ],
              ),
              Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: theme.primaryColor.withOpacity(0.1), shape: BoxShape.circle), child: Icon(Icons.apartment_rounded, color: theme.primaryColor, size: 28 * theme.fontScale))
            ],
          ),
          const SizedBox(height: 25),

          Row(
            children: [
              Icon(Icons.badge_rounded, color: theme.subTextColor, size: 16 * theme.fontScale), const SizedBox(width: 8),
              Text("GVCN: ", style: TextStyle(color: theme.subTextColor, fontSize: 13 * theme.fontScale)),
              Expanded(child: Text(teacherName, style: TextStyle(color: theme.textColor, fontSize: 13 * theme.fontScale, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis)),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Icon(Icons.groups_rounded, color: theme.subTextColor, size: 16 * theme.fontScale), const SizedBox(width: 8),
              Text("Sĩ số: ", style: TextStyle(color: theme.subTextColor, fontSize: 13 * theme.fontScale)),
              Text("${students.length} học sinh", style: TextStyle(color: theme.textColor, fontSize: 13 * theme.fontScale, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 25),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              // ĐÂY CHÍNH LÀ LỆNH MỞ TRANG CHI TIẾT LỚP MÀ BẠN ĐÃ VIẾT Ở CÁC BÀI TRƯỚC
              onPressed: () {
                Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => ClassManagementView(classId: cls['id'], className: cls['class_name'], isSuperAdmin: true))
                ).then((_) => _fetchClasses()); // Refresh khi quay lại
              },
              icon: const Icon(Icons.settings_suggest_rounded, color: Colors.white, size: 18),
              label: const Text("QUẢN TRỊ LỚP", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(backgroundColor: theme.primaryColor, padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            ),
          )
        ],
      ),
    );
  }
}