import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../theme_manager.dart';
import '../globals.dart' as globals;

class AttendanceReportView extends StatefulWidget {
  const AttendanceReportView({super.key});

  @override
  State<AttendanceReportView> createState() => _AttendanceReportViewState();
}

class _AttendanceReportViewState extends State<AttendanceReportView> with SingleTickerProviderStateMixin {
  bool _isSubjectMode = true;
  bool _isLoading = true;
  late AnimationController _pulseController;
  Timer? _refreshTimer;

  List<Map<String, dynamic>> subjectModeData = [];
  List<Map<String, dynamic>> sessionModeData = [];

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(vsync: this, duration: const Duration(seconds: 1))..repeat(reverse: true);
    
    // Tải dữ liệu báo cáo lần đầu tiên
    _fetchAttendanceReport(showLoading: true);

    // Bật timer tự động cập nhật ngầm (Silent update) mỗi 10 giây
    _refreshTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
      if (mounted) {
        _fetchAttendanceReport(showLoading: false);
      }
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _fetchAttendanceReport({bool showLoading = true}) async {
    if (showLoading) {
      setState(() {
        _isLoading = true;
      });
    }
    try {
      final response = await http.get(
        Uri.parse('http://127.0.0.1:8000/api/projects/${globals.currentProjectId}/attendance-today'),
      );
      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        if (data['status'] == 'success') {
          if (mounted) {
            setState(() {
              subjectModeData = List<Map<String, dynamic>>.from(data['subject_mode']);
              sessionModeData = List<Map<String, dynamic>>.from(data['session_mode']);
              _isLoading = false;
            });
          }
        } else {
          if (mounted) {
            setState(() {
              _isLoading = false;
            });
          }
        }
      } else {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
      print("Lỗi tải báo cáo điểm danh LIVE: $e");
    }
  }

