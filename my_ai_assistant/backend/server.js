import 'dotenv/config';
import express from 'express';
import cors from 'cors';
import morgan from 'morgan';
import fs from 'fs';
import rateLimit from 'express-rate-limit';
import OpenAI from 'openai';
import { pool, init } from './db.js';

const app = express();
app.use(cors());
app.use(express.json({ limit: '100kb' }));
fs.mkdirSync('logs', { recursive: true });
app.use(morgan('combined', { stream: fs.createWriteStream('logs/requests.log', { flags: 'a' }) }));
app.use(morgan('dev'));

// Ключ берётся ТОЛЬКО из .env на сервере
const openai = new OpenAI({ apiKey: process.env.OPENAI_API_KEY });
const MODEL = process.env.OPENAI_MODEL || 'gpt-4o-mini';
const PRICE_IN = 0.15 / 1e6, PRICE_OUT = 0.60 / 1e6; // gpt-4o-mini, USD за токен

const PROMPTS = {
  consultant: 'Ты — вежливый универсальный AI-консультант. Отвечай ясно, по делу и на языке пользователя.',
  teacher: 'Ты — терпеливый преподаватель. Объясняй пошагово, простыми словами, приводи примеры и проверяй понимание.',
  programmer: 'Ты — опытный программист. Давай точные ответы с примерами кода в блоках, указывай на лучшие практики и возможные ошибки.',
  translator: 'Ты — профессиональный переводчик. Переводи текст точно, сохраняя стиль; если язык не указан, переводи на английский (или на русский, если текст английский).',
};

const err = (res, status, error) => res.status(status).json({ success: false, error });

// --- идентификация устройства ---
app.use('/api', (req, res, next) => {
  if (req.path.startsWith('/admin')) return next();
  const id = req.header('x-device-id');
  if (!id || !/^[\w-]{8,64}$/.test(id)) return err(res, 400, 'Отсутствует или некорректен x-device-id');
  req.deviceId = id;
  next();
});

// --- ограничение количества запросов ---
const limiter = rateLimit({
  windowMs: 60_000, limit: 20, standardHeaders: true, legacyHeaders: false,
  handler: (req, res) => err(res, 429, 'Слишком много запросов. Подождите минуту.'),
});
app.use('/api/chat', limiter);

// --- валидация + контекст диалога ---
async function prepare(req, res) {
  const { message, conversationId, role = 'consultant' } = req.body || {};
  if (typeof message !== 'string' || !message.trim() || message.length > 4000)
    return err(res, 400, 'message: строка от 1 до 4000 символов'), null;
  if (typeof conversationId !== 'string' || !/^[\w-]{1,64}$/.test(conversationId))
    return err(res, 400, 'conversationId некорректен'), null;
  if (!PROMPTS[role]) return err(res, 400, 'Неизвестная роль'), null;

  const conv = (await pool.query('SELECT device_id FROM conversations WHERE id=$1', [conversationId])).rows[0];
  if (conv && conv.device_id !== req.deviceId) return err(res, 403, 'Нет доступа к диалогу'), null;

  const history = (await pool.query(
    `SELECT role, content FROM (SELECT id, role, content FROM messages
     WHERE conversation_id=$1 ORDER BY id DESC LIMIT 20) t ORDER BY id`, [conversationId])).rows;

  const text = message.trim();
  return {
    conversationId, role, text,
    msgs: [{ role: 'system', content: PROMPTS[role] }, ...history, { role: 'user', content: text }],
  };
}

async function save(deviceId, p, reply, usage) {
  await pool.query(
    `INSERT INTO conversations(id, device_id, title, role) VALUES($1,$2,$3,$4)
     ON CONFLICT (id) DO UPDATE SET role = EXCLUDED.role`,
    [p.conversationId, deviceId, p.text.slice(0, 40), p.role]);
  await pool.query(
    `INSERT INTO messages(conversation_id, role, content) VALUES ($1,'user',$2), ($1,'assistant',$3)`,
    [p.conversationId, p.text, reply]);
  const pt = usage?.prompt_tokens || 0, ct = usage?.completion_tokens || 0;
  await pool.query(
    `INSERT INTO usage_log(device_id, conversation_id, prompt_tokens, completion_tokens, cost_usd)
     VALUES($1,$2,$3,$4,$5)`, [deviceId, p.conversationId, pt, ct, pt * PRICE_IN + ct * PRICE_OUT]);
}

