import 'package:flutter/material.dart';
import '../theme_manager.dart';
import 'project_info_view.dart';
import 'project_members_view.dart';
import 'class_management_view.dart';
import 'attendance_report_view.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'dart:js' as js;
import '../globals.dart' as globals;
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
// ignore: avoid_web_libraries_in_flutter
import 'dart:ui_web' as ui_web;


class ProjectWorkspaceScreen extends StatefulWidget {
  // THÊM 2 BIẾN NÀY ĐỂ PHÂN QUYỀN TỪ MÀN HÌNH NGOÀI
  final String userRole; // 'Super Admin' hoặc 'Admin'
  final String? assignedUnit; // Ví dụ: 'Lớp 10A1' (Nếu là Admin)

  const ProjectWorkspaceScreen({
    super.key,
    this.userRole = 'Super Admin', // Mặc định để test là Super Admin
    this.assignedUnit,
  });

  @override
  State<ProjectWorkspaceScreen> createState() => _ProjectWorkspaceScreenState();
}

class _ProjectWorkspaceScreenState extends State<ProjectWorkspaceScreen> {
  String _activeMenuId = 'info';
  bool _isClassMenuExpanded = false;
  // ---> BIẾN LƯU DANH SÁCH LỚP THẬT
  List<dynamic> _classList = [];
  bool _isLoadingClasses = true;

  @override
  void initState() {
    super.initState();
    _fetchClassMenu(); // Gọi API kéo menu lớp
  }

