import { Module } from '@nestjs/common';
import { ModuleActionLogController } from './module-action-log.controller';
import { ModuleActionLogService } from './module-action-log.service';
import { ModuleActionLogRepository } from './module-action-log.repository';

@Module({
  controllers: [ModuleActionLogController],
  providers: [ModuleActionLogService, ModuleActionLogRepository],
  exports: [ModuleActionLogService],
})
export class ModuleActionLogModule {}
