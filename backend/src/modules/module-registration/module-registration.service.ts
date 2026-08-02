import { Injectable, NotFoundException, ConflictException } from '@nestjs/common';
import { ModuleRegistrationRepository } from './module-registration.repository';
import { DeviceService } from '../device/device.service';
import { SocietiesRepository } from '../societies/societies.repository';
import { ModuleStatusService } from '../module-status/module-status.service';
import { CreateModuleRegistrationDto } from './dto/create-module-registration.dto';
import { UpdateModuleRegistrationDto } from './dto/update-module-registration.dto';

@Injectable()
export class ModuleRegistrationService {
  constructor(
    private readonly repository: ModuleRegistrationRepository,
    private readonly deviceService: DeviceService,
    private readonly societiesRepository: SocietiesRepository,
    private readonly moduleStatusService: ModuleStatusService,
  ) {}

  async create(dto: CreateModuleRegistrationDto) {
    // 1. Verify the ESP is registered (throws NotFoundException if not)
    await this.deviceService.findBySerialNumber(dto.serialNumber);

    // 2. Prevent duplicate active registration
    const existing = await this.repository.findActiveBySerialNumber(dto.serialNumber);
    if (existing) {
      throw new ConflictException(`Module '${dto.serialNumber}' is already registered`);
    }

    const registration = await this.repository.create({
      serialNumber: dto.serialNumber,
      registeredTo: dto.societyCode,
      noOfPump: dto.noOfPump,
      phase: dto.phase,
      hpOfPump: dto.hpOfPump,
      address: dto.address,
      wingBlock: dto.wingBlock,
      pincode: dto.pincode,
      district: dto.district,
      state: dto.state ?? 'Maharashtra',
      country: dto.country ?? 'India',
      createdBy: dto.createdBy,
      ...(dto.createDate && { createDate: new Date(dto.createDate) }),
    });

    if (dto.userId) {
      await this.societiesRepository.updateMemberSerialNumber(
        dto.societyCode,
        dto.userId,
        dto.serialNumber,
      );
    }

    await this.moduleStatusService.upsert({
      serialNumber: dto.serialNumber,
      updatedBy: dto.createdBy,
    });

    return registration;
  }

  async findAll() {
    return this.repository.findAll();
  }

  async findAllByRegisteredTo(registeredTo: string) {
    return this.repository.findAllByRegisteredTo(registeredTo);
  }

  async findById(id: string) {
    const registration = await this.repository.findById(id);
    if (!registration) {
      throw new NotFoundException(`Registration with id '${id}' not found`);
    }
    return registration;
  }

  async update(id: string, dto: UpdateModuleRegistrationDto) {
    await this.findById(id);
    return this.repository.update(id, {
      ...(dto.registeredTo && { registeredTo: dto.registeredTo }),
      ...(dto.noOfPump !== undefined && { noOfPump: dto.noOfPump }),
      ...(dto.phase && { phase: dto.phase }),
      ...(dto.hpOfPump !== undefined && { hpOfPump: dto.hpOfPump }),
      updatedBy: dto.updatedBy,
      ...(dto.updateDate && { updateDate: new Date(dto.updateDate) }),
    });
  }

  async remove(id: string, deletedBy: string) {
    await this.findById(id);
    return this.repository.softDelete(id, deletedBy);
  }
}
