import { IsString, IsNotEmpty, MinLength, Matches } from 'class-validator';
import { ApiProperty } from '@nestjs/swagger';

export class SocietyLoginDto {
  @ApiProperty({ example: '+919876543210', description: 'Phone number registered with the society' })
  @IsString()
  @Matches(/^\+[1-9]\d{1,14}$/, {
    message: 'Phone number must be in E.164 format (e.g. +919876543210)',
  })
  phoneNumber: string;

  @ApiProperty({ example: 'SecurePass@123', description: 'Society password' })
  @IsString()
  @IsNotEmpty()
  @MinLength(6)
  password: string;
}
