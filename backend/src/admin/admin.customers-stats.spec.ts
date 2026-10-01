import { AdminService } from './admin.service';

/**
 * REAL customer statistics: the admin service must return counts derived
 * from the users table — never sample values. This regression pins the
 * contract (keys + shapes) and proves the numbers come from Prisma counts.
 */
describe('AdminService — customerStats()', () => {
  const buildService = () => {
    const calls: unknown[][] = [];
    const prisma = {
      user: {
        count: jest.fn().mockImplementation(async (where?: unknown) => {
          calls.push([where]);
          return 42;
        }),
      },
    };
    return { service: new AdminService(prisma as never), calls };
  };

  it('returns real totals/new/active shaped for the admin console', async () => {
    const { service } = buildService();
    const stats = await service.customerStats();
    expect(stats).toEqual({
      total_customers: 42,
      new_customers_30d: 42,
      active_customers: 42,
      generated_at: expect.any(String),
    });
  });

  it('counts only non-deleted customer-primaried accounts', async () => {
    const { service, calls } = buildService();
    await service.customerStats();
    const whereOf = (i: number) => (calls[i][0] as { where: unknown }).where;
    expect(whereOf(0)).toMatchObject({ primaryRole: 'customer', deletedAt: null });
    // New = created within the trailing 30 days.
    expect(whereOf(1)).toMatchObject({ createdAt: { gte: expect.any(Date) } });
    // Active = placed at least one booking or group booking.
    expect(whereOf(2)).toHaveProperty('OR');
    expect(whereOf(2)).toMatchObject({
      primaryRole: 'customer',
      deletedAt: null,
    });
  });
});
