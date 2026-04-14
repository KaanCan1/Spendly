import 'dotenv/config';
import Fastify from 'fastify';
import cors from '@fastify/cors';
import { OAuth2Client } from 'google-auth-library';
import { prisma } from './lib/prisma.js';
import {
  hashPassword,
  signPasswordResetToken,
  signUserToken,
  userPublic,
  verifyPassword,
  verifyPasswordResetToken,
  verifyUserToken,
} from './lib/auth.js';
import { sendPasswordResetEmail } from './lib/mail.js';

const googleClient = new OAuth2Client();

async function buildServer() {
  const app = Fastify({ logger: true });

  await app.register(cors, {
    origin: true,
    credentials: true,
  });

  app.get('/health', async () => ({ ok: true }));

  app.post('/auth/register', async (request, reply) => {
    const body = request.body ?? {};
    const email = typeof body.email === 'string' ? body.email.trim().toLowerCase() : '';
    const password = typeof body.password === 'string' ? body.password : '';
    const name = typeof body.name === 'string' ? body.name.trim() : null;

    if (!email || !password) {
      return reply.code(400).send({ error: 'email and password are required' });
    }
    if (password.length < 8) {
      return reply.code(400).send({ error: 'password must be at least 8 characters' });
    }

    const existing = await prisma.user.findUnique({ where: { email } });
    if (existing) {
      return reply.code(409).send({ error: 'email already registered' });
    }

    const passwordHash = await hashPassword(password);
    const user = await prisma.user.create({
      data: { email, passwordHash, name: name || null },
    });

    const token = signUserToken(user.id);
    return { token, user: userPublic(user) };
  });

  app.post('/auth/login', async (request, reply) => {
    const body = request.body ?? {};
    const email = typeof body.email === 'string' ? body.email.trim().toLowerCase() : '';
    const password = typeof body.password === 'string' ? body.password : '';

    if (!email || !password) {
      return reply.code(400).send({ error: 'email and password are required' });
    }

    const user = await prisma.user.findUnique({ where: { email } });
    if (!user?.passwordHash) {
      return reply.code(401).send({ error: 'invalid email or password' });
    }

    const ok = await verifyPassword(password, user.passwordHash);
    if (!ok) {
      return reply.code(401).send({ error: 'invalid email or password' });
    }

    const token = signUserToken(user.id);
    return { token, user: userPublic(user) };
  });

  app.post('/auth/google', async (request, reply) => {
    const body = request.body ?? {};
    const idToken = typeof body.idToken === 'string' ? body.idToken : '';
    const audience = process.env.GOOGLE_WEB_CLIENT_ID;

    if (!idToken) {
      return reply.code(400).send({ error: 'idToken is required' });
    }
    if (!audience) {
      return reply.code(500).send({ error: 'server GOOGLE_WEB_CLIENT_ID is not configured' });
    }

    let ticket;
    try {
      ticket = await googleClient.verifyIdToken({
        idToken,
        audience,
      });
    } catch {
      return reply.code(401).send({ error: 'invalid Google token' });
    }

    const payload = ticket.getPayload();
    if (!payload?.sub || !payload.email) {
      return reply.code(401).send({ error: 'invalid Google token payload' });
    }

    const googleSub = payload.sub;
    const email = payload.email.toLowerCase();
    const name =
      payload.name?.trim() ||
      [payload.given_name, payload.family_name].filter(Boolean).join(' ').trim() ||
      null;

    let user = await prisma.user.findFirst({
      where: { OR: [{ googleSub }, { email }] },
    });

    if (user) {
      user = await prisma.user.update({
        where: { id: user.id },
        data: {
          googleSub,
          email,
          name: user.name ?? name,
        },
      });
    } else {
      user = await prisma.user.create({
        data: {
          email,
          googleSub,
          name,
          passwordHash: null,
        },
      });
    }

    const token = signUserToken(user.id);
    return { token, user: userPublic(user) };
  });

  app.post('/auth/forgot-password', async (request, reply) => {
    const body = request.body ?? {};
    const email = typeof body.email === 'string' ? body.email.trim().toLowerCase() : '';

    if (!email) {
      return reply.code(400).send({ error: 'email is required' });
    }

    const user = await prisma.user.findUnique({ where: { email } });
    if (user?.passwordHash) {
      const resetToken = signPasswordResetToken(user.id);
      await sendPasswordResetEmail(app, email, resetToken);
    }

    return { ok: true };
  });

  app.post('/auth/reset-password', async (request, reply) => {
    const body = request.body ?? {};
    const token = typeof body.token === 'string' ? body.token.trim() : '';
    const password = typeof body.password === 'string' ? body.password : '';

    if (!token || !password) {
      return reply.code(400).send({ error: 'token and password are required' });
    }
    if (password.length < 8) {
      return reply.code(400).send({ error: 'password must be at least 8 characters' });
    }

    let userId;
    try {
      userId = verifyPasswordResetToken(token);
    } catch {
      return reply.code(400).send({ error: 'invalid or expired reset token' });
    }

    const user = await prisma.user.findUnique({ where: { id: userId } });
    if (!user) {
      return reply.code(400).send({ error: 'invalid reset token' });
    }

    const passwordHash = await hashPassword(password);
    await prisma.user.update({
      where: { id: user.id },
      data: { passwordHash },
    });

    return { ok: true };
  });

  app.get('/me', async (request, reply) => {
    const userId = await authenticate(request, reply);
    if (!userId) return;

    const user = await prisma.user.findUnique({ where: { id: userId } });
    if (!user) {
      return reply.code(404).send({ error: 'user not found' });
    }
    return userPublic(user);
  });

  app.get('/expenses', async (request, reply) => {
    const userId = await authenticate(request, reply);
    if (!userId) return;

    const list = await prisma.expense.findMany({
      where: { userId },
      orderBy: { occurredAt: 'desc' },
    });
    return list.map((e) => ({
      id: e.id,
      amount: e.amount.toString(),
      currency: e.currency,
      note: e.note,
      occurredAt: e.occurredAt.toISOString(),
      createdAt: e.createdAt.toISOString(),
    }));
  });

  app.post('/expenses', async (request, reply) => {
    const userId = await authenticate(request, reply);
    if (!userId) return;

    const body = request.body ?? {};
    const rawAmount = body.amount;
    const amount =
      typeof rawAmount === 'number'
        ? rawAmount
        : typeof rawAmount === 'string'
          ? Number.parseFloat(rawAmount)
          : Number.NaN;

    if (!Number.isFinite(amount) || amount <= 0) {
      return reply.code(400).send({ error: 'amount must be a positive number' });
    }

    const currency =
      typeof body.currency === 'string' && body.currency.trim()
        ? body.currency.trim().toUpperCase()
        : 'TRY';
    const note =
      typeof body.note === 'string' && body.note.trim() ? body.note.trim() : null;
    let occurredAt = new Date();
    if (typeof body.occurredAt === 'string' && body.occurredAt) {
      const d = new Date(body.occurredAt);
      if (!Number.isNaN(d.getTime())) occurredAt = d;
    }

    const expense = await prisma.expense.create({
      data: {
        userId,
        amount,
        currency,
        note,
        occurredAt,
      },
    });

    return {
      id: expense.id,
      amount: expense.amount.toString(),
      currency: expense.currency,
      note: expense.note,
      occurredAt: expense.occurredAt.toISOString(),
      createdAt: expense.createdAt.toISOString(),
    };
  });

  return app;
}

async function authenticate(request, reply) {
  const header = request.headers.authorization;
  if (!header?.startsWith('Bearer ')) {
    reply.code(401).send({ error: 'missing bearer token' });
    return null;
  }
  const token = header.slice(7);
  try {
    const payload = verifyUserToken(token);
    if (typeof payload.sub !== 'string') {
      reply.code(401).send({ error: 'invalid token' });
      return null;
    }
    return payload.sub;
  } catch {
    reply.code(401).send({ error: 'invalid or expired token' });
    return null;
  }
}

const port = Number.parseInt(process.env.PORT ?? '3000', 10);

buildServer()
  .then((app) =>
    app.listen({ port, host: '0.0.0.0' }),
  )
  .catch((err) => {
    console.error(err);
    process.exit(1);
  });
