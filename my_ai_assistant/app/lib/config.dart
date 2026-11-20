// Адрес Backend. Для эмулятора Android: http://10.0.2.2:3000
// Для реального телефона: http://<IP-компьютера>:3000
// Запуск: flutter run --dart-define=API_URL=http://192.168.1.10:3000
const String kApiUrl =
    String.fromEnvironment('API_URL', defaultValue: 'http://localhost:3000');

const Map<String, String> kRoles = {
  'consultant': 'Консультант',
  'teacher': 'Преподаватель',
  'programmer': 'Программист',
  'translator': 'Переводчик',
};
