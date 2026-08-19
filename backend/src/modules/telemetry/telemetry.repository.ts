import { Injectable } from '@nestjs/common';
import { PrismaService } from '../../prisma/prisma.service';
import { MotorTelemetry, MotorAlert } from '@prisma/client';

@Injectable()
export class TelemetryRepository {
  constructor(private readonly prisma: PrismaService) {}

  async createTelemetry(data: {
    serialHash: string;
    serialNumber: string;
    voltage: number;
    current: number;
    overcurrent: number;
    undercurrent: number;
    groundTank?: number | null;
    overheadTank?: number | null;
    motorRunning: boolean;
  }): Promise<MotorTelemetry> {
    return this.prisma.motorTelemetry.create({ data });
  }

  async createAlert(data: {
    serialHash: string;
    serialNumber: string;
    overcurrentBreached?: number | null;
    undercurrentBreached?: number | null;
  }): Promise<MotorAlert> {
    return this.prisma.motorAlert.create({ data });
  }

  async findTelemetryByDevice(serialHash: string): Promise<MotorTelemetry[]> {
    return this.prisma.motorTelemetry.findMany({
      where: { serialHash },
      orderBy: { recordedAt: 'desc' },
      take: 100,
    });
  }

  async findAlertsByDevice(serialHash: string): Promise<MotorAlert[]> {
    return this.prisma.motorAlert.findMany({
      where: { serialHash },
      orderBy: { recordedAt: 'desc' },
      take: 100,
    });
  }

  // The topic's identifier segment is the serialHash for devices registered
  // before the productCode-based topic scheme, or the productCode for
  // devices registered after it (existing devices' topics were deliberately
  // not rewritten, to avoid breaking already-flashed firmware) — so this
  // matches either.
  async findRegistrationByTopicKey(topicKey: string) {
    return this.prisma.espRegistration.findFirst({
      where: { OR: [{ serialHash: topicKey }, { productCode: topicKey }] },
    });
  }
}
