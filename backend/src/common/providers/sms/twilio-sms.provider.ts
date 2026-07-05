import { Injectable, Logger } from '@nestjs/common';
import { SmsProvider } from './sms.provider.interface';

/**
 * Twilio SMS Provider
 *
 * To activate:
 * 1. npm install twilio
 * 2. Set TWILIO_ACCOUNT_SID, TWILIO_AUTH_TOKEN, TWILIO_FROM_NUMBER in .env
 * 3. Set SMS_PROVIDER=twilio in .env
 * 4. Uncomment the implementation below
 */
@Injectable()
export class TwilioSmsProvider implements SmsProvider {
  private readonly logger = new Logger(TwilioSmsProvider.name);
  // private client: Twilio.Twilio;

  constructor(
    private readonly accountSid: string,
    private readonly authToken: string,
    private readonly fromNumber: string,
  ) {
    // this.client = require('twilio')(accountSid, authToken);
  }

  async sendSms(phoneNumber: string, message: string): Promise<void> {
    this.logger.log(`[TWILIO] Sending SMS to ${phoneNumber}`);
    // await this.client.messages.create({
    //   body: message,
    //   from: this.fromNumber,
    //   to: phoneNumber,
    // });
    throw new Error('Twilio SMS provider is not yet configured. See twilio-sms.provider.ts.');
  }
}
