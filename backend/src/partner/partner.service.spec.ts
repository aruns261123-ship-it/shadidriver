import * as fs from 'fs';
import * as path from 'path';
import { VerificationStatus } from '@prisma/client';
import { PartnerService } from './partner.service';
import { UpdateVehicleDto } from './dto/partner.dto';

const ME = 'user-me';
const OTHER = 'user-other';
const MY_PARTNER = 'partner-1';
const OTHER_PARTNER = 'partner-2';
const MY_VEHICLE = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
const THEIR_VEHICLE = 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb';

function partnerRow(overrides: Record<string, unknown> = {}) {
  return {
    id: MY_PARTNER,
    userId: ME,
    companyName: 'Fleur Chauffeurs Pvt Ltd',
    contactName: 'Arun Kumar',
    baseCity: 'Delhi NCR',
    serviceCities: ['Delhi NCR'],
    languagesSpoken: ['Hindi'],
    experienceYears: 12,
    licenseNumber: 'DL-0420110000123',
    emergencyContactName: null,
    emergencyContactPhone: null,
    tradeLicenseNumber: null,
    panNumber: null,
    gstin: null,
    verificationStatus: VerificationStatus.PENDING_SUBMISSION,
    submittedAt: null,
    reviewedAt: null,
    decisionReason: null,
    ...overrides,
  };
}

function vehicleRow(overrides: Record<string, unknown> = {}) {
  return {
    id: MY_VEHICLE,
    fleetCode: 'SD-DEL-00001',
    vehicleTypeId: 'VT_THAR',
    fleetOwnerId: MY_PARTNER,
    yearOfManufacture: 2023,
    registrationNumber: 'DL01AB1234',
    color: 'Pearl White',
    fuelType: 'DIESEL',
    transmission: 'AUTOMATIC',
    city: 'Delhi NCR',
    serviceAreas: ['Delhi NCR'],
    amenityTags: ['AC'],
    photoUrls: [] as string[],
    verificationStatus: VerificationStatus.PENDING_SUBMISSION,
    isActive: true,
    isAvailable: true,
    ...overrides,
  };
}

