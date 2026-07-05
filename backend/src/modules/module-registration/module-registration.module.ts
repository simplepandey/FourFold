import { Module } from '@nestjs/common';
import { ModuleRegistrationController } from './module-registration.controller';
import { ModuleRegistrationService } from './module-registration.service';
import { ModuleRegistrationRepository } from './module-registration.repository';
import { ModuleMasterModule } from '../module-master/module-master.module';

@Module({
  imports: [ModuleMasterModule],
  controllers: [ModuleRegistrationController],
  providers: [ModuleRegistrationService, ModuleRegistrationRepository],
  exports: [ModuleRegistrationService],
})
export class ModuleRegistrationModule {}
