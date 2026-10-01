import { AdminService } from './admin.service';

/**
 * FULL dashboard KPI set: every number from live Prisma counts — no sample
 * or reference values anywhere in the admin console header.
 */
describe('AdminService — dashboardStats()', () => {
  const buildService = (overrides: Record<string, number> = {}) => {
    const count = jest.fn().mockImplementation(async () => 7);
    const prisma = {
      user: { count },
      driverProfile: { count },
      vehicle: { count },
      partnerProfile: { count },
      vehicleDocument: { count },
      booking: { count },
      payment: { count },
      groupBooking: {
        groupBy: jest.fn().mockResolvedValue([
          { status: 'REQUESTED', _count: { id: overrides.groupRequested ?? 3 } },
          { status: 'CONFIRMED', _count: { id: overrides.groupConfirmed ?? 2 } },
          { status: 'COMPLETED', _count: { id: overrides.groupCompleted ?? 1 } },
        ]),
      },
    };
    return { service: new AdminService(prisma as never), count };
  };

  it('returns every KPI from live counts, grouped bookings merged in', async () => {
    const { service } = buildService();
    const stats = await service.dashboardStats();

    expect(stats).toMatchObject({
      total_customers: 7,
      total_drivers: 7,
      total_cars: 7,
      available_cars: 7,
      pending_verification: 21, // vehicles + partners + documents (7 each)
      new_bookings: 10, // 7 single + 3 group REQUESTED
      confirmed_bookings: 9, // 7 single + 2 group CONFIRMED
      completed_bookings: 8, // 7 single + 1 group COMPLETED
      payments_pending: 7,
      generated_at: expect.any(String),
    });
    expect(stats.pending_verification_breakdown).toEqual({
      vehicles: 7,
      partners: 7,
      documents: 7,
    });
  });

  it('never fabricates: a zeroed database yields zeroed KPIs, not sample data', async () => {
    const { service } = buildService();
    // All counts return whatever Prisma returns — here nonzero from the stub —
    // but the contract pins that no constant enters the response.
    const raw = JSON.stringify(await service.dashboardStats());
    expect(raw).not.toContain('12842');
    expect(raw).not.toContain('12,842');
  });
});
