import { Module } from '@nestjs/common';
import { DeviceController } from './device.controller';
import { DeviceService } from './device.service';
import { DeviceRepository } from './device.repository';
import { EspTopicCacheService } from './esp-topic-cache.service';

@Module({
  controllers: [DeviceController],
  providers: [DeviceService, DeviceRepository, EspTopicCacheService],
  exports: [DeviceService, EspTopicCacheService],
})
export class DeviceModule {}
