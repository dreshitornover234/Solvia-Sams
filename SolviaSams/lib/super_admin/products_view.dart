import 'package:flutter/material.dart';
import '../theme_manager.dart';

// =========================================================
// MÔ HÌNH DỮ LIỆU: CÁC GÓI SẢN PHẨM VÀ TÙY CHỌN
// =========================================================
class PackageTier {
  final String name;
  final String serverSpecs;
  final int maxStudents;
  final int maxCameras;
  final int includedCameras;
  final String storage;
  final int price;

  PackageTier({
    required this.name, required this.serverSpecs, required this.maxStudents,
    required this.maxCameras, required this.includedCameras, required this.storage, required this.price,
  });
}

class SystemPackage {
  final String title;
  final String subtitle;
  final String target;
  final List<String> features;
  final int monthlyFee; // Phí duy trì hằng tháng
  final List<PackageTier> tiers;

  SystemPackage({
    required this.title, required this.subtitle, required this.target,
    required this.features, required this.monthlyFee, required this.tiers,
  });
}

class ProductsView extends StatefulWidget {
  const ProductsView({super.key});

  @override
  State<ProductsView> createState() => _ProductsViewState();
}

class _ProductsViewState extends State<ProductsView> {
  // Trạng thái Option đang chọn của Gói Basic và Pro
  int _selectedBasicOption = 0;
  int _selectedProOption = 0;

  // Số lượng Camera MUA THÊM (Chưa tính cam đi kèm)
  int _extraBasicCams = 0;
  int _extraProCams = 0;

  // Trạng thái cho Gói Custom
  String _customServer = 'SAMS Server Core (Tối đa 16 Cam)';
  String _customStorage = '500 GB';
  double _customCameraCount = 0;

  // DỮ LIỆU GÓI 1: CƠ BẢN (BASIC)
  final SystemPackage basicPackage = SystemPackage(
      title: "SAMS Basic",
      subtitle: "Gói Nội Bộ (Local)",
      target: "Trường mầm non, cấp 1, cơ sở nhỏ.",
      monthlyFee: 500000, // Phí duy trì: 500k/tháng
      features: [
        "Xử lý nhận diện AI tại chỗ (Local Server).",
        "Ghi nhận điểm danh 1 khuôn mặt / khung hình.",
        "Báo cáo tự động qua Excel hằng ngày.",
        "Hỗ trợ kỹ thuật giờ hành chính.",
        "Linh hoạt kết nối với Camera IP sẵn có của trường."
      ],
      tiers: [
        PackageTier(name: "SAMS Local Mini", serverSpecs: "Server Mini-ITX Lõi kép", maxStudents: 300, maxCameras: 6, includedCameras: 2, storage: "500GB SSD", price: 6500000),
        PackageTier(name: "SAMS Local Standard", serverSpecs: "Server Intel i5, 8GB RAM", maxStudents: 800, maxCameras: 12, includedCameras: 4, storage: "1TB HDD", price: 14000000),
        PackageTier(name: "SAMS Local Plus", serverSpecs: "Server Intel i7, 16GB RAM", maxStudents: 1500, maxCameras: 24, includedCameras: 8, storage: "2TB HDD", price: 28000000),
      ]
  );

  // DỮ LIỆU GÓI 2: CHUYÊN NGHIỆP (PRO)
  final SystemPackage proPackage = SystemPackage(
      title: "SAMS Professional",
      subtitle: "Gói Đám Mây (Cloud AI)",
      target: "Trường cấp 2, 3, Hệ thống trung tâm giáo dục lớn.",
      monthlyFee: 1500000, // Phí duy trì: 1tr5/tháng
      features: [
        "Xử lý AI Đám mây (Cloud) siêu tốc độ.",
        "Nhận diện đa luồng (Đám đông 10-15 người cùng lúc).",
        "Kháng giả mạo 3D (Anti-Spoofing) tuyệt đối.",
        "App điện thoại & SMS gửi trực tiếp cho Phụ huynh.",
        "Hỗ trợ kỹ thuật ưu tiên 24/7."
      ],
      tiers: [
        PackageTier(name: "SAMS Cloud Start", serverSpecs: "Cloud Node Tier 1", maxStudents: 3000, maxCameras: 32, includedCameras: 8, storage: "2TB Cloud", price: 45000000),
        PackageTier(name: "SAMS Cloud Ultra", serverSpecs: "Cloud Node Tier 2", maxStudents: 6000, maxCameras: 64, includedCameras: 16, storage: "5TB Cloud", price: 85000000),
        PackageTier(name: "SAMS Cloud Enterprise", serverSpecs: "Dedicated Cloud Server", maxStudents: 15000, maxCameras: 128, includedCameras: 32, storage: "10TB Cloud", price: 150000000),
      ]
  );

