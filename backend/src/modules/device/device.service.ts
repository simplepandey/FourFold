import { Injectable, NotFoundException } from '@nestjs/common';
import { createHash } from 'crypto';
import { DeviceRepository } from './device.repository';
import { EspTopicCacheService } from './esp-topic-cache.service';

@Injectable()
export class DeviceService {
  constructor(
    private readonly repository: DeviceRepository,
    private readonly topicCache: EspTopicCacheService,
  ) {}

  async register(serialNumber: string, type?: string): Promise<{ data: object; created: boolean }> {
    const existing = await this.repository.findOneBySerialNumber(serialNumber);
    if (existing) {
      this.topicCache.set(existing.productCode, existing.topics);
      return { data: this.format(existing), created: false };
    }

    const serialHash = createHash('sha256').update(serialNumber).digest('hex').substring(0, 12);
    const productCode = await this.repository.nextProductCode();

    const base = `motors/${productCode}`;
    const registration = await this.repository.create({
      serialNumber,
      serialHash,
      productCode,
      type,
      commandTopic: `${base}/commands`,
      telemetryTopic: `${base}/telemetry`,
      alertTopic: `${base}/alert`,
      heartbeatTopic: `${base}/heartbeat`,
    });

    this.topicCache.set(registration.productCode, registration.topics);

    return { data: this.format(registration), created: true };
  }

  private format(r: {
    id: string;
    serialNumber: string;
    serialHash: string;
    productCode: string;
    type: string | null;
    username: string | null;
    userId: string | null;
    societyId: string | null;
    topics: {
      commandTopic: string;
      telemetryTopic: string;
      alertTopic: string;
      heartbeatTopic: string;
    };
    createdAt: Date;
  }) {
    return {
      id: r.id,
      serialNumber: r.serialNumber,
      serialHash: r.serialHash,
      productCode: r.productCode,
      type: r.type,
      username: r.username,
      userId: r.userId,
      societyId: r.societyId,
      topics: {
        commands: r.topics.commandTopic,
        telemetry: r.topics.telemetryTopic,
        alert: r.topics.alertTopic,
        heartbeat: r.topics.heartbeatTopic,
      },
      createdAt: r.createdAt,
    };
  }

  async findBySerialNumber(serialNumber: string) {
    const records = await this.repository.findBySerialNumber(serialNumber);
    if (!records || records.length === 0) {
      throw new NotFoundException(`Device with serial number '${serialNumber}' not found`);
    }
    return records;
  }

  async findByUserId(userId: string) {
    return this.repository.findByUserId(userId);
  }

  async findByProductCode(productCode: string) {
    const esp = await this.repository.findOneByProductCode(productCode);
    if (!esp) {
      throw new NotFoundException(`Device with product code '${productCode}' not found`);
    }
    return esp;
  }

  async getUserModules(userId: string) {
    return this.repository.findModulesByUserId(userId);
  }

  // ── Per-device membership ────────────────────────────────────────
  async grantDeviceAdmin(productCode: string, societyCode: string, userId: string) {
    await this.repository.upsertDeviceMemberByUserId({
      productCode,
      societyCode,
      userId,
      role: 'admin',
    });
  }

  async isDeviceMember(productCode: string, userId: string): Promise<boolean> {
    const member = await this.repository.findDeviceMemberByUserId(productCode, userId);
    return member !== null;
  }

  async findFirstDeviceMembership(userId: string) {
    return this.repository.findFirstDeviceMemberByUserId(userId);
  }

  async claimDeviceMemberships(phoneNumber: string, userId: string): Promise<void> {
    await this.repository.claimDeviceMembersByPhone(phoneNumber, userId);
  }

  async findDeviceMemberByPhone(productCode: string, phoneNumber: string) {
    return this.repository.findDeviceMemberByPhone(productCode, phoneNumber);
  }

  async addDeviceMember(params: {
    productCode: string;
    societyCode: string;
    phoneNumber: string;
    userId?: string | null;
    role: string;
  }) {
    return this.repository.createDeviceMember(params);
  }

  async getInfo(identifier: string) {
    const { esp, module, members } = await this.repository.findFullInfoBySerialNumber(identifier);

    if (!esp && !module) {
      throw new NotFoundException(`No records found for '${identifier}'`);
    }

    return {
      esp: esp
        ? {
            id: esp.id,
            serialNumber: esp.serialNumber,
            serialHash: esp.serialHash,
            productCode: esp.productCode,
            topics: {
              commands: esp.topics.commandTopic,
              telemetry: esp.topics.telemetryTopic,
              alert: esp.topics.alertTopic,
              heartbeat: esp.topics.heartbeatTopic,
            },
            createdAt: esp.createdAt,
          }
        : null,
      module: module
        ? {
            id: module.id,
            productCode: module.productCode,
            name: module.name,
            registeredTo: module.registeredTo,
            noOfPump: module.noOfPump,
            phase: module.phase,
            hpOfPump: module.hpOfPump,
            address: module.address,
            wingBlock: module.wingBlock,
            pincode: module.pincode,
            district: module.district,
            state: module.state,
            country: module.country,
            createdBy: module.createdBy,
            createDate: module.createDate,
          }
        : null,
      members: members.map((m) => ({
        id: m.id,
        phoneNumber: m.phoneNumber,
        userId: m.userId,
        productCode: m.productCode,
        role: m.role,
        joinedAt: m.joinedAt,
      })),
    };
  }
}
