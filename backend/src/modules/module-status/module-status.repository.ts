import { Injectable } from '@nestjs/common';
import { PrismaService } from '../../prisma/prisma.service';
import { ModuleStatus, Prisma } from '@prisma/client';

@Injectable()
export class ModuleStatusRepository {
  constructor(private readonly prisma: PrismaService) {}

  async upsert(
    serialNumber: string,
    create: Prisma.ModuleStatusCreateInput,
    update: Prisma.ModuleStatusUpdateInput,
  ): Promise<ModuleStatus> {
    return this.prisma.moduleStatus.upsert({
      where: { serialNumber },
      create,
      update,
    });
  }

  async findBySerialNumber(serialNumber: string): Promise<ModuleStatus | null> {
    return this.prisma.moduleStatus.findUnique({ where: { serialNumber } });
  }
}
