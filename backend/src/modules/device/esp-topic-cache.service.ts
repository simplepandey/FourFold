import { Injectable, Logger, NotFoundException, OnModuleInit } from '@nestjs/common';
import { DeviceRepository } from './device.repository';

export interface EspTopics {
  commandTopic: string;
  telemetryTopic: string;
  alertTopic: string;
  heartbeatTopic: string;
}

/**
 * App-level cache of ESP MQTT topics keyed by serialNumber.
 * Preloaded from esp_registrations on startup; on a cache miss (device
 * registered after boot) it falls back to the DB and backfills the entry.
 */
@Injectable()
export class EspTopicCacheService implements OnModuleInit {
  private readonly logger = new Logger(EspTopicCacheService.name);
  private readonly cache = new Map<string, EspTopics>();

  constructor(private readonly repository: DeviceRepository) {}

  async onModuleInit(): Promise<void> {
    const registrations = await this.repository.findAll();
    for (const r of registrations) {
      this.cache.set(r.serialNumber, r.topics);
    }
    this.logger.log(`Cached MQTT topics for ${this.cache.size} device(s)`);
  }

  async getTopics(serialNumber: string): Promise<EspTopics> {
    const cached = this.cache.get(serialNumber);
    if (cached) {
      return cached;
    }

    const registration = await this.repository.findOneBySerialNumber(serialNumber);
    if (!registration) {
      throw new NotFoundException(`No ESP registration found for serial number '${serialNumber}'`);
    }

    const topics = registration.topics;
    this.cache.set(serialNumber, topics);
    return topics;
  }

  set(serialNumber: string, topics: EspTopics): void {
    this.cache.set(serialNumber, topics);
  }
}
