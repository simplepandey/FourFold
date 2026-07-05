import { IsString, IsInt, IsNumber, IsNotEmpty, IsOptional, IsDateString, Min, Max } from 'class-validator';
import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';

export class CreateModuleRegistrationDto {
  @ApiProperty({ example: 'SN-2024-001', description: 'Serial number of the module to register' })
  @IsString()
  @IsNotEmpty()
  moduleSerialNumber: string;

  @ApiProperty({ example: 'user-id-or-name', description: 'User or entity this module is registered to' })
  @IsString()
  @IsNotEmpty()
  registeredTo: string;

  @ApiProperty({ example: 3, description: 'Number of pumps' })
  @IsInt()
  @Min(1)
  @Max(100)
  noOfPump: number;

  @ApiProperty({ example: 'Single Phase', description: 'Electrical phase type (e.g. Single Phase, Three Phase)' })
  @IsString()
  @IsNotEmpty()
  phase: string;

  @ApiProperty({ example: 1.5, description: 'Horsepower of the pump' })
  @IsNumber()
  @Min(0.1)
  hpOfPump: number;

  @ApiProperty({ example: 'Admin', description: 'Who is creating this registration' })
  @IsString()
  @IsNotEmpty()
  createdBy: string;

  @ApiPropertyOptional({ example: '2026-05-20T10:00:00.000Z', description: 'Custom creation date (defaults to server time if omitted)' })
  @IsOptional()
  @IsDateString()
  createDate?: string;
}
