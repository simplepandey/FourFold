import { Injectable } from '@nestjs/common';
import { PrismaService } from '../../prisma/prisma.service';
import { MotorCommand } from '@prisma/client';

@Injectable()
export class MotorCommandRepository {
  constructor(private readonly prisma: PrismaService) {}

  async create(data: {
    societyCode: string;
    motorId: string;
    command: string;
    commandBy: string;
    cmdId: string;
    status: string;
  }): Promise<MotorCommand> {
    return this.prisma.motorCommand.create({ data });
  }

  async findAll(): Promise<MotorCommand[]> {
    return this.prisma.motorCommand.findMany({ orderBy: { createDate: 'desc' } });
  }

  async findBySocietyAndMotor(societyCode: string, motorId: string): Promise<MotorCommand[]> {
    return this.prisma.motorCommand.findMany({
      where: { societyCode, motorId },
      orderBy: { createDate: 'desc' },
    });
  }
}
