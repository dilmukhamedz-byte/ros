import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'api_service.dart';
import 'chat_provider.dart';
import 'screens/welcome_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  var id = prefs.getString('device_id');
  if (id == null) {
    id = const Uuid().v4();
    await prefs.setString('device_id', id);
  }
  final api = ApiService(id);
  runApp(MultiProvider(
    providers: [
      Provider<ApiService>.value(value: api),
      ChangeNotifierProvider(create: (_) => ChatProvider(api)),
    ],
    child: const MyApp(),
  ));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Мой AI-помощник',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(colorSchemeSeed: Colors.indigo, useMaterial3: true),
        home: const WelcomeScreen(),
      );
}
