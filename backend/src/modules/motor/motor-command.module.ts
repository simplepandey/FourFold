import { Module } from '@nestjs/common';
import { MotorCommandController } from './motor-command.controller';
import { MotorCommandService } from './motor-command.service';
import { MotorCommandRepository } from './motor-command.repository';
import { MqttModule } from '../mqtt/mqtt.module';
import { SocietiesModule } from '../societies/societies.module';
import { ModuleStatusModule } from '../module-status/module-status.module';
import { ModuleActionLogModule } from '../module-action-log/module-action-log.module';
import { DeviceModule } from '../device/device.module';

@Module({
  imports: [MqttModule, SocietiesModule, ModuleStatusModule, ModuleActionLogModule, DeviceModule],
  controllers: [MotorCommandController],
  providers: [MotorCommandService, MotorCommandRepository],
})
export class MotorCommandModule {}
