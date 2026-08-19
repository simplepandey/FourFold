import { Controller, Get, Param, UseGuards } from '@nestjs/common';
import { ApiTags, ApiOperation, ApiBearerAuth, ApiOkResponse, ApiParam } from '@nestjs/swagger';
import { ModuleActionLogService } from './module-action-log.service';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';

@ApiTags('Module Action Logs')
@Controller({ path: 'module-action-logs', version: '1' })
@UseGuards(JwtAuthGuard)
@ApiBearerAuth('JWT-auth')
export class ModuleActionLogController {
  constructor(private readonly service: ModuleActionLogService) {}

  @Get(':productCode')
  @ApiOperation({ summary: 'Get recent action log entries for a module, most recent first' })
  @ApiParam({ name: 'productCode', example: 'FF00100' })
  @ApiOkResponse({ description: 'List of action log entries' })
  async findByProductCode(@Param('productCode') productCode: string) {
    const data = await this.service.findByProductCode(productCode);
    return { success: true, message: 'Action logs retrieved successfully', data };
  }
}
