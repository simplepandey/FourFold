import { Module } from '@nestjs/common';
import { MqttService } from './mqtt.service';
import { TelemetryModule } from '../telemetry/telemetry.module';
import { TopicPatternRepository } from './topic-pattern.repository';

@Module({
  imports: [TelemetryModule],
  providers: [MqttService, TopicPatternRepository],
  exports: [MqttService],
})
export class MqttModule {}
