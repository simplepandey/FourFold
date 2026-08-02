import { Module } from '@nestjs/common';
import { ModuleStatusController } from './module-status.controller';
import { ModuleStatusService } from './module-status.service';
import { ModuleStatusRepository } from './module-status.repository';

@Module({
  controllers: [ModuleStatusController],
  providers: [ModuleStatusService, ModuleStatusRepository],
  exports: [ModuleStatusService],
})
export class ModuleStatusModule {}
