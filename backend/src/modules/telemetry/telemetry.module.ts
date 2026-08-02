import { Module } from '@nestjs/common';
import { TelemetryService } from './telemetry.service';
import { TelemetryRepository } from './telemetry.repository';
import { ModuleStatusModule } from '../module-status/module-status.module';

@Module({
  imports: [ModuleStatusModule],
  providers: [TelemetryService, TelemetryRepository],
  exports: [TelemetryService],
})
export class TelemetryModule {}
