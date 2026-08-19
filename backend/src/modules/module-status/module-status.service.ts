import { Injectable, Logger, NotFoundException, OnModuleInit } from '@nestjs/common';
import { randomUUID } from 'crypto';
import { ModuleStatusRepository } from './module-status.repository';
import { EspTopicCacheService } from '../device/esp-topic-cache.service';
import { HeartbeatRegistryService } from '../device/heartbeat-registry.service';
import { MqttService } from '../mqtt/mqtt.service';

export interface ModuleStatusUpsertInput {
  productCode: string;
  voltage?: number;
  current?: number;
  overcurrent?: number;
  undercurrent?: number;
  overheadTankLevel?: number;
  undergroundTankLevel?: number;
  motorStatus?: string;
  ocBreached?: boolean;
  ucBreached?: boolean;
  isOnline?: boolean;
  updatedBy?: string;
}

interface HeartbeatPayload {
  id: string; // cmd_id from the SEND_HEARTBEAT command this is answering
  v: number; // voltage (V)
  i: number; // current (A)
  oc: number; // over current (A)
  uc: number; // under current (A)
  motor?: boolean; // motor relay state - optional, older firmware may not send it
}

@Injectable()
export class ModuleStatusService implements OnModuleInit {
  private readonly logger = new Logger(ModuleStatusService.name);
  private static readonly HEARTBEAT_TIMEOUT_MS = 30_000;

  constructor(
    private readonly repository: ModuleStatusRepository,
    private readonly espTopicCache: EspTopicCacheService,
    private readonly heartbeatRegistry: HeartbeatRegistryService,
    private readonly mqttService: MqttService,
  ) {}

  onModuleInit(): void {
    // Heartbeat is a connectivity check, not sensor data — handled here
    // (where the request originates and HeartbeatRegistryService already
    // lives) rather than by TelemetryService.
    this.mqttService.registerHandler('heartbeat', (topic, payload) =>
      this.processHeartbeat(topic, payload),
    );
  }

  /** Upserts by productCode — creates the row with sane defaults on first write, otherwise only touches the fields provided. */
  async upsert(input: ModuleStatusUpsertInput) {
    const { productCode, updatedBy, ...fields } = input;
    return this.repository.upsert(
      productCode,
      {
        productCode,
        voltage: fields.voltage ?? 0,
        current: fields.current ?? 0,
        overcurrent: fields.overcurrent ?? 0,
        undercurrent: fields.undercurrent ?? 0,
        overheadTankLevel: fields.overheadTankLevel ?? 0,
        undergroundTankLevel: fields.undergroundTankLevel ?? 0,
        motorStatus: fields.motorStatus ?? 'OFF',
        ocBreached: fields.ocBreached ?? false,
        ucBreached: fields.ucBreached ?? false,
        isOnline: fields.isOnline ?? false,
        updatedBy,
      },
      {
        ...(fields.voltage !== undefined && { voltage: fields.voltage }),
        ...(fields.current !== undefined && { current: fields.current }),
        ...(fields.overcurrent !== undefined && { overcurrent: fields.overcurrent }),
        ...(fields.undercurrent !== undefined && { undercurrent: fields.undercurrent }),
        ...(fields.overheadTankLevel !== undefined && {
          overheadTankLevel: fields.overheadTankLevel,
        }),
        ...(fields.undergroundTankLevel !== undefined && {
          undergroundTankLevel: fields.undergroundTankLevel,
        }),
        ...(fields.motorStatus !== undefined && { motorStatus: fields.motorStatus }),
        ...(fields.ocBreached !== undefined && { ocBreached: fields.ocBreached }),
        ...(fields.ucBreached !== undefined && { ucBreached: fields.ucBreached }),
        ...(fields.isOnline !== undefined && { isOnline: fields.isOnline }),
        updatedBy,
      },
    );
  }

  // Called from GET /module-status/:productCode (dashboard device tap) —
  // pings the device for a fresh heartbeat and WAITS for the outcome (up to
  // HEARTBEAT_TIMEOUT_MS) before responding, so the caller always gets a
  // definitive answer: either confirmed-online with fresh readings, or
  // confirmed-offline.
  async findByProductCode(productCode: string) {
    await this.requestHeartbeatAndWait(productCode);

    const status = await this.repository.findByProductCode(productCode);
    if (!status) {
      throw new NotFoundException(`No status found for product code '${productCode}'`);
    }
    return status;
  }

