import {
  IsString,
  IsInt,
  IsNotEmpty,
  IsOptional,
  MinLength,
  Min,
  Max,
  Matches,
} from 'class-validator';
import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';

export class CreateSocietyDto {
  @ApiProperty({
    example: '+919876543210',
    description: 'Phone number used to login (E.164 format)',
  })
  @IsString()
  @Matches(/^\+[1-9]\d{1,14}$/, {
    message: 'Phone number must be in E.164 format (e.g. +919876543210)',
  })
  phoneNumber: string;

  @ApiProperty({
    example: 'Rahul Sharma',
    description: 'Name of the society admin or contact person',
  })
  @IsString()
  @IsNotEmpty()
  name: string;

  @ApiProperty({
    example: 'Green Valley Apartments',
    description: 'Name of the society or apartment complex',
  })
  @IsString()
  @IsNotEmpty()
  societyName: string;

  @ApiProperty({ example: 'Block A', description: 'Block or wing name within the society' })
  @IsString()
  @IsNotEmpty()
  blockOrWing: string;

  @ApiProperty({ example: 120, description: 'Total number of members in the society' })
  @IsInt()
  @Min(1)
  @Max(10000)
  totalMembers: number;

  @ApiProperty({ example: 'SecurePass@123', description: 'Password (minimum 6 characters)' })
  @IsString()
  @MinLength(6, { message: 'Password must be at least 6 characters' })
  password: string;

  @ApiPropertyOptional({
    example: 'user-uuid',
    description: 'User ID of the society creator (becomes admin)',
  })
  @IsOptional()
  @IsString()
  @IsNotEmpty()
  createdBy?: string;
}
