import { Module } from '@nestjs/common';
import { SocietiesController } from './societies.controller';
import { SocietiesService } from './societies.service';
import { SocietiesRepository } from './societies.repository';

@Module({
  controllers: [SocietiesController],
  providers: [SocietiesService, SocietiesRepository],
  exports: [SocietiesService],
})
export class SocietiesModule {}
