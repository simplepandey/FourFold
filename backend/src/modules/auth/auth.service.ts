import { Injectable, Logger, UnauthorizedException } from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import { ConfigService } from '@nestjs/config';
import * as bcrypt from 'bcrypt';
import { SendOtpDto } from './dto/send-otp.dto';
import { VerifyOtpDto } from './dto/verify-otp.dto';
import { VerifyOtpTokenDto } from './dto/verify-otp-token.dto';
import { ResetPasswordDto } from './dto/reset-password.dto';
import { SocietyLoginDto } from '../societies/dto/society-login.dto';
import { OtpService } from '../otp/otp.service';
import { UsersService } from '../users/users.service';
import { SocietiesService } from '../societies/societies.service';
import { SocietiesRepository } from '../societies/societies.repository';
import { JwtPayload } from '../../common/interfaces/jwt-payload.interface';

@Injectable()
export class AuthService {
  private readonly logger = new Logger(AuthService.name);

  constructor(
    private readonly otpService: OtpService,
    private readonly usersService: UsersService,
    private readonly societiesService: SocietiesService,
    private readonly societiesRepository: SocietiesRepository,
    private readonly jwtService: JwtService,
    private readonly configService: ConfigService,
  ) {}

  async sendOtp(sendOtpDto: SendOtpDto) {
    const { phoneNumber } = sendOtpDto;
    const { otpCode, expiresIn } = await this.otpService.generateAndSaveOtp(phoneNumber);
    const isDevelopment = this.configService.get<string>('nodeEnv') !== 'production';

    // otpCode is null when MSG91 manages the OTP — nothing to expose in dev mode
    return {
      success: true,
      message: 'OTP sent successfully',
      ...(isDevelopment && otpCode ? { data: { otp: otpCode, expiresIn } } : {}),
    };
  }

  async verifyOtp(verifyOtpDto: VerifyOtpDto) {
    const { phoneNumber, otp } = verifyOtpDto;

    await this.otpService.verifyOtp(phoneNumber, otp);

    let user = await this.usersService.findByPhoneNumber(phoneNumber);
    if (!user) {
      user = await this.usersService.create({ phoneNumber });
      this.logger.log(`New user auto-created for phone: ${phoneNumber}`);
    }

    if (!user.isVerified) {
      user = await this.usersService.markAsVerified(user.id);
    }

    const payload: JwtPayload = {
      sub: user.id,
      phoneNumber: user.phoneNumber,
      type: 'user',
    };

    const token = this.jwtService.sign(payload);
    const societyInfo = await this._resolveSociety(user.id);

    return {
      success: true,
      message: 'OTP verified successfully',
      data: {
        user: {
          id: user.id,
          phoneNumber: user.phoneNumber,
          name: user.name,
          isVerified: user.isVerified,
          ...societyInfo,
        },
        token,
      },
    };
  }

  private async _verifyMsg91AccessToken(accessToken: string): Promise<void> {
    const widgetAuthKey = this.configService.get<string>('sms.msg91.widgetAuthKey');
    const res = await fetch('https://control.msg91.com/api/v5/widget/verifyAccessToken', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ authkey: widgetAuthKey, 'access-token': accessToken }),
    });

    const msg91 = (await res.json()) as { type?: string };
    if (msg91.type !== 'success') {
      throw new UnauthorizedException('Invalid or expired OTP');
    }
  }

  async verifyOtpToken(dto: VerifyOtpTokenDto) {
    const { accessToken, phoneNumber } = dto;

    await this._verifyMsg91AccessToken(accessToken);

    let user = await this.usersService.findByPhoneNumber(phoneNumber);
    if (!user) {
      user = await this.usersService.create({ phoneNumber });
      this.logger.log(`New user auto-created for phone: ${phoneNumber}`);
    }
    if (!user.isVerified) {
      user = await this.usersService.markAsVerified(user.id);
    }

    const payload: JwtPayload = { sub: user.id, phoneNumber: user.phoneNumber, type: 'user' };
    const token = this.jwtService.sign(payload);
    const societyInfo = await this._resolveSociety(user.id);

    return {
      success: true,
      message: 'OTP verified successfully',
      data: {
        user: {
          id: user.id,
          phoneNumber: user.phoneNumber,
          name: user.name,
          isVerified: user.isVerified,
          ...societyInfo,
        },
        token,
      },
    };
  }

  private async _resolveSociety(userId: string) {
    const member = await this.societiesRepository.findFirstMemberByUserId(userId);
    if (!member) return {};
    const society = await this.societiesRepository.findBySocietyCode(member.societyCode);
    if (!society) return {};
    return {
      societyId: society.id,
      societyCode: society.societyCode,
      societyName: society.societyName,
      blockOrWing: society.blockOrWing,
      role: member.role,
    };
  }

  async societyLogin(dto: SocietyLoginDto) {
    const { phoneNumber, password } = dto;

    const user = await this.usersService.findByPhoneNumber(phoneNumber);
    if (!user || !user.password) {
      throw new UnauthorizedException('Invalid phone number or password');
    }

    const passwordMatch = await bcrypt.compare(password, user.password);
    if (!passwordMatch) {
      throw new UnauthorizedException('Invalid phone number or password');
    }

    const society = await this.societiesService.findByPhoneNumber(phoneNumber);
    if (!society) {
      throw new UnauthorizedException('No society found for this account');
    }

    const payload: JwtPayload = {
      sub: user.id,
      phoneNumber,
      type: 'user',
    };

    const token = this.jwtService.sign(payload);

    this.logger.log(`Society login: ${society.societyName} (${phoneNumber})`);

    return {
      success: true,
      message: 'Login successful',
      data: {
        society: {
          id: society.id,
          userId: user.id,
          societyCode: society.societyCode,
          phoneNumber,
          name: society.name,
          societyName: society.societyName,
          blockOrWing: society.blockOrWing,
          totalMembers: society.totalMembers,
        },
        token,
      },
    };
  }

  async resetPassword(dto: ResetPasswordDto) {
    const { accessToken, phoneNumber, newPassword } = dto;

    await this._verifyMsg91AccessToken(accessToken);

    const user = await this.usersService.findByPhoneNumber(phoneNumber);
    if (!user) {
      throw new UnauthorizedException('No account found for this phone number');
    }

    const hashedPassword = await bcrypt.hash(newPassword, 10);
    await this.usersService.setPassword(user.id, hashedPassword);

    const payload: JwtPayload = { sub: user.id, phoneNumber: user.phoneNumber, type: 'user' };
    const token = this.jwtService.sign(payload);
    const societyInfo = await this._resolveSociety(user.id);

    this.logger.log(`Password reset for ${phoneNumber}`);

    return {
      success: true,
      message: 'Password reset successfully',
      data: {
        user: {
          id: user.id,
          phoneNumber: user.phoneNumber,
          name: user.name,
          isVerified: user.isVerified,
          ...societyInfo,
        },
        token,
      },
    };
  }
}
