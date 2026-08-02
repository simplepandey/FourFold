import { Injectable } from '@nestjs/common';
import { PrismaService } from '../../prisma/prisma.service';
import { ModuleActionLog, Prisma } from '@prisma/client';

@Injectable()
export class ModuleActionLogRepository {
  constructor(private readonly prisma: PrismaService) {}

  async create(data: Prisma.ModuleActionLogCreateInput): Promise<ModuleActionLog> {
    return this.prisma.moduleActionLog.create({ data });
  }

  async findBySerialNumber(serialNumber: string): Promise<ModuleActionLog[]> {
    return this.prisma.moduleActionLog.findMany({
      where: { serialNumber },
      orderBy: { createdAt: 'desc' },
      take: 100,
    });
  }
}
