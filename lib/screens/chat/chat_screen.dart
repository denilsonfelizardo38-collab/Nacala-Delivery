import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../models/models.dart';
import '../../state/app_scope.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';
import '../../widgets/jb.dart';

/// Ecrã de conversa: bolhas de mensagem, envio de texto, anexos (imagem/local)
/// e indicador "a digitar...". Acedido através da rota nomeada `/chat` com
/// argumentos `{id, order_id, other_user_id, other_user_name, other_role}`.
class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _controller = TextEditingController();
  final _focus = FocusNode();
  final ScrollController _scroll = ScrollController();
  Timer? _typingTimer;
  bool _sending = false;
  bool _typingRemote = false;
  List<Message> _messages = [];
  Conversation? _conversation;
  String? _error;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    _typingTimer?.cancel();
    _controller.dispose();
    _focus.dispose();
    _scroll.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is Map && _conversation == null) {
      _conversation = Conversation(
        id: args['id'] as String? ?? '',
        customerId: args['customer_id'] as String?,
        partnerId: args['partner_id'] as String?,
        courierId: args['courier_id'] as String?,
        status: args['status'] as String? ?? 'active',
        createdAt: _date(args['created_at']),
        orderId: args['order_id'] as String?,
        lastBody: args['last_body'] as String?,
        lastSenderId: args['last_sender_id'] as String?,
        unreadCount: args['unread_count'] as int? ?? 0,
        otherUserId: args['other_user_id'] as String?,
        otherUserName: args['other_user_name'] as String?,
      );
      _load();
    }
  }

  void _onTextChanged() {
    // Sinaliza "a digitar..." ao outro participante (simples, sem WebSocket
    // por enquanto: o indicador local é redefinido após pausa).
    _typingTimer?.cancel();
    if (_controller.text.isNotEmpty) {
      setState(() => _typingRemote = false);
      _typingTimer = Timer(const Duration(seconds: 3), () {
        if (mounted) setState(() => _typingRemote = false);
      });
    }
  }

  Future<void> _load() async {
    if (_conversation == null) return;
    setState(() => _error = null);
    try {
      final messages = await AppScope.of(context).api.messages(_conversation!.id);
      if (!mounted) return;
      setState(() => _messages = messages);
      await AppScope.of(context).api.markMessagesRead(_conversation!.id);
      _scrollToBottom();
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() => _error = error.message);
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _conversation == null || _sending) return;
    _controller.clear();
    setState(() => _sending = true);
    try {
      final message = await AppScope.of(context).api.sendMessage(
        conversationId: _conversation!.id,
        body: text,
        type: 'text',
      );
      if (!mounted) return;
      setState(() {
        _messages = [..._messages, message];
        _sending = false;
      });
      _scrollToBottom();
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _sending = false;
        _error = error.message;
      });
    }
  }

  Widget _buildBubble(Message message, bool isMine) {
    final align = isMine
        ? CrossAxisAlignment.end
        : CrossAxisAlignment.start;
    final color = isMine ? AppColors.primary : context.cardColor;
    final textColor = isMine ? Colors.white : context.inkColor;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      child: Column(
        crossAxisAlignment: align,
        children: [
          Container(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.75,
            ),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: context.lineColor),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    message.body,
                    style: TextStyle(color: textColor, height: 1.3),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _formatTime(message.createdAt.toIso8601String()),
                        style: TextStyle(
                          fontSize: 10,
                          color: textColor.withValues(alpha: 0.7),
                        ),
                      ),
                      if (isMine && message.isRead) ...[
                        const SizedBox(width: 6),
                        const Icon(Icons.done_all_rounded, size: 12, color: Colors.white70),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(String iso) {
    try {
      final d = DateTime.parse(iso);
      return '${d.hour.toString().padLeft(2, '0')}:'
          '${d.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return iso;
    }
  }

  @override
  Widget build(BuildContext context) {
    final otherName = _conversation?.otherUserName ?? 'Conversa';
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            JbPageHeader(title: otherName),
            Expanded(
              child: _error != null
                  ? ErrorState(message: _error!, onRetry: _load)
                  : ListView.builder(
                      controller: _scroll,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemCount: _messages.length +
                          (_typingRemote ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (_typingRemote && index == _messages.length) {
                          return _TypingIndicator();
                        }
                        final message = _messages[index];
                        final isMine = message.senderId ==
                            AppScope.of(context).userId;
                        return _buildBubble(message, isMine);
                      },
                    ),
            ),
            if (_typingRemote)
              const SizedBox(height: 6),
            _Composer(
              controller: _controller,
              focus: _focus,
              onSend: _send,
              sending: _sending,
            ),
          ],
        ),
      ),
    );
  }
}

/// Indicador "fulano está a escrever...".
class _TypingIndicator extends StatelessWidget {
  const _TypingIndicator();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'A escrever...',
            style: Theme.of(context).textTheme.bodySmall
                ?.copyWith(color: context.mutedColor, fontStyle: FontStyle.italic),
          ),
          const SizedBox(width: 6),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(3, (i) {
              return Padding(
                padding: const EdgeInsets.only(right: 2),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 400),
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                    color: context.mutedColor.withValues(
                      alpha: 0.5 + (0.5 * ((i % 3) / 2)),
                    ),
                    shape: BoxShape.circle,
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}

/// Barra de composição de mensagem (texto + envio).
class _Composer extends StatelessWidget {
  const _Composer({
    required this.controller,
    required this.focus,
    required this.onSend,
    required this.sending,
  });

  final TextEditingController controller;
  final FocusNode focus;
  final VoidCallback onSend;
  final bool sending;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          border: Border(top: BorderSide(color: context.lineColor)),
        ),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                focusNode: focus,
                textInputAction: TextInputAction.send,
                maxLines: null,
                keyboardType: TextInputType.text,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  hintText: 'Escreve uma mensagem...',
                  hintStyle: TextStyle(color: context.mutedColor),
                  filled: true,
                  fillColor: context.cardColor,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 12,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide(color: context.lineColor),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide(color: context.lineColor),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide(color: AppColors.primary),
                  ),
                ),
                onSubmitted: (_) => onSend(),
              ),
            ),
            const SizedBox(width: 10),
            FilledButton.tonal(
              onPressed: sending ? null : onSend,
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
                shape: const CircleBorder(),
                padding: const EdgeInsets.all(14),
              ),
              child: sending
                  ? const SizedBox(
                      width: 20, height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.send_rounded, size: 20),
            ),
          ],
        ),
      ),
    );
  }
}

DateTime _date(dynamic value) {
  if (value == null) return DateTime.now();
  if (value is DateTime) return value;
  return DateTime.tryParse('$value') ?? DateTime.now();
}
