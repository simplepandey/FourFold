import { Injectable, Logger } from '@nestjs/common';
import { SmsProvider } from './sms.provider.interface';

/**
 * AWS SNS SMS Provider
 *
 * To activate:
 * 1. npm install @aws-sdk/client-sns
 * 2. Set AWS_REGION, AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY in .env
 * 3. Set SMS_PROVIDER=aws-sns in .env
 * 4. Uncomment and complete the implementation below
 */
@Injectable()
export class AwsSnsSmsProvider implements SmsProvider {
  private readonly logger = new Logger(AwsSnsSmsProvider.name);
  // private client: SNSClient;

  constructor(
    private readonly region: string,
    private readonly accessKeyId: string,
    private readonly secretAccessKey: string,
  ) {
    // this.client = new SNSClient({
    //   region,
    //   credentials: { accessKeyId, secretAccessKey },
    // });
  }

  async sendSms(phoneNumber: string, message: string): Promise<void> {
    this.logger.log(`[AWS SNS] Sending SMS to ${phoneNumber}`);
    // await this.client.send(new PublishCommand({
    //   Message: message,
    //   PhoneNumber: phoneNumber,
    //   MessageAttributes: {
    //     'AWS.SNS.SMS.SenderID': { DataType: 'String', StringValue: 'FourFold' },
    //     'AWS.SNS.SMS.SMSType': { DataType: 'String', StringValue: 'Transactional' },
    //   },
    // }));
    throw new Error('AWS SNS SMS provider is not yet configured. See aws-sns-sms.provider.ts.');
  }
}
