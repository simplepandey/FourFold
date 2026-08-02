import { Injectable, Logger } from '@nestjs/common';
import { TelemetryRepository } from './telemetry.repository';
import { ModuleStatusService } from '../module-status/module-status.service';

interface TelemetryPayload {
  v: number; // voltage (V)
  i: number; // current (A)
  oc: number; // over current (A)
  uc: number; // under current (A)
  gt?: number; // ground tank (%)
  oh?: number; // overhead tank (%)
  motor: boolean; // motor relay state
  sn: number; // ESP32 serial number
}

@Injectable()
export class TelemetryService {
  private readonly logger = new Logger(TelemetryService.name);

  constructor(
    private readonly repository: TelemetryRepository,
    private readonly moduleStatusService: ModuleStatusService,
  ) {}

  async processTelemetry(topic: string, rawPayload: string): Promise<void> {
    const { serialHash } = this.parseTopic(topic);

    let payload: TelemetryPayload;
    try {
      payload = JSON.parse(rawPayload);
    } catch {
      this.logger.warn(`Invalid JSON on telemetry topic '${topic}': ${rawPayload}`);
      return;
    }

    const registration = await this.repository.findRegistrationByHash(serialHash);
    const serialNumber = registration?.serialNumber ?? payload.sn.toString();

    await this.repository.createTelemetry({
      serialHash,
      serialNumber,
      voltage: payload.v,
      current: payload.i,
      overcurrent: payload.oc,
      undercurrent: payload.uc,
      groundTank: payload.gt ?? null,
      overheadTank: payload.oh ?? null,
      motorRunning: payload.motor,
    });

    await this.moduleStatusService.upsert({
      serialNumber,
      voltage: payload.v,
      current: payload.i,
      overcurrent: payload.oc,
      undercurrent: payload.uc,
      ...(payload.oh !== undefined && { overheadTankLevel: Math.round(payload.oh) }),
      ...(payload.gt !== undefined && { undergroundTankLevel: Math.round(payload.gt) }),
      motorStatus: payload.motor ? 'ON' : 'OFF',
      updatedBy: 'device',
    });

    this.logger.log(
      `Telemetry stored — serial=${serialNumber} motor=${payload.motor ? 'running' : 'stopped'} v=${payload.v}V i=${payload.i}A oc=${payload.oc} uc=${payload.uc} gt=${payload.gt ?? '-'}% oh=${payload.oh ?? '-'}%`,
    );
  }

  async processAlert(topic: string, rawPayload: string): Promise<void> {
    const { serialHash } = this.parseTopic(topic);

    let payload: { overcurrent_breached?: number; undercurrent_breached?: number } = {};
    try {
      payload = JSON.parse(rawPayload);
    } catch {
      this.logger.warn(`Invalid JSON on alert topic '${topic}': ${rawPayload}`);
      return;
    }

    const registration = await this.repository.findRegistrationByHash(serialHash);
    const serialNumber = registration?.serialNumber ?? serialHash;

    await this.repository.createAlert({
      serialHash,
      serialNumber,
      overcurrentBreached: payload.overcurrent_breached ?? null,
      undercurrentBreached: payload.undercurrent_breached ?? null,
    });

    await this.moduleStatusService.upsert({
      serialNumber,
      ocBreached: payload.overcurrent_breached != null,
      ucBreached: payload.undercurrent_breached != null,
      updatedBy: 'device',
    });

    this.logger.warn(
      `Alert stored — serial=${serialNumber} overcurrent=${payload.overcurrent_breached ?? '-'} undercurrent=${payload.undercurrent_breached ?? '-'}`,
    );
  }

  private parseTopic(topic: string): { serialHash: string } {
    // topic shape: motors/{serialHash}/telemetry|alert
    const segments = topic.split('/');
    return { serialHash: segments[1] };
  }
}
