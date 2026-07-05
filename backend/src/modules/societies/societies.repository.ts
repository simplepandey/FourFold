import { Injectable } from '@nestjs/common';
import { PrismaService } from '../../prisma/prisma.service';
import { Prisma, Society } from '@prisma/client';

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

  async findAll(): Promise<Society[]> {
    return this.prisma.society.findMany({ orderBy: { createdAt: 'desc' } });
  }
}
