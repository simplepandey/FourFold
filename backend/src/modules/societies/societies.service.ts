import { Injectable, NotFoundException, ConflictException } from '@nestjs/common';
import * as bcrypt from 'bcrypt';
import { randomBytes } from 'crypto';
import { SocietiesRepository } from './societies.repository';
import { UsersService } from '../users/users.service';
import { DeviceService } from '../device/device.service';
import { CreateSocietyDto } from './dto/create-society.dto';
import { AddMemberDto } from './dto/add-member.dto';
import { Society } from '@prisma/client';

@Injectable()
export class SocietiesService {
  constructor(
    private readonly societiesRepository: SocietiesRepository,
    private readonly usersService: UsersService,
    private readonly deviceService: DeviceService,
  ) {}

  async create(dto: CreateSocietyDto) {
    const existing = await this.societiesRepository.findByPhoneNumber(dto.phoneNumber);
    if (existing) {
      throw new ConflictException('A society with this phone number already exists');
    }

    const societyCode = 'SOC-' + randomBytes(4).toString('hex').toUpperCase();

    const society = await this.societiesRepository.create({
      phoneNumber: dto.phoneNumber,
      name: dto.name,
      societyName: dto.societyName,
      blockOrWing: dto.blockOrWing,
      totalMembers: dto.totalMembers,
      societyCode,
    });

    const user = await this.societiesRepository.findUserByPhone(dto.phoneNumber);
    if (user && dto.password) {
      const hashedPassword = await bcrypt.hash(dto.password, 10);
      await this.usersService.setPassword(user.id, hashedPassword);
    }

    return society;
  }

  // Members are only ever granted access to a specific device — there's no
  // society-wide roster anymore. The society's own admin logs in via
  // societyLogin (password, matched on Society.phoneNumber directly), so
  // they never needed a roster entry either.
  async addMember(societyId: string, dto: AddMemberDto) {
    const society = await this.societiesRepository.findById(societyId);
    if (!society) {
      throw new NotFoundException(`Society with id '${societyId}' not found`);
    }
    const societyCode = society.societyCode!;

    const existingDeviceLink = await this.deviceService.findDeviceMemberByPhone(
      dto.productCode,
      dto.phoneNumber,
    );
    if (existingDeviceLink) {
      throw new ConflictException('This phone number already has access to this device');
    }

    const user = await this.societiesRepository.findUserByPhone(dto.phoneNumber);

    return this.deviceService.addDeviceMember({
      productCode: dto.productCode,
      societyCode,
      phoneNumber: dto.phoneNumber,
      userId: user?.id ?? null,
      role: 'member',
    });
  }

  async findById(id: string) {
    const society = await this.societiesRepository.findById(id);
    if (!society) {
      throw new NotFoundException(`Society with id ${id} not found`);
    }
    return society;
  }

  async findByPhoneNumber(phoneNumber: string): Promise<Society | null> {
    return this.societiesRepository.findByPhoneNumber(phoneNumber);
  }

  async findAll() {
    return this.societiesRepository.findAll();
  }
}
