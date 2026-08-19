import { Module } from '@nestjs/common';
import { MqttService } from './mqtt.service';
import { TopicPatternRepository } from './topic-pattern.repository';

@Module({
  providers: [MqttService, TopicPatternRepository],
  exports: [MqttService],
})
export class MqttModule {}
