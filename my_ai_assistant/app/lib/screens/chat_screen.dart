import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../chat_provider.dart';
import '../config.dart';
import '../models.dart';
import 'history_screen.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});
  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _ctrl = TextEditingController();
  final _scroll = ScrollController();

  void _scrollDown() => WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scroll.hasClients) {
          _scroll.animateTo(_scroll.position.maxScrollExtent,
              duration: const Duration(milliseconds: 200), curve: Curves.easeOut);
        }
      });

  Future<void> _send() async {
    final p = context.read<ChatProvider>();
    if (p.isLoading) return;
    final ok = await p.send(_ctrl.text);
    if (ok) _ctrl.clear(); // очистка поля только после успешной отправки
  }

  Future<void> _retry() async {
    final ok = await context.read<ChatProvider>().retry();
    if (ok) _ctrl.clear();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<ChatProvider>();
    _scrollDown();
    return Scaffold(
      appBar: AppBar(
        title: Text('AI · ${kRoles[p.role]}'),
        actions: [
          PopupMenuButton<String>(
            tooltip: 'Роль AI',
            icon: const Icon(Icons.psychology_alt_outlined),
            onSelected: p.setRole,
            itemBuilder: (_) => [
              for (final e in kRoles.entries)
                CheckedPopupMenuItem(value: e.key, checked: p.role == e.key, child: Text(e.value)),
            ],
          ),
          IconButton(
            tooltip: 'Новый чат',
            icon: const Icon(Icons.add_comment_outlined),
            onPressed: p.isLoading ? null : p.newChat,
          ),
          IconButton(
            tooltip: 'История',
            icon: const Icon(Icons.history),
            onPressed: () => Navigator.of(context)
                .push(MaterialPageRoute(builder: (_) => const HistoryScreen())),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: p.messages.isEmpty
                ? const _EmptyView()
                : ListView.builder(
                    controller: _scroll,
                    padding: const EdgeInsets.all(12),
                    itemCount: p.messages.length,
                    itemBuilder: (_, i) {
                      final m = p.messages[i];
                      final typing = p.isLoading && i == p.messages.length - 1 && m.content.isEmpty;
                      return _Bubble(message: m, typing: typing);
                    },
                  ),
          ),
          if (p.hasFailed) _ErrorBanner(provider: p, onRetry: _retry),
          _InputBar(controller: _ctrl, loading: p.isLoading, onSend: _send),
        ],
      ),
    );
  }
}

class _EmptyView extends StatelessWidget {
  const _EmptyView();
  @override
  Widget build(BuildContext context) => Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.forum_outlined, size: 64, color: Theme.of(context).colorScheme.outline),
          const SizedBox(height: 12),
          const Text('Сообщений пока нет.\nЗадайте свой первый вопрос!', textAlign: TextAlign.center),
        ]),
      );
}

class _Bubble extends StatelessWidget {
  final ChatMessage message;
  final bool typing;
  const _Bubble({required this.message, required this.typing});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final me = message.isUser;
    return Align(
      alignment: me ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.8),
        decoration: BoxDecoration(
          color: me ? cs.primary : cs.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (typing)
              Row(mainAxisSize: MainAxisSize.min, children: [
                const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)),
                const SizedBox(width: 8),
                Text('AI печатает…', style: TextStyle(color: cs.onSurfaceVariant)),
              ])
            else
              SelectableText(message.content,
                  style: TextStyle(color: me ? cs.onPrimary : cs.onSurface)),
            const SizedBox(height: 2),
            Text(DateFormat.Hm().format(message.time),
                style: TextStyle(fontSize: 11, color: (me ? cs.onPrimary : cs.onSurface).withOpacity(0.6))),
          ],
        ),
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  final ChatProvider provider;
  final VoidCallback onRetry;
  const _ErrorBanner({required this.provider, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final icon = switch (provider.status) {
      ChatStatus.offline => Icons.wifi_off,
      ChatStatus.timeout => Icons.timer_off_outlined,
      _ => Icons.error_outline,
    };
    return Material(
      color: Theme.of(context).colorScheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Row(children: [
          Icon(icon, color: Theme.of(context).colorScheme.onErrorContainer),
          const SizedBox(width: 8),
          Expanded(child: Text(provider.error ?? 'Ошибка')),
          TextButton(onPressed: onRetry, child: const Text('Повторить')),
        ]),
      ),
    );
  }
}

class _InputBar extends StatelessWidget {
  final TextEditingController controller;
  final bool loading;
  final VoidCallback onSend;
  const _InputBar({required this.controller, required this.loading, required this.onSend});

  @override
  Widget build(BuildContext context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 6, 12, 8),
          child: Row(children: [
            Expanded(
              child: TextField(
                controller: controller,
                enabled: !loading,
                minLines: 1,
                maxLines: 5,
                maxLength: 4000,
                textInputAction: TextInputAction.newline,
                decoration: InputDecoration(
                  hintText: 'Введите сообщение…',
                  counterText: '',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(24)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filled(
              onPressed: loading ? null : onSend,
              icon: loading
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.send),
            ),
          ]),
        ),
      );
}
