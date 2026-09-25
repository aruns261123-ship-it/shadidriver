import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import {
  ArrayMaxSize,
  IsArray,
  IsInt,
  IsIn,
  IsOptional,
  IsString,
  IsUUID,
  IsDateString,
  Length,
  Matches,
  Max,
  Min,
} from 'class-validator';

/** E.164, same rule the auth contract uses. */
export const E164_REGEX = /^\+[1-9]\d{7,14}$/;
/** Indian commercial plate, tolerant of spacing/hyphens: DL01AB1234. */
export const REGISTRATION_NUMBER_REGEX =
  /^[A-Z]{2}[ -]?[0-9]{1,2}[ -]?[A-Z]{0,3}[ -]?[0-9]{4}$/;
export const PAN_REGEX = /^[A-Z]{5}[0-9]{4}[A-Z]$/;
export const GSTIN_REGEX = /^[0-9]{2}[A-Z]{5}[0-9]{4}[A-Z][0-9A-Z]Z[0-9A-Z]$/;

export const TRANSMISSIONS = ['AUTOMATIC', 'MANUAL'] as const;
export const FUEL_TYPES = [
  'PETROL',
  'DIESEL',
  'CNG',
  'ELECTRIC',
  'HYBRID',
] as const;
export const PARTNER_DOCUMENT_TYPES = [
  'PARTNER_IDENTITY',
  'DRIVING_LICENCE',
  'TRADE_LICENSE',
  'POLICE_VERIFICATION',
  'GST_CERTIFICATE',
  'BANK_PROOF',
] as const;
export const VEHICLE_DOCUMENT_TYPES = [
  'REGISTRATION_CERTIFICATE',
  'COMMERCIAL_INSURANCE',
  'PUC',
  'FITNESS_CERTIFICATE',
  'COMMERCIAL_PERMIT',
  'VEHICLE_TAX',
] as const;

/** Step 1–3 of partner onboarding: account + professional details + intent. */
export class RegisterPartnerDto {
  @ApiProperty({ example: 'Fleur Chauffeurs Pvt Ltd' })
  @IsString()
  @Length(2, 200)
  companyName!: string;

  @ApiPropertyOptional({ example: 'Arun Kumar' })
  @IsOptional()
  @IsString()
  @Length(2, 150)
  contactName?: string;

  @ApiProperty({ example: 'Delhi NCR' })
  @IsString()
  @Length(2, 50)
  baseCity!: string;

  @ApiPropertyOptional({ example: ['Delhi NCR', 'Jaipur'] })
  @IsOptional()
  @IsArray()
  @ArrayMaxSize(10)
  @IsString({ each: true })
  @Length(2, 50, { each: true })
  serviceCities?: string[];

  @ApiPropertyOptional({ example: ['Hindi', 'English'] })
  @IsOptional()
  @IsArray()
  @ArrayMaxSize(10)
  @IsString({ each: true })
  @Length(2, 30, { each: true })
  languagesSpoken?: string[];

  @ApiPropertyOptional({ example: 12 })
  @IsOptional()
  @IsInt()
  @Min(0)
  @Max(60)
  experienceYears?: number;

  @ApiPropertyOptional({ example: 'DL-0420110000123' })
  @IsOptional()
  @IsString()
  @Length(5, 50)
  licenseNumber?: string;

  @ApiPropertyOptional({ example: 'Sunita Sharma' })
  @IsOptional()
  @IsString()
  @Length(2, 150)
  emergencyContactName?: string;

  @ApiPropertyOptional({ example: '+919810000009' })
  @IsOptional()
  @IsString()
  @Matches(E164_REGEX, { message: 'emergencyContactPhone must be an E.164 string' })
  emergencyContactPhone?: string;

  @ApiPropertyOptional({ example: 'DL-ABC-12345' })
  @IsOptional()
  @IsString()
  @Length(4, 100)
  tradeLicenseNumber?: string;

  @ApiPropertyOptional({ example: 'AABCU9603R' })
  @IsOptional()
  @IsString()
  @Matches(PAN_REGEX, { message: 'panNumber must be a valid PAN' })
  panNumber?: string;

  @ApiPropertyOptional({ example: '07AABCU9603R1ZM' })
  @IsOptional()
  @IsString()
  @Matches(GSTIN_REGEX, { message: 'gstin must be a valid 15-character GSTIN' })
  gstin?: string;
}

/** Editable professional details. Company/legal identity fields are included. */
export class UpdatePartnerProfileDto {
  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  @Length(2, 200)
  companyName?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  @Length(2, 150)
  contactName?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  @Length(2, 50)
  baseCity?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsArray()
  @ArrayMaxSize(10)
  @IsString({ each: true })
  @Length(2, 50, { each: true })
  serviceCities?: string[];

  @ApiPropertyOptional()
  @IsOptional()
  @IsArray()
  @ArrayMaxSize(10)
  @IsString({ each: true })
  @Length(2, 30, { each: true })
  languagesSpoken?: string[];

  @ApiPropertyOptional()
  @IsOptional()
  @IsInt()
  @Min(0)
  @Max(60)
  experienceYears?: number;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  @Length(5, 50)
  licenseNumber?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  @Length(2, 150)
  emergencyContactName?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  @Matches(E164_REGEX, { message: 'emergencyContactPhone must be an E.164 string' })
  emergencyContactPhone?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  @Length(4, 100)
  tradeLicenseNumber?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  @Matches(PAN_REGEX, { message: 'panNumber must be a valid PAN' })
  panNumber?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  @Matches(GSTIN_REGEX, { message: 'gstin must be a valid 15-character GSTIN' })
  gstin?: string;
}

