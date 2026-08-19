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

  // Atomic under concurrent registrations (e.g. a factory batch booting at
  // once) — a Postgres sequence, not a count-and-increment in app code.
  // Sequence starts at 100, so the first product code is FF00100.
  async nextProductCode(): Promise<string> {
    const rows = await this.prisma.$queryRaw<
      { nextval: bigint }[]
    >`SELECT nextval('product_code_seq') AS nextval`;
    return 'FF' + rows[0].nextval.toString().padStart(5, '0');
  }

  async create(data: {
    serialNumber: string;
    serialHash: string;
    productCode: string;
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

  async findOneByProductCode(productCode: string): Promise<EspWithTopics | null> {
    return this.prisma.espRegistration.findFirst({
      where: { productCode: { equals: productCode, mode: 'insensitive' } },
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
    const members = await this.prisma.deviceMember.findMany({
      where: { userId },
      orderBy: { joinedAt: 'asc' },
    });

    if (members.length === 0) return [];

    const productCodes = members.map((m) => m.productCode);

    const [espRecords, moduleRecords] = await Promise.all([
      this.prisma.espRegistration.findMany({
        where: { productCode: { in: productCodes } },
      }),
      this.prisma.moduleRegistration.findMany({
        where: { productCode: { in: productCodes }, isDeleted: false },
      }),
    ]);

    const espMap = new Map(espRecords.map((e) => [e.productCode, e]));
    const moduleMap = new Map(moduleRecords.map((m) => [m.productCode, m]));

    return members.map((m) => {
      const esp = espMap.get(m.productCode) ?? null;
      const module = moduleMap.get(m.productCode) ?? null;
      return {
        productCode: m.productCode,
        name: module?.name ?? null,
        societyCode: m.societyCode,
        role: m.role,
        joinedAt: m.joinedAt,
        esp: esp ? { id: esp.id, serialHash: esp.serialHash, createdAt: esp.createdAt } : null,
      };
    });
  }

  // ── Per-device membership (DeviceMember) ────────────────────────────
  // Separate from SocietyMember — one person can be linked to many devices,
  // each with its own role, so this is keyed by (productCode, phoneNumber)
  // rather than living as a single column on the society roster.

  async findDeviceMemberByPhone(productCode: string, phoneNumber: string) {
    return this.prisma.deviceMember.findUnique({
      where: { productCode_phoneNumber: { productCode, phoneNumber } },
    });
  }

  async findDeviceMemberByUserId(productCode: string, userId: string) {
    return this.prisma.deviceMember.findFirst({ where: { productCode, userId } });
  }

  // society_members no longer exists — this is how auth now resolves which
  // society a logged-in user belongs to: whichever device they were added
  // to first. Members only ever get added per-device now.
  async findFirstDeviceMemberByUserId(userId: string) {
    return this.prisma.deviceMember.findFirst({
      where: { userId },
      orderBy: { joinedAt: 'asc' },
    });
  }

  async createDeviceMember(data: {
    productCode: string;
    societyCode: string;
    phoneNumber: string;
    userId?: string | null;
    role: string;
  }) {
    return this.prisma.deviceMember.create({ data });
  }

  // A phone number can be granted device access before it ever has a User
  // account (added via "Add Member" while userId is still unknown). Called
  // on every login so that once they do sign up, any devices they were
  // already added to become visible immediately instead of staying
  // orphaned by userId forever.
  async claimDeviceMembersByPhone(phoneNumber: string, userId: string): Promise<void> {
    await this.prisma.deviceMember.updateMany({
      where: { phoneNumber, userId: null },
      data: { userId },
    });
  }

  // Used when registering a device: the registering user becomes admin of
  // that specific device. Resolves phoneNumber from userId internally, same
  // as the old (now-removed) SocietyMember-based version did.
  async upsertDeviceMemberByUserId(params: {
    productCode: string;
    societyCode: string;
    userId: string;
    role: string;
  }): Promise<void> {
    const user = await this.prisma.user.findUnique({ where: { id: params.userId } });
    if (!user) return;

    await this.prisma.deviceMember.upsert({
      where: {
        productCode_phoneNumber: { productCode: params.productCode, phoneNumber: user.phoneNumber },
      },
      update: { role: params.role, userId: params.userId },
      create: {
        productCode: params.productCode,
        societyCode: params.societyCode,
        phoneNumber: user.phoneNumber,
        userId: params.userId,
        role: params.role,
      },
    });
  }

  // identifier can be either the ESP's serialNumber or its productCode — the
  // app only has productCode once a device is added (module-registration and
  // everything downstream of it is now productCode-keyed), but this stays a
  // single flexible lookup rather than a second endpoint, so the excepted
  // esp_registration table/POST /device/register route stay untouched.
  async findFullInfoBySerialNumber(identifier: string) {
    const esp = await this.prisma.espRegistration.findFirst({
      where: { OR: [{ serialNumber: identifier }, { productCode: identifier }] },
      orderBy: { createdAt: 'desc' },
      include: { topics: true },
    });

    // module_registration is now keyed by productCode, not serialNumber, so
    // this lookup can only run once we know the ESP's productCode.
    const module = esp
      ? await this.prisma.moduleRegistration.findFirst({
          where: { productCode: esp.productCode, isDeleted: false },
        })
      : null;

    // Members of this specific device (not the whole society) — a society
    // can have several devices with different people granted access to each.
    let members: {
      id: string;
      phoneNumber: string;
      userId: string | null;
      productCode: string | null;
      role: string;
      joinedAt: Date;
    }[] = [];
    if (esp) {
      members = await this.prisma.deviceMember.findMany({
        where: { productCode: esp.productCode },
        orderBy: { joinedAt: 'asc' },
      });
    }

    return { esp, module, members };
  }
}
