import { IsString, IsOptional, IsNotEmpty, IsDateString } from 'class-validator';
import { ApiPropertyOptional, ApiProperty } from '@nestjs/swagger';

export class UpdateModuleMasterDto {
  @ApiPropertyOptional({ example: 'SN-2024-002', description: 'Updated serial number' })
  @IsOptional()
  @IsString()
  @IsNotEmpty()
  serialNumber?: string;

  @ApiProperty({
    example: 'admin-uuid or Admin Name',
    description: 'ID or name of the user updating this record',
  })
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
