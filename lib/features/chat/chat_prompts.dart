/// Questions supported by the backend chatbot. Answers always come from BE.
typedef ChatPrompt = ({String label, String question});

class ChatPrompts {
  ChatPrompts._();

  static const personal = <ChatPrompt>[
    (label: 'Số dư ví', question: 'Số dư ví của tôi là bao nhiêu?'),
    (
      label: 'Cọc đang giữ',
      question: 'Tiền cọc của tôi đang được giữ bao nhiêu?'
    ),
    (label: 'Phiên của tôi', question: 'Tôi đang dẫn đầu phiên nào?'),
    (
      label: 'Đơn cần trả tiền',
      question: 'Đơn hàng của tôi cần thanh toán là những đơn nào?'
    ),
  ];

  static const topics = <ChatPrompt>[
    (label: 'Đặt cọc', question: 'Đặt cọc hoạt động thế nào?'),
    (
      label: 'Đặt giá',
      question: 'Bước giá và đặt giá tối thiểu hoạt động thế nào?'
    ),
    (
      label: 'Gia hạn phút chót',
      question: 'Phiên được gia hạn phút chót như thế nào?'
    ),
    (
      label: 'Người thắng phiên',
      question: 'Chỉ một người đấu giá thì có được thắng phiên không?'
    ),
    (label: 'Bị vượt giá', question: 'Tôi nên làm gì khi bị vượt giá?'),
    (
      label: 'Thanh toán',
      question: 'Thanh toán có những khoản phí nào và hạn bao lâu?'
    ),
    (label: 'Giao hàng', question: 'Giao hàng diễn ra như thế nào?'),
    (
      label: 'Nhận hàng, giải ngân',
      question: 'Xác nhận đã nhận hàng và giải ngân như thế nào?'
    ),
    (
      label: 'Tranh chấp',
      question: 'Tôi muốn khiếu nại đơn hàng, mở tranh chấp thế nào?'
    ),
    (label: 'Nạp tiền', question: 'Cách nạp tiền vào ví'),
    (
      label: 'Đăng tin bán hàng',
      question: 'Cách đăng tin bán sản phẩm và gửi thẩm định'
    ),
    (
      label: 'Tạm dừng, hủy phiên',
      question: 'Phiên bị tạm dừng hoặc hủy thì sao?'
    ),
  ];

  static List<ChatPrompt> forRole(String role, {bool continuing = false}) => [
        if (continuing) (label: 'Còn gì nữa?', question: 'Còn gì nữa?'),
        if (role == 'bidder') ...personal,
        if (role == 'seller') topics[10],
        ...topics.where((p) => role != 'seller' || p != topics[10]),
      ];
}
