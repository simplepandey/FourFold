import { Injectable } from '@nestjs/common';
import { PrismaService } from '../../prisma/prisma.service';
import { Prisma, Society, SocietyMember, User } from '@prisma/client';

@Injectable()
export class SocietiesRepository {
  constructor(private readonly prisma: PrismaService) {}

  async create(data: Prisma.SocietyCreateInput): Promise<Society> {
    return this.prisma.society.create({ data });
  }

  async findById(id: string): Promise<Society | null> {
    return this.prisma.society.findUnique({ where: { id } });
  }

  async findByPhoneNumber(phoneNumber: string): Promise<Society | null> {
    return this.prisma.society.findUnique({ where: { phoneNumber } });
  }

  async findBySocietyCode(societyCode: string): Promise<Society | null> {
    return this.prisma.society.findUnique({ where: { societyCode } });
  }

  async findAll(): Promise<Society[]> {
    return this.prisma.society.findMany({ orderBy: { createdAt: 'desc' } });
  }

  async createMember(data: {
    societyCode: string;
    phoneNumber: string;
    userId?: string | null;
    serialNumber?: string | null;
    role: string;
  }): Promise<SocietyMember> {
    return this.prisma.societyMember.create({ data });
  }

  async findMemberByPhone(societyCode: string, phoneNumber: string): Promise<SocietyMember | null> {
    return this.prisma.societyMember.findUnique({
      where: { societyCode_phoneNumber: { societyCode, phoneNumber } },
    });
  }

  async findMemberByUserId(societyCode: string, userId: string): Promise<SocietyMember | null> {
    return this.prisma.societyMember.findFirst({
      where: { societyCode, userId },
    });
  }

  async findMembersBySociety(societyCode: string): Promise<SocietyMember[]> {
    return this.prisma.societyMember.findMany({
      where: { societyCode },
      orderBy: { joinedAt: 'asc' },
    });
  }

  async findUserByPhone(phoneNumber: string): Promise<User | null> {
    return this.prisma.user.findUnique({ where: { phoneNumber } });
  }

  async findMemberById(memberId: string): Promise<SocietyMember | null> {
    return this.prisma.societyMember.findUnique({ where: { id: memberId } });
  }

  async updateMember(
    memberId: string,
    data: { phoneNumber?: string; userId?: string | null; role?: string },
  ): Promise<SocietyMember> {
    return this.prisma.societyMember.update({ where: { id: memberId }, data });
  }

  async deleteMember(memberId: string): Promise<SocietyMember> {
    return this.prisma.societyMember.delete({ where: { id: memberId } });
  }

  async updateUserName(userId: string, name: string): Promise<User> {
    return this.prisma.user.update({ where: { id: userId }, data: { name } });
  }

  async findFirstMemberByUserId(userId: string): Promise<SocietyMember | null> {
    return this.prisma.societyMember.findFirst({
      where: { userId },
      orderBy: { joinedAt: 'asc' },
    });
  }

  async updateMemberSerialNumber(
    societyCode: string,
    userId: string,
    serialNumber: string,
  ): Promise<SocietyMember | null> {
    const user = await this.prisma.user.findUnique({ where: { id: userId } });
    if (!user) return null;

    return this.prisma.societyMember.upsert({
      where: { societyCode_phoneNumber: { societyCode, phoneNumber: user.phoneNumber } },
      update: { serialNumber, userId },
      create: { societyCode, phoneNumber: user.phoneNumber, userId, serialNumber, role: 'admin' },
    });
  }
}