function mapOpenAIError(e) {
  console.error('OpenAI error:', e.status, e.message);
  if (e.status === 429) return [429, 'Лимит OpenAI исчерпан, попробуйте позже'];
  if (e.status === 401) return [500, 'Ошибка конфигурации сервера (API-ключ)'];
  if (e.status === 400) return [400, 'OpenAI отклонил запрос'];
  return [502, 'Сервис AI временно недоступен'];
}
const fail = (e) => e.status ? mapOpenAIError(e) : (console.error(e), [500, 'Внутренняя ошибка сервера']);

// --- POST /api/chat (обычный ответ) ---
app.post('/api/chat', async (req, res) => {
  try {
    const p = await prepare(req, res); if (!p) return;
    const r = await openai.chat.completions.create({ model: MODEL, messages: p.msgs });
    const reply = r.choices[0].message.content;
    await save(req.deviceId, p, reply, r.usage);
    res.json({ success: true, reply, conversationId: p.conversationId });
  } catch (e) { const [s, m] = fail(e); err(res, s, m); }
});

// --- POST /api/chat/stream (потоковый ответ, SSE) ---
app.post('/api/chat/stream', async (req, res) => {
  let started = false;
  try {
    const p = await prepare(req, res); if (!p) return;
    const stream = await openai.chat.completions.create({
      model: MODEL, messages: p.msgs, stream: true, stream_options: { include_usage: true },
    });
    res.set({ 'Content-Type': 'text/event-stream', 'Cache-Control': 'no-cache', Connection: 'keep-alive' });
    res.flushHeaders(); started = true;
    let full = '', usage = null;
    for await (const chunk of stream) {
      const d = chunk.choices[0]?.delta?.content;
      if (d) { full += d; res.write(`data: ${JSON.stringify({ delta: d })}\n\n`); }
      if (chunk.usage) usage = chunk.usage;
    }
    await save(req.deviceId, p, full, usage);
    res.write(`data: ${JSON.stringify({ done: true })}\n\n`);
    res.end();
  } catch (e) {
    const [s, m] = fail(e);
    if (started) { res.write(`data: ${JSON.stringify({ error: m })}\n\n`); res.end(); }
    else err(res, s, m);
  }
});

// --- история ---
app.get('/api/conversations', async (req, res) => {
  const { rows } = await pool.query(
    'SELECT id, title, role, created_at FROM conversations WHERE device_id=$1 ORDER BY created_at DESC', [req.deviceId]);
  res.json({ success: true, conversations: rows });
});

app.get('/api/conversations/:id/messages', async (req, res) => {
  const c = (await pool.query('SELECT device_id FROM conversations WHERE id=$1', [req.params.id])).rows[0];
  if (!c || c.device_id !== req.deviceId) return err(res, 404, 'Диалог не найден');
  const { rows } = await pool.query(
    'SELECT role, content, created_at FROM messages WHERE conversation_id=$1 ORDER BY id', [req.params.id]);
  res.json({ success: true, messages: rows });
});

app.delete('/api/conversations/:id', async (req, res) => {
  await pool.query('DELETE FROM conversations WHERE id=$1 AND device_id=$2', [req.params.id, req.deviceId]);
  res.json({ success: true });
});

// --- панель администратора ---
app.get('/api/admin/stats', async (req, res) => {
  if (!process.env.ADMIN_KEY || req.header('x-admin-key') !== process.env.ADMIN_KEY)
    return err(res, 401, 'Неверный ключ администратора');
  const total = (await pool.query(
    `SELECT COUNT(*)::int AS requests, COUNT(DISTINCT device_id)::int AS users,
     COALESCE(SUM(prompt_tokens),0)::int AS prompt_tokens, COALESCE(SUM(completion_tokens),0)::int AS completion_tokens,
     COALESCE(SUM(cost_usd),0)::float AS cost_usd FROM usage_log`)).rows[0];
  const daily = (await pool.query(
    `SELECT to_char(created_at::date,'YYYY-MM-DD') AS day, COUNT(*)::int AS requests,
     COUNT(DISTINCT device_id)::int AS users, SUM(cost_usd)::float AS cost_usd
     FROM usage_log GROUP BY 1 ORDER BY 1 DESC LIMIT 7`)).rows;
  res.json({ success: true, total, daily });
});

app.use((req, res) => err(res, 404, 'Маршрут не найден'));
app.use((e, req, res, next) => {
  if (e.type === 'entity.parse.failed') return err(res, 400, 'Некорректный JSON');
  console.error(e); err(res, 500, 'Внутренняя ошибка сервера');
});

await init();
app.listen(process.env.PORT || 3000, () => console.log('Server started'));
