import { Injectable, Logger } from '@nestjs/common';
import { SmsProvider } from './sms.provider.interface';

@Injectable()
export class ConsoleSmsProvider implements SmsProvider {
  private readonly logger = new Logger(ConsoleSmsProvider.name);

  async sendSms(phoneNumber: string, message: string): Promise<void> {
    this.logger.log(`[DEV SMS] ─────────────────────────────`);
    this.logger.log(`[DEV SMS] To:      ${phoneNumber}`);
    this.logger.log(`[DEV SMS] Message: ${message}`);
    this.logger.log(`[DEV SMS] ─────────────────────────────`);
  }
}
