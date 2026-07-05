export interface SmsProvider {
  sendSms(phoneNumber: string, message: string): Promise<void>;
}

export const SMS_PROVIDER_TOKEN = 'SMS_PROVIDER';
