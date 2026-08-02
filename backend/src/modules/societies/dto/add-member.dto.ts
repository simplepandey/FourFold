import { IsString, IsNotEmpty, IsOptional, Matches } from 'class-validator';
import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';

export class AddMemberDto {
  @ApiProperty({ example: '+919876543210' })
  @IsString()
  @Matches(/^\+[1-9]\d{1,14}$/, { message: 'Phone number must be in E.164 format' })
  phoneNumber: string;

  @ApiPropertyOptional({ example: 'Jane Doe' })
  @IsOptional()
  @IsString()
  @IsNotEmpty()
  name?: string;

  @ApiPropertyOptional({ example: 'SR00123' })
  @IsOptional()
  @IsString()
  @IsNotEmpty()
  serialNumber?: string;
}
