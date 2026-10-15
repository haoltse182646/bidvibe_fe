import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/remote_app_store.dart';
import '../../features/chat/chat_controller.dart';
import '../../features/chat/chat_repository.dart';
import '../../store.dart';
import '../../theme.dart';
import '../../widgets/common.dart';

class CustomerChatbotScreen extends StatefulWidget {
  final ChatController? controller;
  const CustomerChatbotScreen({super.key, this.controller});
  @override
  State<CustomerChatbotScreen> createState() => _CustomerChatbotScreenState();
}

class _CustomerChatbotScreenState extends State<CustomerChatbotScreen> {
  final _text = TextEditingController(), _scroll = ScrollController();
  late final ChatController _chat;
  late final RemoteAppStore _store;
  bool _loggingOut = false;
  static const suggestions = [
    'Đặt cọc hoạt động thế nào?',
    'Khi nào tôi được hoàn cọc?',
    'Giao hàng diễn ra như thế nào?',
    'Cách nạp tiền vào ví',
    'Thanh toán có những khoản phí nào?',
    'Tôi muốn khiếu nại đơn hàng',
    'Cách đăng tin bán sản phẩm',
  ];
  @override
  void initState() {
    super.initState();
    _store = context.read<AppStore>() as RemoteAppStore;
    _chat =
        widget.controller ??
        ChatController(
          repository: ChatRepository(_store.api),
          accountId: _store.currentUser!.id,
        );
    _chat.addListener(_changed);
    unawaited(_chat.load());
  }

