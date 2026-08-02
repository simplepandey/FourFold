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
import { ModuleRegistrationService } from './module-registration.service';
import { CreateModuleRegistrationDto } from './dto/create-module-registration.dto';
import { UpdateModuleRegistrationDto } from './dto/update-module-registration.dto';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';

@ApiTags('Module Registration')
@Controller({ path: 'module-registration', version: '1' })
@UseGuards(JwtAuthGuard)
@ApiBearerAuth('JWT-auth')
export class ModuleRegistrationController {
  constructor(private readonly service: ModuleRegistrationService) {}

  // ─── CREATE ─────────────────────────────────────────────
  @Post()
  @HttpCode(HttpStatus.CREATED)
  @ApiOperation({ summary: 'Register a module to a user' })
  @ApiBody({ type: CreateModuleRegistrationDto })
  @ApiCreatedResponse({
    description: 'Module registered successfully',
    schema: {
      example: {
        success: true,
        message: 'Module registered successfully',
        data: {
          id: 'uuid',
          serialNumber: 'SN-2024-001',
          registeredTo: 'user-id',
          noOfPump: 3,
          phase: 'Single Phase',
          hpOfPump: 1.5,
          createdBy: 'Admin',
          createDate: '2026-05-20T10:00:00.000Z',
          updatedBy: null,
          updateDate: '2026-05-20T10:00:00.000Z',
          isDeleted: false,
        },
      },
    },
  })
  @ApiNotFoundResponse({ description: 'Module serial number not found' })
  @ApiConflictResponse({ description: 'Module is already registered' })
  async create(@Body() dto: CreateModuleRegistrationDto) {
    const data = await this.service.create(dto);
    return { success: true, message: 'Module registered successfully', data };
  }

  // ─── GET ALL ─────────────────────────────────────────────
  @Get()
  @ApiOperation({ summary: 'Get all active registrations (excludes soft-deleted)' })
  @ApiOkResponse({ description: 'List of all registrations' })
  async findAll() {
    const data = await this.service.findAll();
    return { success: true, message: 'Registrations retrieved successfully', data };
  }

  // ─── GET BY USER ─────────────────────────────────────────
  @Get('module/user/:id')
  @ApiOperation({ summary: 'Get all modules registered to a specific user' })
  @ApiParam({ name: 'id', description: 'User ID (registeredTo value)' })
  @ApiOkResponse({ description: 'List of registrations for the given user' })
  async findByUser(@Param('id') id: string) {
    const data = await this.service.findAllByRegisteredTo(id);
    return { success: true, message: 'Registrations retrieved successfully', data };
  }

  // ─── GET BY ID ───────────────────────────────────────────
  @Get(':id')
  @ApiOperation({ summary: 'Get a registration by ID' })
  @ApiParam({ name: 'id', description: 'Registration UUID' })
  @ApiOkResponse({ description: 'Registration found' })
  @ApiNotFoundResponse({ description: 'Registration not found' })
  async findOne(@Param('id') id: string) {
    const data = await this.service.findById(id);
    return { success: true, message: 'Registration retrieved successfully', data };
  }

  // ─── UPDATE ──────────────────────────────────────────────
  @Put(':id')
  @ApiOperation({ summary: 'Update a registration by ID' })
  @ApiParam({ name: 'id', description: 'Registration UUID' })
  @ApiBody({ type: UpdateModuleRegistrationDto })
  @ApiOkResponse({ description: 'Registration updated successfully' })
  @ApiNotFoundResponse({ description: 'Registration not found' })
  async update(@Param('id') id: string, @Body() dto: UpdateModuleRegistrationDto) {
    const data = await this.service.update(id, dto);
    return { success: true, message: 'Registration updated successfully', data };
  }

  // ─── DELETE (soft) ───────────────────────────────────────
  @Delete(':id')
  @ApiOperation({
    summary: 'Soft-delete a registration by ID',
    description: 'Sets isDeleted = true. The module becomes available for re-registration.',
  })
  @ApiParam({ name: 'id', description: 'Registration UUID' })
  @ApiQuery({
    name: 'deletedBy',
    required: true,
    description: 'ID or name of the user deleting this record',
  })
  @ApiOkResponse({ description: 'Registration deleted successfully' })
  @ApiNotFoundResponse({ description: 'Registration not found' })
  async remove(@Param('id') id: string, @Query('deletedBy') deletedBy: string) {
    const data = await this.service.remove(id, deletedBy || 'system');
    return { success: true, message: 'Registration deleted successfully', data };
  }
}
