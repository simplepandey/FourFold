import {
  Controller,
  Get,
  Post,
  Put,
  Delete,
  Body,
  Param,
  Query,
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
  ApiNotFoundResponse,
  ApiConflictResponse,
  ApiQuery,
  ApiParam,
  ApiBody,
} from '@nestjs/swagger';
import { ModuleMasterService } from './module-master.service';
import { CreateModuleMasterDto } from './dto/create-module-master.dto';
import { UpdateModuleMasterDto } from './dto/update-module-master.dto';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';

@ApiTags('Module Master')
@Controller({ path: 'module-master', version: '1' })
@UseGuards(JwtAuthGuard)
@ApiBearerAuth('JWT-auth')
export class ModuleMasterController {
  constructor(private readonly service: ModuleMasterService) {}

  // ─── CREATE ─────────────────────────────────────────────
  @Post()
  @HttpCode(HttpStatus.CREATED)
  @ApiOperation({ summary: 'Create a new module' })
  @ApiBody({ type: CreateModuleMasterDto })
  @ApiCreatedResponse({
    description: 'Module created successfully',
    schema: {
      example: {
        success: true,
        message: 'Module created successfully',
        data: {
          id: 'uuid',
          serialNumber: 'SN-2024-001',
          createdBy: 'Admin',
          createDate: '2026-05-20T10:00:00.000Z',
          updatedBy: null,
          updateDate: '2026-05-20T10:00:00.000Z',
          isDeleted: false,
        },
      },
    },
  })
  @ApiConflictResponse({ description: 'Serial number already exists' })
  async create(@Body() dto: CreateModuleMasterDto) {
    const data = await this.service.create(dto);
    return { success: true, message: 'Module created successfully', data };
  }

  // ─── GET ALL ─────────────────────────────────────────────
  @Get()
  @ApiOperation({ summary: 'Get all active modules (excludes soft-deleted)' })
  @ApiOkResponse({ description: 'List of all modules' })
  async findAll() {
    const data = await this.service.findAll();
    return { success: true, message: 'Modules retrieved successfully', data };
  }

  // ─── GET BY SERIAL NUMBER ────────────────────────────────
  @Get('serial-number/:serialNumber')
  @ApiOperation({ summary: 'Get a module by serial number' })
  @ApiParam({
    name: 'serialNumber',
    description: 'Module serial number (may contain hyphens, e.g. SN-2024-001)',
  })
  @ApiOkResponse({ description: 'Module found' })
  @ApiNotFoundResponse({ description: 'Module not found' })
  async findBySerialNumber(@Param('serialNumber') serialNumber: string) {
    const data = await this.service.findOneBySerialNumber(serialNumber);
    return { success: true, message: 'Module retrieved successfully', data };
  }

  // ─── GET BY ID ───────────────────────────────────────────
  @Get(':id')
  @ApiOperation({ summary: 'Get a module by ID' })
  @ApiParam({ name: 'id', description: 'Module UUID' })
  @ApiOkResponse({ description: 'Module found' })
  @ApiNotFoundResponse({ description: 'Module not found' })
  async findOne(@Param('id') id: string) {
    const data = await this.service.findById(id);
    return { success: true, message: 'Module retrieved successfully', data };
  }

  // ─── UPDATE ──────────────────────────────────────────────
  @Put(':id')
  @ApiOperation({ summary: 'Update a module by ID' })
  @ApiParam({ name: 'id', description: 'Module UUID' })
  @ApiBody({ type: UpdateModuleMasterDto })
  @ApiOkResponse({ description: 'Module updated successfully' })
  @ApiNotFoundResponse({ description: 'Module not found' })
  @ApiConflictResponse({ description: 'Serial number already in use' })
  async update(@Param('id') id: string, @Body() dto: UpdateModuleMasterDto) {
    const data = await this.service.update(id, dto);
    return { success: true, message: 'Module updated successfully', data };
  }

  // ─── DELETE (soft) ───────────────────────────────────────
  @Delete(':id')
  @ApiOperation({
    summary: 'Soft-delete a module by ID',
    description: 'Sets isDeleted = true. The record stays in the database.',
  })
  @ApiParam({ name: 'id', description: 'Module UUID' })
  @ApiQuery({
    name: 'deletedBy',
    required: true,
    description: 'ID or name of the user deleting this record',
  })
  @ApiOkResponse({ description: 'Module deleted successfully' })
  @ApiNotFoundResponse({ description: 'Module not found' })
  async remove(@Param('id') id: string, @Query('deletedBy') deletedBy: string) {
    const data = await this.service.remove(id, deletedBy || 'system');
    return { success: true, message: 'Module deleted successfully', data };
  }
}
