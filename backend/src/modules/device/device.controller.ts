import { Controller, Post, Get, Param, HttpStatus, UseGuards, Res } from '@nestjs/common';
import { Response } from 'express';
import {
  ApiTags,
  ApiOperation,
  ApiCreatedResponse,
  ApiOkResponse,
  ApiParam,
  ApiBasicAuth,
} from '@nestjs/swagger';
import { DeviceService } from './device.service';
import { Public } from '../../common/decorators/public.decorator';
import { BasicAuthGuard } from '../../common/guards/basic-auth.guard';

@ApiTags('Device Registration')
@Controller({ path: 'device', version: '1' })
export class DeviceController {
  constructor(private readonly service: DeviceService) {}

  @Public()
  @UseGuards(BasicAuthGuard)
  @Post('register/:serialNo')
  @ApiBasicAuth('basic-auth')
  @ApiOperation({
    summary: 'Register an ESP device by serial number',
    description:
      'Called by the ESP device on first boot. Returns 201 on first registration, 200 if already registered. Payload is identical in both cases.',
  })
  @ApiParam({ name: 'serialNo', example: 'SR12345', description: 'ESP device serial number' })
  @ApiCreatedResponse({
    description: '201 created (new) or 200 OK (already registered) — same payload',
    schema: {
      example: {
        success: true,
        message: 'Device registered successfully',
        data: {
          id: 'uuid',
          serialNumber: 'SR12345',
          serialHash: 'a1b2c3d4e5f6',
          username: null,
          userId: null,
          societyId: null,
          topics: {
            commands: 'motors/a1b2c3d4e5f6/commands',
            telemetry: 'motors/a1b2c3d4e5f6/telemetry',
            alert: 'motors/a1b2c3d4e5f6/alert',
            heartbeat: 'motors/a1b2c3d4e5f6/heartbeat',
          },
          createdAt: '2026-07-22T10:00:00.000Z',
        },
      },
    },
  })
  async register(@Param('serialNo') serialNo: string, @Res() res: Response) {
    const { data, created } = await this.service.register(serialNo);
    const status = created ? HttpStatus.CREATED : HttpStatus.OK;
    res.status(status).json({ success: true, message: 'Device registered successfully', data });
  }

  @Public()
  @Get('register/:serialNo')
  @ApiOperation({ summary: 'Get all registrations for a serial number' })
  @ApiParam({ name: 'serialNo', example: 'SR12345' })
  @ApiOkResponse({ description: 'Registration history for this serial number' })
  async findBySerial(@Param('serialNo') serialNo: string) {
    const data = await this.service.findBySerialNumber(serialNo);
    return { success: true, message: 'Registrations retrieved successfully', data };
  }

  @Public()
  @Get('user/:userId')
  @ApiOperation({ summary: 'Get all devices registered to a user' })
  @ApiParam({ name: 'userId', example: 'user-uuid' })
  @ApiOkResponse({ description: 'All device registrations for this user' })
  async findByUser(@Param('userId') userId: string) {
    const data = await this.service.findByUserId(userId);
    return { success: true, message: 'Devices retrieved successfully', data };
  }

  @Public()
  @Get('user-modules/:userId')
  @ApiOperation({
    summary: 'Get all ESP modules linked to a user',
    description:
      'Returns all serialNumbers from society_members for this userId (where serialNumber is set), with ESP registration details for each.',
  })
  @ApiParam({ name: 'userId', example: 'user-uuid' })
  @ApiOkResponse({
    description: 'List of ESP modules linked to the user',
    schema: {
      example: {
        success: true,
        message: 'User modules retrieved successfully',
        data: [
          {
            serialNumber: 'SR12345',
            societyCode: 'SOC-1A2B3C4D',
            role: 'admin',
            joinedAt: '2026-01-01T00:00:00.000Z',
            esp: {
              id: 'uuid',
              serialHash: 'a1b2c3d4e5f6',
              createdAt: '2026-07-20T10:00:00.000Z',
            },
          },
        ],
      },
    },
  })
  async getUserModules(@Param('userId') userId: string) {
    const data = await this.service.getUserModules(userId);
    return { success: true, message: 'User modules retrieved successfully', data };
  }

  @Public()
  @Get('info/:serialNo')
  @ApiOperation({
    summary: 'Get full device info by serial number',
    description:
      'Returns ESP registration (MQTT topics), module registration (pump config + address), and all society members with their role (admin/member).',
  })
  @ApiParam({ name: 'serialNo', example: 'SR12345', description: 'ESP device serial number' })
  @ApiOkResponse({
    description: 'Combined device + member info',
    schema: {
      example: {
        success: true,
        message: 'Device info retrieved successfully',
        data: {
          esp: {
            id: 'uuid',
            serialNumber: 'SR12345',
            serialHash: 'a1b2c3d4e5f6',
            topics: {
              commands: 'motors/a1b2c3d4e5f6/commands',
              telemetry: 'motors/a1b2c3d4e5f6/telemetry',
              alert: 'motors/a1b2c3d4e5f6/alert',
              heartbeat: 'motors/a1b2c3d4e5f6/heartbeat',
            },
            createdAt: '2026-07-22T10:00:00.000Z',
          },
          module: {
            id: 'uuid',
            serialNumber: 'SR12345',
            registeredTo: 'SOC-1A2B3C4D',
            noOfPump: 3,
            phase: '3-Phase',
            hpOfPump: 1.5,
            address: 'Plot 12, Near Water Tank',
            wingBlock: 'A Wing',
            pincode: '411001',
            district: 'Pune',
            state: 'Maharashtra',
            country: 'India',
            createdBy: 'Admin',
            createDate: '2026-07-22T10:00:00.000Z',
          },
          members: [
            {
              id: 'uuid',
              phoneNumber: '+919876543210',
              userId: 'user-uuid',
              serialNumber: 'SR12345',
              role: 'admin',
              joinedAt: '2026-01-01T00:00:00.000Z',
            },
            {
              id: 'uuid',
              phoneNumber: '+919876543211',
              userId: 'user-uuid',
              serialNumber: null,
              role: 'member',
              joinedAt: '2026-02-15T00:00:00.000Z',
            },
          ],
        },
      },
    },
  })
  async getInfo(@Param('serialNo') serialNo: string) {
    const data = await this.service.getInfo(serialNo);
    return { success: true, message: 'Device info retrieved successfully', data };
  }
}
