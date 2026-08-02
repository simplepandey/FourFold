import { Injectable, ServiceUnavailableException, ForbiddenException } from '@nestjs/common';
import { randomUUID } from 'crypto';
import { MotorCommandRepository } from './motor-command.repository';
import { MqttService } from '../mqtt/mqtt.service';
import { SocietiesService } from '../societies/societies.service';
import { ModuleStatusService } from '../module-status/module-status.service';
import { ModuleActionLogService } from '../module-action-log/module-action-log.service';
import { EspTopicCacheService } from '../device/esp-topic-cache.service';
import { CreateMotorCommandDto } from './dto/create-motor-command.dto';

@Injectable()
export class MotorCommandService {
  constructor(
    private readonly repository: MotorCommandRepository,
    private readonly mqttService: MqttService,
    private readonly societiesService: SocietiesService,
    private readonly moduleStatusService: ModuleStatusService,
    private readonly moduleActionLogService: ModuleActionLogService,
    private readonly espTopicCache: EspTopicCacheService,
  ) {}

  async sendCommand(dto: CreateMotorCommandDto) {
    const isMember = await this.societiesService.checkUserMembership(
      dto.societyCode,
      dto.commandBy,
    );
    if (!isMember) {
      throw new ForbiddenException(
        'User is not a member of this society and cannot send motor commands',
      );
    }

    const cmdId = randomUUID();
    const topics = await this.espTopicCache.getTopics(dto.serialNumber);
    const topic = topics.commandTopic;

    const mqttPayload = {
      cmd: dto.command,
      value: dto.value ?? null,
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

    const current = await this.moduleStatusService.findBySerialNumberOrNull(dto.serialNumber);

    const motorStatus =
      dto.command === 'TURN_ON'
        ? 'ON'
        : dto.command === 'TURN_OFF'
          ? 'OFF'
          : (current?.motorStatus ?? 'OFF');
    const overcurrent = dto.command === 'SET_OC' ? dto.value! : (current?.overcurrent ?? 0);
    const undercurrent = dto.command === 'SET_UC' ? dto.value! : (current?.undercurrent ?? 0);

    await this.moduleActionLogService.create({
      serialNumber: dto.serialNumber,
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
      serialNumber: dto.serialNumber,
      motorStatus,
      overcurrent,
      undercurrent,
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
