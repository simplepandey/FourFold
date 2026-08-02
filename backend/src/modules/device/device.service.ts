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
      this.topicCache.set(existing.serialNumber, {
        commandTopic: existing.commandTopic,
        telemetryTopic: existing.telemetryTopic,
        alertTopic: existing.alertTopic,
        heartbeatTopic: existing.heartbeatTopic,
      });
      return { data: this.format(existing), created: false };
    }

    const serialHash = createHash('sha256').update(serialNumber).digest('hex').substring(0, 12);

    const base = `motors/${serialHash}`;
    const registration = await this.repository.create({
      serialNumber,
      serialHash,
      type,
      commandTopic: `${base}/commands`,
      telemetryTopic: `${base}/telemetry`,
      alertTopic: `${base}/alert`,
      heartbeatTopic: `${base}/heartbeat`,
    });

    this.topicCache.set(registration.serialNumber, {
      commandTopic: registration.commandTopic,
      telemetryTopic: registration.telemetryTopic,
      alertTopic: registration.alertTopic,
      heartbeatTopic: registration.heartbeatTopic,
    });

    return { data: this.format(registration), created: true };
  }

  private format(r: {
    id: string;
    serialNumber: string;
    serialHash: string;
    type: string | null;
    username: string | null;
    userId: string | null;
    societyId: string | null;
    commandTopic: string;
    telemetryTopic: string;
    alertTopic: string;
    heartbeatTopic: string;
    createdAt: Date;
  }) {
    return {
      id: r.id,
      serialNumber: r.serialNumber,
      serialHash: r.serialHash,
      type: r.type,
      username: r.username,
      userId: r.userId,
      societyId: r.societyId,
      topics: {
        commands: r.commandTopic,
        telemetry: r.telemetryTopic,
        alert: r.alertTopic,
        heartbeat: r.heartbeatTopic,
      },
      createdAt: r.createdAt,
    };
  }

  async findBySerialNumber(serialNumber: string) {
    const records = await this.repository.findBySerialNumber(serialNumber);
    if (!records || records.length === 0) {
      throw new NotFoundException(`Device with serial number '${serialNumber}' not found`);
    }
    return true;
  }

  async findByUserId(userId: string) {
    return this.repository.findByUserId(userId);
  }

  async getUserModules(userId: string) {
    return this.repository.findModulesByUserId(userId);
  }

  async getInfo(serialNumber: string) {
    const { esp, module, members } = await this.repository.findFullInfoBySerialNumber(serialNumber);

    if (!esp && !module) {
      throw new NotFoundException(`No records found for serial number '${serialNumber}'`);
    }

    return {
      esp: esp
        ? {
            id: esp.id,
            serialNumber: esp.serialNumber,
            serialHash: esp.serialHash,
            topics: {
              commands: esp.commandTopic,
              telemetry: esp.telemetryTopic,
              alert: esp.alertTopic,
              heartbeat: esp.heartbeatTopic,
            },
            createdAt: esp.createdAt,
          }
        : null,
      module: module
        ? {
            id: module.id,
            serialNumber: module.serialNumber,
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
        serialNumber: m.serialNumber,
        role: m.role,
        joinedAt: m.joinedAt,
      })),
    };
  }
}
