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

  @Get(':productCode')
  @ApiOperation({ summary: 'Get the current live status of a module' })
  @ApiParam({ name: 'productCode', example: 'FF00100' })
  @ApiOkResponse({ description: 'Current module status' })
  @ApiNotFoundResponse({ description: 'No status found for this product code' })
  async findOne(@Param('productCode') productCode: string) {
    const data = await this.service.findByProductCode(productCode);
    return { success: true, message: 'Module status retrieved successfully', data };
  }
}
