import { Injectable, NotFoundException } from '@nestjs/common';
import { ModuleStatusRepository } from './module-status.repository';

export interface ModuleStatusUpsertInput {
  serialNumber: string;
  voltage?: number;
  current?: number;
  overcurrent?: number;
  undercurrent?: number;
  overheadTankLevel?: number;
  undergroundTankLevel?: number;
  motorStatus?: string;
  ocBreached?: boolean;
  ucBreached?: boolean;
  updatedBy?: string;
}

@Injectable()
export class ModuleStatusService {
  constructor(private readonly repository: ModuleStatusRepository) {}

  /** Upserts by serialNumber — creates the row with sane defaults on first write, otherwise only touches the fields provided. */
  async upsert(input: ModuleStatusUpsertInput) {
    const { serialNumber, updatedBy, ...fields } = input;
    return this.repository.upsert(
      serialNumber,
      {
        serialNumber,
        voltage: fields.voltage ?? 0,
        current: fields.current ?? 0,
        overcurrent: fields.overcurrent ?? 0,
        undercurrent: fields.undercurrent ?? 0,
        overheadTankLevel: fields.overheadTankLevel ?? 0,
        undergroundTankLevel: fields.undergroundTankLevel ?? 0,
        motorStatus: fields.motorStatus ?? 'OFF',
        ocBreached: fields.ocBreached ?? false,
        ucBreached: fields.ucBreached ?? false,
        updatedBy,
      },
      {
        ...(fields.voltage !== undefined && { voltage: fields.voltage }),
        ...(fields.current !== undefined && { current: fields.current }),
        ...(fields.overcurrent !== undefined && { overcurrent: fields.overcurrent }),
        ...(fields.undercurrent !== undefined && { undercurrent: fields.undercurrent }),
        ...(fields.overheadTankLevel !== undefined && {
          overheadTankLevel: fields.overheadTankLevel,
        }),
        ...(fields.undergroundTankLevel !== undefined && {
          undergroundTankLevel: fields.undergroundTankLevel,
        }),
        ...(fields.motorStatus !== undefined && { motorStatus: fields.motorStatus }),
        ...(fields.ocBreached !== undefined && { ocBreached: fields.ocBreached }),
        ...(fields.ucBreached !== undefined && { ucBreached: fields.ucBreached }),
        updatedBy,
      },
    );
  }

  async findBySerialNumber(serialNumber: string) {
    const status = await this.repository.findBySerialNumber(serialNumber);
    if (!status) {
      throw new NotFoundException(`No status found for serial number '${serialNumber}'`);
    }
    return status;
  }

  findBySerialNumberOrNull(serialNumber: string) {
    return this.repository.findBySerialNumber(serialNumber);
  }
}
