import { ApiProperty } from '@nestjs/swagger';
import {
  IsIn,
  IsOptional,
  IsString,
  Length,
  Matches,
  MaxLength,
} from 'class-validator';

export class RequestOtpDto {
  @ApiProperty({ example: '+919810000001' })
  @IsString()
  @Matches(/^\+[1-9]\d{7,14}$/)
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
  @Matches(/^\+[1-9]\d{7,14}$/)
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
