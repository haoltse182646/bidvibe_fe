import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../features/auctions/auction_live_controller.dart';

class AuctionBidPanel extends StatefulWidget {
  final AuctionLiveController controller;
  const AuctionBidPanel({super.key, required this.controller});
  @override
  State<AuctionBidPanel> createState() => _AuctionBidPanelState();
}

class _AuctionBidPanelState extends State<AuctionBidPanel> {
  final _amount = TextEditingController();
  final _form = GlobalKey<FormState>();
  bool _confirming = false;
  String _money(num amount) =>
      '${NumberFormat.decimalPattern('vi_VN').format(amount)} đ';

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final c = widget.controller;
    if (_confirming || !c.canBid || !_form.currentState!.validate()) {
      return;
    }
    final amount = int.parse(_amount.text.trim());
    setState(() => _confirming = true);
    try {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Xác nhận đặt giá'),
          content: Text('Gửi mức giá ${_money(amount)} cho phiên này?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Hủy'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Xác nhận đặt giá'),
            ),
          ],
        ),
      );
      if (!mounted || confirmed != true) {
        return;
      }
      final success = await c.bid(amount);
      if (mounted && success) {
        _amount.clear();
      }
    } finally {
      if (mounted) {
        setState(() => _confirming = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    final a = c.data!;
    final minimum = (a['minNextBid'] as num?)?.toInt() ?? 0;
    final disabled = !c.canBid || _confirming;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Đặt giá', style: Theme.of(context).textTheme.titleLarge),
            if (a['joined'] != true)
              const Text('Bạn cần đặt cọc trước khi đặt giá.')
            else if (a['leading'] == true)
              const Text('Bạn đang dẫn đầu, không cần tự vượt giá mình.'),
            if (c.events != null && !c.connected)
              const Text(
                'Đang chờ kết nối thời gian thực. Nút đặt giá tạm khóa.',
              ),
            if (c.notice != null) Text(c.notice!),
            if (c.posting) const LinearProgressIndicator(),
            Text('Giá tối thiểu tiếp theo: ${_money(minimum)}'),
            const SizedBox(height: 12),
            Form(
              key: _form,
              child: TextFormField(
                controller: _amount,
                enabled: !disabled,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Giá muốn đặt (VND)',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  final raw = value?.trim() ?? '';
                  final amount = int.tryParse(raw);
                  if (!RegExp(r'^[0-9]+$').hasMatch(raw) ||
                      amount == null ||
                      amount <= 0) {
                    return 'Nhập số nguyên dương, không có dấu phân cách.';
                  }
                  if (amount < minimum) {
                    return 'Tối thiểu ${_money(minimum)}';
                  }
                  return null;
                },
              ),
            ),
            TextButton(
              onPressed: disabled ? null : () => _amount.text = '$minimum',
              child: const Text('Dùng giá tối thiểu'),
            ),
            FilledButton(
              onPressed: disabled ? null : _submit,
              child: const Text('Đặt giá'),
            ),
            if (c.uncertainBid)
              TextButton(
                onPressed: c.loading || c.posting
                    ? null
                    : () => c.refresh(verifyBid: true),
                child: const Text('Kiểm tra kết quả lượt giá'),
              ),
          ],
        ),
      ),
    );
  }
}
