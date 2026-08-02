import { IsString, IsNotEmpty, IsOptional, Matches, IsEnum } from 'class-validator';
import { ApiPropertyOptional } from '@nestjs/swagger';

export class UpdateMemberDto {
  @ApiPropertyOptional({
    example: '+919876543210',
    description: 'New phone number for this member',
  })
  @IsOptional()
  @IsString()
  @Matches(/^\+[1-9]\d{1,14}$/, { message: 'Phone number must be in E.164 format' })
  phoneNumber?: string;

  @ApiPropertyOptional({ example: 'Jane Doe', description: 'Update the linked user name' })
  @IsOptional()
  @IsString()
  @IsNotEmpty()
  name?: string;

  @ApiPropertyOptional({ example: 'admin', enum: ['member', 'admin'] })
  @IsOptional()
  @IsEnum(['member', 'admin'], { message: 'role must be either member or admin' })
  role?: 'member' | 'admin';
}
