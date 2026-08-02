import {
  IsString,
  IsInt,
  IsNumber,
  IsOptional,
  IsNotEmpty,
  IsDateString,
  Min,
  Max,
} from 'class-validator';
import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';

export class UpdateModuleRegistrationDto {
  @ApiPropertyOptional({
    example: 'new-user-id',
    description: 'Updated user or entity this module is registered to',
  })
  @IsString()
  @IsOptional()
  registeredTo?: string;

  @ApiPropertyOptional({ example: 4, description: 'Updated number of pumps' })
  @IsOptional()
  @IsInt()
  @Min(1)
  @Max(100)
  noOfPump?: number;

  @ApiPropertyOptional({ example: 'Three Phase', description: 'Updated phase type' })
  @IsOptional()
  @IsString()
  @IsNotEmpty()
  phase?: string;

  @ApiPropertyOptional({ example: 2.5, description: 'Updated horsepower of the pump' })
  @IsOptional()
  @IsNumber()
  @Min(0.1)
  hpOfPump?: number;

  @ApiProperty({ example: 'Admin', description: 'Who is updating this record' })
  @IsString()
  @IsNotEmpty()
  updatedBy: string;

  @ApiPropertyOptional({
    example: '2026-05-20T12:00:00.000Z',
    description: 'Custom update date (defaults to server time if omitted)',
  })
  @IsOptional()
  @IsDateString()
  updateDate?: string;
}
