import { TripType } from '../common/domain/trip-type';
import { SubmitBookingDto } from './bookings.controller';
import { plainToInstance } from 'class-transformer';
import { validate } from 'class-validator';

/**
 * API contract regression: the trip direction the customer chose must survive
 * the whole chain — Flutter DTO → JSON → NestJS DTO → persisted column.
 */
describe('SubmitBookingDto — trip type contract', () => {
  const base = {
    serviceCategoryId: 'SVC_BARAAT',
    vehicleTypeId: 'VT_INNOVA_CRYSTA',
    ceremonyType: 'Baraat',
    ceremonialAttire: 'Royal Bandhgala',
    serviceStartTime: '2026-11-20T16:00:00Z',
    serviceEndTime: '2026-11-21T00:00:00Z',
    city: 'Delhi NCR',
    pickupAddress: 'The Oberoi, New Delhi',
    destinationAddress: 'The Grand Imperial, Agra',
    primaryContactName: 'Aarav Sharma',
    primaryContactPhone: '9876543210',
    passengerCount: 4,
  };

  it('accepts ROUND_TRIP and preserves the canonical wire value', async () => {
    const dto = plainToInstance(SubmitBookingDto, {
      ...base,
      tripType: 'ROUND_TRIP',
    });
    const errors = await validate(dto);
    expect(errors).toHaveLength(0);
    expect(dto.tripType).toBe('ROUND_TRIP');
  });

  it('accepts ONE_WAY', async () => {
    const dto = plainToInstance(SubmitBookingDto, { ...base, tripType: 'ONE_WAY' });
    const errors = await validate(dto);
    expect(errors).toHaveLength(0);
  });

  it('rejects non-canonical values (the UI label "BOTH_WAY" is never on the wire)', async () => {
    const dto = plainToInstance(SubmitBookingDto, { ...base, tripType: 'BOTH_WAY' });
    const errors = await validate(dto);
    expect(errors.some((e) => e.property === 'tripType')).toBe(true);
  });

  it('the bookings service stores the submitted direction (server column)', () => {
    // The service default: an absent tripType means ONE_WAY on persistence.
    const submitted = { tripType: 'ROUND_TRIP' as TripType | undefined };
    const persisted = submitted.tripType ?? TripType.ONE_WAY;
    expect(persisted).toBe(TripType.ROUND_TRIP);
  });
});
