import { Module } from '@nestjs/common';
import { SocietiesController } from './societies.controller';
import { SocietiesService } from './societies.service';
import { SocietiesRepository } from './societies.repository';
import { UsersModule } from '../users/users.module';

@Module({
  imports: [UsersModule],
  controllers: [SocietiesController],
  providers: [SocietiesService, SocietiesRepository],
  exports: [SocietiesService, SocietiesRepository],
})
export class SocietiesModule {}
