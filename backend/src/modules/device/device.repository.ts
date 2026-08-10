import { Injectable } from '@nestjs/common';
import { PrismaService } from '../../prisma/prisma.service';
import { EspRegistration, Topic } from '@prisma/client';

type EspWithTopics = EspRegistration & { topics: Topic };

// Pre-refactor EspRegistration shape (topics were flat columns on this table).
// Endpoints that serialize records directly (not through DeviceService.format()/
// getInfo()) must keep returning exactly this shape.
type FlatEspRegistration = Omit<EspRegistration, 'topicsId'> & {
  commandTopic: string;
  telemetryTopic: string;
  alertTopic: string;
  heartbeatTopic: string;
};

@Injectable()
export class DeviceRepository {
  constructor(private readonly prisma: PrismaService) {}

  private flatten(r: EspWithTopics): FlatEspRegistration {
    const { topics, topicsId: _topicsId, ...rest } = r;
    return {
      ...rest,
      commandTopic: topics.commandTopic,
      telemetryTopic: topics.telemetryTopic,
      alertTopic: topics.alertTopic,
      heartbeatTopic: topics.heartbeatTopic,
    };
  }

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
  }): Promise<EspWithTopics> {
    const { commandTopic, telemetryTopic, alertTopic, heartbeatTopic, ...rest } = data;
    return this.prisma.espRegistration.create({
      data: {
        ...rest,
        topics: {
          create: { commandTopic, telemetryTopic, alertTopic, heartbeatTopic },
        },
      },
      include: { topics: true },
    });
  }

  async findAll(): Promise<EspWithTopics[]> {
    return this.prisma.espRegistration.findMany({
      orderBy: { createdAt: 'asc' },
      include: { topics: true },
    });
  }

  async findOneBySerialNumber(serialNumber: string): Promise<EspWithTopics | null> {
    return this.prisma.espRegistration.findFirst({
      where: { serialNumber },
      orderBy: { createdAt: 'desc' },
      include: { topics: true },
    });
  }

  async findBySerialNumber(serialNumber: string): Promise<FlatEspRegistration[]> {
    const records = await this.prisma.espRegistration.findMany({
      where: { serialNumber: { equals: serialNumber, mode: 'insensitive' } },
      orderBy: { createdAt: 'desc' },
      include: { topics: true },
    });
    return records.map((r) => this.flatten(r));
  }

  async findByUserId(userId: string): Promise<FlatEspRegistration[]> {
    const records = await this.prisma.espRegistration.findMany({
      where: { userId },
      orderBy: { createdAt: 'desc' },
      include: { topics: true },
    });
    return records.map((r) => this.flatten(r));
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
        include: { topics: true },
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
