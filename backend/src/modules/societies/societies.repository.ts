import { Injectable } from '@nestjs/common';
import { PrismaService } from '../../prisma/prisma.service';
import { Prisma, Society, User } from '@prisma/client';

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

  async findUserByPhone(phoneNumber: string): Promise<User | null> {
    return this.prisma.user.findUnique({ where: { phoneNumber } });
  }
}