  @override
  void dispose() {
    _chat.removeListener(_changed);
    if (widget.controller == null) {
      _chat.dispose();
    }
    _text.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _changed() {
    if (!mounted) {
      return;
    }
    if (_chat.authCode != null && !_loggingOut) {
      _loggingOut = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }
        if (_store.currentUser?.id == _chat.accountId) {
          _store.logout();
          _store.sessionError = _chat.authCode == 'ACCOUNT_SUSPENDED'
              ? 'Tài khoản đã bị tạm khóa.'
              : 'Phiên đăng nhập đã hết hạn. Vui lòng đăng nhập lại.';
          Navigator.of(context).popUntil((route) => route.isFirst);
        }
      });
    }
    setState(() {});
    if (_chat.sending || (!_chat.loading && _chat.messages.isNotEmpty)) {
      _toBottom();
    }
  }

  void _toBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _scroll.hasClients) {
        unawaited(
          _scroll.animateTo(
            _scroll.position.maxScrollExtent,
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
          ),
        );
      }
    });
  }

  Future<void> _send(String value) async {
    if (!_chat.canSend) {
      return;
    }
    final original = value;
    FocusScope.of(context).unfocus();
    final accepted = await _chat.send(value);
    if (!mounted) {
      return;
    }
    if (accepted && _text.text.trim() == original.trim()) {
      _text.clear();
    }
    setState(() {});
  }

  Future<void> _newConversation() async {
    if (_chat.loading || _chat.sending) {
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Bắt đầu hội thoại mới?'),
        content: const Text(
          'Hội thoại hiện tại vẫn được lưu trên máy chủ. Câu hỏi tiếp theo sẽ bắt đầu một hội thoại mới.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Bắt đầu mới'),
          ),
        ],
      ),
    );
    if (!mounted || confirmed != true) {
      return;
    }
    final changed = await _chat.newConversation();
    if (mounted && changed) {
      _text.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AppStore>().currentUser;
    if (user == null || user.id != _chat.accountId) {
      return const SizedBox.shrink();
    }
    final busy = _chat.loading || _chat.sending;
    return PopScope(
      canPop: !_chat.sending,
      child: Scaffold(
        backgroundColor: AppColors.bg,
        appBar: AppBar(
          title: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircleAvatar(
                radius: 14,
                backgroundColor: AppColors.accent,
                child: Icon(Icons.support_agent, size: 16, color: Colors.white),
              ),
              SizedBox(width: 8),
              Flexible(
                child: Text(
                  'Trợ lý hỗ trợ',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          centerTitle: true,
          actions: [
            IconButton(
              tooltip: 'Tải lại lịch sử',
              onPressed: busy ? null : _chat.load,
              icon: const Icon(Icons.refresh),
            ),
            IconButton(
              tooltip: 'Hội thoại mới',
              onPressed: busy ? null : _newConversation,
              icon: const Icon(Icons.add_comment_outlined),
            ),
          ],
        ),
        body: Column(
          children: [
            if (_chat.loading) const LinearProgressIndicator(),
            if (_chat.sessionId != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: SelectableText(
                  'Hội thoại #${_chat.sessionId}',
                  style: const TextStyle(fontSize: 12, color: AppColors.muted),
                ),
              ),
            Expanded(
              child: ListView.builder(
                controller: _scroll,
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                itemCount: _chat.messages.isEmpty
                    ? 1
                    : _chat.messages.length + (_chat.sending ? 1 : 0),
                itemBuilder: (context, i) {
                  if (_chat.messages.isEmpty) {
                    return const _Bubble(
                      text: 'Xin chào! Bạn cần hỗ trợ về đặt cọc, đặt giá, thanh toán, giao hàng hay tranh chấp? Chọn gợi ý bên dưới hoặc nhập câu hỏi của bạn.',
                      fromUser: false,
                    );
                  }
                  if (i == _chat.messages.length) {
                    return const _Bubble(
                      text: 'Đang gửi câu hỏi…',
                      fromUser: false,
                      faded: true,
                    );
                  }
                  final message = _chat.messages[i];
                  return _Bubble(
                    key: ValueKey('chat.message.${message.id}'),
                    text: message.content,
                    fromUser: message.sender == 'user',
                  );
                },
              ),
            ),
            if (_chat.error != null || _chat.warning != null || _chat.uncertain)
              Container(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.sizeOf(context).height * .28,
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        _chat.error ?? _chat.warning ?? 'Hãy kiểm tra lịch sử trước khi tiếp tục. Câu hỏi không được tự động gửi lại.',
                        style: TextStyle(
                          fontSize: 12,
                          color: _chat.error != null
                              ? AppColors.dangerStrong
                              : AppColors.muted,
                        ),
                      ),
                      if (!busy && !_chat.ready && _chat.authCode == null)
                        TextButton(
                          onPressed: _chat.load,
                          child: const Text('Thử tải lại'),
                        ),
                      if (_chat.uncertain && _chat.sessionId != null && !busy)
                        TextButton(
                          onPressed: _chat.load,
                          child: const Text('Kiểm tra lịch sử'),
                        ),
                      if (_chat.uncertain && _chat.historyChecked && !busy)
                        TextButton(
                          onPressed: () {
                            _text.clear();
                            _chat.acknowledgeHistory();
                          },
                          child: const Text('Tôi đã kiểm tra, tiếp tục'),
                        ),
                    ],
                  ),
                ),
              ),
            SizedBox(
              height: 44,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: suggestions.length,
                separatorBuilder: (context, i) => const SizedBox(width: 8),
                itemBuilder: (context, i) => FilterChipButton(
                  label: suggestions[i],
                  selected: false,
                  onTap: () {
                    if (_chat.canSend) {
                      unawaited(_send(suggestions[i]));
                    }
                  },
                ),
              ),
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: TextField(
                        key: const ValueKey('chat.input'),
                        controller: _text,
                        enabled: _chat.canSend,
                        maxLength: 2000,
                        minLines: 1,
                        maxLines: 3,
                        onChanged: (value) => setState(() {}),
                        onSubmitted: _send,
                        textInputAction: TextInputAction.send,
                        decoration: appInputDecoration('Nhập câu hỏi của bạn…'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filled(
                      onPressed: _chat.canSend && _text.text.trim().isNotEmpty
                          ? () => _send(_text.text)
                          : null,
                      style: IconButton.styleFrom(
                        backgroundColor: AppColors.accent,
                        minimumSize: const Size(48, 48),
                      ),
                      icon: _chat.sending
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(
                              Icons.send,
                              size: 20,
                              color: Colors.white,
                            ),
                      tooltip: 'Gửi',
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  final String text;
  final bool fromUser, faded;
  const _Bubble({
    super.key,
    required this.text,
    required this.fromUser,
    this.faded = false,
  });
  @override
  Widget build(BuildContext context) => Align(
    alignment: fromUser ? Alignment.centerRight : Alignment.centerLeft,
    child: Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      constraints: BoxConstraints(
        maxWidth: MediaQuery.sizeOf(context).width * .8,
      ),
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
      child: SelectableText(
        text,
        style: TextStyle(
          fontSize: 14,
          height: 1.45,
          color: fromUser
              ? Colors.white
              : (faded ? AppColors.muted : AppColors.ink),
          fontStyle: faded ? FontStyle.italic : FontStyle.normal,
        ),
      ),
    ),
  );
}
