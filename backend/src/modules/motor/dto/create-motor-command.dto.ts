import { IsString, IsNotEmpty, IsIn, IsNumber, ValidateIf } from 'class-validator';
import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';

const THRESHOLD_COMMANDS = ['SET_OC', 'SET_UC'];

export class CreateMotorCommandDto {
  @ApiProperty({ example: 'SOC001' })
  @IsString()
  @IsNotEmpty()
  societyCode: string;

  @ApiProperty({ example: 'esp32_test' })
  @IsString()
  @IsNotEmpty()
  motorId: string;

  @ApiProperty({
    example: 'FF00100',
    description: 'Module product code — used to key module_status / module_action_logs',
  })
  @IsString()
  @IsNotEmpty()
  productCode: string;

  @ApiProperty({
    enum: ['TURN_ON', 'TURN_OFF', 'SET_OC', 'SET_UC'],
    example: 'TURN_ON',
  })
  @IsString()
  @IsIn(['TURN_ON', 'TURN_OFF', 'SET_OC', 'SET_UC'])
  command: string;

  @ApiPropertyOptional({
    example: 8.5,
    description: 'Threshold value in amps — required when command is SET_OC or SET_UC',
  })
  @ValidateIf((o: CreateMotorCommandDto) => THRESHOLD_COMMANDS.includes(o.command))
  @IsNumber()
  value?: number;

  @ApiProperty({ example: 'user_id_or_name' })
  @IsString()
  @IsNotEmpty()
  commandBy: string;
}
