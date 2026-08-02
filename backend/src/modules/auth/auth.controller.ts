import { Controller, Post, Body, HttpCode, HttpStatus } from '@nestjs/common';
import {
  ApiTags,
  ApiOperation,
  ApiOkResponse,
  ApiBadRequestResponse,
  ApiUnauthorizedResponse,
  ApiBody,
} from '@nestjs/swagger';
import { AuthService } from './auth.service';
import { SendOtpDto } from './dto/send-otp.dto';
import { VerifyOtpDto } from './dto/verify-otp.dto';
import { VerifyOtpTokenDto } from './dto/verify-otp-token.dto';
import { SocietyLoginDto } from '../societies/dto/society-login.dto';
import { Public } from '../../common/decorators/public.decorator';

@ApiTags('Auth')
@Controller({ path: 'auth', version: '1' })
@Public()
export class AuthController {
  constructor(private readonly authService: AuthService) {}

  @Post('send-otp')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Send OTP to phone number' })
  @ApiBody({ type: SendOtpDto })
  @ApiOkResponse({
    description: 'OTP sent successfully',
    schema: {
      example: {
        success: true,
        message: 'OTP sent successfully',
        data: { otp: '123456', expiresIn: 300 },
      },
    },
  })
  @ApiBadRequestResponse({ description: 'Invalid phone number format' })
  async sendOtp(@Body() sendOtpDto: SendOtpDto) {
    return this.authService.sendOtp(sendOtpDto);
  }

  @Post('verify-otp')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Verify OTP — returns JWT token for users' })
  @ApiBody({ type: VerifyOtpDto })
  @ApiOkResponse({
    description: 'OTP verified, JWT token returned',
    schema: {
      example: {
        success: true,
        message: 'OTP verified successfully',
        data: {
          user: { id: 'uuid', phoneNumber: '+919876543210', isVerified: true, name: null },
          token: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...',
        },
      },
    },
  })
  @ApiBadRequestResponse({ description: 'Invalid or expired OTP' })
  async verifyOtp(@Body() verifyOtpDto: VerifyOtpDto) {
    return this.authService.verifyOtp(verifyOtpDto);
  }

  @Post('verify-otp-token')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({
    summary: 'Verify MSG91 widget access token — returns JWT',
    description:
      'Client obtains an access token from the MSG91 OTP widget, then sends it here. The server verifies it with MSG91 and returns our own JWT.',
  })
  @ApiBody({ type: VerifyOtpTokenDto })
  @ApiOkResponse({
    description: 'Token verified, JWT returned',
    schema: {
      example: {
        success: true,
        message: 'OTP verified successfully',
        data: {
          user: { id: 'uuid', phoneNumber: '+919876543210', name: null, isVerified: true },
          token: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...',
        },
      },
    },
  })
  @ApiUnauthorizedResponse({ description: 'Invalid or expired access token' })
  async verifyOtpToken(@Body() dto: VerifyOtpTokenDto) {
    return this.authService.verifyOtpToken(dto);
  }

  @Post('user-login')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({
    summary: 'Society login with phone number + password',
    description:
      'Login using the phone number and password set during society registration. Returns a JWT token.',
  })
  @ApiBody({ type: SocietyLoginDto })
  @ApiOkResponse({
    description: 'Login successful — JWT token returned',
    schema: {
      example: {
        success: true,
        message: 'Login successful',
        data: {
          society: {
            id: 'uuid',
            phoneNumber: '+919876543210',
            name: 'Rahul Sharma',
            societyName: 'Green Valley Apartments',
            blockOrWing: 'Block A',
            totalMembers: 120,
          },
          token: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...',
        },
      },
    },
  })
  @ApiUnauthorizedResponse({ description: 'Invalid phone number or password' })
  async societyLogin(@Body() societyLoginDto: SocietyLoginDto) {
    return this.authService.societyLogin(societyLoginDto);
  }
}
