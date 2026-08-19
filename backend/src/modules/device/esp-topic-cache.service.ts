import { Injectable, Logger, NotFoundException, OnModuleInit } from '@nestjs/common';
import { DeviceRepository } from './device.repository';

export interface EspTopics {
  commandTopic: string;
  telemetryTopic: string;
  alertTopic: string;
  heartbeatTopic: string;
}

/**
 * App-level cache of ESP MQTT topics keyed by productCode (the identifier
 * every other module now uses — the ESP's own serialNumber stays internal
 * to esp_registrations).
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
      this.cache.set(r.productCode, r.topics);
    }
    this.logger.log(`Cached MQTT topics for ${this.cache.size} device(s)`);
  }

  async getTopics(productCode: string): Promise<EspTopics> {
    const cached = this.cache.get(productCode);
    if (cached) {
      return cached;
    }

    const registration = await this.repository.findOneByProductCode(productCode);
    if (!registration) {
      throw new NotFoundException(`No ESP registration found for product code '${productCode}'`);
    }

    const topics = registration.topics;
    this.cache.set(productCode, topics);
    return topics;
  }

  set(productCode: string, topics: EspTopics): void {
    this.cache.set(productCode, topics);
  }
}
