import { TokenService } from './token.service';
import { Role } from '../domain/roles';

describe('TokenService (unit)', () => {
  let service: TokenService;
  let jwtMock: { signAsync: jest.Mock };
  let prismaMock: {
    refreshToken: {
      create: jest.Mock;
      findUnique: jest.Mock;
      update: jest.Mock;
      updateMany: jest.Mock;
    };
    $transaction: jest.Mock;
  };

  const config = {
    jwt: {
      accessSecret: 'test-secret-at-least-32-characters-long',
      refreshSecret: 'test-refresh-secret-at-least-32-char',
      accessTtlSeconds: 900,
      refreshTtlSeconds: 1209600,
      issuer: 'shadidriver.api',
    },
  };

  const user = { id: 'u1', phoneNumber: '+919810000001', primaryRole: Role.Customer };

  beforeEach(() => {
    jwtMock = { signAsync: jest.fn().mockResolvedValue('signed-access-token') };
    prismaMock = {
      refreshToken: {
        create: jest.fn().mockResolvedValue({ id: 'rt1' }),
        findUnique: jest.fn(),
        update: jest.fn().mockResolvedValue({}),
        updateMany: jest.fn().mockResolvedValue({ count: 1 }),
      },
      $transaction: jest.fn(async (fn: (tx: unknown) => Promise<unknown>) =>
        fn({
          refreshToken: {
            create: prismaMock.refreshToken.create,
            update: prismaMock.refreshToken.update,
          },
        }),
      ),
    };
    service = new TokenService(jwtMock as never, prismaMock as never, config as never);
  });

  it('issues an access token and persists a hashed refresh token', async () => {
    const tokens = await service.issueTokenPair(user, 'device1');
    expect(tokens.accessToken).toBe('signed-access-token');
    expect(tokens.refreshToken).toBeTruthy();
    const created = prismaMock.refreshToken.create.mock.calls[0][0].data;
    expect(created.tokenHash).toHaveLength(64);
    expect(created.tokenHash).not.toBe(tokens.refreshToken); // stored hashed only
    expect(created.userId).toBe('u1');
  });

  it('rotates a valid refresh token: old revoked, new issued', async () => {
    prismaMock.refreshToken.findUnique.mockResolvedValue({
      id: 'rt_old',
      userId: 'u1',
      tokenHash: 'hash-of-presented',
      revokedAt: null,
      expiresAt: new Date(Date.now() + 60_000),
      user: { id: 'u1', phoneNumber: user.phoneNumber, primaryRole: Role.Customer, accountStatus: 'ACTIVE', isActive: true },
    });

    const result = await service.rotateRefreshToken('presented-token');
    expect(result.userId).toBe('u1');
    expect(prismaMock.refreshToken.update).toHaveBeenCalledWith(
      expect.objectContaining({ where: { id: 'rt_old' }, data: expect.objectContaining({ revokedAt: expect.any(Date) }) }),
    );
    // Exactly ONE new refresh token is minted per rotation.
    expect(prismaMock.refreshToken.create).toHaveBeenCalledTimes(1);
    expect(result.tokens.refreshToken).toBeTruthy();
    expect(result.tokens.refreshToken).not.toBe('presented-token');
  });

  it('rejects reuse of a rotated (revoked) refresh token', async () => {
    prismaMock.refreshToken.findUnique.mockResolvedValue({
      id: 'rt_old',
      userId: 'u1',
      tokenHash: 'hash',
      revokedAt: new Date(),
      expiresAt: new Date(Date.now() + 60_000),
      user: { id: 'u1', primaryRole: Role.Customer, accountStatus: 'ACTIVE' },
    });
    await expect(service.rotateRefreshToken('stolen-token')).rejects.toThrow(/invalid or expired/);
    expect(prismaMock.refreshToken.create).not.toHaveBeenCalled();
  });

  it('rejects expired refresh tokens', async () => {
    prismaMock.refreshToken.findUnique.mockResolvedValue({
      id: 'rt_old',
      userId: 'u1',
      tokenHash: 'hash',
      revokedAt: null,
      expiresAt: new Date(Date.now() - 1000),
      user: { id: 'u1', primaryRole: Role.Customer },
    });
    await expect(service.rotateRefreshToken('expired')).rejects.toThrow(/invalid or expired/);
  });

  it('rejects refresh for suspended accounts', async () => {
    prismaMock.refreshToken.findUnique.mockResolvedValue({
      id: 'rt_old',
      userId: 'u1',
      tokenHash: 'hash',
      revokedAt: null,
      expiresAt: new Date(Date.now() + 60_000),
      user: { id: 'u1', primaryRole: Role.Customer, accountStatus: 'SUSPENDED', isActive: true },
    });
    await expect(service.rotateRefreshToken('valid-but-suspended')).rejects.toThrow(/suspended/);
  });

  it('revokes all sessions for a user on security events', async () => {
    await service.revokeAllForUser('u1');
    expect(prismaMock.refreshToken.updateMany).toHaveBeenCalledWith(
      expect.objectContaining({ where: expect.objectContaining({ userId: 'u1' }) }),
    );
  });
});
