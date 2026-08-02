import { Injectable, BadRequestException, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { OtpRepository } from './otp.repository';
import { generateOtp } from '../../common/utils/otp.utils';

@Injectable()
export class OtpService {
  private readonly logger = new Logger(OtpService.name);

  constructor(
    private readonly otpRepository: OtpRepository,
    private readonly configService: ConfigService,
  ) {}

  // Returns otpCode=null when MSG91 manages the OTP (no local code to expose)
  async generateAndSaveOtp(
    phoneNumber: string,
  ): Promise<{ otpCode: string | null; expiresIn: number }> {
    const provider = this.configService.get<string>('sms.provider', 'console');
    const expiryMinutes = this.configService.get<number>('otp.expiryMinutes', 5);
    const expiresIn = expiryMinutes * 60;

    if (provider === 'msg91') {
      await this.msg91SendOtp(phoneNumber);
      return { otpCode: null, expiresIn };
    }

    // Console / fallback: generate locally and save to DB
    await this.otpRepository.invalidatePreviousOtps(phoneNumber);
    const length = this.configService.get<number>('otp.length', 6);
    const otpCode = generateOtp(length);
    const expiresAt = new Date(Date.now() + expiresIn * 1000);
    await this.otpRepository.create({ phoneNumber, otpCode, expiresAt });
    this.logger.log(`[OTP] ${phoneNumber} → ${otpCode} (expires in ${expiresIn}s)`);

    return { otpCode, expiresIn };
  }

  async verifyOtp(phoneNumber: string, otpCode: string): Promise<void> {
    const provider = this.configService.get<string>('sms.provider', 'console');

    if (provider === 'msg91') {
      await this.msg91VerifyOtp(phoneNumber, otpCode);
      return;
    }

    // Console / fallback: verify against DB
    const otp = await this.otpRepository.findLatestValid(phoneNumber);
    if (!otp || otp.otpCode !== otpCode) {
      throw new BadRequestException('Invalid or expired OTP');
    }
    await this.otpRepository.markAsUsed(otp.id);
    this.logger.log(`OTP verified for ${phoneNumber}`);
  }

  // ─── MSG91 OTP API ────────────────────────────────────────────

  private get msg91AuthKey(): string {
    const key = this.configService.get<string>('sms.msg91.authKey');
    if (!key) throw new Error('MSG91_AUTH_KEY is not set');
    return key;
  }

  private get msg91TemplateId(): string {
    const id = this.configService.get<string>('sms.msg91.templateId');
    if (!id) throw new Error('MSG91_TEMPLATE_ID is not set');
    return id;
  }

  // Strip + from E.164 → MSG91 expects 91XXXXXXXXXX
  private toMsg91Mobile(phoneNumber: string): string {
    return phoneNumber.replace('+', '');
  }

  private async msg91SendOtp(phoneNumber: string): Promise<void> {
    const mobile = this.toMsg91Mobile(phoneNumber);

    const res = await fetch('https://api.msg91.com/api/v5/otp', {
      method: 'POST',
      headers: {
        authkey: this.msg91AuthKey,
        'Content-Type': 'application/json',
        accept: 'application/json',
      },
      body: JSON.stringify({
        template_id: this.msg91TemplateId,
        mobile,
      }),
    });

    const body = (await res.json()) as { type: string; message: string };

    if (body.type !== 'success') {
      this.logger.error(`MSG91 send failed for ${phoneNumber}: ${JSON.stringify(body)}`);
      throw new BadRequestException(`Failed to send OTP: ${body.message ?? 'MSG91 error'}`);
    }

    this.logger.log(`MSG91 OTP sent to ${phoneNumber} (requestId: ${body.message})`);
  }

  private async msg91VerifyOtp(phoneNumber: string, otpCode: string): Promise<void> {
    const mobile = this.toMsg91Mobile(phoneNumber);

    const url = new URL('https://api.msg91.com/api/v5/otp/verify');
    url.searchParams.set('mobile', mobile);
    url.searchParams.set('otp', otpCode);
    url.searchParams.set('authkey', this.msg91AuthKey);

    const res = await fetch(url.toString(), {
      method: 'GET',
      headers: { accept: 'application/json' },
    });

    const body = (await res.json()) as { type: string; message: string };

    if (body.type !== 'success') {
      this.logger.warn(`MSG91 verify failed for ${phoneNumber}: ${JSON.stringify(body)}`);
      throw new BadRequestException('Invalid or expired OTP');
    }

    this.logger.log(`MSG91 OTP verified for ${phoneNumber}`);
  }
}
