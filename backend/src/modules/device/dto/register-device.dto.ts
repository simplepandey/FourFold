import { IsString, IsNotEmpty } from 'class-validator';
import { ApiProperty } from '@nestjs/swagger';

export class RegisterDeviceDto {
  @ApiProperty({ example: 'John Doe' })
  @IsString()
  @IsNotEmpty()
  username: string;

  @ApiProperty({ example: 'user-uuid' })
  @IsString()
  @IsNotEmpty()
  userId: string;

  @ApiProperty({ example: 'SOC001' })
  @IsString()
  @IsNotEmpty()
  societyId: string;
}
