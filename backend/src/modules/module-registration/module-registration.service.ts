import { Injectable, NotFoundException, ConflictException } from '@nestjs/common';
import { ModuleRegistrationRepository } from './module-registration.repository';
import { ModuleMasterService } from '../module-master/module-master.service';
import { CreateModuleRegistrationDto } from './dto/create-module-registration.dto';
import { UpdateModuleRegistrationDto } from './dto/update-module-registration.dto';

@Injectable()
export class ModuleRegistrationService {
  constructor(
    private readonly repository: ModuleRegistrationRepository,
    private readonly moduleMasterService: ModuleMasterService,
  ) {}

  async create(dto: CreateModuleRegistrationDto) {
    const module = await this.moduleMasterService.findBySerialNumber(dto.moduleSerialNumber);
    if (!module) {
      throw new NotFoundException(`Module with serial number '${dto.moduleSerialNumber}' not found`);
    }

    const existing = await this.repository.findActiveBySerialNumber(dto.moduleSerialNumber);
    if (existing) {
      throw new ConflictException(`Module '${dto.moduleSerialNumber}' is already registered`);
    }

    return this.repository.create({
      moduleSerialNumber: dto.moduleSerialNumber,
      registeredTo: dto.registeredTo,
      noOfPump: dto.noOfPump,
      phase: dto.phase,
      hpOfPump: dto.hpOfPump,
      createdBy: dto.createdBy,
      ...(dto.createDate && { createDate: new Date(dto.createDate) }),
    });
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
