import { Module } from '@nestjs/common';
import { TelemetryService } from './telemetry.service';
import { TelemetryRepository } from './telemetry.repository';
import { ModuleStatusModule } from '../module-status/module-status.module';
import { MqttModule } from '../mqtt/mqtt.module';

@Module({
  imports: [ModuleStatusModule, MqttModule],
  providers: [TelemetryService, TelemetryRepository],
  exports: [TelemetryService],
})
export class TelemetryModule {}
