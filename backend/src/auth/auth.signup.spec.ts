import { AuthService } from './auth.service';
import { AuthController } from './auth.controller';
import { Role } from './domain/roles';
import { ConflictAppException } from './errors/auth.exceptions';

/**
 * Sign-up flow contract: creating the minimal unverified user, issuing an OTP
 * through the OtpService (which delivers via the SMS provider abstraction),
 * and exposing ONLY safe response data — the OTP/debug_code is never part of
 * the signup response.
 */
describe('Sign-up flow', () => {
  const makeConfig = () => ({ otp: { ttlSeconds: 300 } });

  function makeService() {
    const prismaMock = {
      user: {
        findUnique: jest.fn().mockResolvedValue(null),
        create: jest.fn().mockResolvedValue({}),
      },
    };
    const otpMock = {
      requestOtp: jest
        .fn()
        .mockResolvedValue({ sessionId: 'sess-123', expiresInSeconds: 300 }),
    };
    const tokenMock = {};
    const service = new AuthService(
      prismaMock as never,
      otpMock as never,
      tokenMock as never,
      makeConfig() as never,
    );
    return { service, prismaMock, otpMock };
  }

  it('creates an unverified user, requests an OTP, and returns a session', async () => {
    const { service, prismaMock, otpMock } = makeService();

    const result = await service.signUp('+919876543210', 'Aarav Sharma', 'customer');

    expect(prismaMock.user.create).toHaveBeenCalledTimes(1);
    const created = prismaMock.user.create.mock.calls[0][0].data;
    expect(created.phoneNumber).toBe('+919876543210');
    expect(created.fullName).toBe('Aarav Sharma');
    expect(created.primaryRole).toBe(Role.Customer);
    expect(created.isPhoneVerified).toBe(false);
    expect(created.accountStatus).toBe('ACTIVE');

    // OTP generation + delivery is delegated to OtpService (SMS provider).
    expect(otpMock.requestOtp).toHaveBeenCalledWith('+919876543210', 'SIGNUP');
    expect(result).toEqual({ sessionId: 'sess-123', expiresInSeconds: 300 });
    // The service result carries no OTP/debug code.
    expect(Object.keys(result)).not.toContain('debugCode');
  });

  it('creates a driver account with the driver role', async () => {
    const { service, prismaMock } = makeService();
    await service.signUp('+919876543211', 'Ravi Driver', 'driver');
    expect(prismaMock.user.create.mock.calls[0][0].data.primaryRole).toBe(Role.Driver);
  });

  it('rejects an already registered phone number without touching OTP', async () => {
    const { service, prismaMock, otpMock } = makeService();
    prismaMock.user.findUnique.mockResolvedValue({ id: 'existing' });

    await expect(
      service.signUp('+919876543210', 'Aarav Sharma', 'customer'),
    ).rejects.toBeInstanceOf(ConflictAppException);
    expect(prismaMock.user.create).not.toHaveBeenCalled();
    expect(otpMock.requestOtp).not.toHaveBeenCalled();
  });

  describe('AuthController responses', () => {
    it('signUp responds with session data only — no OTP/debug_code', async () => {
      const serviceStub = {
        signUp: jest
          .fn()
          .mockResolvedValue({ sessionId: 'sess-123', expiresInSeconds: 300 }),
      };
      const controller = new AuthController(serviceStub as never);

      const body = await controller.signUp({
        phoneNumber: '+919876543210',
        displayName: 'Aarav Sharma',
        role: 'customer',
      });

      expect(body).toEqual({
        session_id: 'sess-123',
        expires_in_seconds: 300,
        next_step: 'VERIFY_OTP',
      });
      expect(Object.keys(body)).not.toContain('debug_code');
    });

    it('requestOtp omits debug_code when the server did not emit one', async () => {
      const serviceStub = {
        requestOtp: jest.fn().mockResolvedValue({
          sessionId: 'sess-123',
          expiresInSeconds: 300,
          resendAvailableInSeconds: 30,
        }),
      };
      const controller = new AuthController(serviceStub as never);

      const body = await controller.requestOtp({
        phoneNumber: '+919876543210',
        purpose: 'LOGIN',
      });

      expect(body).not.toHaveProperty('debug_code');
    });

    it('requestOtp includes debug_code only when explicitly emitted (dev opt-in)', async () => {
      const serviceStub = {
        requestOtp: jest.fn().mockResolvedValue({
          sessionId: 'sess-123',
          expiresInSeconds: 300,
          resendAvailableInSeconds: 30,
          debugCode: '849201',
        }),
      };
      const controller = new AuthController(serviceStub as never);

      const body = await controller.requestOtp({
        phoneNumber: '+919876543210',
        purpose: 'LOGIN',
      });

      expect(body).toHaveProperty('debug_code', '849201');
    });
  });
});
