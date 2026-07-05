import { Injectable } from '@nestjs/common';
import { PrismaService } from '../../prisma/prisma.service';
import { Otp } from '@prisma/client';

@Injectable()
export class OtpRepository {
  constructor(private readonly prisma: PrismaService) {}

  async create(data: { phoneNumber: string; otpCode: string; expiresAt: Date }): Promise<Otp> {
    return this.prisma.otp.create({ data });
  }

  async findLatestValid(phoneNumber: string): Promise<Otp | null> {
    return this.prisma.otp.findFirst({
      where: {
        phoneNumber,
        isUsed: false,
        expiresAt: { gt: new Date() },
      },
      orderBy: { createdAt: 'desc' },
    });
  }

  async invalidatePreviousOtps(phoneNumber: string): Promise<void> {
    await this.prisma.otp.updateMany({
      where: { phoneNumber, isUsed: false },
      data: { isUsed: true },
    });
  }

  async markAsUsed(id: string): Promise<void> {
    await this.prisma.otp.update({
      where: { id },
      data: { isUsed: true },
    });
  }
}
