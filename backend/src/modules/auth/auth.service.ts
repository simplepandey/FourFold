import { Injectable, Logger, UnauthorizedException } from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import { ConfigService } from '@nestjs/config';
import * as bcrypt from 'bcrypt';
import { SendOtpDto } from './dto/send-otp.dto';
import { VerifyOtpDto } from './dto/verify-otp.dto';
import { SocietyLoginDto } from '../societies/dto/society-login.dto';
import { OtpService } from '../otp/otp.service';
import { UsersService } from '../users/users.service';
import { SocietiesService } from '../societies/societies.service';
import { JwtPayload } from '../../common/interfaces/jwt-payload.interface';

@Injectable()
export class AuthService {
  private readonly logger = new Logger(AuthService.name);

  constructor(
    private readonly otpService: OtpService,
    private readonly usersService: UsersService,
    private readonly societiesService: SocietiesService,
    private readonly jwtService: JwtService,
    private readonly configService: ConfigService,
  ) {}

  async sendOtp(sendOtpDto: SendOtpDto) {
    const { phoneNumber } = sendOtpDto;
    const { otpCode, expiresIn } = await this.otpService.generateAndSaveOtp(phoneNumber);
    const isDevelopment = this.configService.get<string>('nodeEnv') !== 'production';

    return {
      success: true,
      message: 'OTP sent successfully',
      ...(isDevelopment ? { data: { otp: otpCode, expiresIn } } : {}),
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

    return {
      success: true,
      message: 'OTP verified successfully',
      data: {
        user: {
          id: user.id,
          phoneNumber: user.phoneNumber,
          name: user.name,
          isVerified: user.isVerified,
        },
        token,
      },
    };
  }

  async societyLogin(dto: SocietyLoginDto) {
    const { phoneNumber, password } = dto;

    const society = await this.societiesService.findByPhoneNumber(phoneNumber);
    if (!society) {
      throw new UnauthorizedException('Invalid phone number or password');
    }

    const passwordMatch = await bcrypt.compare(password, society.password);
    if (!passwordMatch) {
      throw new UnauthorizedException('Invalid phone number or password');
    }

    // phoneNumber comes from dto — same value used to find the society
    const payload: JwtPayload = {
      sub: society.id,
      phoneNumber,
      type: 'society',
    };

    const token = this.jwtService.sign(payload);

    this.logger.log(`Society login: ${society.societyName} (${phoneNumber})`);

    return {
      success: true,
      message: 'Login successful',
      data: {
        society: {
          id: society.id,
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
}
