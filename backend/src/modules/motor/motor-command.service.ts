import {
  Injectable,
  ServiceUnavailableException,
  ForbiddenException,
  BadRequestException,
} from '@nestjs/common';
import { randomUUID } from 'crypto';
import { MotorCommandRepository } from './motor-command.repository';
import { MqttService } from '../mqtt/mqtt.service';
import { DeviceService } from '../device/device.service';
import { ModuleStatusService } from '../module-status/module-status.service';
import { ModuleActionLogService } from '../module-action-log/module-action-log.service';
import { EspTopicCacheService } from '../device/esp-topic-cache.service';
import { CreateMotorCommandDto } from './dto/create-motor-command.dto';

@Injectable()
export class MotorCommandService {
  constructor(
    private readonly repository: MotorCommandRepository,
    private readonly mqttService: MqttService,
    private readonly deviceService: DeviceService,
    private readonly moduleStatusService: ModuleStatusService,
    private readonly moduleActionLogService: ModuleActionLogService,
    private readonly espTopicCache: EspTopicCacheService,
  ) {}

  async sendCommand(dto: CreateMotorCommandDto) {
    // Device-level, not society-level — being a member of the society
    // doesn't imply access to every device in it.
    const hasAccess = await this.deviceService.isDeviceMember(dto.productCode, dto.commandBy);
    if (!hasAccess) {
      throw new ForbiddenException(
        'User does not have access to this device and cannot send motor commands',
      );
    }

    // SET_MODE only makes sense on a device with sensors driving an Auto
    // state (Two_Tank_System.ino) - a plain manual_controlled device
    // (em_pro_v2_2button.ino) has no such concept, so reject it here
    // rather than publish a command the firmware wouldn't even understand.
    if (dto.command === 'SET_MODE') {
      const esp = await this.deviceService.findByProductCode(dto.productCode);
      if (esp.type !== 'sensor_based_auto_controlled') {
        throw new BadRequestException("Your module doesn't support auto mode");
      }
    }

    const cmdId = randomUUID();
    const topics = await this.espTopicCache.getTopics(dto.productCode);
    const topic = topics.commandTopic;

    // Wire payload stays the generic {cmd, value, cmd_id, ts} shape the
    // firmware already parses for every command - SET_MODE's mode string
    // just rides in the same "value" key SET_OC/SET_UC use for their
    // numeric thresholds, rather than adding a new top-level JSON key.
    const mqttPayload = {
      cmd: dto.command,
      value: dto.command === 'SET_MODE' ? dto.mode! : (dto.value ?? null),
      cmd_id: cmdId,
      ts: Math.floor(Date.now() / 1000),
    };

    let status = 'sent';
    try {
      await this.mqttService.publish(topic, mqttPayload);
    } catch {
      status = 'failed';
      throw new ServiceUnavailableException('Failed to publish command to MQTT broker');
    }

    const created = await this.repository.create({
      societyCode: dto.societyCode,
      motorId: dto.motorId,
      command: dto.command,
      commandBy: dto.commandBy,
      cmdId,
      status,
    });

    const current = await this.moduleStatusService.findByProductCodeOrNull(dto.productCode);

    const motorStatus =
      dto.command === 'TURN_ON'
        ? 'ON'
        : dto.command === 'TURN_OFF'
          ? 'OFF'
          : (current?.motorStatus ?? 'OFF');
    const overcurrent = dto.command === 'SET_OC' ? dto.value! : (current?.overcurrent ?? 0);
    const undercurrent = dto.command === 'SET_UC' ? dto.value! : (current?.undercurrent ?? 0);
    const mode = dto.command === 'SET_MODE' ? dto.mode! : current?.mode;

    await this.moduleActionLogService.create({
      productCode: dto.productCode,
      voltage: current?.voltage ?? 0,
      current: current?.current ?? 0,
      overcurrent,
      undercurrent,
      overheadTankLevel: current?.overheadTankLevel ?? 0,
      undergroundTankLevel: current?.undergroundTankLevel ?? 0,
      motorStatus,
      ocBreached: current?.ocBreached ?? false,
      ucBreached: current?.ucBreached ?? false,
      createdBy: dto.commandBy,
    });

    await this.moduleStatusService.upsert({
      productCode: dto.productCode,
      motorStatus,
      overcurrent,
      undercurrent,
      ...(mode !== undefined && { mode }),
      updatedBy: dto.commandBy,
    });

    return created;
  }

  findAll() {
    return this.repository.findAll();
  }

  findBySocietyAndMotor(societyCode: string, motorId: string) {
    return this.repository.findBySocietyAndMotor(societyCode, motorId);
  }
}
