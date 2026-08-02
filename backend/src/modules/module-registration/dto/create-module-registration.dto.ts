import {
  IsString,
  IsInt,
  IsNumber,
  IsNotEmpty,
  IsOptional,
  IsDateString,
  Min,
  Max,
} from 'class-validator';
import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';

export class CreateModuleRegistrationDto {
  @ApiProperty({
    example: 'SN-2024-001',
    description: 'ESP32 serial number (must exist in esp_registrations)',
  })
  @IsString()
  @IsNotEmpty()
  serialNumber: string;

  @ApiProperty({
    example: 'SOC-1A2B3C4D',
    description: 'Society code this module is registered to',
  })
  @IsString()
  @IsNotEmpty()
  societyCode: string;

  @ApiProperty({ example: 3, description: 'Number of pumps' })
  @IsInt()
  @Min(1)
  @Max(100)
  noOfPump: number;

  @ApiProperty({
    example: 'Single Phase',
    description: 'Electrical phase type (e.g. Single Phase, Three Phase)',
  })
  @IsString()
  @IsNotEmpty()
  phase: string;

  @ApiProperty({ example: 1.5, description: 'Horsepower of the pump' })
  @IsNumber()
  @Min(0.1)
  hpOfPump: number;

  @ApiProperty({ example: 'Plot 12, Near Water Tank', description: "Module's street address" })
  @IsString()
  @IsNotEmpty()
  address: string;

  @ApiProperty({ example: 'A Wing', description: 'Wing or block of the building' })
  @IsString()
  @IsNotEmpty()
  wingBlock: string;

  @ApiProperty({ example: '411001', description: 'Pincode' })
  @IsString()
  @IsNotEmpty()
  pincode: string;

  @ApiProperty({ example: 'Pune', description: 'District' })
  @IsString()
  @IsNotEmpty()
  district: string;

  @ApiPropertyOptional({ example: 'Maharashtra', description: 'State (defaults to Maharashtra)' })
  @IsOptional()
  @IsString()
  state?: string;

  @ApiPropertyOptional({ example: 'India', description: 'Country (defaults to India)' })
  @IsOptional()
  @IsString()
  country?: string;

  @ApiPropertyOptional({
    example: 'uuid-of-user',
    description: 'User ID of the person registering (used to link serialNumber in society_members)',
  })
  @IsOptional()
  @IsString()
  userId?: string;

  @ApiProperty({ example: 'Admin', description: 'Who is creating this registration' })
  @IsString()
  @IsNotEmpty()
  createdBy: string;

  @ApiPropertyOptional({
    example: '2026-05-20T10:00:00.000Z',
    description: 'Custom creation date (defaults to server time if omitted)',
  })
  @IsOptional()
  @IsDateString()
  createDate?: string;
}
