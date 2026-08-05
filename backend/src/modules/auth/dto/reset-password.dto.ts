import { IsString, IsNotEmpty, MinLength, Matches } from 'class-validator';
import { ApiProperty } from '@nestjs/swagger';

export class ResetPasswordDto {
  @ApiProperty({
    description: 'MSG91 widget access token received after OTP verification on client',
    example: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...',
  })
  @IsString()
  @IsNotEmpty()
  accessToken: string;

  @ApiProperty({
    example: '+919876543210',
    description: 'Phone number registered with the account, in E.164 format',
  })
  @IsString()
  @Matches(/^\+[1-9]\d{1,14}$/, {
    message: 'Phone number must be in E.164 format (e.g. +919876543210)',
  })
  phoneNumber: string;

  @ApiProperty({ example: 'NewSecurePass@123', description: 'New account password' })
  @IsString()
  @IsNotEmpty()
  @MinLength(6)
  newPassword: string;
}
