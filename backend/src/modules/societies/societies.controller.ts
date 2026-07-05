import { Controller, Post, Get, Param, Body, HttpCode, HttpStatus, UseGuards } from '@nestjs/common';
import {
  ApiTags,
  ApiOperation,
  ApiCreatedResponse,
  ApiOkResponse,
  ApiNotFoundResponse,
  ApiBearerAuth,
  ApiBody,
} from '@nestjs/swagger';
import { SocietiesService } from './societies.service';
import { CreateSocietyDto } from './dto/create-society.dto';
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
  @ApiCreatedResponse({
    description: 'Society registered successfully',
    schema: {
      example: {
        success: true,
        message: 'Society registered successfully',
        data: {
          id: 'uuid',
          name: 'Rahul Sharma',
          societyName: 'Green Valley Apartments',
          blockOrWing: 'Block A',
          totalMembers: 120,
          createdAt: '2026-05-20T10:00:00.000Z',
          updatedAt: '2026-05-20T10:00:00.000Z',
        },
      },
    },
  })
  async create(@Body() createSocietyDto: CreateSocietyDto) {
    const data = await this.societiesService.create(createSocietyDto);
    return {
      success: true,
      message: 'Society registered successfully',
      data,
    };
  }

  @Get()
  @ApiOperation({ summary: 'Get all societies' })
  @ApiOkResponse({ description: 'List of all societies' })
  async findAll() {
    const data = await this.societiesService.findAll();
    return {
      success: true,
      message: 'Societies retrieved successfully',
      data,
    };
  }

  @Get(':id')
  @ApiOperation({ summary: 'Get a society by ID' })
  @ApiOkResponse({ description: 'Society found' })
  @ApiNotFoundResponse({ description: 'Society not found' })
  async findOne(@Param('id') id: string) {
    const data = await this.societiesService.findById(id);
    return {
      success: true,
      message: 'Society retrieved successfully',
      data,
    };
  }
}
