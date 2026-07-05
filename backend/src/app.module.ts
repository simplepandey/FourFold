import { Module } from '@nestjs/common';
import { ConfigModule } from '@nestjs/config';
import { ThrottlerModule } from '@nestjs/throttler';
import { PrismaModule } from './prisma/prisma.module';
import { AuthModule } from './modules/auth/auth.module';
import { UsersModule } from './modules/users/users.module';
import { OtpModule } from './modules/otp/otp.module';
import { SocietiesModule } from './modules/societies/societies.module';
import { ModuleMasterModule } from './modules/module-master/module-master.module';
import { ModuleRegistrationModule } from './modules/module-registration/module-registration.module';
import { MqttModule } from './modules/mqtt/mqtt.module';
import configuration from './config/configuration';

@Module({
  imports: [
    ConfigModule.forRoot({
      isGlobal: true,
      load: [configuration],
      envFilePath: '.env',
    }),
    // Rate limiting — apply ThrottlerGuard to specific routes or globally as needed
    ThrottlerModule.forRoot([
      {
        ttl: 60000,  // 1 minute window
        limit: 10,   // max 10 requests per window
      },
    ]),
    PrismaModule,
    AuthModule,
    UsersModule,
    OtpModule,
    SocietiesModule,
    ModuleMasterModule,
    ModuleRegistrationModule,
    MqttModule,
  ],
})
export class AppModule {}
