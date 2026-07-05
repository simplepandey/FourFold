import { IsString, IsNotEmpty, IsOptional, IsDateString } from 'class-validator';
import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';

export class CreateModuleMasterDto {
  @ApiProperty({ example: 'SN-2024-001', description: 'Unique serial number of the module' })
  @IsString()
  @IsNotEmpty()
  serialNumber: string;

  @ApiProperty({ example: 'admin-uuid or Admin Name', description: 'ID or name of the user creating this record' })
  @IsString()
  @IsNotEmpty()
  createdBy: string;

  @ApiPropertyOptional({ example: '2026-05-20T10:00:00.000Z', description: 'Custom creation date (defaults to server time if omitted)' })
  @IsOptional()
  @IsDateString()
  createDate?: string;
}
