import { Injectable } from '@nestjs/common';
import { ModuleActionLogRepository } from './module-action-log.repository';

export interface CreateModuleActionLogInput {
  serialNumber: string;
  voltage: number;
  current: number;
  overcurrent: number;
  undercurrent: number;
  overheadTankLevel: number;
  undergroundTankLevel: number;
  motorStatus: string;
  ocBreached: boolean;
  ucBreached: boolean;
  createdBy?: string;
}

@Injectable()
export class ModuleActionLogService {
  constructor(private readonly repository: ModuleActionLogRepository) {}

  create(input: CreateModuleActionLogInput) {
    return this.repository.create(input);
  }

  findBySerialNumber(serialNumber: string) {
    return this.repository.findBySerialNumber(serialNumber);
  }
}
