import { Module } from '@nestjs/common';
import { SocietiesController } from './societies.controller';
import { SocietiesService } from './societies.service';
import { SocietiesRepository } from './societies.repository';
import { UsersModule } from '../users/users.module';
import { DeviceModule } from '../device/device.module';

@Module({
  imports: [UsersModule, DeviceModule],
  controllers: [SocietiesController],
  providers: [SocietiesService, SocietiesRepository],
  exports: [SocietiesService, SocietiesRepository],
})
export class SocietiesModule {}
