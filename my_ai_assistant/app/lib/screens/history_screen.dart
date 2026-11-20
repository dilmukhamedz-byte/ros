import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../api_service.dart';
import '../chat_provider.dart';
import '../config.dart';
import '../models.dart';
import 'admin_screen.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});
  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  List<Conversation>? _items;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _items = null;
      _error = null;
    });
    try {
      final list = await context.read<ApiService>().conversations();
      if (mounted) setState(() => _items = list);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  Future<void> _delete(Conversation c) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Удалить диалог?'),
        content: Text(c.title),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Отмена')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Удалить')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final chat = context.read<ChatProvider>();
    try {
      await context.read<ApiService>().deleteConversation(c.id);
      if (chat.conversationId == c.id) chat.newChat();
      _load();
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('История диалогов'),
        actions: [
          IconButton(
            tooltip: 'Статистика (админ)',
            icon: const Icon(Icons.bar_chart),
            onPressed: () =>
                Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AdminScreen())),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add),
        label: const Text('Новый чат'),
        onPressed: () {
          context.read<ChatProvider>().newChat();
          Navigator.pop(context);
        },
      ),
      body: _error != null
          ? Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Text(_error!),
                TextButton(onPressed: _load, child: const Text('Повторить')),
              ]),
            )
          : _items == null
              ? const Center(child: CircularProgressIndicator())
              : _items!.isEmpty
                  ? const Center(child: Text('Сохранённых диалогов пока нет'))
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView.separated(
                        itemCount: _items!.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (_, i) {
                          final c = _items![i];
                          return ListTile(
                            leading: const Icon(Icons.chat_bubble_outline),
                            title: Text(c.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                            subtitle: Text(
                                '${kRoles[c.role] ?? c.role} · ${DateFormat('dd.MM.yyyy HH:mm').format(c.createdAt)}'),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete_outline),
                              onPressed: () => _delete(c),
                            ),
                            onTap: () async {
                              final chat = context.read<ChatProvider>();
                              final nav = Navigator.of(context);
                              await chat.openConversation(c);
                              nav.pop();
                            },
                          );
                        },
                      ),
                    ),
    );
  }
}