  findByProductCodeOrNull(productCode: string) {
    return this.repository.findByProductCode(productCode);
  }

  private async requestHeartbeatAndWait(productCode: string): Promise<void> {
    try {
      const topics = await this.espTopicCache.getTopics(productCode);
      const cmdId = randomUUID();

      // Resolves as soon as heartbeatRegistry.consume(cmdId) is called by
      // EITHER path below — a real reply (processHeartbeat) or the timeout
      // giving up. Whichever happens first "wins"; the other's consume()
      // call just returns null since the entry is already gone.
      const settled = new Promise<void>((resolve) => {
        this.heartbeatRegistry.register(cmdId, productCode, resolve);
      });

      await this.mqttService.publish(topics.commandTopic, {
        cmd: 'SEND_HEARTBEAT',
        cmd_id: cmdId,
        ts: Math.floor(Date.now() / 1000),
      });
      // Deliberately separate from MqttService's generic publish log — this
      // is the one to grep for when testing without real hardware: copy the
      // cmd_id into scripts/simulate-heartbeat.js.
      this.logger.log(`Heartbeat requested for '${productCode}' — cmd_id: ${cmdId}`);

      setTimeout(() => {
        const entry = this.heartbeatRegistry.consume(cmdId);
        if (!entry) return;
        this.upsert({ productCode: entry.productCode, isOnline: false, updatedBy: 'system' })
          .catch((err: Error) =>
            this.logger.error(`Failed to mark '${entry.productCode}' offline: ${err.message}`),
          )
          .finally(() => entry.resolve());
        this.logger.warn(
          `No heartbeat reply for '${entry.productCode}' within ${ModuleStatusService.HEARTBEAT_TIMEOUT_MS / 1000}s — marked offline`,
        );
      }, ModuleStatusService.HEARTBEAT_TIMEOUT_MS);

      await settled;
    } catch (err) {
      // Device may be unregistered or the broker unreachable — don't let
      // that break the status read, just serve the last-known row.
      this.logger.warn(
        `Failed to request heartbeat for '${productCode}': ${(err as Error).message}`,
      );
    }
  }

  // Answers a SEND_HEARTBEAT command from requestHeartbeat() above. Only
  // trusted if `id` matches a request we actually sent (HeartbeatRegistryService)
  // — an unsolicited message on this topic is logged and ignored rather than
  // blindly marking the device online.
  private async processHeartbeat(topic: string, rawPayload: string): Promise<void> {
    let payload: HeartbeatPayload;
    try {
      payload = JSON.parse(rawPayload);
    } catch {
      this.logger.warn(`Invalid JSON on heartbeat topic '${topic}': ${rawPayload}`);
      return;
    }

    const entry = this.heartbeatRegistry.consume(payload.id);
    if (!entry) {
      this.logger.warn(
        `Heartbeat on '${topic}' with id '${payload.id}' doesn't match a pending request — ignoring`,
      );
      return;
    }
    const { productCode } = entry;

    try {
      // Same reasoning as TelemetryService.processTelemetry(): ocBreached/
      // ucBreached are only ever set true (by processAlert), never cleared
      // — a manual refresh (GET /module-status, which lands here via
      // requestHeartbeatAndWait) would otherwise keep showing a stale
      // breach forever even once current is genuinely back in range. Only
      // clear while the motor is confirmed running - a near-zero reading
      // because the relay is still latched off after a real fault must not
      // look like "resolved".
      const clearOc = payload.motor === true && payload.i <= payload.oc;
      const clearUc = payload.motor === true && payload.i >= payload.uc;

      await this.upsert({
        productCode,
        voltage: payload.v,
        current: payload.i,
        overcurrent: payload.oc,
        undercurrent: payload.uc,
        ...(payload.motor !== undefined && { motorStatus: payload.motor ? 'ON' : 'OFF' }),
        ...(clearOc && { ocBreached: false }),
        ...(clearUc && { ucBreached: false }),
        isOnline: true,
        updatedBy: 'device',
      });

      this.logger.log(
        `Heartbeat confirmed — product=${productCode} v=${payload.v}V i=${payload.i}A oc=${payload.oc} uc=${payload.uc}`,
      );
    } finally {
      // Only now — the write is actually done — is it safe to wake up the
      // GET request waiting on this outcome (see requestHeartbeatAndWait).
      entry.resolve();
    }
  }
}
