import { ApiPropertyOptional } from '@nestjs/swagger';
import {
  ArrayMaxSize,
  IsArray,
  IsInt,
  IsOptional,
  IsString,
  Length,
  Max,
  Min,
} from 'class-validator';

export class UpdateCustomerProfileDto {
  @ApiPropertyOptional({ example: 'Aarav Sharma' })
  @IsOptional()
  @IsString()
  @Length(2, 150)
  fullName?: string;

  @ApiPropertyOptional({ example: 'aarav@example.com' })
  @IsOptional()
  @IsString()
  @Length(5, 255)
  email?: string;

  @ApiPropertyOptional({ example: 'Sunita Sharma' })
  @IsOptional()
  @IsString()
  @Length(2, 150)
  emergencyContactName?: string;

  @ApiPropertyOptional({ example: '+919810000009' })
  @IsOptional()
  @IsString()
  @Length(8, 20)
  emergencyContactPhone?: string;

  @ApiPropertyOptional({ example: '07AABCU9603R1ZM' })
  @IsOptional()
  @IsString()
  @Length(15, 15)
  gstin?: string;

  @ApiPropertyOptional({ example: 'en' })
  @IsOptional()
  @IsString()
  @Length(2, 20)
  preferredLanguage?: string;
}

export class UpdateDriverProfileDto {
  @ApiPropertyOptional({
    example: '12 years of premium ceremonial chauffeuring across Delhi NCR.',
  })
  @IsOptional()
  @IsString()
  @Length(10, 500)
  bio?: string;

  @ApiPropertyOptional({ example: 12 })
  @IsOptional()
  @IsInt()
  @Min(0)
  @Max(60)
  experienceYears?: number;

  @ApiPropertyOptional({ example: ['Hindi', 'English', 'Punjabi'] })
  @IsOptional()
  @IsArray()
  @ArrayMaxSize(10)
  @IsString({ each: true })
  languagesSpoken?: string[];
}
