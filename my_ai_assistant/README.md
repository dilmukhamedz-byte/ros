# Мой AI-помощник

Flutter-клиент + Node.js/Express Backend + PostgreSQL + OpenAI API.

## Структура
- `backend/` — сервер (Express). Ключ OpenAI хранится только здесь, в `.env`.
- `app/` — мобильное приложение Flutter (Provider + Dio).
- `docker-compose.yml` — PostgreSQL.

## Запуск Backend
```bash
docker compose up -d                 # PostgreSQL
cd backend
cp .env.example .env                 # впишите OPENAI_API_KEY и ADMIN_KEY
npm install
npm start                            # http://localhost:3000
```

## Запуск Flutter
```bash
cd app
flutter create . --project-name my_ai_assistant --org com.example   # сгенерирует android/ios (lib и pubspec сохранятся)
flutter pub get
flutter run --dart-define=API_URL=http://10.0.2.2:3000   # эмулятор Android
# реальный телефон: --dart-define=API_URL=http://<IP-компьютера>:3000
```
Для Android с HTTP (не HTTPS) добавьте в `android/app/src/main/AndroidManifest.xml`:
- `<uses-permission android:name="android.permission.INTERNET"/>` (перед `<application>`)
- `android:usesCleartextTraffic="true"` в тег `<application>`

## API
- `POST /api/chat` — `{message, conversationId, role?}` → `{success, reply, conversationId}`
- `POST /api/chat/stream` — то же, ответ потоком (SSE) — используется в приложении
- `GET /api/conversations`, `GET /api/conversations/:id/messages`, `DELETE /api/conversations/:id`
- `GET /api/admin/stats` (заголовок `x-admin-key`)
Все запросы (кроме admin) требуют заголовок `x-device-id` (приложение генерирует его само).

## Реализовано
Обязательное: 3 экрана, Backend, валидация, OpenAI через сервер, `.env`, system prompt,
контекст (последние 20 сообщений), rate limit (20/мин), журнал `backend/logs/requests.log`,
история в PostgreSQL, состояния Loading/Success/Error/Empty/Offline/Timeout, блокировка повторной
отправки, кнопка «Повторить», очистка поля после успеха, сохранение текста при ошибке.

Advanced (3 из 5): **выбор роли AI**, **Streaming Response**, **панель администратора**.