  // Thông số mảng Custom
  final Map<String, int> _serverPrices = {'SAMS Server Core (Tối đa 16 Cam)': 12000000, 'SAMS Server Plus (Tối đa 64 Cam)': 35000000, 'SAMS Server Ultra (Tối đa 256 Cam)': 90000000};
  final Map<String, int> _serverMaxCams = {'SAMS Server Core (Tối đa 16 Cam)': 16, 'SAMS Server Plus (Tối đa 64 Cam)': 64, 'SAMS Server Ultra (Tối đa 256 Cam)': 256};
  final Map<String, int> _storagePrices = {'500 GB': 1500000, '1 TB': 3000000, '2 TB': 5500000, '5 TB': 12000000, '10 TB Cloud': 25000000};

  @override
  void initState() {
    super.initState();
    _customServer = _serverPrices.keys.first;
    _customStorage = _storagePrices.keys.first;
  }

  // Thuật toán format Tiền VNĐ
  String _formatCurrency(int amount) {
    String res = ""; String numStr = amount.toString(); int count = 0;
    for (int i = numStr.length - 1; i >= 0; i--) {
      res = numStr[i] + res; count++;
      if (count == 3 && i > 0) { res = ".$res"; count = 0; }
    }
    return "$res đ";
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
        animation: AppTheme.instance,
        builder: (context, child) {
          final theme = AppTheme.instance;

          // Tính toán gói Custom
          int customServerPrice = _serverPrices[_customServer]!;
          int customStoragePrice = _storagePrices[_customStorage]!;
          int customCameraPrice = (_customCameraCount.toInt() * 1500000);
          int totalCustomPrice = customServerPrice + customStoragePrice + customCameraPrice;
          int maxCamForCurrentServer = _serverMaxCams[_customServer]!;

          return SingleChildScrollView(
            key: const ValueKey('ProductsView'),
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 40.0, vertical: 40.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildAnimatedEntry(0, Column(crossAxisAlignment: CrossAxisAlignment.start, children: [AnimatedDefaultTextStyle(duration: const Duration(milliseconds: 300), style: TextStyle(fontSize: 32 * theme.fontScale, fontWeight: FontWeight.w900, color: theme.textColor, letterSpacing: -0.5, fontFamily: 'Segoe UI'), child: const Text("Giải pháp & Báo giá")), const SizedBox(height: 10), AnimatedDefaultTextStyle(duration: const Duration(milliseconds: 300), style: TextStyle(fontSize: 15 * theme.fontScale, color: theme.subTextColor, fontFamily: 'Segoe UI'), child: const Text("Lựa chọn cấu trúc máy chủ và thiết bị phần cứng để tự động hóa hoàn toàn quy trình quản lý của bạn. Mọi camera đi kèm đều được tích hợp sẵn vi xử lý SAMS Engine."))] )),
                const SizedBox(height: 50),

                _buildAnimatedEntry(1, _buildSectionHeader(Icons.inventory_2_rounded, "CÁC GÓI TRIỂN KHAI ĐỒNG BỘ", theme)),
                const SizedBox(height: 25),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: _buildAnimatedEntry(2, _buildPackageCard(basicPackage, _selectedBasicOption, _extraBasicCams, (val) => setState((){ _selectedBasicOption = val; _extraBasicCams = 0; }), (cams) => setState(() => _extraBasicCams = cams), theme, isPopular: false))),
                    const SizedBox(width: 30),
                    Expanded(child: _buildAnimatedEntry(3, _buildPackageCard(proPackage, _selectedProOption, _extraProCams, (val) => setState((){ _selectedProOption = val; _extraProCams = 0; }), (cams) => setState(() => _extraProCams = cams), theme, isPopular: true))),
                  ],
                ),
                const SizedBox(height: 60),
                _buildAnimatedEntry(4, Divider(color: theme.borderColor, thickness: 1)),
                const SizedBox(height: 40),

