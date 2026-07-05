import { Module } from '@nestjs/common';
import { ModuleMasterController } from './module-master.controller';
import { ModuleMasterService } from './module-master.service';
import { ModuleMasterRepository } from './module-master.repository';

@Module({
  controllers: [ModuleMasterController],
  providers: [ModuleMasterService, ModuleMasterRepository],
  exports: [ModuleMasterService],
})
export class ModuleMasterModule {}
