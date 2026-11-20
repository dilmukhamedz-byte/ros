import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../chat_provider.dart';
import 'chat_screen.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircleAvatar(
                radius: 56,
                backgroundColor: cs.primaryContainer,
                child: Icon(Icons.smart_toy_rounded, size: 64, color: cs.primary),
              ),
              const SizedBox(height: 24),
              Text('Мой AI-помощник',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              const Text(
                'Задавайте вопросы искусственному интеллекту, выбирайте роль помощника '
                '(преподаватель, программист, переводчик, консультант), получайте ответы '
                'в реальном времени и возвращайтесь к сохранённым диалогам.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 40),
              FilledButton.icon(
                icon: const Icon(Icons.chat_bubble_outline),
                label: const Text('Начать общение'),
                onPressed: () {
                  context.read<ChatProvider>().newChat();
                  Navigator.of(context).pushReplacement(
                      MaterialPageRoute(builder: (_) => const ChatScreen()));
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
