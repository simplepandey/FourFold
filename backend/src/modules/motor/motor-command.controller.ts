import {
  Controller,
  Post,
  Get,
  Body,
  Param,
  HttpCode,
  HttpStatus,
  UseGuards,
} from '@nestjs/common';
import {
  ApiTags,
  ApiOperation,
  ApiBearerAuth,
  ApiCreatedResponse,
  ApiOkResponse,
  ApiBody,
  ApiParam,
} from '@nestjs/swagger';
import { MotorCommandService } from './motor-command.service';
import { CreateMotorCommandDto } from './dto/create-motor-command.dto';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';

@ApiTags('Motor Commands')
@Controller({ path: 'motor', version: '1' })
@UseGuards(JwtAuthGuard)
@ApiBearerAuth('JWT-auth')
export class MotorCommandController {
  constructor(private readonly service: MotorCommandService) {}

  @Post('command')
  @HttpCode(HttpStatus.CREATED)
  @ApiOperation({
    summary: 'Send a command (TURN_ON / TURN_OFF / SET_OC / SET_UC) to a motor via MQTT and log it',
  })
  @ApiBody({ type: CreateMotorCommandDto })
  @ApiCreatedResponse({
    description: 'Command sent and logged',
    schema: {
      example: {
        success: true,
        message: 'Command sent successfully',
        data: {
          id: 'uuid',
          societyCode: 'SOC001',
          motorId: 'esp32_test',
          serialNumber: 'SN-2024-001',
          command: 'TURN_ON',
          commandBy: 'user_id',
          cmdId: 'uuid',
          status: 'sent',
          createDate: '2026-07-22T10:00:00.000Z',
        },
      },
    },
  })
  async sendCommand(@Body() dto: CreateMotorCommandDto) {
    const data = await this.service.sendCommand(dto);
    return { success: true, message: 'Command sent successfully', data };
  }

  @Get('commands')
  @ApiOperation({ summary: 'Get all motor commands' })
  @ApiOkResponse({ description: 'List of all motor commands' })
  async findAll() {
    const data = await this.service.findAll();
    return { success: true, message: 'Commands retrieved successfully', data };
  }

  @Get('commands/:societyCode/:motorId')
  @ApiOperation({ summary: 'Get commands for a specific motor' })
  @ApiParam({ name: 'societyCode', example: 'SOC001' })
  @ApiParam({ name: 'motorId', example: 'esp32_test' })
  @ApiOkResponse({ description: 'Commands for the specified motor' })
  async findByMotor(@Param('societyCode') societyCode: string, @Param('motorId') motorId: string) {
    const data = await this.service.findBySocietyAndMotor(societyCode, motorId);
    return { success: true, message: 'Commands retrieved successfully', data };
  }
}
