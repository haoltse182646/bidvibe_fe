import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../store.dart';
import '../../theme.dart';
import '../../widgets/common.dart';
import '../../widgets/order_status.dart';

class _Msg {
  final String text;
  final bool fromUser;
  _Msg(this.text, {required this.fromUser});
}

/// Chatbot hỗ trợ khách hàng (Query Support Chatbot). Đây là bot giả lập
/// trả lời theo từ khoá; một số câu dùng số liệu thật trong store (số dư
/// ví, trạng thái đơn hàng) để minh hoạ khả năng tra cứu theo tài khoản.
class CustomerChatbotScreen extends StatefulWidget {
  const CustomerChatbotScreen({super.key});

  @override
  State<CustomerChatbotScreen> createState() => _CustomerChatbotScreenState();
}

class _CustomerChatbotScreenState extends State<CustomerChatbotScreen> {
  final ctrl = TextEditingController();
  final scroll = ScrollController();
  final List<_Msg> msgs = [];
  bool typing = false;

  static const suggestions = [
    'Đặt cọc hoạt động thế nào?',
    'Khi nào tôi được hoàn cọc?',
    'Đơn hàng của tôi đang ở đâu?',
    'Số dư ví của tôi',
    'Phí dịch vụ là bao nhiêu?',
    'Tôi muốn khiếu nại đơn hàng',
    'Cách ký gửi sản phẩm',
  ];

  @override
  void initState() {
    super.initState();
    msgs.add(_Msg('Xin chào! Mình là trợ lý BidVibe. Bạn cần hỗ trợ về đặt cọc, thanh toán, giao hàng hay tranh chấp? Chọn một gợi ý bên dưới hoặc nhập câu hỏi của bạn.', fromUser: false));
  }

  @override
  void dispose() {
    ctrl.dispose();
    scroll.dispose();
    super.dispose();
  }

  void _send(String text) {
    final t = text.trim();
    if (t.isEmpty || typing) return;
    setState(() {
      msgs.add(_Msg(t, fromUser: true));
      typing = true;
      ctrl.clear();
    });
    _toBottom();
    Future.delayed(const Duration(milliseconds: 700), () {
      if (!mounted) return;
      setState(() {
        msgs.add(_Msg(_answer(t.toLowerCase()), fromUser: false));
        typing = false;
      });
      _toBottom();
    });
  }

