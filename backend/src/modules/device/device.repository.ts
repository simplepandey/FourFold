import { Injectable } from '@nestjs/common';
import { PrismaService } from '../../prisma/prisma.service';
import { EspRegistration } from '@prisma/client';

@Injectable()
export class DeviceRepository {
  constructor(private readonly prisma: PrismaService) {}

  async create(data: {
    serialNumber: string;
    serialHash: string;
    type?: string;
    username?: string;
    userId?: string;
    societyId?: string;
    commandTopic: string;
    telemetryTopic: string;
    alertTopic: string;
    heartbeatTopic: string;
  }): Promise<EspRegistration> {
    return this.prisma.espRegistration.create({ data });
  }

  async findAll(): Promise<EspRegistration[]> {
    return this.prisma.espRegistration.findMany({ orderBy: { createdAt: 'asc' } });
  }

  async findOneBySerialNumber(serialNumber: string): Promise<EspRegistration | null> {
    return this.prisma.espRegistration.findFirst({
      where: { serialNumber },
      orderBy: { createdAt: 'desc' },
    });
  }

  async findBySerialNumber(serialNumber: string): Promise<EspRegistration[]> {
    return this.prisma.espRegistration.findMany({
      where: { serialNumber },
      orderBy: { createdAt: 'desc' },
    });
  }

  async findByUserId(userId: string): Promise<EspRegistration[]> {
    return this.prisma.espRegistration.findMany({
      where: { userId },
      orderBy: { createdAt: 'desc' },
    });
  }

  async findModulesByUserId(userId: string) {
    const members = await this.prisma.societyMember.findMany({
      where: { userId, serialNumber: { not: null } },
      orderBy: { joinedAt: 'asc' },
    });

    if (members.length === 0) return [];

    const serialNumbers = members.map((m) => m.serialNumber as string);

    const espRecords = await this.prisma.espRegistration.findMany({
      where: { serialNumber: { in: serialNumbers } },
    });

    const espMap = new Map(espRecords.map((e) => [e.serialNumber, e]));

    return members.map((m) => {
      const esp = espMap.get(m.serialNumber as string) ?? null;
      return {
        serialNumber: m.serialNumber as string,
        societyCode: m.societyCode,
        role: m.role,
        joinedAt: m.joinedAt,
        esp: esp ? { id: esp.id, serialHash: esp.serialHash, createdAt: esp.createdAt } : null,
      };
    });
  }

  async findFullInfoBySerialNumber(serialNumber: string) {
    const [esp, module] = await Promise.all([
      this.prisma.espRegistration.findFirst({
        where: { serialNumber },
        orderBy: { createdAt: 'desc' },
      }),
      this.prisma.moduleRegistration.findFirst({
        where: { serialNumber, isDeleted: false },
      }),
    ]);

    let members: {
      id: string;
      phoneNumber: string;
      userId: string | null;
      serialNumber: string | null;
      role: string;
      joinedAt: Date;
    }[] = [];
    if (module?.registeredTo) {
      members = await this.prisma.societyMember.findMany({
        where: { societyCode: module.registeredTo },
        orderBy: { joinedAt: 'asc' },
      });
    }

    return { esp, module, members };
  }
}
