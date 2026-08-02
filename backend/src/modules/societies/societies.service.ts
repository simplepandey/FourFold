import {
  Injectable,
  NotFoundException,
  ConflictException,
  ForbiddenException,
} from '@nestjs/common';
import * as bcrypt from 'bcrypt';
import { randomBytes } from 'crypto';
import { SocietiesRepository } from './societies.repository';
import { UsersService } from '../users/users.service';
import { CreateSocietyDto } from './dto/create-society.dto';
import { AddMemberDto } from './dto/add-member.dto';
import { UpdateMemberDto } from './dto/update-member.dto';
import { Society } from '@prisma/client';

@Injectable()
export class SocietiesService {
  constructor(
    private readonly societiesRepository: SocietiesRepository,
    private readonly usersService: UsersService,
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

    await this.societiesRepository.createMember({
      societyCode: society.societyCode!,
      phoneNumber: dto.phoneNumber,
      userId: dto.createdBy ?? user?.id ?? null,
      role: 'admin',
    });

    return society;
  }

  async addMember(societyId: string, dto: AddMemberDto) {
    const society = await this.societiesRepository.findById(societyId);
    if (!society) {
      throw new NotFoundException(`Society with id '${societyId}' not found`);
    }

    const existing = await this.societiesRepository.findMemberByPhone(
      society.societyCode!,
      dto.phoneNumber,
    );
    if (existing) {
      throw new ConflictException('This phone number is already a member of this society');
    }

    const user = await this.societiesRepository.findUserByPhone(dto.phoneNumber);

    return this.societiesRepository.createMember({
      societyCode: society.societyCode!,
      phoneNumber: dto.phoneNumber,
      userId: user?.id ?? null,
      serialNumber: dto.serialNumber ?? null,
      role: 'member',
    });
  }

  async getMembers(societyId: string) {
    const society = await this.societiesRepository.findById(societyId);
    if (!society) {
      throw new NotFoundException(`Society with id '${societyId}' not found`);
    }
    return this.societiesRepository.findMembersBySociety(society.societyCode!);
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

  async updateMember(
    societyId: string,
    memberId: string,
    dto: UpdateMemberDto,
    requestingUserId: string,
  ) {
    const society = await this.societiesRepository.findById(societyId);
    if (!society) {
      throw new NotFoundException(`Society with id '${societyId}' not found`);
    }

    const requester = await this.societiesRepository.findMemberByUserId(
      society.societyCode!,
      requestingUserId,
    );
    if (!requester || requester.role !== 'admin') {
      throw new ForbiddenException('Only admins can update members');
    }

    const member = await this.societiesRepository.findMemberById(memberId);
    if (!member || member.societyCode !== society.societyCode) {
      throw new NotFoundException(`Member not found in this society`);
    }

    const updates: { phoneNumber?: string; userId?: string | null; role?: string } = {};

    if (dto.phoneNumber && dto.phoneNumber !== member.phoneNumber) {
      const conflict = await this.societiesRepository.findMemberByPhone(
        society.societyCode!,
        dto.phoneNumber,
      );
      if (conflict) {
        throw new ConflictException('This phone number is already a member of this society');
      }
      const user = await this.societiesRepository.findUserByPhone(dto.phoneNumber);
      updates.phoneNumber = dto.phoneNumber;
      updates.userId = user?.id ?? null;
    }

    if (dto.role) {
      updates.role = dto.role;
    }

    if (dto.name && member.userId) {
      await this.societiesRepository.updateUserName(member.userId, dto.name);
    }

    if (Object.keys(updates).length === 0) {
      return member;
    }

    return this.societiesRepository.updateMember(memberId, updates);
  }

  async removeMember(societyId: string, memberId: string, requestingUserId: string) {
    const society = await this.societiesRepository.findById(societyId);
    if (!society) {
      throw new NotFoundException(`Society with id '${societyId}' not found`);
    }

    const requester = await this.societiesRepository.findMemberByUserId(
      society.societyCode!,
      requestingUserId,
    );
    if (!requester || requester.role !== 'admin') {
      throw new ForbiddenException('Only admins can remove members');
    }

    const member = await this.societiesRepository.findMemberById(memberId);
    if (!member || member.societyCode !== society.societyCode) {
      throw new NotFoundException(`Member not found in this society`);
    }

    if (requester.id === memberId) {
      throw new ForbiddenException('Admin cannot remove themselves from the society');
    }

    return this.societiesRepository.deleteMember(memberId);
  }

  async checkUserMembership(societyCode: string, userId: string): Promise<boolean> {
    const member = await this.societiesRepository.findMemberByUserId(societyCode, userId);
    return member !== null;
  }

  async isMemberOfSocietyById(societyId: string, userId: string): Promise<boolean> {
    const society = await this.societiesRepository.findById(societyId);
    if (!society || !society.societyCode) return false;
    const member = await this.societiesRepository.findMemberByUserId(society.societyCode, userId);
    return member !== null;
  }
}
