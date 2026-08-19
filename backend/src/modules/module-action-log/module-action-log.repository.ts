import { Injectable } from '@nestjs/common';
import { PrismaService } from '../../prisma/prisma.service';
import { ModuleActionLog, Prisma } from '@prisma/client';

@Injectable()
export class ModuleActionLogRepository {
  constructor(private readonly prisma: PrismaService) {}

  async create(data: Prisma.ModuleActionLogCreateInput): Promise<ModuleActionLog> {
    return this.prisma.moduleActionLog.create({ data });
  }

  async findByProductCode(productCode: string): Promise<ModuleActionLog[]> {
    return this.prisma.moduleActionLog.findMany({
      where: { productCode },
      orderBy: { createdAt: 'desc' },
      take: 100,
    });
  }
}
