/* eslint-disable no-console */
import { PrismaClient, BookingStatus, DutyStatus, VerificationStatus } from '@prisma/client';

/**
 * Development seed — realistic Delhi NCR ceremonial fleet data.
 * Contains NO real credentials; phone numbers are 9810000001–9810000015,
 * clearly synthetic. Admin accounts exist for local API exploration only.
 */
const prisma = new PrismaClient();

async function main(): Promise<void> {
  console.log('Seeding ShadiDriver development data…');

  // ------------------------------------------------------------------ users
  const adminOps = await prisma.user.upsert({
    where: { phoneNumber: '+9198100000011' },
    update: {},
    create: {
      phoneNumber: '+9198100000011',
      fullName: 'Ops Control (Dev)',
      primaryRole: 'operationsAdmin',
      isPhoneVerified: true,
    },
  });
  const adminVerify = await prisma.user.upsert({
    where: { phoneNumber: '+9198100000012' },
    update: {},
    create: {
      phoneNumber: '+9198100000012',
      fullName: 'Verification Desk (Dev)',
      primaryRole: 'verificationAdmin',
      isPhoneVerified: true,
    },
  });

  const customer = await prisma.user.upsert({
    where: { phoneNumber: '+919810000001' },
    update: {},
    create: {
      phoneNumber: '+919810000001',
      fullName: 'Aarav Sharma',
      primaryRole: 'customer',
      isPhoneVerified: true,
    },
  });
  await prisma.customerProfile.upsert({
    where: { userId: customer.id },
    update: {},
    create: { userId: customer.id },
  });

  const fleetOwnerUser = await prisma.user.upsert({
    where: { phoneNumber: '+9198100000013' },
    update: {},
    create: {
      phoneNumber: '+9198100000013',
      fullName: 'Dev Fleur Chauffeurs Pvt Ltd',
      primaryRole: 'fleetOwner',
      isPhoneVerified: true,
    },
  });
  const fleetOwner = await prisma.fleetOwnerProfile.upsert({
    where: { userId: fleetOwnerUser.id },
    update: {},
    create: { userId: fleetOwnerUser.id, companyName: 'Fleur Chauffeurs Pvt Ltd' },
  });

  const driverUsersData = [
    { phone: '+919810000002', name: 'Rajesh Kumar', exp: 12, languages: ['Hindi', 'English', 'Punjabi'] },
    { phone: '+919810000003', name: 'Suresh Yadav', exp: 8, languages: ['Hindi', 'English'] },
    { phone: '+919810000004', name: 'Vijay Singh', exp: 15, languages: ['Hindi', 'English', 'Haryanvi'] },
    { phone: '+919810000005', name: 'Anil Chauhan', exp: 6, languages: ['Hindi'] },
    { phone: '+919810000006', name: 'Manoj Tiwari', exp: 10, languages: ['Hindi', 'English'] },
  ];
  const drivers = [];
  for (const d of driverUsersData) {
    const u = await prisma.user.upsert({
      where: { phoneNumber: d.phone },
      update: {},
      create: { phoneNumber: d.phone, fullName: d.name, primaryRole: 'driver', isPhoneVerified: true },
    });
    const profile = await prisma.driverProfile.upsert({
      where: { userId: u.id },
      update: {},
      create: {
        userId: u.id,
        fleetOwnerId: fleetOwner.id,
        experienceYears: d.exp,
        languagesSpoken: d.languages,
        dutyStatus: DutyStatus.AVAILABLE,
        verificationStatus: VerificationStatus.APPROVED,
        bio: `${d.exp} years of premium ceremonial & corporate chauffeuring across Delhi NCR.`,
      },
    });
    drivers.push(profile);
  }

  // ------------------------------------------------------------ vehicle types
  const vehicleTypesData = [
    { id: 'VT_INNOVA_CRYSTA', make: 'Toyota', model: 'Innova Crysta', displayName: 'Toyota Innova Crysta', seatingCap: 6, vehicleClass: 'EXECUTIVE_MPV', amenityTags: ['Dual AC', 'Charging Ports'] },
    { id: 'VT_CAMRY', make: 'Toyota', model: 'Camry', displayName: 'Toyota Camry Hybrid', seatingCap: 4, vehicleClass: 'LUXURY_SEDAN', amenityTags: ['Dual AC', 'Leather Interior'] },
    { id: 'VT_BMW5', make: 'BMW', model: '5 Series', displayName: 'BMW 5 Series', seatingCap: 4, vehicleClass: 'LUXURY_SEDAN', amenityTags: ['Dual AC', 'Sunroof', 'Ambient Lighting'] },
    { id: 'VT_MERCEDES_E', make: 'Mercedes-Benz', model: 'E-Class', displayName: 'Mercedes-Benz E-Class', seatingCap: 4, vehicleClass: 'ULTRA_LUXURY', amenityTags: ['Dual AC', 'Chauffeur Partition'] },
  ];
  for (const vt of vehicleTypesData) {
    await prisma.vehicleType.upsert({ where: { id: vt.id }, update: {}, create: vt });
  }

  // ---------------------------------------------------------------- vehicles
  const vehiclesData = [
    { fleetCode: 'FLR-INN-01', typeId: 'VT_INNOVA_CRYSTA', reg: 'DL01CX1001', city: 'Delhi NCR', price: 2500000n, driverIdx: 0 },
    { fleetCode: 'FLR-INN-02', typeId: 'VT_INNOVA_CRYSTA', reg: 'DL01CX1002', city: 'Delhi NCR', price: 2500000n, driverIdx: 1 },
    { fleetCode: 'FLR-INN-03', typeId: 'VT_INNOVA_CRYSTA', reg: 'DL01CX1003', city: 'Delhi NCR', price: 2500000n, driverIdx: 2 },
    { fleetCode: 'FLR-INN-04', typeId: 'VT_INNOVA_CRYSTA', reg: 'DL01CX1004', city: 'Gurugram', price: 2500000n, driverIdx: 3 },
    { fleetCode: 'FLR-INN-05', typeId: 'VT_INNOVA_CRYSTA', reg: 'DL01CX1005', city: 'Noida', price: 2500000n, driverIdx: 4 },
    { fleetCode: 'FLR-CAM-01', typeId: 'VT_CAMRY', reg: 'DL01CX2001', city: 'Delhi NCR', price: 3000000n, driverIdx: 1 },
    { fleetCode: 'FLR-CAM-02', typeId: 'VT_CAMRY', reg: 'DL01CX2002', city: 'Delhi NCR', price: 3000000n, driverIdx: 2 },
    { fleetCode: 'FLR-BMW-01', typeId: 'VT_BMW5', reg: 'DL01CX3001', city: 'Delhi NCR', price: 4500000n, driverIdx: 0 },
    { fleetCode: 'FLR-BMW-02', typeId: 'VT_BMW5', reg: 'DL01CX3002', city: 'Gurugram', price: 4500000n, driverIdx: 3 },
    { fleetCode: 'FLR-MER-01', typeId: 'VT_MERCEDES_E', reg: 'DL01CX4001', city: 'Delhi NCR', price: 5500000n, driverIdx: 4 },
  ];
  const vehicles = [];
  for (const v of vehiclesData) {
    const vt = vehicleTypesData.find((t) => t.id === v.typeId)!;
    const vehicle = await prisma.vehicle.upsert({
      where: { fleetCode: v.fleetCode },
      update: {},
      create: {
        fleetCode: v.fleetCode,
        vehicleTypeId: v.typeId,
        fleetOwnerId: fleetOwner.id,
        yearOfManufacture: 2023,
        color: 'Pearl White',
        registrationNumber: v.reg,
        fuelType: 'PETROL',
        basePricePaise: v.price,
        city: v.city,
        verificationStatus: VerificationStatus.APPROVED,
        amenityTags: vt.amenityTags,
        serviceAreas: ['Delhi NCR', 'Gurugram', 'Noida', 'Faridabad', 'Ghaziabad'],
      },
    });
    vehicles.push(vehicle);
  }

  // Link each vehicle to its primary chauffeur via fleet roster.
  for (const v of vehicles) {
    const idx = vehiclesData.find((d) => d.fleetCode === v.fleetCode)!.driverIdx;
    await prisma.vehicle.update({
      where: { id: v.id },
      data: { independentDriverId: drivers[idx].id },
    });
  }

  // ------------------------------------------------------ categories & addons
  const categories = [
    { id: 'SVC_BARAAT', title: 'Baraat Procession', description: 'Grand baraat entry with decorated ceremonial vehicles.', displayOrder: 1 },
    { id: 'SVC_VIDAI', title: 'Vidai', description: 'Graceful vidai departure fleet.', displayOrder: 2 },
    { id: 'SVC_RECEPTION', title: 'Reception VIP', description: 'VIP arrival for receptions and engagements.', displayOrder: 3 },
    { id: 'SVC_AIRPORT_VIP', title: 'Airport / VIP Transfer', description: 'Discreet premium transfers for guests.', displayOrder: 4 },
  ];
  for (const c of categories) {
    await prisma.serviceCategory.upsert({ where: { id: c.id }, update: {}, create: c });
  }

  const addons = [
    { name: 'Floral Vehicle Decoration', pricePaise: 350000n, category: 'SVC_BARAAT' },
    { name: 'Chauffeur Safa & Jodhpuri Attire', pricePaise: 150000n, category: 'SVC_BARAAT' },
    { name: 'Welcome refreshment hamper', pricePaise: 80000n, category: 'SVC_RECEPTION' },
  ];
  for (const a of addons) {
    await prisma.serviceAddon.upsert({
      where: { id: (await findOrCreateAddon(a.name)).id },
      update: { pricePaise: a.pricePaise },
      create: { name: a.name, pricePaise: a.pricePaise, serviceCategoryId: a.category },
    });
  }

  // ------------------------------------------------------------ pricing rules
  const pricingRules = [
    { cat: 'SVC_BARAAT', vc: 'EXECUTIVE_MPV', base: 2500000n, extraHour: 250000n },
    { cat: 'SVC_BARAAT', vc: 'LUXURY_SEDAN', base: 3500000n, extraHour: 350000n },
    { cat: 'SVC_BARAAT', vc: 'ULTRA_LUXURY', base: 5500000n, extraHour: 550000n },
    { cat: 'SVC_VIDAI', vc: 'EXECUTIVE_MPV', base: 2200000n, extraHour: 220000n },
    { cat: 'SVC_AIRPORT_VIP', vc: 'LUXURY_SEDAN', base: 1800000n, extraHour: 180000n },
  ];
  for (const r of pricingRules) {
    const existing = await prisma.pricingRule.findFirst({
      where: { serviceCategoryId: r.cat, vehicleClass: r.vc, cityCode: 'DEL', isActive: true },
    });
    if (!existing) {
      await prisma.pricingRule.create({
        data: {
          serviceCategoryId: r.cat,
          vehicleClass: r.vc,
          cityCode: 'DEL',
          baseHours: 8,
          baseKm: 80,
          baseRatePaise: r.base,
          extraHourRatePaise: r.extraHour,
          extraKmRatePaise: 15000n,
          nightAllowancePaise: 200000n,
          effectiveFrom: new Date('2026-01-01T00:00:00Z'),
        },
      });
    }
  }

  // ------------------------------------------------------------ booking policy
  const policyExisting = await prisma.bookingPolicy.findFirst({ where: { isDefault: true } });
  if (!policyExisting) {
    await prisma.bookingPolicy.create({
      data: {
        policyName: 'MVP Default Policy (Dev)',
        advanceTokenPercentage: 25.0,
        cancellationTiers: [
          { hours_before: 168, refund_percent: 100 },
          { hours_before: 72, refund_percent: 75 },
          { hours_before: 24, refund_percent: 50 },
          { hours_before: 0, refund_percent: 0 },
        ],
        gracePeriodMinutes: 30,
        overtimeIncrementMinutes: 30,
        isDefault: true,
      },
    });
  }

  // ------------------------------------------------------------ sample booking
  const existingBooking = await prisma.booking.findUnique({
    where: { idempotencyKey: 'seed-sample-booking-0001' },
  });
  if (!existingBooking) {
    const start = nextSaturdayEvening();
    const end = new Date(start.getTime() + 8 * 3600_000);
    await prisma.booking.create({
      data: {
        referenceCode: 'SD-2026-0101',
        customerFk: customer.id,
        driverFk: drivers[0].id,
        vehicleFk: vehicles[0].id,
        serviceCategoryId: 'SVC_BARAAT',
        ceremonyType: 'Baraat',
        ceremonialAttire: 'Royal Bandhgala & Gold Safa',
        serviceStartTime: start,
        serviceEndTime: end,
        city: 'Delhi NCR',
        pickupAddress: 'The Oberoi, Dr Zakir Hussain Marg, New Delhi',
        destinationAddress: 'Grand Imperial Banquets, MG Road, Gurugram',
        venueName: 'Grand Imperial Ballroom',
        primaryContactName: 'Aarav Sharma',
        primaryContactPhone: '9810000001',
        passengerCount: 4,
        estimatedTotalPaise: 2500000n,
        advanceTokenPaise: 625000n,
        status: BookingStatus.REQUESTED,
        idempotencyKey: 'seed-sample-booking-0001',
      },
    });
  }

  console.log('Seed complete.');
  console.log(`  users: admin ops +${adminOps.phoneNumber.slice(-10)}, verification +admin, customer, 5 drivers`);
  console.log(`  vehicles: ${vehicles.length} across 4 types`);
}

async function findOrCreateAddon(name: string) {
  const existing = await prisma.serviceAddon.findFirst({ where: { name } });
  return existing ?? prisma.serviceAddon.create({ data: { name, pricePaise: 0n } });
}

/** Next Saturday 16:00 local — a plausible wedding slot. */
function nextSaturdayEvening(): Date {
  const now = new Date();
  const result = new Date(now);
  result.setDate(now.getDate() + ((6 - now.getDay() + 7) % 7 || 7));
  result.setHours(16, 0, 0, 0);
  return result;
}

main()
  .catch((e) => {
    console.error(e);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
