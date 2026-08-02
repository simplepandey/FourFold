import {
  Controller,
  Post,
  Get,
  Put,
  Delete,
  Param,
  Body,
  HttpCode,
  HttpStatus,
  UseGuards,
} from '@nestjs/common';
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
import { UpdateMemberDto } from './dto/update-member.dto';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { CurrentUser } from '../../common/decorators/current-user.decorator';

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
    summary: 'Add a member to a society by phone number',
    description:
      'If the phone number exists in the users table, userId is linked automatically. Otherwise the member is stored with userId = null until they register.',
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
          societyId: 'society-uuid',
          phoneNumber: '+919876543210',
          userId: 'user-uuid or null',
          role: 'member',
          joinedAt: '2026-07-22T10:00:00.000Z',
        },
      },
    },
  })
  @ApiConflictResponse({ description: 'Phone number is already a member of this society' })
  @ApiNotFoundResponse({ description: 'Society not found' })
  async addMember(@Param('societyId') societyId: string, @Body() dto: AddMemberDto) {
    const data = await this.societiesService.addMember(societyId, dto);
    return { success: true, message: 'Member added successfully', data };
  }

  @Get(':societyId/members')
  @ApiOperation({ summary: 'Get all members of a society' })
  @ApiParam({ name: 'societyId', description: 'Society UUID' })
  @ApiOkResponse({ description: 'List of society members' })
  @ApiNotFoundResponse({ description: 'Society not found' })
  async getMembers(@Param('societyId') societyId: string) {
    const data = await this.societiesService.getMembers(societyId);
    return { success: true, message: 'Members retrieved successfully', data };
  }

  @Put(':societyId/members/:memberId')
  @ApiOperation({ summary: 'Update a member phone number or name' })
  @ApiParam({ name: 'societyId', description: 'Society UUID' })
  @ApiParam({ name: 'memberId', description: 'Member UUID' })
  @ApiBody({ type: UpdateMemberDto })
  @ApiOkResponse({ description: 'Member updated successfully' })
  @ApiNotFoundResponse({ description: 'Member not found in this society' })
  @ApiConflictResponse({ description: 'Phone number already belongs to another member' })
  async updateMember(
    @Param('societyId') societyId: string,
    @Param('memberId') memberId: string,
    @Body() dto: UpdateMemberDto,
    @CurrentUser('id') requestingUserId: string,
  ) {
    const data = await this.societiesService.updateMember(
      societyId,
      memberId,
      dto,
      requestingUserId,
    );
    return { success: true, message: 'Member updated successfully', data };
  }

  @Delete(':societyId/members/:memberId')
  @ApiOperation({ summary: 'Remove a member from a society' })
  @ApiParam({ name: 'societyId', description: 'Society UUID' })
  @ApiParam({ name: 'memberId', description: 'Member UUID' })
  @ApiOkResponse({ description: 'Member removed successfully' })
  @ApiNotFoundResponse({ description: 'Member not found in this society' })
  async removeMember(
    @Param('societyId') societyId: string,
    @Param('memberId') memberId: string,
    @CurrentUser('id') requestingUserId: string,
  ) {
    const data = await this.societiesService.removeMember(societyId, memberId, requestingUserId);
    return { success: true, message: 'Member removed successfully', data };
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
