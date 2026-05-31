import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:camera/camera.dart';
import '../theme_manager.dart';

class CameraAiView extends StatefulWidget {
  const CameraAiView({super.key});

  @override
  State<CameraAiView> createState() => _CameraAiViewState();
}

class _CameraAiViewState extends State<CameraAiView> with SingleTickerProviderStateMixin {
  CameraController? _controller;
  bool _isTracking = false;
  bool _hasError = false;
  bool _isStartingCam = false;

  Timer? _trackingTimer;
  final List<Map<String, dynamic>> _recentLogs = [];
  late AnimationController _scannerController;

  @override
  void initState() {
    super.initState();
    _scannerController = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat(reverse: true);
  }

  Future<void> _initCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isNotEmpty) {
        _controller = CameraController(cameras.first, ResolutionPreset.low, enableAudio: false);
        await _controller!.initialize();
      } else {
        setState(() => _hasError = true);
      }
    } catch (e) {
      setState(() => _hasError = true);
    }
  }

  Future<void> _toggleTracking() async {
    // Tắt Camera
    if (_isTracking) {
      _trackingTimer?.cancel();
      await _controller?.dispose();
      _controller = null;
      setState(() => _isTracking = false);
    }
    // Bật Camera
    else {
      setState(() { _isStartingCam = true; _hasError = false; });

      await _initCamera();

      setState(() => _isStartingCam = false);

      if (!_hasError && _controller != null) {
        setState(() => _isTracking = true);

        _trackingTimer = Timer.periodic(const Duration(milliseconds: 1500), (timer) {
          _captureAndSendToAI();
        });
      }
    }
  }

  Future<void> _captureAndSendToAI() async {
    if (_controller == null || !_controller!.value.isInitialized) return;

    try {
      final XFile file = await _controller!.takePicture();
      final bytes = await file.readAsBytes();
      final dataUrl = "data:image/jpeg;base64,${base64Encode(bytes)}";

      // Xóa ngay file tạm sau khi nén thành base64 để chống đầy ổ cứng
      try {
        await File(file.path).delete();
      } catch (e) {
        debugPrint("Lỗi không xóa được file tạm: $e");
      }

      var response = await http.post(
        Uri.parse('http://127.0.0.1:8000/api/attendance/recognize-face'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'image_base64': dataUrl}),
      );

      if (response.statusCode == 200) {
        var resData = jsonDecode(utf8.decode(response.bodyBytes));
        if (resData['status'] != 'no_face') {
          _addLog(resData);
        }
      }
    } catch (e) {
      debugPrint("Lỗi AI: $e");
    }
  }

  void _addLog(Map<String, dynamic> data) {
    if (!mounted) return;
    setState(() {
      _recentLogs.insert(0, {...data, "timestamp": DateTime.now()});
      if (_recentLogs.length > 4) _recentLogs.removeLast();
    });
  }

  @override
  void dispose() {
    _trackingTimer?.cancel();
    _scannerController.dispose();
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.instance;

    return Padding(
      padding: const EdgeInsets.all(40.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Giám Sát AI Real-time", style: TextStyle(color: theme.textColor, fontSize: 28 * theme.fontScale, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 8),
                  Text("Hệ thống tự động phát hiện và đối khớp khuôn mặt trên máy tính.", style: TextStyle(color: theme.subTextColor, fontSize: 13 * theme.fontScale)),
                ],
              ),
              ElevatedButton.icon(
                onPressed: _hasError || _isStartingCam ? null : _toggleTracking,
                icon: Icon(_isStartingCam ? Icons.hourglass_empty_rounded : (_isTracking ? Icons.stop_circle_rounded : Icons.play_circle_fill_rounded), color: Colors.white, size: 24),
                label: Text(
                    _isStartingCam ? "ĐANG BẬT CAMERA..." : (_isTracking ? "TẠM DỪNG AI" : "KÍCH HOẠT NHẬN DIỆN AI"),
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)
                ),
                style: ElevatedButton.styleFrom(backgroundColor: _isStartingCam ? Colors.orangeAccent : (_isTracking ? Colors.redAccent : theme.successColor), padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              )
            ],
          ),
          const SizedBox(height: 30),

          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 7,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.black, borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: _isTracking ? theme.successColor.withOpacity(0.5) : theme.borderColor, width: 2),
                      boxShadow: _isTracking ? [BoxShadow(color: theme.successColor.withOpacity(0.15), blurRadius: 30, spreadRadius: 5)] : [],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(24),
                      child: _hasError
                          ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [const Icon(Icons.videocam_off_rounded, color: Colors.redAccent, size: 50), const SizedBox(height: 15), const Text("Lỗi kết nối Camera Windows!", style: TextStyle(color: Colors.white70, fontSize: 14))]))
                          : (!_isTracking
                      // TRẠNG THÁI NGỦ (CHƯA BẬT)
                          ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.visibility_off_rounded, color: Colors.white.withOpacity(0.2), size: 60), const SizedBox(height: 15), Text(_isStartingCam ? "Đang đánh thức Webcam..." : "Camera đang tắt. Bấm Kích hoạt để bắt đầu.", style: const TextStyle(color: Colors.white54, fontSize: 13))]))
                      // TRẠNG THÁI ĐANG QUÉT
                          : Stack(
                        children: [
                          SizedBox(
                            width: double.infinity, height: double.infinity,
                            child: FittedBox(
                              fit: BoxFit.cover,
                              child: SizedBox(
                                width: _controller!.value.previewSize?.width ?? 1,
                                height: _controller!.value.previewSize?.height ?? 1,
                                child: CameraPreview(_controller!),
                              ),
                            ),
                          ),
                          if (_isTracking)
                            Positioned.fill(
                              child: AnimatedBuilder(
                                animation: _scannerController,
                                builder: (context, child) {
                                  return Align(
                                    alignment: Alignment(0, _scannerController.value * 2 - 1),
                                    child: Container(height: 4, width: double.infinity, decoration: BoxDecoration(boxShadow: [BoxShadow(color: theme.successColor.withOpacity(0.8), blurRadius: 15, spreadRadius: 3)], gradient: LinearGradient(colors: [Colors.transparent, theme.successColor, Colors.transparent]))),
                                  );
                                },
                              ),
                            ),
                          Positioned(top: 20, left: 20, child: Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), decoration: BoxDecoration(color: Colors.redAccent.withOpacity(0.8), borderRadius: BorderRadius.circular(8)), child: const Row(children: [Icon(Icons.fiber_manual_record, color: Colors.white, size: 12), SizedBox(width: 8), Text("LIVE REC", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12))]))),
                        ],
                      )),
                    ),
                  ),
                ),
                const SizedBox(width: 30),

                Expanded(
                  flex: 3,
                  child: Container(
                    padding: const EdgeInsets.all(25), decoration: BoxDecoration(color: theme.cardColor, borderRadius: BorderRadius.circular(24), border: Border.all(color: theme.borderColor)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("LỊCH SỬ QUÉT", style: TextStyle(color: theme.textColor, fontWeight: FontWeight.bold, fontSize: 14 * theme.fontScale, letterSpacing: 1.0)),
                        const SizedBox(height: 20),
                        if (_recentLogs.isEmpty)
                          Text("Chưa có dữ liệu nhận diện...", style: TextStyle(color: theme.subTextColor, fontStyle: FontStyle.italic))
                        else
                          Expanded(
                            child: ListView.builder(
                              physics: const BouncingScrollPhysics(),
                              itemCount: _recentLogs.length,
                              itemBuilder: (context, index) {
                                var log = _recentLogs[index];

                                // ĐÃ FIX: Logic màu sắc thông minh cho báo cáo Điểm danh AI
                                bool isUnknown = log['status'] == 'unknown';
                                bool isSuccess = log['attendance_status'] == 'Hợp lệ';
                                bool isFree = log['attendance_status'] == 'Trống tiết';

                                // Nếu Trống tiết -> Màu xanh dương (theme.infoColor)
                                Color cardColor = isUnknown ? theme.errorColor :
                                (isFree ? theme.infoColor :
                                (isSuccess ? theme.successColor : theme.warningColor));

                                String titleStr = isUnknown ? "KHUÔN MẶT LẠ" : "${log['attendance_status'].toUpperCase()} - ${log['confidence'].toStringAsFixed(1)}%";

                                String studentName = log['student_name'] ?? "Không xác định";
                                String studentCode = log['student_code'] ?? "";
                                String className = log['class_name'] ?? "Chưa rõ lớp";

                                return AnimatedContainer(
                                  duration: const Duration(milliseconds: 400), margin: const EdgeInsets.only(bottom: 15), padding: const EdgeInsets.all(15),
                                  decoration: BoxDecoration(color: cardColor.withOpacity(0.08), borderRadius: BorderRadius.circular(16), border: Border.all(color: cardColor.withOpacity(0.3))),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      // ĐÃ FIX: Icon linh hoạt (Cà phê = Trống tiết)
                                      Icon(isUnknown ? Icons.warning_amber_rounded : (isFree ? Icons.coffee_rounded : Icons.check_circle_rounded), color: cardColor, size: 28),
                                      const SizedBox(width: 15),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(titleStr, style: TextStyle(color: cardColor, fontWeight: FontWeight.bold, fontSize: 12)),
                                            const SizedBox(height: 6),
                                            Text(isUnknown ? "Không khớp hồ sơ trong hệ thống." : studentName, style: TextStyle(color: theme.textColor, fontWeight: FontWeight.bold, fontSize: 15)),

                                            // ĐÃ FIX: Hiển thị thêm Mã HS và Tên Lớp
                                            if (!isUnknown) ...[
                                              const SizedBox(height: 8),
                                              Row(
                                                children: [
                                                  Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3), decoration: BoxDecoration(color: theme.textColor.withOpacity(0.1), borderRadius: BorderRadius.circular(4)), child: Text(studentCode, style: TextStyle(color: theme.subTextColor, fontSize: 10, fontWeight: FontWeight.bold))),
                                                  const SizedBox(width: 8),
                                                  Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3), decoration: BoxDecoration(color: theme.purpleColor.withOpacity(0.15), borderRadius: BorderRadius.circular(4)), child: Text("Lớp $className", style: TextStyle(color: theme.purpleColor, fontSize: 10, fontWeight: FontWeight.bold))),
                                                ],
                                              )
                                            ]
                                          ],
                                        ),
                                      )
                                    ],
                                  ),
                                );
                              },
                            ),
                          )
                      ],
                    ),
                  ),
                )
              ],
            ),
          )
        ],
      ),
    );
  }
}