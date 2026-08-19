import { Module } from '@nestjs/common';
import { ModuleStatusController } from './module-status.controller';
import { ModuleStatusService } from './module-status.service';
import { ModuleStatusRepository } from './module-status.repository';
import { DeviceModule } from '../device/device.module';
import { MqttModule } from '../mqtt/mqtt.module';

@Module({
  imports: [DeviceModule, MqttModule],
  controllers: [ModuleStatusController],
  providers: [ModuleStatusService, ModuleStatusRepository],
  exports: [ModuleStatusService],
})
export class ModuleStatusModule {}
