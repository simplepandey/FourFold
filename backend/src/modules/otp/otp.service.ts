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

  async generateAndSaveOtp(phoneNumber: string): Promise<{ otpCode: string; expiresIn: number }> {
    // Invalidate all previous OTPs for this number (only latest should be valid)
    await this.otpRepository.invalidatePreviousOtps(phoneNumber);

    const length = this.configService.get<number>('otp.length', 6);
    const expiryMinutes = this.configService.get<number>('otp.expiryMinutes', 5);
    const expiresIn = expiryMinutes * 60;

    const otpCode = generateOtp(length);
    const expiresAt = new Date(Date.now() + expiresIn * 1000);

    await this.otpRepository.create({ phoneNumber, otpCode, expiresAt });

    this.logger.log(`OTP generated for ${phoneNumber}, expires in ${expiresIn}s`);

    return { otpCode, expiresIn };
  }

  async verifyOtp(phoneNumber: string, otpCode: string): Promise<void> {
    const otp = await this.otpRepository.findLatestValid(phoneNumber);

    if (!otp) {
      throw new BadRequestException('Invalid or expired OTP');
    }

    if (otp.otpCode !== otpCode) {
      throw new BadRequestException('Invalid or expired OTP');
    }

    await this.otpRepository.markAsUsed(otp.id);

    this.logger.log(`OTP verified successfully for ${phoneNumber}`);
  }
}
