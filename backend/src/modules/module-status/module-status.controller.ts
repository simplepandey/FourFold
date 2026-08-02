import { Controller, Get, Param, UseGuards } from '@nestjs/common';
import {
  ApiTags,
  ApiOperation,
  ApiBearerAuth,
  ApiOkResponse,
  ApiNotFoundResponse,
  ApiParam,
} from '@nestjs/swagger';
import { ModuleStatusService } from './module-status.service';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';

@ApiTags('Module Status')
@Controller({ path: 'module-status', version: '1' })
@UseGuards(JwtAuthGuard)
@ApiBearerAuth('JWT-auth')
export class ModuleStatusController {
  constructor(private readonly service: ModuleStatusService) {}

  @Get(':serialNumber')
  @ApiOperation({ summary: 'Get the current live status of a module' })
  @ApiParam({ name: 'serialNumber', example: 'SN-2024-001' })
  @ApiOkResponse({ description: 'Current module status' })
  @ApiNotFoundResponse({ description: 'No status found for this serial number' })
  async findOne(@Param('serialNumber') serialNumber: string) {
    const data = await this.service.findBySerialNumber(serialNumber);
    return { success: true, message: 'Module status retrieved successfully', data };
  }
}