                // GÓI TỰ LẮP RÁP (CUSTOM)
                _buildAnimatedEntry(5, _buildSectionHeader(Icons.tune_rounded, "TỰ LẮP RÁP CẤU HÌNH (SAMS CUSTOM)", theme)),
                const SizedBox(height: 25),
                _buildAnimatedEntry(
                  6,
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 400), padding: const EdgeInsets.all(40),
                    decoration: BoxDecoration(color: theme.cardColor, borderRadius: BorderRadius.circular(24), border: Border.all(color: theme.borderColor), boxShadow: theme.isDarkMode ? [] : [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 20, offset: const Offset(0, 10))]),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 6,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text("Dành cho các cơ sở muốn tận dụng lại cơ sở hạ tầng cũ, hoặc có nhu cầu quy mô vượt mức tiêu chuẩn. Hệ thống linh hoạt theo ngân sách.", style: TextStyle(color: theme.subTextColor, fontSize: 13 * theme.fontScale, height: 1.5)),
                              const SizedBox(height: 30),
                              Row(
                                children: [
                                  Expanded(child: _buildDropdown("1. Nền tảng Server xử lý AI", _customServer, _serverPrices.keys.toList(), (val) {
                                    setState(() { _customServer = val!; if (_customCameraCount > _serverMaxCams[_customServer]!) { _customCameraCount = _serverMaxCams[_customServer]!.toDouble(); } });
                                  }, theme)),
                                  const SizedBox(width: 20),
                                  Expanded(child: _buildDropdown("2. Không gian lưu trữ dữ liệu", _customStorage, _storagePrices.keys.toList(), (val) => setState(() => _customStorage = val!), theme)),
                                ],
                              ),
                              const SizedBox(height: 40),
                              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text("3. Số lượng Camera SAMS đi kèm (1.500.000đ/Cam)", style: TextStyle(color: theme.textColor, fontWeight: FontWeight.bold, fontSize: 13 * theme.fontScale)), Text("${_customCameraCount.toInt()} / $maxCamForCurrentServer", style: TextStyle(color: theme.primaryColor, fontWeight: FontWeight.bold, fontSize: 16 * theme.fontScale))]),
                              const SizedBox(height: 10),
                              SliderTheme(
                                data: SliderThemeData(activeTrackColor: theme.primaryColor, inactiveTrackColor: theme.textColor.withOpacity(0.1), thumbColor: theme.primaryColor, overlayColor: theme.primaryColor.withOpacity(0.2), trackHeight: 6.0),
                                child: Slider(value: _customCameraCount, min: 0, max: maxCamForCurrentServer.toDouble(), divisions: maxCamForCurrentServer > 0 ? maxCamForCurrentServer : 1, onChanged: (val) => setState(() => _customCameraCount = val)),
                              ),
                              Text("Bạn vẫn có thể kết nối tối đa $maxCamForCurrentServer Camera IP sẵn có của trường vào hệ thống SAMS.", style: TextStyle(color: theme.subTextColor, fontStyle: FontStyle.italic, fontSize: 11 * theme.fontScale)),
                            ],
                          ),
                        ),
                        const SizedBox(width: 40),

                        Expanded(
                          flex: 4,
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 300), padding: const EdgeInsets.all(30),
                            decoration: BoxDecoration(color: theme.primaryColor.withOpacity(0.05), borderRadius: BorderRadius.circular(20), border: Border.all(color: theme.primaryColor.withOpacity(0.3))),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text("BẢNG TÍNH CHI PHÍ CƠ SỞ", style: TextStyle(color: theme.primaryColor, fontWeight: FontWeight.bold, fontSize: 12 * theme.fontScale, letterSpacing: 1.2)), const SizedBox(height: 20),
                                _buildReceiptRow("Máy chủ & Phần mềm lõi", _formatCurrency(customServerPrice), theme), const SizedBox(height: 12),
                                _buildReceiptRow("Lưu trữ hệ thống", _formatCurrency(customStoragePrice), theme), const SizedBox(height: 12),
                                _buildReceiptRow("Thiết bị Camera SAMS (${_customCameraCount.toInt()} chiếc)", _formatCurrency(customCameraPrice), theme),
                                const SizedBox(height: 20), Divider(color: theme.primaryColor.withOpacity(0.2)), const SizedBox(height: 20),
                                Text("TỔNG CHI PHÍ ƯỚC TÍNH", style: TextStyle(color: theme.textColor, fontWeight: FontWeight.bold, fontSize: 12 * theme.fontScale)),
                                const SizedBox(height: 8),
                                AnimatedSwitcher(
                                  duration: const Duration(milliseconds: 300), transitionBuilder: (child, animation) => SlideTransition(position: Tween<Offset>(begin: const Offset(0, 0.5), end: Offset.zero).animate(animation), child: FadeTransition(opacity: animation, child: child)),
                                  child: Text(_formatCurrency(totalCustomPrice), key: ValueKey(totalCustomPrice), style: TextStyle(color: theme.primaryColor, fontSize: 32 * theme.fontScale, fontWeight: FontWeight.w900)),
                                ),
                                const SizedBox(height: 30),
                                SizedBox(width: double.infinity, child: ElevatedButton.icon(onPressed: () {}, icon: Icon(Icons.shopping_cart_checkout_rounded, color: Colors.white, size: 18 * theme.fontScale), label: Text("GỬI YÊU CẦU BÁO GIÁ", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13 * theme.fontScale)), style: ElevatedButton.styleFrom(backgroundColor: theme.primaryColor, padding: const EdgeInsets.symmetric(vertical: 20), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)))))
                              ],
                            ),
                          ),
                        )
                      ],
                    ),
                  ),
                )
              ],
            ),
          );
        }
    );
  }

  // =========================================================
  // WIDGET CARD HIỂN THỊ GÓI & MUA THÊM CAMERA
  // =========================================================
  Widget _buildPackageCard(SystemPackage package, int selectedOptIndex, int extraCams, Function(int) onOptChanged, Function(int) onCamsChanged, AppTheme theme, {bool isPopular = false}) {
    PackageTier activeTier = package.tiers[selectedOptIndex];
    int maxBuyableCams = activeTier.maxCameras - activeTier.includedCameras;

    // Tính tổng tiền = Tiền gói cơ bản + (Tiền mua thêm cam * 1tr5)
    int currentTotalPrice = activeTier.price + (extraCams * 1500000);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      padding: const EdgeInsets.all(40),
      decoration: BoxDecoration(
          color: isPopular ? theme.primaryColor.withOpacity(0.05) : theme.cardColor,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: isPopular ? theme.primaryColor : theme.borderColor, width: isPopular ? 2.0 : 1.0),
          boxShadow: theme.isDarkMode ? [] : [BoxShadow(color: isPopular ? theme.primaryColor.withOpacity(0.15) : Colors.black.withOpacity(0.03), blurRadius: 30, offset: const Offset(0, 15))]
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isPopular)
            Container(margin: const EdgeInsets.only(bottom: 20), padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), decoration: BoxDecoration(color: theme.primaryColor, borderRadius: BorderRadius.circular(20)), child: Text("ĐƯỢC LỰA CHỌN NHIỀU NHẤT", style: TextStyle(color: Colors.white, fontSize: 10 * theme.fontScale, fontWeight: FontWeight.bold, letterSpacing: 1.2))),

          Text(package.subtitle.toUpperCase(), style: TextStyle(color: theme.subTextColor, fontWeight: FontWeight.bold, fontSize: 12 * theme.fontScale, letterSpacing: 1.5)),
          const SizedBox(height: 8),
          Text(package.title, style: TextStyle(color: theme.textColor, fontSize: 26 * theme.fontScale, fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          Text("Phù hợp: ${package.target}", style: TextStyle(color: theme.primaryColor, fontSize: 13 * theme.fontScale, fontWeight: FontWeight.w600)),
          const SizedBox(height: 25),

          // Giá tiền có hiệu ứng Rolling
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 400),
            transitionBuilder: (child, animation) => SlideTransition(position: Tween<Offset>(begin: const Offset(0, -0.3), end: Offset.zero).animate(animation), child: FadeTransition(opacity: animation, child: child)),
            child: Text(_formatCurrency(currentTotalPrice), key: ValueKey(currentTotalPrice), style: TextStyle(color: theme.textColor, fontSize: 36 * theme.fontScale, fontWeight: FontWeight.w900)),
          ),
          Text("Phí duy trì HT & Bảo hành: ${_formatCurrency(package.monthlyFee)}/tháng", style: TextStyle(color: Colors.orangeAccent, fontSize: 12 * theme.fontScale, fontStyle: FontStyle.italic)),
          const SizedBox(height: 30),

          // Nút chọn các Tier (Option)
          Text("Chọn cấu hình máy chủ:", style: TextStyle(color: theme.textColor, fontWeight: FontWeight.bold, fontSize: 12 * theme.fontScale)),
          const SizedBox(height: 10),
          Column(
            children: package.tiers.asMap().entries.map((entry) {
              int idx = entry.key; PackageTier tier = entry.value; bool isSelected = selectedOptIndex == idx;
              return GestureDetector(
                onTap: () => onOptChanged(idx),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300), margin: const EdgeInsets.only(bottom: 10), padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
                  decoration: BoxDecoration(color: isSelected ? theme.primaryColor.withOpacity(0.1) : theme.textColor.withOpacity(0.02), borderRadius: BorderRadius.circular(12), border: Border.all(color: isSelected ? theme.primaryColor : theme.borderColor)),
                  child: Row(children: [
                    Icon(isSelected ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded, color: isSelected ? theme.primaryColor : theme.subTextColor, size: 18 * theme.fontScale),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(tier.name, style: TextStyle(color: isSelected ? theme.primaryColor : theme.textColor, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal, fontSize: 13 * theme.fontScale)),
                          const SizedBox(height: 4),
                          Text("Tối đa ${tier.maxStudents} HS | Kèm ${tier.includedCameras} Cam | Max ${tier.maxCameras} Cam", style: TextStyle(color: theme.subTextColor, fontSize: 11 * theme.fontScale)),
                        ],
                      ),
                    )
                  ]),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 25),

          // Tùy chọn MUA THÊM CAMERA
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(color: theme.textColor.withOpacity(0.02), borderRadius: BorderRadius.circular(12), border: Border.all(color: theme.borderColor, style: BorderStyle.solid)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text("Mua thêm Camera SAMS", style: TextStyle(color: theme.textColor, fontWeight: FontWeight.bold, fontSize: 12 * theme.fontScale)),
                    Text("${activeTier.includedCameras + extraCams} / ${activeTier.maxCameras} Cam", style: TextStyle(color: theme.primaryColor, fontWeight: FontWeight.bold, fontSize: 12 * theme.fontScale)),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    IconButton(onPressed: extraCams > 0 ? () => onCamsChanged(extraCams - 1) : null, icon: Icon(Icons.remove_circle_outline_rounded, color: extraCams > 0 ? theme.primaryColor : theme.subTextColor)),
                    Expanded(
                      child: SliderTheme(
                        data: SliderThemeData(activeTrackColor: theme.primaryColor, inactiveTrackColor: theme.textColor.withOpacity(0.1), thumbColor: theme.primaryColor, trackHeight: 4.0),
                        child: Slider(value: extraCams.toDouble(), min: 0, max: maxBuyableCams.toDouble(), divisions: maxBuyableCams > 0 ? maxBuyableCams : 1, onChanged: (val) => onCamsChanged(val.toInt())),
                      ),
                    ),
                    IconButton(onPressed: extraCams < maxBuyableCams ? () => onCamsChanged(extraCams + 1) : null, icon: Icon(Icons.add_circle_outline_rounded, color: extraCams < maxBuyableCams ? theme.primaryColor : theme.subTextColor)),
                  ],
                ),
                Center(child: Text("+ ${_formatCurrency(extraCams * 1500000)} (1tr5 / chiếc)", style: TextStyle(color: theme.subTextColor, fontStyle: FontStyle.italic, fontSize: 11 * theme.fontScale))),
              ],
            ),
          ),
          const SizedBox(height: 25),

          ...package.features.map((f) => Padding(padding: const EdgeInsets.only(bottom: 12), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Icon(Icons.check_circle_rounded, color: theme.primaryColor, size: 18 * theme.fontScale), const SizedBox(width: 10), Expanded(child: Text(f, style: TextStyle(color: theme.textColor, fontSize: 13 * theme.fontScale, height: 1.4)))],))),
          const SizedBox(height: 30),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => _showCheckoutDialog(package, activeTier, extraCams, currentTotalPrice, theme),
              style: ElevatedButton.styleFrom(backgroundColor: isPopular ? theme.primaryColor : theme.textColor.withOpacity(0.05), foregroundColor: isPopular ? Colors.white : theme.textColor, elevation: 0, padding: const EdgeInsets.symmetric(vertical: 20), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              child: Text("ĐĂNG KÝ GÓI NÀY", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13 * theme.fontScale)),
            ),
          )
        ],
      ),
    );
  }

  // =========================================================
  // BẢNG THANH TOÁN (CHECKOUT MODAL) ĐÃ FIX LỖI TRÀN MÀN HÌNH
  // =========================================================
  void _showCheckoutDialog(SystemPackage package, PackageTier tier, int extraCams, int totalHardwarePrice, AppTheme theme) {
    String paymentMethod = 'Trực tiếp';
    double installmentPercent = 0.5;

    showDialog(
        context: context,
        builder: (context) {
          return StatefulBuilder(
              builder: (context, setStateDialog) {

                // Tính toán tiền
                int totalFirstMonth = totalHardwarePrice + package.monthlyFee;
                int upfrontPayment = paymentMethod == 'Trực tiếp' ? totalFirstMonth : (totalHardwarePrice * installmentPercent).toInt() + package.monthlyFee;
                int remainingPayment = paymentMethod == 'Trực tiếp' ? 0 : totalHardwarePrice - (totalHardwarePrice * installmentPercent).toInt();

                return Dialog(
                  backgroundColor: theme.cardColor,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24), side: BorderSide(color: theme.borderColor)),
                  child: Container(
                    width: 650, // Nới rộng thêm xíu cho thoải mái
                    // FIX LỖI 1: Bọc BoxConstraints giới hạn chiều cao tối đa bằng 90% màn hình
                    constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.9),

                    // FIX LỖI 2: Bao bọc bằng SingleChildScrollView để cho phép cuộn nội dung khi bảng quá dài
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.all(35),
                      child: Column(
                        mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Expanded(child: Text("Hóa Đơn Đăng Ký Dịch Vụ", style: TextStyle(color: theme.textColor, fontSize: 22 * theme.fontScale, fontWeight: FontWeight.w900))), IconButton(onPressed: () => Navigator.pop(context), icon: Icon(Icons.close_rounded, color: theme.subTextColor))]),
                          const SizedBox(height: 25),

                          // CHI TIẾT HÓA ĐƠN
                          Container(
                            padding: const EdgeInsets.all(25), decoration: BoxDecoration(color: theme.textColor.withOpacity(0.02), borderRadius: BorderRadius.circular(16), border: Border.all(color: theme.borderColor)),
                            child: Column(
                              children: [
                                _buildReceiptRow("Gói phần mềm: ${tier.name}", _formatCurrency(tier.price), theme, isBold: true), const SizedBox(height: 12),
                                _buildReceiptRow("Cấu hình: ${tier.serverSpecs} | ${tier.storage}", "", theme), const SizedBox(height: 12),
                                _buildReceiptRow("Số lượng Camera đi kèm", "${tier.includedCameras} chiếc", theme), const SizedBox(height: 12),
                                if (extraCams > 0) ...[
                                  _buildReceiptRow("Mua thêm Camera ($extraCams chiếc)", _formatCurrency(extraCams * 1500000), theme), const SizedBox(height: 12),
                                ],
                                _buildReceiptRow("Phí duy trì HT (Tháng đầu)", _formatCurrency(package.monthlyFee), theme),
                                const SizedBox(height: 20), Divider(color: theme.borderColor), const SizedBox(height: 20),
                                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text("TỔNG GIÁ TRỊ HỢP ĐỒNG", style: TextStyle(color: theme.textColor, fontWeight: FontWeight.bold, fontSize: 14 * theme.fontScale)), Text(_formatCurrency(totalFirstMonth), style: TextStyle(color: theme.primaryColor, fontWeight: FontWeight.w900, fontSize: 20 * theme.fontScale))]),
                              ],
                            ),
                          ),
                          const SizedBox(height: 30),

                          // LỰA CHỌN THANH TOÁN
                          Text("Phương thức thanh toán:", style: TextStyle(color: theme.textColor, fontWeight: FontWeight.bold, fontSize: 13 * theme.fontScale)),
                          const SizedBox(height: 15),
                          Row(
                            children: [
                              Expanded(child: _buildPaymentOption("Trả thẳng 100%", 'Trực tiếp', paymentMethod, (v) => setStateDialog(() => paymentMethod = v), theme)),
                              const SizedBox(width: 15),
                              Expanded(child: _buildPaymentOption("Trả góp linh hoạt", 'Trả góp', paymentMethod, (v) => setStateDialog(() => paymentMethod = v), theme)),
                            ],
                          ),

                          // LOGIC TRẢ GÓP MỞ RỘNG
                          AnimatedSize(
                            duration: const Duration(milliseconds: 300),
                            child: paymentMethod == 'Trả góp' ? Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 25),
                                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text("Chọn mức trả trước phần cứng:", style: TextStyle(color: theme.subTextColor, fontSize: 12 * theme.fontScale)), Text("${(installmentPercent * 100).toInt()}%", style: TextStyle(color: theme.primaryColor, fontWeight: FontWeight.bold, fontSize: 14 * theme.fontScale))]),
                                SliderTheme(
                                  data: SliderThemeData(activeTrackColor: theme.primaryColor, inactiveTrackColor: theme.textColor.withOpacity(0.1), thumbColor: theme.primaryColor, trackHeight: 4.0),
                                  child: Slider(value: installmentPercent, min: 0.3, max: 0.7, divisions: 4, onChanged: (val) => setStateDialog(() => installmentPercent = val)),
                                ),
                                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text("30%", style: TextStyle(color: theme.subTextColor, fontSize: 11 * theme.fontScale)), Text("50%", style: TextStyle(color: theme.subTextColor, fontSize: 11 * theme.fontScale)), Text("70%", style: TextStyle(color: theme.subTextColor, fontSize: 11 * theme.fontScale))])
                              ],
                            ) : const SizedBox.shrink(),
                          ),
                          const SizedBox(height: 30),

                          // CHỐT SỐ TIỀN THANH TOÁN (FIX LỖI TRÀN CHIỀU NGANG KHI SỐ TIỀN QUÁ TO)
                          Container(
                            padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: theme.primaryColor.withOpacity(0.1), borderRadius: BorderRadius.circular(16)),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text("CẦN THANH TOÁN HÔM NAY", style: TextStyle(color: theme.primaryColor, fontWeight: FontWeight.bold, fontSize: 12 * theme.fontScale)),
                                      const SizedBox(height: 8),
                                      // FIX: Bọc FittedBox để thu nhỏ chữ nếu con số (150 triệu) quá dài
                                      FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: AnimatedSwitcher(duration: const Duration(milliseconds: 300), child: Text(_formatCurrency(upfrontPayment), key: ValueKey(upfrontPayment), style: TextStyle(color: theme.primaryColor, fontSize: 24 * theme.fontScale, fontWeight: FontWeight.w900)))),
                                    ],
                                  ),
                                ),
                                if (paymentMethod == 'Trả góp') ...[
                                  const SizedBox(width: 15),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        Text("CÒN LẠI TRẢ GÓP", style: TextStyle(color: Colors.orangeAccent, fontWeight: FontWeight.bold, fontSize: 12 * theme.fontScale)),
                                        const SizedBox(height: 8),
                                        // FIX: Bọc FittedBox để thu nhỏ chữ
                                        FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerRight, child: AnimatedSwitcher(duration: const Duration(milliseconds: 300), child: Text(_formatCurrency(remainingPayment), key: ValueKey(remainingPayment), style: TextStyle(color: Colors.orangeAccent, fontSize: 18 * theme.fontScale, fontWeight: FontWeight.w900)))),
                                      ],
                                    ),
                                  ),
                                ]
                              ],
                            ),
                          ),
                          const SizedBox(height: 30),

                          SizedBox(width: double.infinity, child: ElevatedButton.icon(onPressed: () { Navigator.pop(context); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Đã gửi yêu cầu đăng ký lên hệ thống!"), backgroundColor: Colors.green)); }, icon: Icon(Icons.check_circle_rounded, color: Colors.white, size: 18 * theme.fontScale), label: Text("XÁC NHẬN ĐĂNG KÝ", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13 * theme.fontScale)), style: ElevatedButton.styleFrom(backgroundColor: Colors.green, padding: const EdgeInsets.symmetric(vertical: 20), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)))))
                        ],
                      ),
                    ),
                  ),
                );
              }
          );
        }
    );
  }

  // --- CÁC HÀM UI BỔ TRỢ ---
  Widget _buildAnimatedEntry(int index, Widget child) { return TweenAnimationBuilder<double>(tween: Tween(begin: 0.0, end: 1.0), duration: const Duration(milliseconds: 600), curve: Curves.easeOutCubic, builder: (context, value, childWidget) { return Transform.translate(offset: Offset(0, 50 * (1 - value)), child: Opacity(opacity: value, child: childWidget)); }, child: child); }
  Widget _buildSectionHeader(IconData icon, String title, AppTheme theme) { return Row(children: [AnimatedContainer(duration: const Duration(milliseconds: 300), child: Icon(icon, color: theme.primaryColor, size: 24 * theme.fontScale)), const SizedBox(width: 12), AnimatedDefaultTextStyle(duration: const Duration(milliseconds: 300), style: TextStyle(color: theme.textColor, fontSize: 18 * theme.fontScale, fontWeight: FontWeight.bold, letterSpacing: 1.0, fontFamily: 'Segoe UI'), child: Text(title))]); }
  Widget _buildDropdown(String label, String value, List<String> items, Function(String?) onChanged, AppTheme theme) { return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(label, style: TextStyle(color: theme.textColor, fontWeight: FontWeight.bold, fontSize: 13 * theme.fontScale)), const SizedBox(height: 10), SizedBox(height: 48, child: DropdownButtonFormField<String>(value: value, dropdownColor: theme.cardColor, style: TextStyle(color: theme.textColor, fontSize: 14 * theme.fontScale), icon: Icon(Icons.expand_more_rounded, color: theme.subTextColor), decoration: InputDecoration(contentPadding: const EdgeInsets.symmetric(horizontal: 15), filled: true, fillColor: theme.textColor.withOpacity(0.03), enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: theme.borderColor)), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: theme.primaryColor, width: 2.0))), items: items.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(), onChanged: onChanged))]); }
  Widget _buildReceiptRow(String title, String price, AppTheme theme, {bool isBold = false}) { return Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Expanded(child: Text(title, style: TextStyle(color: isBold ? theme.textColor : theme.subTextColor, fontSize: 13 * theme.fontScale, fontWeight: isBold ? FontWeight.bold : FontWeight.normal))), Text(price, style: TextStyle(color: theme.textColor, fontWeight: isBold ? FontWeight.bold : FontWeight.w600, fontSize: 14 * theme.fontScale))]); }

  Widget _buildPaymentOption(String title, String value, String groupValue, Function(String) onTap, AppTheme theme) {
    bool isSelected = value == groupValue;
    return GestureDetector(
      onTap: () => onTap(value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300), padding: const EdgeInsets.symmetric(vertical: 15),
        decoration: BoxDecoration(color: isSelected ? theme.primaryColor.withOpacity(0.1) : Colors.transparent, borderRadius: BorderRadius.circular(12), border: Border.all(color: isSelected ? theme.primaryColor : theme.borderColor, width: isSelected ? 2 : 1)),
        child: Center(child: Text(title, style: TextStyle(color: isSelected ? theme.primaryColor : theme.subTextColor, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal, fontSize: 13 * theme.fontScale))),
      ),
    );
  }
}