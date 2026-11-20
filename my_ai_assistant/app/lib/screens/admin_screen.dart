import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../api_service.dart';

class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});
  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  final _key = TextEditingController();
  Map<String, dynamic>? _data;
  String? _error;
  bool _loading = false;

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final d = await context.read<ApiService>().adminStats(_key.text.trim());
      setState(() => _data = d);
    } on ApiException catch (e) {
      setState(() {
        _data = null;
        _error = e.message;
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = _data?['total'] as Map?;
    final daily = (_data?['daily'] as List?) ?? [];
    return Scaffold(
      appBar: AppBar(title: const Text('Панель администратора')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        TextField(
          controller: _key,
          obscureText: true,
          decoration: const InputDecoration(labelText: 'Ключ администратора', border: OutlineInputBorder()),
        ),
        const SizedBox(height: 8),
        FilledButton(onPressed: _loading ? null : _load, child: const Text('Показать статистику')),
        if (_loading) const Padding(padding: EdgeInsets.all(16), child: Center(child: CircularProgressIndicator())),
        if (_error != null)
          Padding(padding: const EdgeInsets.all(16), child: Text(_error!, style: const TextStyle(color: Colors.red))),
        if (t != null) ...[
          const SizedBox(height: 16),
          Card(
            child: Column(children: [
              ListTile(title: const Text('Всего запросов'), trailing: Text('${t['requests']}')),
              ListTile(title: const Text('Пользователей'), trailing: Text('${t['users']}')),
              ListTile(title: const Text('Токенов (вход / выход)'),
                  trailing: Text('${t['prompt_tokens']} / ${t['completion_tokens']}')),
              ListTile(title: const Text('Расходы на API'),
                  trailing: Text('\$${(t['cost_usd'] as num).toStringAsFixed(4)}')),
            ]),
          ),
          const SizedBox(height: 8),
          const Text('Последние 7 дней', style: TextStyle(fontWeight: FontWeight.bold)),
          for (final d in daily)
            ListTile(
              dense: true,
              title: Text(d['day']),
              subtitle: Text('запросов: ${d['requests']} · пользователей: ${d['users']}'),
              trailing: Text('\$${(d['cost_usd'] as num).toStringAsFixed(4)}'),
            ),
        ],
      ]),
    );
  }
}
