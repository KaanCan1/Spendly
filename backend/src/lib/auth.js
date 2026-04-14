import bcrypt from 'bcrypt';
import jwt from 'jsonwebtoken';

const SALT_ROUNDS = 12;
const JWT_EXPIRES = '7d';
const PASSWORD_RESET_EXPIRES = '1h';

export async function hashPassword(plain) {
  return bcrypt.hash(plain, SALT_ROUNDS);
}

export async function verifyPassword(plain, hash) {
  return bcrypt.compare(plain, hash);
}

export function signUserToken(userId) {
  const secret = process.env.JWT_SECRET;
  if (!secret) {
    throw new Error('JWT_SECRET is not set');
  }
  return jwt.sign({ sub: userId }, secret, { expiresIn: JWT_EXPIRES });
}

export function verifyUserToken(token) {
  const secret = process.env.JWT_SECRET;
  if (!secret) {
    throw new Error('JWT_SECRET is not set');
  }
  return jwt.verify(token, secret);
}

export function signPasswordResetToken(userId) {
  const secret = process.env.JWT_SECRET;
  if (!secret) {
    throw new Error('JWT_SECRET is not set');
  }
  return jwt.sign({ sub: userId, pwdReset: true }, secret, {
    expiresIn: PASSWORD_RESET_EXPIRES,
  });
}

export function verifyPasswordResetToken(token) {
  const secret = process.env.JWT_SECRET;
  if (!secret) {
    throw new Error('JWT_SECRET is not set');
  }
  const payload = jwt.verify(token, secret);
  if (!payload?.pwdReset || typeof payload.sub !== 'string') {
    throw new Error('invalid reset token');
  }
  return payload.sub;
}

export function userPublic(user) {
  if (!user) return null;
  return {
    id: user.id,
    email: user.email,
    name: user.name,
    createdAt: user.createdAt,
  };
}