  Future<void> _fetchClassMenu() async {
    try {
      var response = await http.get(Uri.parse('http://127.0.0.1:8000/api/projects/${globals.currentProjectId}/classes'));
      if (response.statusCode == 200) {
        var data = jsonDecode(utf8.decode(response.bodyBytes));
        if (data['status'] == 'success') {
          setState(() {
            _classList = data['data'];
            _isLoadingClasses = false;
          });
        }
      }
    } catch (e) {
      setState(() => _isLoadingClasses = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: AppTheme.instance,
      builder: (context, child) {
        final theme = AppTheme.instance;
        bool isSuperAdmin = widget.userRole == 'Super Admin';

        return Scaffold(
          backgroundColor: theme.isDarkMode ? const Color(0xFF050505) : theme.backgroundColor,
          body: Row(
            children: [
              // ==========================================
              // MENU DỌC BÊN TRÁI (SIDEBAR ĐỘNG THEO QUYỀN)
              // ==========================================
              Container(
                width: 280 * theme.fontScale,
                decoration: BoxDecoration(
                  color: theme.isDarkMode ? const Color(0xFF0A101E).withOpacity(0.5) : theme.cardColor,
                  border: Border(right: BorderSide(color: theme.isDarkMode ? Colors.white.withOpacity(0.08) : theme.borderColor))
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: InkWell(
                        onTap: () => Navigator.pop(context),
                        child: Row(children: [Icon(Icons.arrow_back_ios_new_rounded, color: theme.isDarkMode ? Colors.white54 : Colors.black54, size: 16 * theme.fontScale), const SizedBox(width: 10), AnimatedDefaultTextStyle(duration: const Duration(milliseconds: 300), style: TextStyle(color: theme.isDarkMode ? Colors.white54 : Colors.black54, fontSize: 13 * theme.fontScale, fontWeight: FontWeight.bold, fontFamily: 'Segoe UI'), child: const Text("Về bảng điều khiển"))]),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Padding(padding: const EdgeInsets.symmetric(horizontal: 25.0), child: AnimatedDefaultTextStyle(duration: const Duration(milliseconds: 300), style: TextStyle(color: theme.textColor, fontSize: 18 * theme.fontScale, fontWeight: FontWeight.w900, fontFamily: 'Segoe UI'), child: const Text("SAMS Cơ sở 1"))),
                    Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 25.0, vertical: 5.0),
                        child: AnimatedDefaultTextStyle(
                            duration: const Duration(milliseconds: 300),
                            // Đổi màu chữ dưới tên dự án để nhận biết quyền
                            style: TextStyle(color: isSuperAdmin ? theme.primaryColor : Colors.greenAccent, fontSize: 12 * theme.fontScale, fontWeight: FontWeight.bold, fontFamily: 'Segoe UI'),
                            child: Text(isSuperAdmin ? "Trường học • Super Admin" : "Trường học • ${widget.assignedUnit ?? 'Admin'}")
                        )
                    ),
                    const SizedBox(height: 30),

                    // 1. INFO: Ai cũng được xem
                    _buildSidebarItem(Icons.info_outline_rounded, "Thông tin dự án", 'info', theme),

                    // 2. THÀNH VIÊN: CHỈ SUPER ADMIN ĐƯỢC XEM
                    if (isSuperAdmin)
                      _buildSidebarItem(Icons.manage_accounts_rounded, "Thành viên quản trị", 'members', theme),

                    // 3. QUẢN LÝ LỚP HỌC
                    if (isSuperAdmin || widget.userRole == 'Khách truy cập')
                      _buildExpandableClassMenu(theme)
                    else
                      _buildSidebarItem(Icons.meeting_room_rounded, "Lớp của tôi (${widget.assignedUnit})", 'class_${widget.assignedUnit}', theme),

                    // 4. CAMERA & BÁO CÁO: Ai cũng được thao tác
                    _buildSidebarItem(Icons.devices_other_rounded, "Thiết bị Camera", 'devices', theme),
                    _buildSidebarItem(Icons.bar_chart_rounded, "Báo cáo điểm danh", 'reports', theme),
                  ],
                ),
              ),

              // ==========================================
              // KHU VỰC HIỂN THỊ BÊN PHẢI (CONTENT)
              // ==========================================
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: _buildWorkspaceContent(isSuperAdmin),
                ),
              )
            ],
          ),
        );
      },
    );
  }

  // Khung điều hướng nội dung có truyền cờ `isSuperAdmin`
  // Khung điều hướng nội dung có truyền cờ `isSuperAdmin`
  Widget _buildWorkspaceContent(bool isSuperAdmin) {
    // NẾU MENU ĐANG CHỌN LÀ LỚP HỌC
    if (_activeMenuId.startsWith('class_')) {
      int classId = int.parse(_activeMenuId.split('_')[1]);
      String className = "Đang tải...";

      // Tìm tên lớp từ danh sách
      for (var cls in _classList) {
        if (cls['id'] == classId) {
          className = cls['class_name'];
          break;
        }
      }

      // BẮT BUỘC PHẢI CÓ CHỮ "return" ĐỂ GIAO DIỆN HIỆN RA
      return ClassManagementView(
        key: ValueKey('class_$classId'),
        classId: classId,
        className: className,
        isSuperAdmin: isSuperAdmin,
      );
    }

    // NẾU LÀ CÁC MENU KHÁC
    switch (_activeMenuId) {
      case 'info':
        return ProjectInfoView(key: const ValueKey('info_view'), isSuperAdmin: isSuperAdmin);
      case 'members':
        return const ProjectMembersView(key: ValueKey('members_view'));
      case 'reports':
        return const AttendanceReportView(key: ValueKey('reports_view'));
      case 'devices':
        return Padding(
          key: const ValueKey('devices_view'),
          padding: const EdgeInsets.all(25.0),
          child: WebCameraView(projectId: globals.currentProjectId, isSuperAdmin: isSuperAdmin),
        );
      default:
        return const Center(child: Text("Tính năng đang phát triển...", style: TextStyle(color: Colors.white)));
    }
  }

  Widget _buildSidebarItem(IconData icon, String title, String menuId, AppTheme theme) {
    bool isSelected = _activeMenuId == menuId;
    return InkWell(
      onTap: () {
        setState(() {
          _activeMenuId = menuId;
          _isClassMenuExpanded = false;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300), margin: const EdgeInsets.symmetric(horizontal: 15, vertical: 4), padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
        decoration: BoxDecoration(color: isSelected ? theme.primaryColor.withOpacity(0.15) : Colors.transparent, borderRadius: BorderRadius.circular(12), border: Border.all(color: isSelected ? theme.primaryColor.withOpacity(0.5) : Colors.transparent)),
        child: Row(children: [Icon(icon, color: isSelected ? theme.primaryColor : (theme.isDarkMode ? Colors.white54 : Colors.black54), size: 20 * theme.fontScale), const SizedBox(width: 15), Expanded(child: AnimatedDefaultTextStyle(duration: const Duration(milliseconds: 300), style: TextStyle(color: isSelected ? theme.primaryColor : (theme.isDarkMode ? Colors.white70 : Colors.black87), fontSize: 13 * theme.fontScale, fontWeight: isSelected ? FontWeight.bold : FontWeight.w600, fontFamily: 'Segoe UI'), child: Text(title)))]),
      ),
    );
  }

  Widget _buildExpandableClassMenu(AppTheme theme) {
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        leading: Icon(Icons.meeting_room_rounded, color: theme.primaryColor),
        title: Text("Quản lý Lớp học", style: TextStyle(color: theme.isDarkMode ? Colors.white : Colors.black87, fontWeight: FontWeight.bold, fontSize: 13 * theme.fontScale)),
        iconColor: theme.primaryColor,
        collapsedIconColor: theme.isDarkMode ? Colors.white54 : Colors.black54,
        children: [
          if (_isLoadingClasses)
            const Padding(padding: EdgeInsets.all(15.0), child: Center(child: CircularProgressIndicator(strokeWidth: 2))),

          if (!_isLoadingClasses && _classList.isEmpty)
            Padding(padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 20), child: Text("Chưa có lớp nào", style: TextStyle(color: theme.isDarkMode ? Colors.white54 : Colors.black54, fontSize: 12 * theme.fontScale, fontStyle: FontStyle.italic))),

          // VÒNG LẶP RENDER LỚP THẬT (GỌN GÀNG, KHÔNG LỖI)
          ..._classList.map((cls) {
            String menuKey = 'class_${cls['id']}';

            return _buildSubMenuItem(
                cls['class_name'], // 1. Tên lớp
                menuKey,           // 2. Mã menu ID
                theme              // 3. Theme (TRUYỀN TRỰC TIẾP, KHÔNG DÙNG HÀM NỮA)
            );
          }).toList(),
        ],
      ),
    );
  }

  Widget _buildSubMenuItem(String title, String menuId, AppTheme theme) {
    bool isSelected = _activeMenuId == menuId;
    return InkWell(
      onTap: () {
        setState(() => _activeMenuId = menuId);
        // Tự động đóng menu nếu màn hình nhỏ (Mobile)
        if (MediaQuery.of(context).size.width < 850) {
          Navigator.pop(context);
        }
      },
      child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          width: double.infinity,
          padding: const EdgeInsets.only(left: 70, top: 12, bottom: 12),
          color: isSelected ? theme.primaryColor.withOpacity(0.05) : Colors.transparent,
          child: Row(children: [
            Container(width: 6, height: 6, decoration: BoxDecoration(shape: BoxShape.circle, color: isSelected ? theme.primaryColor : (theme.isDarkMode ? Colors.white24 : Colors.black26))),
            const SizedBox(width: 15),
            Text(title, style: TextStyle(color: isSelected ? theme.primaryColor : (theme.isDarkMode ? Colors.white54 : Colors.black54), fontSize: 13 * theme.fontScale, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal))
          ])
      ),
    );
  }
}

