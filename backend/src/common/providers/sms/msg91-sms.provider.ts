import { Injectable, Logger } from '@nestjs/common';
import { SmsProvider } from './sms.provider.interface';

/**
 * MSG91 SMS Provider
 *
 * To activate:
 * 1. npm install axios (or use the MSG91 SDK)
 * 2. Set MSG91_AUTH_KEY, MSG91_SENDER_ID in .env
 * 3. Set SMS_PROVIDER=msg91 in .env
 * 4. Uncomment and complete the implementation below
 */
@Injectable()
export class Msg91SmsProvider implements SmsProvider {
  private readonly logger = new Logger(Msg91SmsProvider.name);

  constructor(
    private readonly authKey: string,
    private readonly senderId: string,
  ) {}

  async sendSms(phoneNumber: string, message: string): Promise<void> {
    this.logger.log(`[MSG91] Sending SMS to ${phoneNumber}`);
    // const url = 'https://api.msg91.com/api/v5/flow/';
    // await axios.post(url, {
    //   template_id: 'YOUR_TEMPLATE_ID',
    //   recipients: [{ mobiles: phoneNumber, otp: message }],
    // }, { headers: { authkey: this.authKey } });
    throw new Error('MSG91 SMS provider is not yet configured. See msg91-sms.provider.ts.');
  }
}
