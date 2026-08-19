import { Controller, Post, Get, Param, Body, HttpCode, HttpStatus, UseGuards } from '@nestjs/common';
import {
  ApiTags,
  ApiOperation,
  ApiCreatedResponse,
  ApiOkResponse,
  ApiNotFoundResponse,
  ApiConflictResponse,
  ApiBearerAuth,
  ApiBody,
  ApiParam,
} from '@nestjs/swagger';
import { SocietiesService } from './societies.service';
import { CreateSocietyDto } from './dto/create-society.dto';
import { AddMemberDto } from './dto/add-member.dto';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';

@ApiTags('Societies')
@Controller({ path: 'societies', version: '1' })
@UseGuards(JwtAuthGuard)
@ApiBearerAuth('JWT-auth')
export class SocietiesController {
  constructor(private readonly societiesService: SocietiesService) {}

  @Post()
  @HttpCode(HttpStatus.CREATED)
  @ApiOperation({ summary: 'Register a new society' })
  @ApiBody({ type: CreateSocietyDto })
  @ApiCreatedResponse({ description: 'Society registered successfully' })
  async create(@Body() createSocietyDto: CreateSocietyDto) {
    const data = await this.societiesService.create(createSocietyDto);
    return { success: true, message: 'Society registered successfully', data };
  }

  @Get()
  @ApiOperation({ summary: 'Get all societies' })
  @ApiOkResponse({ description: 'List of all societies' })
  async findAll() {
    const data = await this.societiesService.findAll();
    return { success: true, message: 'Societies retrieved successfully', data };
  }

  // ─── must be before /:id ─────────────────────────────────
  @Post(':societyId/members')
  @HttpCode(HttpStatus.CREATED)
  @ApiOperation({
    summary: 'Grant a phone number access to a specific device',
    description:
      'Members are always added per-device, not to the society as a whole. If the phone number exists in the users table, userId is linked automatically. Otherwise it is stored with userId = null until they register.',
  })
  @ApiParam({ name: 'societyId', description: 'Society UUID' })
  @ApiBody({ type: AddMemberDto })
  @ApiCreatedResponse({
    description: 'Member added',
    schema: {
      example: {
        success: true,
        message: 'Member added successfully',
        data: {
          id: 'uuid',
          productCode: 'FF00100',
          societyCode: 'SOC-1A2B3C4D',
          phoneNumber: '+919876543210',
          userId: 'user-uuid or null',
          role: 'member',
          joinedAt: '2026-07-22T10:00:00.000Z',
        },
      },
    },
  })
  @ApiConflictResponse({ description: 'Phone number already has access to this device' })
  @ApiNotFoundResponse({ description: 'Society not found' })
  async addMember(@Param('societyId') societyId: string, @Body() dto: AddMemberDto) {
    const data = await this.societiesService.addMember(societyId, dto);
    return { success: true, message: 'Member added successfully', data };
  }

  @Get(':id')
  @ApiOperation({ summary: 'Get a society by ID' })
  @ApiOkResponse({ description: 'Society found' })
  @ApiNotFoundResponse({ description: 'Society not found' })
  async findOne(@Param('id') id: string) {
    const data = await this.societiesService.findById(id);
    return { success: true, message: 'Society retrieved successfully', data };
  }
}