class WebCameraView extends StatefulWidget {
  final int projectId;
  final bool isSuperAdmin;
  const WebCameraView({super.key, required this.projectId, this.isSuperAdmin = false});

  @override
  State<WebCameraView> createState() => _WebCameraViewState();
}

class _WebCameraViewState extends State<WebCameraView> {
  html.VideoElement? _videoElement;
  String _viewType = '';
  html.MediaStream? _localStream;
  bool _hasError = false;

  Timer? _scanTimer;
  Timer? _toastTimer;
  bool _isScanning = false;
  Map<String, dynamic>? _detectedStudent;
  List<dynamic> _detectedStudents = [];
  bool _showToast = false;
  Map<String, DateTime> _lockList = {};
  String _statusMessage = 'AI ENGINE: ACTIVE SCANNING';

  @override
  void initState() {
    super.initState();
    _viewType = 'webcam-view-${DateTime.now().millisecondsSinceEpoch}';
    _videoElement = html.VideoElement()
      ..style.width = '100%'
      ..style.height = '100%'
      ..autoplay = true
      ..style.objectFit = 'cover'
      ..style.borderRadius = '16px';

    // Đăng ký View Factory
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
        
        // Bắt đầu quét khuôn mặt định kỳ 3 giây/lần sau khi camera chạy
        _scanTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
          if (mounted) _scanFace();
        });
      }
    } catch (e) {
      setState(() {
        _hasError = true;
      });
    }
  }

  String? _captureFrame() {
    if (_videoElement == null || _videoElement!.videoWidth == 0 || _videoElement!.videoHeight == 0) {
      return null;
    }
    final width = _videoElement!.videoWidth;
    final height = _videoElement!.videoHeight;
    final canvas = html.CanvasElement(width: width, height: height);
    final ctx = canvas.context2D;
    ctx.drawImageScaled(_videoElement!, 0, 0, width, height);
    final dataUrl = canvas.toDataUrl('image/jpeg');
    return dataUrl;
  }

  Future<void> _scanFace() async {
    if (_hasError || _videoElement == null || _isScanning) return;

    final dataUrl = _captureFrame();
    if (dataUrl == null) return;

    setState(() {
      _isScanning = true;
      _statusMessage = 'AI ENGINE: ANALYZING FACE...';
    });

    try {
      final response = await http.post(
        Uri.parse('http://127.0.0.1:8000/api/attendance/recognize-face'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'image_base64': dataUrl}),
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        final status = data['status'];

        if (status == 'success' || status == 'already_marked') {
          final studentCode = data['student_code'] ?? '';
          final studentName = data['student_name'] ?? 'Học sinh';
          final className = data['class_name'] ?? '';
          final timeIn = data['time_in'] ?? '';
          final attStatus = data['attendance_status'] ?? 'Hợp lệ';
          final confidence = data['confidence'] ?? 0.0;
          final currentSlot = data['current_slot'] ?? 'Đầu giờ Sáng';

          final now = DateTime.now();
          if (_lockList.containsKey(studentCode)) {
            final lastMatchTime = _lockList[studentCode]!;
            if (now.difference(lastMatchTime).inSeconds < 10) {
              setState(() {
                _statusMessage = 'AI ENGINE: COOLDOWN ACTIVE';
                _isScanning = false;
              });
              return;
            }
          }

          // Khóa học sinh này trong 10 giây
          _lockList[studentCode] = now;

          final resultsRaw = data['results'] as List?;
          final List<Map<String, dynamic>> resolvedResults = [];
          if (resultsRaw != null) {
            for (var r in resultsRaw) {
              resolvedResults.add({
                'student_code': r['student_code'] ?? '',
                'student_name': r['student_name'] ?? 'Học sinh',
                'class_name': r['class_name'] ?? '',
                'time_in': r['time_in'] ?? '',
                'status': r['attendance_status'] ?? 'Hợp lệ',
                'is_already': r['status'] == 'already_marked',
                'confidence': r['confidence'] ?? 0.0,
                'current_slot': r['current_slot'] ?? 'Đầu giờ Sáng',
              });
              _lockList[r['student_code']] = now;
            }
          } else {
            resolvedResults.add({
              'student_code': studentCode,
              'student_name': studentName,
              'class_name': className,
              'time_in': timeIn,
              'status': attStatus,
              'is_already': status == 'already_marked',
              'confidence': confidence,
              'current_slot': currentSlot,
            });
          }

          setState(() {
            _detectedStudents = resolvedResults;
            _detectedStudent = Map<String, dynamic>.from(_detectedStudents[0]);
            _showToast = true;
            _statusMessage = _detectedStudents.length > 1
                ? 'AI ENGINE: MATCHED ${_detectedStudents.length} STUDENTS'
                : 'AI ENGINE: MATCHED ${studentName.toUpperCase()} (${confidence.toStringAsFixed(1)}%)';
          });

          // Hiệu ứng âm thanh check-in thành công bằng Web Audio API qua JS
          try {
            if (_detectedStudents.length > 1) {
              js.context.callMethod('eval', ["""
                (function() {
                  try {
                    var audioCtx = new (window.AudioContext || window.webkitAudioContext)();
                    var osc1 = audioCtx.createOscillator();
                    var gain1 = audioCtx.createGain();
                    osc1.connect(gain1);
                    gain1.connect(audioCtx.destination);
                    osc1.frequency.setValueAtTime(660, audioCtx.currentTime);
                    gain1.gain.setValueAtTime(0.08, audioCtx.currentTime);
                    osc1.start();
                    osc1.stop(audioCtx.currentTime + 0.1);

                    var osc2 = audioCtx.createOscillator();
                    var gain2 = audioCtx.createGain();
                    osc2.connect(gain2);
                    gain2.connect(audioCtx.destination);
                    osc2.frequency.setValueAtTime(880, audioCtx.currentTime + 0.15);
                    gain2.gain.setValueAtTime(0.08, audioCtx.currentTime + 0.15);
                    osc2.start(audioCtx.currentTime + 0.15);
                    osc2.stop(audioCtx.currentTime + 0.25);
                  } catch (e) {
                    console.log("Audio feedback failed: " + e);
                  }
                })();
              """]);
            } else {
              js.context.callMethod('eval', ["""
                (function() {
                  try {
                    var audioCtx = new (window.AudioContext || window.webkitAudioContext)();
                    var oscillator = audioCtx.createOscillator();
                    var gainNode = audioCtx.createGain();
                    oscillator.connect(gainNode);
                    gainNode.connect(audioCtx.destination);
                    oscillator.type = 'sine';
                    oscillator.frequency.setValueAtTime(660, audioCtx.currentTime);
                    gainNode.gain.setValueAtTime(0.08, audioCtx.currentTime);
                    oscillator.start();
                    oscillator.stop(audioCtx.currentTime + 0.15);
                  } catch (e) {
                    console.log("Audio feedback failed: " + e);
                  }
                })();
              """]);
            }
          } catch (_) {}

          // Tự động tắt Toast
          _toastTimer?.cancel();
          _toastTimer = Timer(Duration(seconds: _detectedStudents.length > 1 ? 8 : 5), () {
            if (mounted) {
              setState(() {
                _showToast = false;
              });
            }
          });
        } else if (status == 'no_face') {
          setState(() {
            _statusMessage = 'AI ENGINE: NO FACE IN FRAME';
          });
        } else if (status == 'unknown') {
          setState(() {
            _statusMessage = 'AI ENGINE: UNKNOWN FACE DETECTED';
          });
        } else {
          setState(() {
            _statusMessage = 'AI ENGINE: ACTIVE SCANNING';
          });
        }
      } else {
        setState(() {
          _statusMessage = 'AI ENGINE: SERVER ERROR (${response.statusCode})';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _statusMessage = 'AI ENGINE: CONNECTION ERROR';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isScanning = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _scanTimer?.cancel();
    _toastTimer?.cancel();
    _localStream?.getTracks().forEach((track) {
      track.stop();
    });
    _videoElement?.srcObject = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.instance;

    if (_hasError) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.videocam_off_rounded, color: Colors.redAccent, size: 60),
            SizedBox(height: 15),
            Text(
              "Không thể truy cập Webcam của bạn.\nVui lòng cấp quyền truy cập camera cho trình duyệt!",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white70, fontSize: 16),
            ),
          ],
        ),
      );
    }

    final frameColor = _showToast 
        ? Colors.greenAccent 
        : (_statusMessage.contains('ERROR') ? Colors.redAccent : theme.primaryColor);

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0F1422),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, 8),
          )
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          children: [
            // Camera View
            HtmlElementView(viewType: _viewType),
            
            // Face Scanning Overlay
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: frameColor.withOpacity(0.3), width: 2),
                ),
                child: Stack(
                  children: [
                    // Khung nhận diện góc (Face Box Corners)
                    _buildCorner(0, 0, top: 30, left: 30, color: frameColor),
                    _buildCorner(1, 0, top: 30, right: 30, color: frameColor),
                    _buildCorner(0, 1, bottom: 30, left: 30, color: frameColor),
                    _buildCorner(1, 1, bottom: 30, right: 30, color: frameColor),
                    
                    // Hiệu ứng quét dòng quét Neon chạy dọc xuống
                    ScanningLine(color: frameColor),
                    
                    // Trạng thái AI hoạt động ở góc
                    Positioned(
                      top: 25,
                      left: 25,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.7),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: frameColor, width: 1.5),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.fiber_manual_record, 
                              color: _isScanning 
                                  ? Colors.amberAccent 
                                  : (_showToast ? Colors.greenAccent : (_statusMessage.contains('ERROR') ? Colors.redAccent : Colors.greenAccent)), 
                              size: 10
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _statusMessage,
                              style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1, fontFamily: 'Segoe UI'),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // NÚT CÀI ĐẶT GIỜ ĐIỂM DANH (CHỈ ADMIN MỚI THẤY)
                    if (widget.isSuperAdmin)
                      Positioned(
                        top: 25,
                        right: 25,
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: () => _showAttendanceConfigDialog(context),
                            child: Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.7),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: theme.primaryColor.withOpacity(0.6), width: 1.5),
                                boxShadow: [
                                  BoxShadow(
                                    color: theme.primaryColor.withOpacity(0.15),
                                    blurRadius: 10,
                                  )
                                ],
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.settings_rounded, color: theme.primaryColor, size: 16),
                                  const SizedBox(width: 6),
                                  Text(
                                    "CÀI ĐẶT GIỜ",
                                    style: TextStyle(color: theme.primaryColor, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1, fontFamily: 'Segoe UI'),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),

                    // Thông báo chỉ dẫn người dùng
                    Positioned(
                      bottom: 25,
                      left: 0,
                      right: 0,
                      child: Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.7),
                            borderRadius: BorderRadius.circular(30),
                            border: Border.all(color: Colors.white.withOpacity(0.1)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.face_retouching_natural_rounded, color: frameColor, size: 18),
                              const SizedBox(width: 10),
                              const Text(
                                "Vui lòng giữ thẳng mặt trước Camera để AI nhận diện",
                                style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold, fontFamily: 'Segoe UI'),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Glassmorphic Glowing Toast Overlay
            AnimatedPositioned(
              duration: const Duration(milliseconds: 500),
              curve: Curves.elasticOut,
              bottom: _showToast ? 80 : -280,
              left: 25,
              right: 25,
              child: _showToast && _detectedStudents.isNotEmpty
                  ? AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [
                            Color(0xEE0B1A1E), // Dark cyan-grey glass
                            Color(0xEE0A2218), // Dark emerald green glass
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: (_detectedStudent != null && _detectedStudent!['is_already']) 
                              ? Colors.amberAccent.withOpacity(0.8) 
                              : Colors.greenAccent.withOpacity(0.8), 
                          width: 2
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: ((_detectedStudent != null && _detectedStudent!['is_already']) ? Colors.amberAccent : Colors.greenAccent).withOpacity(0.35),
                            blurRadius: 25,
                            spreadRadius: 1,
                          )
                        ],
                      ),
                      child: _detectedStudents.length == 1
                          ? Row(
                              children: [
                                // Circle Avatar với Neon Ring
                                Container(
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: _detectedStudent!['is_already'] ? Colors.amberAccent : Colors.greenAccent, 
                                      width: 2.5
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: (_detectedStudent!['is_already'] ? Colors.amberAccent : Colors.greenAccent).withOpacity(0.3),
                                        blurRadius: 10,
                                      )
                                    ],
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(30),
                                    child: Image.network(
                                      'http://127.0.0.1:8000/static/avatars/${_detectedStudent!['student_code']}_face.jpg',
                                      width: 60,
                                      height: 60,
                                      fit: BoxFit.cover,
                                      errorBuilder: (context, error, stackTrace) {
                                        return Container(
                                          width: 60,
                                          height: 60,
                                          color: const Color(0xFF1E293B),
                                          child: Icon(
                                            Icons.person_rounded, 
                                            color: _detectedStudent!['is_already'] ? Colors.amberAccent : Colors.greenAccent, 
                                            size: 32
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                // Student Details
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: (_detectedStudent!['is_already'] ? Colors.amberAccent : Colors.greenAccent).withOpacity(0.15),
                                              borderRadius: BorderRadius.circular(30),
                                              border: Border.all(
                                                color: _detectedStudent!['is_already'] ? Colors.amberAccent : Colors.greenAccent, 
                                                width: 1
                                              ),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(
                                                  _detectedStudent!['is_already'] ? Icons.warning_amber_rounded : Icons.check_circle_outline_rounded,
                                                  color: _detectedStudent!['is_already'] ? Colors.amberAccent : Colors.greenAccent,
                                                  size: 14,
                                                ),
                                                const SizedBox(width: 5),
                                                Text(
                                                  _detectedStudent!['is_already'] 
                                                      ? "ĐÃ ĐIỂM DANH ${(_detectedStudent!['current_slot'] ?? 'Đầu giờ Sáng').toUpperCase()} TRƯỚC ĐÓ" 
                                                      : "ĐIỂM DANH ${(_detectedStudent!['current_slot'] ?? 'Đầu giờ Sáng').toUpperCase()}",
                                                  style: TextStyle(
                                                    color: _detectedStudent!['is_already'] ? Colors.amberAccent : Colors.greenAccent,
                                                    fontSize: 9,
                                                    fontWeight: FontWeight.w900,
                                                    letterSpacing: 1.2,
                                                    fontFamily: 'Segoe UI',
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          // Confidence
                                          Text(
                                            "${_detectedStudent!['confidence'].toStringAsFixed(1)}% khớp",
                                            style: const TextStyle(
                                              color: Colors.white54, 
                                              fontSize: 10, 
                                              fontWeight: FontWeight.bold,
                                              fontFamily: 'Segoe UI'
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        _detectedStudent!['student_name'],
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 18,
                                          fontWeight: FontWeight.w900,
                                          letterSpacing: 0.5,
                                          fontFamily: 'Segoe UI',
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        "Mã HS: ${_detectedStudent!['student_code']} • Lớp: ${_detectedStudent!['class_name']}",
                                        style: const TextStyle(
                                          color: Colors.white70,
                                          fontSize: 12,
                                          fontFamily: 'Segoe UI',
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 16),
                                // Status Badge with glow
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: (_detectedStudent!['status'] == 'Đi trễ' || _detectedStudent!['status'] == 'Về sớm') 
                                        ? Colors.orangeAccent.withOpacity(0.15) 
                                        : Colors.greenAccent.withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: (_detectedStudent!['status'] == 'Đi trễ' || _detectedStudent!['status'] == 'Về sớm') ? Colors.orangeAccent : Colors.greenAccent,
                                      width: 1.5,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: ((_detectedStudent!['status'] == 'Đi trễ' || _detectedStudent!['status'] == 'Về sớm') ? Colors.orangeAccent : Colors.greenAccent).withOpacity(0.1),
                                        blurRadius: 8,
                                      )
                                    ],
                                  ),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        _detectedStudent!['status'] == 'Đi trễ' 
                                            ? "ĐI TRỄ" 
                                            : (_detectedStudent!['status'] == 'Về sớm' ? "VỀ SỚM" : "HỢP LỆ"),
                                        style: TextStyle(
                                          color: (_detectedStudent!['status'] == 'Đi trễ' || _detectedStudent!['status'] == 'Về sớm') ? Colors.orangeAccent : Colors.greenAccent,
                                          fontWeight: FontWeight.w900,
                                          fontSize: 12,
                                          fontFamily: 'Segoe UI',
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        _detectedStudent!['time_in'],
                                        style: TextStyle(
                                          color: (_detectedStudent!['status'] == 'Đi trễ' || _detectedStudent!['status'] == 'Về sớm') ? Colors.orangeAccent.withOpacity(0.8) : Colors.greenAccent.withOpacity(0.8),
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                          fontFamily: 'Segoe UI',
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            )
                          : Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Row(
                                      children: [
                                        Icon(Icons.people_alt_rounded, color: Colors.greenAccent, size: 20 * theme.fontScale),
                                        const SizedBox(width: 10),
                                        Text(
                                          "ĐÃ PHÁT HIỆN ${_detectedStudents.length} HỌC SINH ĐỒNG THỜI",
                                          style: TextStyle(
                                            color: Colors.greenAccent,
                                            fontSize: 12 * theme.fontScale,
                                            fontWeight: FontWeight.w900,
                                            letterSpacing: 1.2,
                                            fontFamily: 'Segoe UI',
                                          ),
                                        ),
                                      ],
                                    ),
                                    Text(
                                      "${_detectedStudent?['current_slot'] ?? 'Đầu giờ Sáng'}",
                                      style: TextStyle(
                                        color: Colors.white54,
                                        fontSize: 11 * theme.fontScale,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 15),
                                Container(
                                  constraints: const BoxConstraints(maxHeight: 220),
                                  child: SingleChildScrollView(
                                    physics: const BouncingScrollPhysics(),
                                    child: Column(
                                      children: _detectedStudents.map((std) {
                                        bool isAlready = std['is_already'] == true;
                                        Color badgeColor = std['status'] == 'Đi trễ' || std['status'] == 'Về sớm'
                                            ? Colors.orangeAccent
                                            : Colors.greenAccent;
                                        return Container(
                                          margin: const EdgeInsets.only(bottom: 10),
                                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                          decoration: BoxDecoration(
                                            color: Colors.white.withOpacity(0.03),
                                            borderRadius: BorderRadius.circular(12),
                                            border: Border.all(
                                              color: Colors.white.withOpacity(0.05),
                                            ),
                                          ),
                                          child: Row(
                                            children: [
                                              // Avatar
                                              ClipRRect(
                                                borderRadius: BorderRadius.circular(20),
                                                child: Image.network(
                                                  'http://127.0.0.1:8000/static/avatars/${std['student_code']}_face.jpg',
                                                  width: 38,
                                                  height: 38,
                                                  fit: BoxFit.cover,
                                                  errorBuilder: (context, error, stackTrace) {
                                                    return Container(
                                                      width: 38,
                                                      height: 38,
                                                      color: const Color(0xFF1E293B),
                                                      child: Icon(
                                                        Icons.person_rounded,
                                                        color: badgeColor,
                                                        size: 20,
                                                      ),
                                                    );
                                                  },
                                                ),
                                              ),
                                              const SizedBox(width: 12),
                                              // Name & Code
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      std['student_name'],
                                                      style: TextStyle(
                                                        color: Colors.white,
                                                        fontSize: 14 * theme.fontScale,
                                                        fontWeight: FontWeight.bold,
                                                        fontFamily: 'Segoe UI',
                                                      ),
                                                    ),
                                                    const SizedBox(height: 2),
                                                    Text(
                                                      "Mã: ${std['student_code']} • Lớp: ${std['class_name']}",
                                                      style: TextStyle(
                                                        color: Colors.white60,
                                                        fontSize: 10 * theme.fontScale,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              // Status Badge
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                decoration: BoxDecoration(
                                                  color: badgeColor.withOpacity(0.15),
                                                  borderRadius: BorderRadius.circular(8),
                                                  border: Border.all(color: badgeColor, width: 1),
                                                ),
                                                child: Text(
                                                  isAlready
                                                      ? "ĐÃ LƯU"
                                                      : (std['status'] == 'Đi trễ' ? "ĐI TRỄ" : (std['status'] == 'Về sớm' ? "VỀ SỚM" : "HỢP LỆ")),
                                                  style: TextStyle(
                                                    color: badgeColor,
                                                    fontWeight: FontWeight.w900,
                                                    fontSize: 9 * theme.fontScale,
                                                    fontFamily: 'Segoe UI',
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        );
                                      }).toList(),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                    )
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }

  // =====================================================================
  // DIALOG CÀI ĐẶT GIỜ ĐIỂM DANH (GLASSMORPHIC PREMIUM)
  // =====================================================================
  void _showAttendanceConfigDialog(BuildContext context) async {
    final theme = AppTheme.instance;

    // Load cấu hình hiện tại từ Server
    String morningStart = '07:30';
    String morningEnd = '11:30';
    String afternoonStart = '13:30';
    String afternoonEnd = '17:00';

    try {
      final resp = await http.get(
        Uri.parse('http://127.0.0.1:8000/api/projects/${widget.projectId}/attendance-config'),
      );
      if (resp.statusCode == 200) {
        final data = jsonDecode(utf8.decode(resp.bodyBytes));
        if (data['status'] == 'success') {
          final d = data['data'];
          final mt = (d['morning_time'] ?? '07:30 - 11:30').toString();
          final at = (d['afternoon_time'] ?? '13:30 - 17:00').toString();
          if (mt.contains('-')) {
            morningStart = mt.split('-')[0].trim();
            morningEnd = mt.split('-')[1].trim();
          }
          if (at.contains('-')) {
            afternoonStart = at.split('-')[0].trim();
            afternoonEnd = at.split('-')[1].trim();
          }
        }
      }
    } catch (_) {}

    final morningStartCtrl = TextEditingController(text: morningStart);
    final morningEndCtrl = TextEditingController(text: morningEnd);
    final afternoonStartCtrl = TextEditingController(text: afternoonStart);
    final afternoonEndCtrl = TextEditingController(text: afternoonEnd);
    bool isSaving = false;

    if (!mounted) return;

    showDialog(
      context: context,
      barrierColor: Colors.black54,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {

            Future<void> pickTime(TextEditingController ctrl) async {
              final parts = ctrl.text.split(':');
              final initialTime = TimeOfDay(
                hour: int.tryParse(parts[0]) ?? 7,
                minute: int.tryParse(parts.length > 1 ? parts[1] : '0') ?? 0,
              );
              final picked = await showTimePicker(
                context: ctx,
                initialTime: initialTime,
                helpText: 'CHỌN GIỜ',
                cancelText: 'HỦY',
                confirmText: 'CHỌN',
                builder: (context, child) {
                  return Theme(
                    data: ThemeData.dark().copyWith(
                      colorScheme: ColorScheme.dark(
                        primary: theme.primaryColor,
                        surface: const Color(0xFF1A1F2E),
                      ),
                    ),
                    child: child!,
                  );
                },
              );
              if (picked != null) {
                setDialogState(() {
                  ctrl.text = '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
                });
              }
            }

            Widget buildTimeRow(String label, IconData icon, TextEditingController startCtrl, TextEditingController endCtrl, Color accent) {
              return Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: accent.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: accent.withOpacity(0.25)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(icon, color: accent, size: 18),
                        const SizedBox(width: 8),
                        Text(label, style: TextStyle(color: accent, fontSize: 13, fontWeight: FontWeight.w800, fontFamily: 'Segoe UI', letterSpacing: 0.5)),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            borderRadius: BorderRadius.circular(10),
                            onTap: () => pickTime(startCtrl),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              decoration: BoxDecoration(
                                color: const Color(0xFF0D1117),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: accent.withOpacity(0.4)),
                              ),
                              child: Column(
                                children: [
                                  Text('GIỜ VÀO', style: TextStyle(color: Colors.white38, fontSize: 9, fontWeight: FontWeight.w700, letterSpacing: 1)),
                                  const SizedBox(height: 4),
                                  Text(startCtrl.text, style: TextStyle(color: accent, fontSize: 22, fontWeight: FontWeight.w900, fontFamily: 'Segoe UI')),
                                ],
                              ),
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Icon(Icons.arrow_forward_rounded, color: accent.withOpacity(0.5), size: 20),
                        ),
                        Expanded(
                          child: InkWell(
                            borderRadius: BorderRadius.circular(10),
                            onTap: () => pickTime(endCtrl),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              decoration: BoxDecoration(
                                color: const Color(0xFF0D1117),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: accent.withOpacity(0.4)),
                              ),
                              child: Column(
                                children: [
                                  Text('GIỜ RA', style: TextStyle(color: Colors.white38, fontSize: 9, fontWeight: FontWeight.w700, letterSpacing: 1)),
                                  const SizedBox(height: 4),
                                  Text(endCtrl.text, style: TextStyle(color: accent, fontSize: 22, fontWeight: FontWeight.w900, fontFamily: 'Segoe UI')),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            }

            return Center(
              child: Material(
                color: Colors.transparent,
                child: Container(
                  width: 420,
                  padding: const EdgeInsets.all(28),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xF0111827), Color(0xF00D1117)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: theme.primaryColor.withOpacity(0.3), width: 1.5),
                    boxShadow: [
                      BoxShadow(color: theme.primaryColor.withOpacity(0.1), blurRadius: 30, spreadRadius: 2),
                      BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 20),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Header
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: theme.primaryColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: theme.primaryColor.withOpacity(0.3)),
                            ),
                            child: Icon(Icons.schedule_rounded, color: theme.primaryColor, size: 22),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Cài đặt giờ Điểm danh', style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w900, fontFamily: 'Segoe UI')),
                                const SizedBox(height: 2),
                                Text('Tùy chỉnh giờ vào/ra cho từng ca học', style: TextStyle(color: Colors.white38, fontSize: 11, fontFamily: 'Segoe UI')),
                              ],
                            ),
                          ),
                          InkWell(
                            onTap: () => Navigator.pop(ctx),
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.05),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(Icons.close_rounded, color: Colors.white38, size: 18),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // Ca Sáng
                      buildTimeRow('CA SÁNG', Icons.wb_sunny_rounded, morningStartCtrl, morningEndCtrl, const Color(0xFFFFA726)),
                      const SizedBox(height: 16),

                      // Ca Chiều
                      buildTimeRow('CA CHIỀU', Icons.nights_stay_rounded, afternoonStartCtrl, afternoonEndCtrl, const Color(0xFF42A5F5)),
                      const SizedBox(height: 10),

                      // Thông tin ân hạn
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.03),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.white.withOpacity(0.06)),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.info_outline_rounded, color: Colors.white24, size: 14),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Hệ thống tự động ân hạn 15 phút cho giờ vào (đi trễ) và giờ ra (về sớm).',
                                style: TextStyle(color: Colors.white30, fontSize: 10.5, fontFamily: 'Segoe UI'),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 22),

                      // Nút Lưu
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton(
                          onPressed: isSaving ? null : () async {
                            setDialogState(() => isSaving = true);
                            try {
                              final morningTime = '${morningStartCtrl.text} - ${morningEndCtrl.text}';
                              final afternoonTime = '${afternoonStartCtrl.text} - ${afternoonEndCtrl.text}';
                              final resp = await http.put(
                                Uri.parse('http://127.0.0.1:8000/api/projects/${widget.projectId}/attendance-config'),
                                headers: {'Content-Type': 'application/json'},
                                body: jsonEncode({
                                  'morning_time': morningTime,
                                  'afternoon_time': afternoonTime,
                                }),
                              );
                              if (resp.statusCode == 200) {
                                final data = jsonDecode(utf8.decode(resp.bodyBytes));
                                if (data['status'] == 'success') {
                                  Navigator.pop(ctx);
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Row(
                                          children: [
                                            const Icon(Icons.check_circle_rounded, color: Colors.greenAccent, size: 18),
                                            const SizedBox(width: 10),
                                            const Text('Đã lưu cấu hình giờ điểm danh!', style: TextStyle(fontWeight: FontWeight.bold)),
                                          ],
                                        ),
                                        backgroundColor: const Color(0xFF1A2332),
                                        behavior: SnackBarBehavior.floating,
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                      ),
                                    );
                                  }
                                }
                              }
                            } catch (e) {
                              // ignore
                            } finally {
                              if (ctx.mounted) setDialogState(() => isSaving = false);
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: theme.primaryColor,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            elevation: 0,
                          ),
                          child: isSaving
                            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.save_rounded, size: 18),
                                SizedBox(width: 8),
                                Text('LƯU CẤU HÌNH', style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: 0.5, fontFamily: 'Segoe UI')),
                              ],
                            ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildCorner(int horizontal, int vertical, {double? top, double? bottom, double? left, double? right, required Color color}) {
    const size = 35.0;
    const thickness = 4.0;

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

class ScanningLine extends StatefulWidget {
  final Color color;
  const ScanningLine({super.key, required this.color});

  @override
  State<ScanningLine> createState() => _ScanningLineState();
}

class _ScanningLineState extends State<ScanningLine> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Align(
          alignment: Alignment(0, _controller.value * 2 - 1),
          child: Container(
            height: 4,
            width: double.infinity,
            decoration: BoxDecoration(
              boxShadow: [
                BoxShadow(
                  color: widget.color.withOpacity(0.8),
                  blurRadius: 12,
                  spreadRadius: 2,
                )
              ],
              gradient: LinearGradient(
                colors: [Colors.transparent, widget.color, Colors.transparent],
              ),
            ),
          ),
        );
      },
    );
  }
}