  void _toBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (scroll.hasClients) scroll.animateTo(scroll.position.maxScrollExtent + 80, duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
    });
  }

  bool _has(String q, List<String> keys) => keys.any(q.contains);

  String _answer(String q) {
    final store = context.read<AppStore>();
    if (_has(q, ['số dư', 'ví ', 'nạp'])) {
      return 'Số dư khả dụng của bạn là ${store.money(store.wallet)}, đang giữ cọc ${store.money(store.walletHeld)}. Bạn có thể nạp thêm bằng VietQR hoặc thẻ nội địa ở tab Ví.';
    }
    if (_has(q, ['hoàn cọc', 'hoàn lại cọc', 'lấy lại cọc'])) {
      return 'Cọc được hoàn tự động về ví ngay khi phiên kết thúc mà bạn không thắng. Nếu bạn thắng, cọc được trừ vào tổng tiền cần thanh toán. Nếu quá 24 giờ không thanh toán, cọc sẽ không được hoàn.';
    }
    if (_has(q, ['cọc'])) {
      return 'Để đặt giá, bạn cần đặt cọc tham gia phiên: 10% giá khởi điểm. Cọc được giữ trong ví cho tới khi phiên kết thúc. Việc bị vượt giá không làm mất cọc.';
    }
    if (_has(q, ['đơn hàng', 'đơn của', 'giao hàng', 'vận chuyển', 'ship', 'kho'])) {
      final orders = store.myOrders;
      if (orders.isNotEmpty && store.currentUser?.role == 'bidder') {
        final a = orders.first;
        final (label, _) = orderStatus(a);
        return 'Đơn gần nhất của bạn: "${a.title}" đang ở trạng thái "$label". Bạn có thể xem chi tiết hành trình trong Hồ sơ → Đơn hàng của tôi. Quy trình chung: thanh toán → người bán gửi kho → kho kiểm hàng → giao đến bạn → bạn xác nhận.';
      }
      return 'Sau khi phiên kết thúc và người mua thanh toán, người bán gửi hàng đến kho BidVibe. Kho kiểm tra đối chiếu với hồ sơ thẩm định rồi mới giao cho người mua, có mã vận đơn theo dõi.';
    }
    if (_has(q, ['phí', 'chi phí', 'bao nhiêu tiền'])) {
      return 'Người mua trả phí dịch vụ 5% giá thắng và 40.000 ₫ phí vận chuyển từ kho. Khoản cọc đã đặt được trừ vào tổng tiền.';
    }
    if (_has(q, ['thanh toán', 'trả tiền', 'hạn'])) {
      return 'Bạn có 24 giờ kể từ khi phiên kết thúc để thanh toán qua VietQR, thẻ nội địa hoặc Ví BidVibe. Tiền thanh toán được giữ ký quỹ và chỉ chuyển cho người bán sau khi bạn xác nhận nhận hàng (hoặc tự động sau 72 giờ kể từ khi giao).';
    }
    if (_has(q, ['khiếu nại', 'tranh chấp', 'hoàn tiền', 'sai mô tả', 'hàng lỗi'])) {
      return 'Nếu hàng nhận không đúng mô tả, hãy vào Hồ sơ → Đơn hàng của tôi → chọn đơn → "Báo vấn đề / Tranh chấp" trước khi xác nhận nhận hàng. Khoản ký quỹ sẽ được giữ lại cho tới khi Admin phán quyết.';
    }
    if (_has(q, ['ký gửi', 'bán hàng', 'đăng bán', 'thẩm định'])) {
      return 'Người bán tạo phiếu ký gửi (ảnh, mô tả, giá khởi điểm — có thể nhờ AI gợi ý giá). Thẩm định viên xác thực hoặc yêu cầu bổ sung ảnh/giấy tờ. Khi được duyệt, phiên sẽ công khai. Khi có người thắng và thanh toán, bạn gửi hàng đến kho.';
    }
    if (_has(q, ['gia hạn', '30 giây', 'vượt giá', 'kết thúc'])) {
      return 'Nếu có lượt đặt giá trong 30 giây cuối, phiên tự gia hạn thêm 30 giây để mọi người có cơ hội đặt lại. Bạn sẽ nhận thông báo ngay khi bị vượt giá.';
    }
    if (_has(q, ['gian lận', 'báo cáo', 'nghi vấn', 'lừa'])) {
      return 'Nếu thấy phiên đáng ngờ, chạm biểu tượng lá cờ ở góc trên màn hình chi tiết phiên để báo cáo. Hệ thống AI và Admin sẽ xem xét, có thể tạm dừng hoặc chấm dứt phiên.';
    }
    if (_has(q, ['mật khẩu', 'đăng nhập', 'tài khoản', 'otp'])) {
      return 'Bạn có thể đổi mật khẩu và bật xác thực 2 lớp ở Hồ sơ → Bảo mật. Nếu không đăng nhập được, hãy kiểm tra email/mật khẩu hoặc liên hệ nhân viên hỗ trợ.';
    }
    if (_has(q, ['nhân viên', 'người thật', 'hotline', 'liên hệ'])) {
      return 'Bạn có thể liên hệ nhân viên hỗ trợ qua hotline 1900 636 868 (8:00–21:00) hoặc email hotro@bidvibe.vn. Mình đã ghi lại cuộc trò chuyện này để chuyển cho nhân viên.';
    }
    return 'Mình chưa hiểu rõ câu hỏi này. Bạn thử hỏi về đặt cọc, thanh toán, giao hàng, phí, khiếu nại hoặc ký gửi nhé — hoặc gõ "nhân viên" để được chuyển cho người thật.';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: const Row(mainAxisSize: MainAxisSize.min, children: [
          CircleAvatar(radius: 14, backgroundColor: AppColors.accent, child: Icon(Icons.support_agent, size: 16, color: Colors.white)),
          SizedBox(width: 8),
          Text('Trợ lý hỗ trợ', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
        ]),
        centerTitle: true,
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: scroll,
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              itemCount: msgs.length + (typing ? 1 : 0),
              itemBuilder: (context, i) {
                if (i == msgs.length) return const _Bubble(text: 'Đang soạn câu trả lời…', fromUser: false, faded: true);
                return _Bubble(text: msgs[i].text, fromUser: msgs[i].fromUser);
              },
            ),
          ),
          SizedBox(
            height: 44,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: suggestions.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, i) => FilterChipButton(label: suggestions[i], selected: false, onTap: () => _send(suggestions[i])),
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: Row(
                children: [
                  Expanded(child: TextField(controller: ctrl, onSubmitted: _send, textInputAction: TextInputAction.send, decoration: appInputDecoration('Nhập câu hỏi của bạn…'))),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    onPressed: () => _send(ctrl.text),
                    style: IconButton.styleFrom(backgroundColor: AppColors.accent, minimumSize: const Size(48, 48)),
                    icon: const Icon(Icons.send, size: 20, color: Colors.white),
                    tooltip: 'Gửi',
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  final String text;
  final bool fromUser;
  final bool faded;
  const _Bubble({required this.text, required this.fromUser, this.faded = false});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: fromUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.8),
        decoration: BoxDecoration(
          color: fromUser ? AppColors.accent : Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(fromUser ? 16 : 4),
            bottomRight: Radius.circular(fromUser ? 4 : 16),
          ),
          border: fromUser ? null : Border.all(color: AppColors.border),
        ),
        child: Text(text, style: TextStyle(fontSize: 14, height: 1.45, color: fromUser ? Colors.white : (faded ? AppColors.muted : AppColors.ink), fontStyle: faded ? FontStyle.italic : FontStyle.normal)),
      ),
    );
  }
}