describe('PartnerService', () => {
  let service: PartnerService;
  let prisma: any;
  let partner: Record<string, unknown>;
  let vehicles: Record<string, unknown>[];
  let upcomingBooking: { id: string } | null;

  function newVehicleDto(overrides: Record<string, unknown> = {}) {
    return {
      vehicleTypeId: 'VT_THAR',
      yearOfManufacture: 2024,
      registrationNumber: 'DL02CD5678',
      color: 'Black',
      fuelType: 'DIESEL',
      transmission: 'MANUAL',
      city: 'Delhi NCR',
      ...overrides,
    } as never;
  }

  function editDto(overrides: Record<string, unknown> = {}) {
    return { color: 'Black', ...overrides } as UpdateVehicleDto;
  }

  beforeEach(() => {
    partner = partnerRow();
    vehicles = [vehicleRow()];
    upcomingBooking = null;

    prisma = {
      user: {
        findUnique: jest.fn(async ({ where }: any) => ({
          id: where.id,
          primaryRole: 'driver',
        })),
        update: jest.fn(async ({ data }: any) => ({ id: ME, ...data })),
      },
      partnerProfile: {
        findUnique: jest.fn(async ({ where }: any) =>
          where.userId === ME || where.id === MY_PARTNER ? partner : null,
        ),
        update: jest.fn(async ({ data }: any) => {
          partner = { ...partner, ...data };
          return partner;
        }),
        create: jest.fn(async ({ data }: any) => {
          partner = { ...partnerRow(), ...data };
          return partner;
        }),
      },
      vehicle: {
        findUnique: jest.fn(async ({ where }: any) => {
          if (where.id) return vehicles.find((v) => v.id === where.id) ?? null;
          if (where.registrationNumber) {
            return (
              vehicles.find(
                (v) => v.registrationNumber === where.registrationNumber,
              ) ?? null
            );
          }
          if (where.fleetCode) {
            return vehicles.find((v) => v.fleetCode === where.fleetCode) ?? null;
          }
          return null;
        }),
        findMany: jest.fn(async ({ where }: any) =>
          vehicles.filter((v) => v.fleetOwnerId === where.fleetOwnerId),
        ),
        count: jest.fn(async ({ where }: any) =>
          vehicles.filter(
            (v) =>
              v.fleetOwnerId === where.fleetOwnerId &&
              (!where.fleetCode || String(v.fleetCode).startsWith(where.fleetCode.startsWith)),
          ).length,
        ),
        create: jest.fn(async ({ data }: any) => {
          const row = vehicleRow({ ...data });
          vehicles.push(row);
          return row;
        }),
        update: jest.fn(async ({ where, data }: any) => {
          const row: any = vehicles.find((v) => v.id === where.id);
          Object.assign(row, data);
          return row;
        }),
      },
      vehicleType: {
        findUnique: jest.fn(async ({ where }: any) => {
          if (where.id === 'VT_THAR') {
            return {
              id: 'VT_THAR',
              isActive: true,
              displayName: 'Mahindra Thar',
              seatingCap: 5,
              vehicleClass: 'PREMIUM_SUV',
            };
          }
          if (where.id === 'VT_INACTIVE') {
            return {
              id: 'VT_INACTIVE',
              isActive: false,
              displayName: 'Retired',
              seatingCap: 4,
              vehicleClass: 'VINTAGE',
            };
          }
          return null;
        }),
      },
      vehicleDocument: {
        upsert: jest.fn(async ({ where, create, update }: any) => ({
          id: 'doc-1',
          vehicleId: where.vehicleId_documentType.vehicleId,
          documentType: where.vehicleId_documentType.documentType,
          verificationStatus: create?.verificationStatus ?? update.verificationStatus,
          expiryDate: create?.expiryDate ?? update.expiryDate ?? null,
        })),
      },
      partnerDocument: {
        upsert: jest.fn(async ({ create, update }: any) => ({
          id: 'pdoc-1',
          documentType: create?.documentType,
          verificationStatus: create?.verificationStatus ?? update.verificationStatus,
          expiryDate: null,
        })),
        count: jest.fn(async () => 0),
      },
      availability: {
        findFirst: jest.fn(async () => upcomingBooking),
      },
      $transaction: jest.fn(async (fn: any) => fn(prisma)),
    };

    service = new PartnerService(prisma);
  });

  // ---------------------------------------------------------------- the gate

  describe('ownership (IDOR)', () => {
    it('reports another partner’s vehicle as NOT FOUND, never FORBIDDEN', async () => {
      vehicles.push(vehicleRow({ id: THEIR_VEHICLE, fleetOwnerId: OTHER_PARTNER }));

      // Not-found rather than forbidden: a forbidden response would confirm the
      // id exists, letting a partner enumerate the platform's fleet by probing.
      await expect(
        service.updateVehicle(ME, THEIR_VEHICLE, editDto()),
      ).rejects.toThrow(/not found/i);
      await expect(service.removeVehicle(ME, THEIR_VEHICLE)).rejects.toThrow(
        /not found/i,
      );
      await expect(
        service.addVehicleDocument(ME, THEIR_VEHICLE, {
          documentType: 'PUC',
          storagePath: 'x/y.pdf',
          mimeType: 'application/pdf',
        }),
      ).rejects.toThrow(/not found/i);
    });

    it('lists only the caller’s own fleet', async () => {
      vehicles.push(vehicleRow({ id: THEIR_VEHICLE, fleetOwnerId: OTHER_PARTNER }));
      const result = await service.listVehicles(ME);
      expect(result.items.map((v: any) => v.id)).toEqual([MY_VEHICLE]);
    });

    it('a non-partner account has no fleet access at all', async () => {
      await expect(service.listVehicles(OTHER)).rejects.toThrow(
        /register as a partner/i,
      );
    });
  });

  // ------------------------------------------------------------ registration

  describe('registration', () => {
    it('promotes a driver account to partner and never auto-approves it', async () => {
      const view = await service.register(ME, {
        companyName: 'Fleur Chauffeurs Pvt Ltd',
        baseCity: 'Delhi NCR',
      });

      expect(prisma.user.update).toHaveBeenCalledWith(
        expect.objectContaining({ data: { primaryRole: 'fleetOwner' } }),
      );
      expect(view.verification_status).toBe(VerificationStatus.PENDING_SUBMISSION);
      expect(view.is_verified).toBe(false);
      expect(view.can_receive_bookings).toBe(false);
    });

    it('does not demote an existing admin', async () => {
      prisma.user.findUnique.mockResolvedValue({ id: ME, primaryRole: 'superAdmin' });
      await service.register(ME, { companyName: 'X Fleet', baseCity: 'Delhi NCR' });
      expect(prisma.user.update).not.toHaveBeenCalled();
    });

    it('is idempotent for an already-registered partner', async () => {
      await service.register(ME, { companyName: 'Fleur Chauffeurs Pvt Ltd', baseCity: 'Delhi NCR' });
      const second = await service.register(ME, {
        companyName: 'Fleur Chauffeurs Pvt Ltd',
        baseCity: 'Delhi NCR',
        contactName: 'Arun Kumar',
      });
      expect(second.company_name).toBe('Fleur Chauffeurs Pvt Ltd');
      expect(prisma.partnerProfile.create).not.toHaveBeenCalled();
    });

    it('a suspended partner cannot edit its way out of suspension', async () => {
      partner = partnerRow({ verificationStatus: VerificationStatus.SUSPENDED });
      await expect(
        service.updateProfile(ME, { companyName: 'Renamed' }),
      ).rejects.toThrow(/suspended/i);
    });

    it('editing an APPROVED partner returns it to review', async () => {
      partner = partnerRow({ verificationStatus: VerificationStatus.APPROVED });
      const view = await service.updateProfile(ME, { serviceCities: ['Jaipur'] });

      expect(view.verification_status).toBe(VerificationStatus.UNDER_REVIEW);
      expect(view.is_verified).toBe(false);
    });

    it('editing a pending partner leaves it pending, not approved', async () => {
      const view = await service.updateProfile(ME, { contactName: 'Arun K' });
      expect(view.verification_status).toBe(VerificationStatus.PENDING_SUBMISSION);
    });
  });

  // -------------------------------------------------------------------- fleet

  describe('adding a vehicle', () => {
    it('starts unverified and explicitly NOT bookable', async () => {
      const view = await service.addVehicle(ME, newVehicleDto());

      expect(view.verification_status).toBe(VerificationStatus.PENDING_SUBMISSION);
      expect(view.is_bookable).toBe(false);
    });

    it('generates the fleet reference server-side', async () => {
      const view = await service.addVehicle(ME, newVehicleDto());
      expect(view.fleet_code).toMatch(/^SD-[A-Z]{3}-\d{5}$/);
    });

    it('normalises and de-duplicates the registration number', async () => {
      await expect(
        service.addVehicle(ME, newVehicleDto({ registrationNumber: 'dl 01 ab 1234' })),
      ).rejects.toThrow(/already registered/i);
    });

    it('refuses an unknown or inactive vehicle type', async () => {
      await expect(
        service.addVehicle(ME, newVehicleDto({ vehicleTypeId: 'VT_NOPE' })),
      ).rejects.toThrow(/unknown or inactive/i);

      await expect(
        service.addVehicle(ME, newVehicleDto({ vehicleTypeId: 'VT_INACTIVE' })),
      ).rejects.toThrow(/unknown or inactive/i);
    });

    it('cannot carry a price or a verification state', () => {
      // Tariffs are a separate reviewed resource, so the single-number pricing
      // model cannot be smuggled back in through the fleet endpoint.
      const source = fs.readFileSync(
        path.join(__dirname, 'dto', 'partner.dto.ts'),
        'utf8',
      );
      const block = source.slice(
        source.indexOf('export class AddVehicleDto'),
        source.indexOf('* Editable vehicle facts'),
      );
      expect(block.length).toBeGreaterThan(0);
      expect(block).not.toMatch(/price/i);
      expect(block).not.toMatch(/Paise/);
      expect(block).not.toMatch(/verificationStatus/i);
      expect(block).not.toMatch(/isActive/i);
    });
  });

  describe('editing a vehicle', () => {
    it('sends an APPROVED vehicle back for re-review', async () => {
      vehicles[0] = vehicleRow({ verificationStatus: VerificationStatus.APPROVED });
      const view = await service.updateVehicle(ME, MY_VEHICLE, editDto());

      expect(view.verification_status).toBe(VerificationStatus.PENDING_SUBMISSION);
      expect(view.is_bookable).toBe(false);
    });

    it('leaves a pending vehicle pending', async () => {
      const view = await service.updateVehicle(ME, MY_VEHICLE, editDto());
      expect(view.verification_status).toBe(VerificationStatus.PENDING_SUBMISSION);
    });

    it('cannot change the registration number or the vehicle type', async () => {
      const view = await service.updateVehicle(
        ME,
        MY_VEHICLE,
        editDto({ registrationNumber: 'DL99ZZ9999', vehicleTypeId: 'VT_OTHER' }),
      );

      // Neither field is on the update DTO and the service never writes them,
      // so they survive an edit attempt untouched.
      expect(view.registration_number).toBe('DL01AB1234');
      expect(view.vehicle_type_id).toBe('VT_THAR');
    });
  });

  describe('removing a vehicle', () => {
    it('is refused while the vehicle is committed to an upcoming booking', async () => {
      upcomingBooking = { id: 'avail-1' };
      await expect(service.removeVehicle(ME, MY_VEHICLE)).rejects.toThrow(
        /committed to an upcoming booking/i,
      );
    });

    it('soft-removes a free vehicle from the bookable fleet', async () => {
      const view = await service.removeVehicle(ME, MY_VEHICLE);
      expect(view.is_active).toBe(false);
      expect(view.is_available).toBe(false);
      expect(view.is_bookable).toBe(false);
      // The row survives: past bookings still reference the vehicle.
      expect(vehicles).toHaveLength(1);
    });
  });

  // --------------------------------------------------------------- documents

  describe('documents', () => {
    it('re-uploading vehicle paperwork clears its previous verification', async () => {
      await service.addVehicleDocument(ME, MY_VEHICLE, {
        documentType: 'COMMERCIAL_INSURANCE',
        storagePath: 'veh/insurance.pdf',
        mimeType: 'application/pdf',
      });
      const call = prisma.vehicleDocument.upsert.mock.calls[0][0];
      expect(call.update.verificationStatus).toBe('PENDING_REVIEW');
      expect(call.update.verifiedBy).toBeNull();
      expect(call.update.verifiedAt).toBeNull();
    });

    it('rejects a document for a vehicle the caller does not own', async () => {
      vehicles.push(vehicleRow({ id: THEIR_VEHICLE, fleetOwnerId: OTHER_PARTNER }));
      await expect(
        service.addVehicleDocument(ME, THEIR_VEHICLE, {
          documentType: 'PUC',
          storagePath: 'veh/puc.pdf',
          mimeType: 'application/pdf',
        }),
      ).rejects.toThrow(/not found/i);
    });
  });

  // ------------------------------------------------------------ verification

  describe('submitting for verification', () => {
    it('requires at least one active vehicle', async () => {
      vehicles = [];
      await expect(service.submitForReview(ME)).rejects.toThrow(
        /at least one vehicle/i,
      );
    });

    it('moves a partner with a fleet into SUBMITTED', async () => {
      const view = await service.submitForReview(ME);
      expect(view.verification_status).toBe(VerificationStatus.SUBMITTED);
      expect(view.can_receive_bookings).toBe(false);
    });

    it('a SUSPENDED partner cannot resubmit', async () => {
      partner = partnerRow({ verificationStatus: VerificationStatus.SUSPENDED });
      await expect(service.submitForReview(ME)).rejects.toThrow(/suspended/i);
    });

    it('a verified PARTNER still does not make its vehicles bookable', async () => {
      partner = partnerRow({ verificationStatus: VerificationStatus.APPROVED });

      const profile = await service.getProfile(ME);
      expect(profile.is_verified).toBe(true);

      const fleet = await service.listVehicles(ME);
      expect(fleet.items[0].verification_status).toBe(
        VerificationStatus.PENDING_SUBMISSION,
      );
      expect(fleet.items[0].is_bookable).toBe(false);
    });
  });
});
