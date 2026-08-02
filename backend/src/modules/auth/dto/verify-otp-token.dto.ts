import { IsString, IsNotEmpty } from 'class-validator';
import { ApiProperty } from '@nestjs/swagger';

export class VerifyOtpTokenDto {
  @ApiProperty({
    description: 'MSG91 widget access token received after OTP verification on client',
    example: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...',
  })
  @IsString()
  @IsNotEmpty()
  accessToken: string;

  @ApiProperty({ description: 'Phone number in E.164 format', example: '+919876543210' })
  @IsString()
  @IsNotEmpty()
  phoneNumber: string;
}