/**
 * Step 4 of onboarding: one vehicle in the partner's fleet.
 *
 * A partner registers MANY of these. Note what is deliberately absent:
 * `verificationStatus` (admin-only), `isAvailable`/`isActive` (platform
 * controlled) and any price — tariffs are a separate, reviewed resource so the
 * "one simple number" model is not reintroduced.
 */
export class AddVehicleDto {
  @ApiProperty({ example: 'VT_INNOVA_CRYSTA' })
  @IsString()
  @Length(2, 50)
  vehicleTypeId!: string;

  @ApiProperty({ example: 2023 })
  @IsInt()
  @Min(1980)
  @Max(2100)
  yearOfManufacture!: number;

  @ApiProperty({ example: 'DL01AB1234' })
  @IsString()
  @Matches(REGISTRATION_NUMBER_REGEX, {
    message: 'registrationNumber must look like an Indian plate (e.g. DL01AB1234)',
  })
  registrationNumber!: string;

  @ApiProperty({ example: 'Pearl White' })
  @IsString()
  @Length(2, 30)
  color!: string;

  @ApiProperty({ example: 'DIESEL' })
  @IsIn(FUEL_TYPES as unknown as string[])
  fuelType!: string;

  @ApiProperty({ example: 'AUTOMATIC' })
  @IsIn(TRANSMISSIONS as unknown as string[])
  transmission!: string;

  @ApiProperty({ example: 'Delhi NCR' })
  @IsString()
  @Length(2, 50)
  city!: string;

  @ApiPropertyOptional({ example: ['Delhi NCR', 'Gurugram'] })
  @IsOptional()
  @IsArray()
  @ArrayMaxSize(10)
  @IsString({ each: true })
  @Length(2, 50, { each: true })
  serviceAreas?: string[];

  @ApiPropertyOptional({ example: ['Sunroof', 'Chauffeur Safa'] })
  @IsOptional()
  @IsArray()
  @ArrayMaxSize(20)
  @IsString({ each: true })
  @Length(2, 60, { each: true })
  amenities?: string[];

  @ApiPropertyOptional({ example: ['https://cdn.example/thar-1.jpg'] })
  @IsOptional()
  @IsArray()
  @ArrayMaxSize(12)
  @IsString({ each: true })
  @Length(8, 500, { each: true })
  photoUrls?: string[];
}

/**
 * Editable vehicle facts. `registrationNumber` and `vehicleTypeId` are not
 * editable here: they change identity and commercial class, so they require a
 * fresh submission rather than a silent edit.
 */
export class UpdateVehicleDto {
  @ApiPropertyOptional()
  @IsOptional()
  @IsInt()
  @Min(1980)
  @Max(2100)
  yearOfManufacture?: number;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  @Length(2, 30)
  color?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsIn(FUEL_TYPES as unknown as string[])
  fuelType?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsIn(TRANSMISSIONS as unknown as string[])
  transmission?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  @Length(2, 50)
  city?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsArray()
  @ArrayMaxSize(10)
  @IsString({ each: true })
  @Length(2, 50, { each: true })
  serviceAreas?: string[];

  @ApiPropertyOptional()
  @IsOptional()
  @IsArray()
  @ArrayMaxSize(20)
  @IsString({ each: true })
  @Length(2, 60, { each: true })
  amenities?: string[];

  @ApiPropertyOptional()
  @IsOptional()
  @IsArray()
  @ArrayMaxSize(12)
  @IsString({ each: true })
  @Length(8, 500, { each: true })
  photoUrls?: string[];
}

/** Vehicle paperwork. Re-submitting the same type replaces it (re-review). */
export class AddVehicleDocumentDto {
  @ApiProperty({ example: 'COMMERCIAL_INSURANCE' })
  @IsIn(VEHICLE_DOCUMENT_TYPES as unknown as string[])
  documentType!: string;

  @ApiPropertyOptional({ example: 'POL-99887766' })
  @IsOptional()
  @IsString()
  @Length(2, 100)
  documentNumber?: string;

  @ApiProperty({ example: 'partners/veh-1/insurance-2026.pdf' })
  @IsString()
  @Length(3, 500)
  storagePath!: string;

  @ApiProperty({ example: 'application/pdf' })
  @IsString()
  @Length(3, 50)
  mimeType!: string;

  @ApiPropertyOptional({ example: '2026-01-01' })
  @IsOptional()
  @IsDateString()
  issuedDate?: string;

  @ApiPropertyOptional({ example: '2027-01-01' })
  @IsOptional()
  @IsDateString()
  expiryDate?: string;
}

/** Partner-level compliance paperwork. */
export class AddPartnerDocumentDto {
  @ApiProperty({ example: 'PARTNER_IDENTITY' })
  @IsIn(PARTNER_DOCUMENT_TYPES as unknown as string[])
  documentType!: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  @Length(2, 100)
  documentNumber?: string;

  @ApiProperty({ example: 'partners/p-1/pan.pdf' })
  @IsString()
  @Length(3, 500)
  storagePath!: string;

  @ApiProperty({ example: 'application/pdf' })
  @IsString()
  @Length(3, 50)
  mimeType!: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsDateString()
  issuedDate?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsDateString()
  expiryDate?: string;
}

/** Internal: id-typed params are validated so a malformed id never hits SQL. */
export class VehicleIdParamDto {
  @IsUUID()
  vehicleId!: string;
}
