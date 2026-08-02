import { Module } from '@nestjs/common';
import { ModuleRegistrationController } from './module-registration.controller';
import { ModuleRegistrationService } from './module-registration.service';
import { ModuleRegistrationRepository } from './module-registration.repository';
import { DeviceModule } from '../device/device.module';
import { SocietiesModule } from '../societies/societies.module';
import { ModuleStatusModule } from '../module-status/module-status.module';

@Module({
  imports: [DeviceModule, SocietiesModule, ModuleStatusModule],
  controllers: [ModuleRegistrationController],
  providers: [ModuleRegistrationService, ModuleRegistrationRepository],
  exports: [ModuleRegistrationService],
})
export class ModuleRegistrationModule {}
