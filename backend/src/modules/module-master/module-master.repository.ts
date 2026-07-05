import { Injectable } from '@nestjs/common';
import { PrismaService } from '../../prisma/prisma.service';
import { ModuleMaster, Prisma } from '@prisma/client';

@Injectable()
export class ModuleMasterRepository {
  constructor(private readonly prisma: PrismaService) {}

  async create(data: Prisma.ModuleMasterCreateInput): Promise<ModuleMaster> {
    return this.prisma.moduleMaster.create({ data });
  }

  async findAll(): Promise<ModuleMaster[]> {
    return this.prisma.moduleMaster.findMany({
      where: { isDeleted: false },
      orderBy: { createDate: 'desc' },
    });
  }

  async findById(id: string): Promise<ModuleMaster | null> {
    return this.prisma.moduleMaster.findFirst({
      where: { id, isDeleted: false },
    });
  }

  async findBySerialNumber(serialNumber: string): Promise<ModuleMaster | null> {
    return this.prisma.moduleMaster.findFirst({
      where: { serialNumber, isDeleted: false },
    });
  }

  async update(id: string, data: Prisma.ModuleMasterUpdateInput): Promise<ModuleMaster> {
    return this.prisma.moduleMaster.update({ where: { id }, data });
  }

  async softDelete(id: string, updatedBy: string): Promise<ModuleMaster> {
    return this.prisma.moduleMaster.update({
      where: { id },
      data: { isDeleted: true, updatedBy },
    });
  }
}
