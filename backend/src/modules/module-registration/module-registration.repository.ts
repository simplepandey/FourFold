import { Injectable } from '@nestjs/common';
import { PrismaService } from '../../prisma/prisma.service';
import { ModuleRegistration, Prisma } from '@prisma/client';

@Injectable()
export class ModuleRegistrationRepository {
  constructor(private readonly prisma: PrismaService) {}

  async create(data: Prisma.ModuleRegistrationCreateInput): Promise<ModuleRegistration> {
    return this.prisma.moduleRegistration.create({ data });
  }

  async findAll(): Promise<ModuleRegistration[]> {
    return this.prisma.moduleRegistration.findMany({
      where: { isDeleted: false },
      orderBy: { createDate: 'desc' },
    });
  }

  async findById(id: string): Promise<ModuleRegistration | null> {
    return this.prisma.moduleRegistration.findFirst({
      where: { id, isDeleted: false },
    });
  }

  async findActiveBySerialNumber(serialNumber: string): Promise<ModuleRegistration | null> {
    return this.prisma.moduleRegistration.findFirst({
      where: { serialNumber: { equals: serialNumber, mode: 'insensitive' }, isDeleted: false },
    });
  }

  async findAllByRegisteredTo(registeredTo: string): Promise<ModuleRegistration[]> {
    return this.prisma.moduleRegistration.findMany({
      where: { registeredTo, isDeleted: false },
      orderBy: { createDate: 'desc' },
    });
  }

  async update(
    id: string,
    data: Prisma.ModuleRegistrationUpdateInput,
  ): Promise<ModuleRegistration> {
    return this.prisma.moduleRegistration.update({ where: { id }, data });
  }

  async softDelete(id: string, updatedBy: string): Promise<ModuleRegistration> {
    return this.prisma.moduleRegistration.update({
      where: { id },
      data: { isDeleted: true, updatedBy },
    });
  }
}
