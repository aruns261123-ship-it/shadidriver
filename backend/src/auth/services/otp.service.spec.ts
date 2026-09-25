import { createHash } from 'crypto';
import { OtpService } from './otp.service';
import { SmsProviderError } from '../../notifications/sms/sms-provider.interface';

describe('OtpService (unit)', () => {
  let service: OtpService;
  let prismaMock: {
    $transaction: jest.Mock;
    otpCode: {
      create: jest.Mock;
      findFirst: jest.Mock;
      findUnique: jest.Mock;
      update: jest.Mock;
      deleteMany: jest.Mock;
      updateMany: jest.Mock;
      count: jest.Mock;
    };
  };
  let smsMock: { sendOtp: jest.Mock; name: string };
  const makeConfig = (overrides: Record<string, unknown> = {}) => ({
    otp: {
      codeLength: 6,
      ttlSeconds: 300,
      maxAttempts: 3,
      resendCooldownSeconds: 30,
      debugLog: false,
      debugEmit: false,
      ...overrides,
    },
  });

  beforeEach(() => {
    prismaMock = {
      $transaction: jest.fn(),
      otpCode: {
        create: jest.fn().mockResolvedValue({}),
        findFirst: jest.fn().mockResolvedValue(null),
        findUnique: jest.fn().mockResolvedValue(null),
        update: jest.fn().mockResolvedValue({}),
        deleteMany: jest.fn().mockResolvedValue({ count: 0 }),
        updateMany: jest.fn().mockResolvedValue({ count: 0 }),
        count: jest.fn().mockResolvedValue(0),
      },
    };
    smsMock = { sendOtp: jest.fn().mockResolvedValue({ accepted: true, messageId: 'm1' }), name: 'test-sms' };
    prismaMock.$transaction = jest.fn(async (ops: unknown) => {
      // Prisma $transaction([...]) receives an array of promises.
      void ops;
      return [];
    }) as never;
    service = new OtpService(prismaMock as never, makeConfig() as never, smsMock as never);
  });

  describe('requestOtp', () => {
    it('sends via SMS provider BEFORE persisting and stores only a hash', async () => {
      const session = await service.requestOtp('+919810000001', 'LOGIN');

      expect(session.sessionId).toHaveLength(32);
      expect(session.expiresInSeconds).toBe(300);
      // Delivery attempted exactly once, with a 6-digit code.
      expect(smsMock.sendOtp).toHaveBeenCalledTimes(1);
      const [phone, code] = smsMock.sendOtp.mock.calls[0];
      expect(phone).toBe('+919810000001');
      expect(code).toMatch(/^\d{6}$/);
      // Persisted record contains a hash, never the plaintext code.
      const arg = prismaMock.otpCode.create.mock.calls[0][0].data;
      expect(arg.phoneNumber).toBe('+919810000001');
      expect(arg.codeHash).not.toMatch(/^\d{6}$/); // never stores plaintext
      expect(arg.codeHash).toHaveLength(64);
      expect(arg.codeHash).not.toContain(code);
      expect(arg.expiresAt.getTime()).toBeGreaterThan(Date.now());
    });

    it('fails loudly and persists NOTHING when SMS delivery fails (no fake success)', async () => {
      smsMock.sendOtp.mockRejectedValue(
        new SmsProviderError('test-sms', 'gateway down', true),
      );
      await expect(service.requestOtp('+919810000001', 'LOGIN')).rejects.toThrow(SmsProviderError);
      expect(prismaMock.otpCode.create).not.toHaveBeenCalled();
      expect(prismaMock.$transaction).not.toHaveBeenCalled();
    });

    it('enforces resend cooldown (anti-abuse)', async () => {
      prismaMock.otpCode.findFirst.mockResolvedValue({ id: 'recent' });
      await expect(service.requestOtp('+919810000001', 'LOGIN')).rejects.toThrow(/wait 30s/);
      expect(smsMock.sendOtp).not.toHaveBeenCalled();
    });

    it('blocks excessive generation within the hourly window', async () => {
      prismaMock.otpCode.count.mockResolvedValue(5);
      await expect(service.requestOtp('+919810000001', 'LOGIN')).rejects.toThrow(/Too many OTP requests/);
      expect(smsMock.sendOtp).not.toHaveBeenCalled();
    });

    it('invalidates previous unconsumed codes when issuing a new one', async () => {
      await service.requestOtp('+919810000001', 'LOGIN');
      // Issuing a new code invalidates all previous unconsumed ones.
      const invalidation = prismaMock.otpCode.updateMany.mock.calls.find(
        (call) => call[0]?.where?.consumedAt === null,
      );
      expect(invalidation).toBeTruthy();
      expect(invalidation![0].where.phoneNumber).toBe('+919810000001');
    });

    it('never returns the code to the client by default (no debug_code leak)', async () => {
      const session = await service.requestOtp('+919810000001', 'LOGIN');
      expect(session.debugCode).toBeUndefined();
      expect(JSON.stringify(session)).not.toContain(
        smsMock.sendOtp.mock.calls[0][1],
      );
    });

    it('returns debug_code ONLY when OTP_DEBUG_EMIT is explicitly enabled', async () => {
      service = new OtpService(
        prismaMock as never,
        makeConfig({ debugEmit: true }) as never,
        smsMock as never,
      );
      const session = await service.requestOtp('+919810000001', 'LOGIN');
      expect(session.debugCode).toBe(smsMock.sendOtp.mock.calls[0][1]);
    });
  });

  describe('verifyOtp', () => {
    function activeSession(code: string, phone: string, overrides: Record<string, unknown> = {}) {
      return {
        id: 'row1',
        sessionId: 'sess123',
        phoneNumber: phone,
        purpose: 'LOGIN',
        attempts: 0,
        consumedAt: null,
        expiresAt: new Date(Date.now() + 60_000),
        codeHash: hashFor(code, phone),
        ...overrides,
      };
    }

  // Reconstruct service hashing to build expected hashes in tests.
  function hashFor(code: string, phone: string): string {
    return createHash('sha256').update(`${phone}:${code}`).digest('hex');
  }

    it('consumes a correct code and marks it used', async () => {
      prismaMock.otpCode.findUnique.mockResolvedValue(activeSession('849201', '+919810000001'));
      const result = await service.verifyOtp('sess123', '849201', 'LOGIN');
      expect(result.phoneNumber).toBe('+919810000001');
      const updateArg = prismaMock.otpCode.update.mock.calls.find(
        (c) => c[0].where.id === 'row1' && c[0].data.consumedAt,
      );
      expect(updateArg).toBeTruthy();
    });

    it('rejects an incorrect code and counts the attempt', async () => {
      prismaMock.otpCode.findUnique.mockResolvedValue(activeSession('849201', '+919810000001'));
      await expect(service.verifyOtp('sess123', '000000', 'LOGIN')).rejects.toThrow(/Incorrect code/);
      const attemptUpdate = prismaMock.otpCode.update.mock.calls.find(
        (c) => c[0].data.attempts?.increment !== undefined,
      );
      expect(attemptUpdate).toBeTruthy();
    });

    it('rejects expired codes with OTP_EXPIRED semantics', async () => {
      prismaMock.otpCode.findUnique.mockResolvedValue(
        activeSession('849201', '+919810000001', { expiresAt: new Date(Date.now() - 1000) }),
      );
      await expect(service.verifyOtp('sess123', '849201', 'LOGIN')).rejects.toThrow(/expired/);
    });

    it('rejects already-consumed codes (replay protection)', async () => {
      prismaMock.otpCode.findUnique.mockResolvedValue(
        activeSession('849201', '+919810000001', { consumedAt: new Date() }),
      );
      await expect(service.verifyOtp('sess123', '849201', 'LOGIN')).rejects.toThrow(/already used/);
    });

    it('rejects after max attempts', async () => {
      prismaMock.otpCode.findUnique.mockResolvedValue(
        activeSession('849201', '+919810000001', { attempts: 3 }),
      );
      await expect(service.verifyOtp('sess123', '849201', 'LOGIN')).rejects.toThrow(/Too many/);
    });

    it('rejects codes invalidated by a newer request (consumedAt set)', async () => {
      prismaMock.otpCode.findUnique.mockResolvedValue(
        activeSession('849201', '+919810000001', { consumedAt: new Date() }),
      );
      await expect(service.verifyOtp('sess123', '849201', 'LOGIN')).rejects.toThrow(/already used/);
    });

    it('rejects unknown sessions', async () => {
      prismaMock.otpCode.findUnique.mockResolvedValue(null);
      await expect(service.verifyOtp('missing', '849201', 'LOGIN')).rejects.toThrow(/not found/);
    });
  });
});