  String _getCurrentTimeString() {
    DateTime now = DateTime.now();
    return '${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year} - ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
        animation: AppTheme.instance,
        builder: (context, child) {
          final theme = AppTheme.instance;
          String today = _getCurrentTimeString();

          if (_isLoading) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(height: 100),
                  CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(theme.primaryColor),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    "Đang đồng bộ dữ liệu điểm danh LIVE...",
                    style: TextStyle(
                      color: theme.subTextColor,
                      fontSize: 14 * theme.fontScale,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
            );
          }

          List<Map<String, dynamic>> currentData = _isSubjectMode ? subjectModeData : sessionModeData;

          int totalViolations = 0; int totalLates = 0; int totalAbsents = 0; int totalExcused = 0;
          for (var c in currentData) {
            for (var v in c['violations']) {
              totalViolations++;
              if (v['type'] == 'Đi trễ') totalLates++;
              if (v['type'] == 'Nghỉ học') totalAbsents++;
              if (v['type'] == 'Có phép') totalExcused++;
            }
          }

          return LayoutBuilder(
              builder: (context, constraints) {
                double width = constraints.maxWidth;

                return SingleChildScrollView(
                  key: const ValueKey('AttendanceReport'),
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.all(40.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        alignment: WrapAlignment.spaceBetween,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        runSpacing: 20,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  AnimatedDefaultTextStyle(duration: const Duration(milliseconds: 300), style: TextStyle(fontSize: 28 * theme.fontScale, fontWeight: FontWeight.w900, color: theme.textColor, letterSpacing: 1.0, fontFamily: 'Segoe UI'), child: const Text("Giám Sát Điểm Danh")),
                                  const SizedBox(width: 15),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: theme.errorColor.withOpacity(0.15), borderRadius: BorderRadius.circular(6), border: Border.all(color: theme.errorColor.withOpacity(0.5))),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        FadeTransition(opacity: _pulseController, child: Icon(Icons.circle, color: theme.errorColor, size: 10 * theme.fontScale)), const SizedBox(width: 6),
                                        Text("LIVE", style: TextStyle(color: theme.errorColor, fontWeight: FontWeight.bold, fontSize: 11 * theme.fontScale, letterSpacing: 1.0))
                                      ],
                                    ),
                                  )
                                ],
                              ),
                              const SizedBox(height: 8),
                              AnimatedDefaultTextStyle(duration: const Duration(milliseconds: 300), style: TextStyle(fontSize: 14 * theme.fontScale, color: theme.subTextColor, fontFamily: 'Segoe UI'), child: Text("Dữ liệu cập nhật theo thời gian thực: $today")),
                            ],
                          ),
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 400),
                            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8), decoration: BoxDecoration(color: theme.cardColor, borderRadius: BorderRadius.circular(12), border: Border.all(color: theme.borderColor), boxShadow: theme.isDarkMode ? [] : [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4))]),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text("Chế độ hiển thị: ", style: TextStyle(color: theme.subTextColor, fontSize: 12 * theme.fontScale)),
                                Text(_isSubjectMode ? "Từng môn" : "Theo buổi", style: TextStyle(color: theme.primaryColor, fontWeight: FontWeight.bold, fontSize: 13 * theme.fontScale)),
                                Switch(value: _isSubjectMode, activeColor: theme.primaryColor, activeTrackColor: theme.primaryColor.withOpacity(0.5), inactiveThumbColor: theme.subTextColor, inactiveTrackColor: theme.subTextColor.withOpacity(0.3), onChanged: (val) => setState(() => _isSubjectMode = val))
                              ],
                            ),
                          )
                        ],
                      ),
                      const SizedBox(height: 40),

                      _buildStatCardsResponsive(width, totalViolations, totalLates, totalAbsents, totalExcused, theme),
                      const SizedBox(height: 40),

                      _buildSectionHeader(Icons.meeting_room_rounded, "BÁO CÁO CHI TIẾT TỪNG LỚP TRONG NGÀY", theme),
                      const SizedBox(height: 25),

                      ...currentData.map((classData) => _buildClassReportCard(classData, theme)),
                      const SizedBox(height: 50),
                    ],
                  ),
                );
              }
          );
        }
    );
  }

  Widget _buildStatCardsResponsive(double width, int totalViolations, int totalLates, int totalAbsents, int totalExcused, AppTheme theme) {
    Widget card1 = _buildStatCard("TỔNG VI PHẠM", totalViolations.toString(), Icons.warning_rounded, theme.errorColor, theme);
    Widget card2 = _buildStatCard("ĐI TRỄ", totalLates.toString(), Icons.watch_later_rounded, theme.warningColor, theme);
    Widget card3 = _buildStatCard("BỎ / NGHỈ HỌC", totalAbsents.toString(), Icons.person_off_rounded, theme.errorColor, theme);
    Widget card4 = _buildStatCard("NGHỈ CÓ PHÉP", totalExcused.toString(), Icons.medical_information_rounded, theme.infoColor, theme);

    if (width >= 1300) return Row(children: [Expanded(child: card1), const SizedBox(width: 20), Expanded(child: card2), const SizedBox(width: 20), Expanded(child: card3), const SizedBox(width: 20), Expanded(child: card4)]);
    if (width >= 750) return Column(children: [Row(children: [Expanded(child: card1), const SizedBox(width: 20), Expanded(child: card2)]), const SizedBox(height: 20), Row(children: [Expanded(child: card3), const SizedBox(width: 20), Expanded(child: card4)])]);
    return Column(children: [card1, const SizedBox(height: 20), card2, const SizedBox(height: 20), card3, const SizedBox(height: 20), card4]);
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color, AppTheme theme) {
    return AnimatedContainer(duration: const Duration(milliseconds: 400), padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 20), decoration: BoxDecoration(color: theme.cardColor, borderRadius: BorderRadius.circular(20), border: Border.all(color: color.withOpacity(0.3), width: 1.5), boxShadow: theme.isDarkMode ? [] : [BoxShadow(color: color.withOpacity(0.1), blurRadius: 15, offset: const Offset(0, 5))]), child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(14)), child: Icon(icon, color: color, size: 24 * theme.fontScale)), const SizedBox(width: 15), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [Text(title, style: TextStyle(color: theme.subTextColor, fontSize: 11 * theme.fontScale, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis), const SizedBox(height: 5), Text(value, style: TextStyle(color: theme.textColor, fontSize: 20 * theme.fontScale, fontWeight: FontWeight.w900), maxLines: 1, overflow: TextOverflow.ellipsis)]))]));
  }

  Widget _buildSectionHeader(IconData icon, String title, AppTheme theme) => Wrap(crossAxisAlignment: WrapCrossAlignment.center, children: [AnimatedContainer(duration: const Duration(milliseconds: 300), child: Icon(icon, color: theme.primaryColor, size: 18 * theme.fontScale)), const SizedBox(width: 10), AnimatedDefaultTextStyle(duration: const Duration(milliseconds: 300), style: TextStyle(color: theme.textColor, fontSize: 14 * theme.fontScale, fontWeight: FontWeight.bold, letterSpacing: 1.2, fontFamily: 'Segoe UI'), child: Text(title, overflow: TextOverflow.ellipsis))]);

  Widget _buildClassReportCard(Map<String, dynamic> classData, AppTheme theme) {
    bool isPerfect = classData['status'] == 'perfect';
    List<dynamic> violations = classData['violations'];

    if (isPerfect) {
      return AnimatedContainer(
        duration: const Duration(milliseconds: 400), margin: const EdgeInsets.only(bottom: 20), padding: const EdgeInsets.all(25),
        decoration: BoxDecoration(color: theme.successColor.withOpacity(0.05), borderRadius: BorderRadius.circular(20), border: Border.all(color: theme.successColor.withOpacity(0.3), width: 1.5), boxShadow: theme.isDarkMode ? [] : [BoxShadow(color: theme.successColor.withOpacity(0.05), blurRadius: 15, offset: const Offset(0, 5))]),
        child: Row(
          children: [
            Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: theme.successColor.withOpacity(0.2), shape: BoxShape.circle), child: Icon(Icons.check_circle_rounded, color: theme.successColor, size: 24 * theme.fontScale)), const SizedBox(width: 20),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(classData['className'], style: TextStyle(color: theme.textColor, fontSize: 18 * theme.fontScale, fontWeight: FontWeight.bold)), const SizedBox(height: 4), Text("GVCN: ${classData['teacher']}", style: TextStyle(color: theme.subTextColor, fontSize: 12 * theme.fontScale))])),
            Container(padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8), decoration: BoxDecoration(color: theme.successColor.withOpacity(0.2), borderRadius: BorderRadius.circular(10)), child: Text("Sĩ số: ${classData['present']}/${classData['total']} - Đi đủ", style: TextStyle(color: theme.successColor, fontWeight: FontWeight.bold, fontSize: 13 * theme.fontScale))),
          ],
        ),
      );
    }
    return AnimatedContainer(
      duration: const Duration(milliseconds: 400), margin: const EdgeInsets.only(bottom: 20), decoration: BoxDecoration(color: theme.cardColor, borderRadius: BorderRadius.circular(20), border: Border.all(color: theme.errorColor.withOpacity(0.3), width: 1.5), boxShadow: theme.isDarkMode ? [] : [BoxShadow(color: theme.errorColor.withOpacity(0.05), blurRadius: 15, offset: const Offset(0, 5))]),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: true, tilePadding: const EdgeInsets.all(25),
          title: Row(
            children: [
              Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: theme.errorColor.withOpacity(0.15), shape: BoxShape.circle), child: Icon(Icons.warning_amber_rounded, color: theme.errorColor, size: 24 * theme.fontScale)), const SizedBox(width: 20),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(classData['className'], style: TextStyle(color: theme.textColor, fontSize: 18 * theme.fontScale, fontWeight: FontWeight.bold)), const SizedBox(height: 4), Text("GVCN: ${classData['teacher']}", style: TextStyle(color: theme.subTextColor, fontSize: 12 * theme.fontScale))])),
              Container(padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8), decoration: BoxDecoration(color: theme.errorColor.withOpacity(0.15), borderRadius: BorderRadius.circular(10)), child: Text("Sĩ số: ${classData['present']}/${classData['total']} (${violations.length} vi phạm)", style: TextStyle(color: theme.errorColor, fontWeight: FontWeight.bold, fontSize: 13 * theme.fontScale))),
            ],
          ),
          children: [
            Divider(color: theme.errorColor.withOpacity(0.2), height: 1),
            Container(padding: const EdgeInsets.all(25), decoration: BoxDecoration(color: theme.textColor.withOpacity(0.02), borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20))), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: violations.map((v) => _buildViolationRow(v, theme)).toList()))
          ],
        ),
      ),
    );
  }

  Widget _buildViolationRow(Map<String, dynamic> v, AppTheme theme) {
    Color statusColor; IconData statusIcon;
    if (v['type'] == 'Đi trễ') { statusColor = theme.warningColor; statusIcon = Icons.watch_later_rounded; }
    else if (v['type'] == 'Nghỉ học') { statusColor = theme.errorColor; statusIcon = Icons.person_off_rounded; }
    else if (v['type'] == 'Có phép') { statusColor = theme.infoColor; statusIcon = Icons.medical_information_rounded; }
    else { statusColor = theme.subTextColor; statusIcon = Icons.hourglass_empty_rounded; }

    return Padding(
      padding: const EdgeInsets.only(bottom: 15),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          CircleAvatar(radius: 18 * theme.fontScale, backgroundColor: statusColor.withOpacity(0.15), child: Icon(Icons.person, color: statusColor, size: 18 * theme.fontScale)), const SizedBox(width: 15),
          SizedBox(width: 200 * theme.fontScale, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(v['name'], style: TextStyle(color: theme.textColor, fontSize: 14 * theme.fontScale, fontWeight: FontWeight.bold)), const SizedBox(height: 2), Text(v['id'], style: TextStyle(color: theme.subTextColor, fontSize: 11 * theme.fontScale))])),
          Container(width: 120 * theme.fontScale, padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6), decoration: BoxDecoration(color: statusColor.withOpacity(0.1), borderRadius: BorderRadius.circular(8), border: Border.all(color: statusColor.withOpacity(0.3))), child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(statusIcon, color: statusColor, size: 12 * theme.fontScale), const SizedBox(width: 6), Text(v['type'], style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 11 * theme.fontScale))])), const SizedBox(width: 20),
          Expanded(child: Text(v['detail'], style: TextStyle(color: theme.subTextColor, fontSize: 13 * theme.fontScale, fontStyle: FontStyle.italic)))
        ],
      ),
    );
  }
}