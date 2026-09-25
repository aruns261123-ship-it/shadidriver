import { ApiProperty } from '@nestjs/swagger';
import {
  IsIn,
  IsOptional,
  IsString,
  Length,
  Matches,
  MaxLength,
} from 'class-validator';

/**
 * Canonical API phone contract (E.164): `+<countrycode><subscriber>`, digits
 * only after the leading `+`, 8–15 digits total (ITU-T E.164) — e.g.
 * `+919876543210`.
 *
 * Indian numbers are additionally validated with an explicit subscriber-prefix
 * rule (`[6-9]`) so the accepted format is exact, not merely "any E.164".
 * The regex is shared with the frontend normalizer (tests assert parity) so
 * client and server always agree on the wire format.
 */
export const PHONE_NUMBER_REGEX = /^\+[1-9]\d{7,14}$/;
export const INDIAN_MOBILE_REGEX = /^\+91[6-9]\d{9}$/;

export class RequestOtpDto {
  @ApiProperty({ example: '+919810000001' })
  @IsString()
  @Matches(PHONE_NUMBER_REGEX, {
    message:
      'phoneNumber must be an E.164 string like +919876543210 (leading +, no spaces or formatting characters).',
  })
  phoneNumber!: string;

  @ApiProperty({ enum: ['LOGIN', 'SIGNUP'], default: 'LOGIN' })
  @IsOptional()
  @IsIn(['LOGIN', 'SIGNUP'])
  purpose?: 'LOGIN' | 'SIGNUP';
}

export class VerifyOtpDto {
  @ApiProperty()
  @IsString()
  @Length(16, 64)
  sessionId!: string;

  @ApiProperty({ example: '849201' })
  @IsString()
  @Matches(/^\d{6}$/)
  otpCode!: string;

  @ApiProperty({ required: false })
  @IsOptional()
  @IsString()
  @MaxLength(128)
  deviceId?: string;
}

export class SignUpDto {
  @ApiProperty({ example: '+919810000009' })
  @IsString()
  @Matches(PHONE_NUMBER_REGEX, {
    message:
      'phoneNumber must be an E.164 string like +919876543210 (leading +, no spaces or formatting characters).',
  })
  @Matches(INDIAN_MOBILE_REGEX, {
    message:
      'phoneNumber must be a valid Indian mobile (+91 followed by a 10-digit number starting 6-9).',
  })
  phoneNumber!: string;

  @ApiProperty({ example: 'Aarav Sharma' })
  @IsString()
  @Length(2, 150)
  displayName!: string;

  @ApiProperty({ enum: ['customer', 'driver'], default: 'customer' })
  @IsIn(['customer', 'driver'])
  role!: 'customer' | 'driver';
}

export class RefreshTokenDto {
  @ApiProperty()
  @IsString()
  @Length(20, 200)
  refreshToken!: string;

  @ApiProperty({ required: false })
  @IsOptional()
  @IsString()
  @MaxLength(128)
  deviceId?: string;
}
