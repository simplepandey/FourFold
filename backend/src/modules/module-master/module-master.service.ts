import { Injectable, NotFoundException, ConflictException } from '@nestjs/common';
import { ModuleMasterRepository } from './module-master.repository';
import { CreateModuleMasterDto } from './dto/create-module-master.dto';
import { UpdateModuleMasterDto } from './dto/update-module-master.dto';

@Injectable()
export class ModuleMasterService {
  constructor(private readonly repository: ModuleMasterRepository) {}

  async create(dto: CreateModuleMasterDto) {
    const existing = await this.repository.findBySerialNumber(dto.serialNumber);
    if (existing) {
      throw new ConflictException(`Module with serial number '${dto.serialNumber}' already exists`);
    }

    return this.repository.create({
      serialNumber: dto.serialNumber,
      createdBy: dto.createdBy,
      ...(dto.createDate && { createDate: new Date(dto.createDate) }),
    });
  }

  async findAll() {
    return this.repository.findAll();
  }

  async findById(id: string) {
    const module = await this.repository.findById(id);
    if (!module) {
      throw new NotFoundException(`Module with id '${id}' not found`);
    }
    return module;
  }

  async findBySerialNumber(serialNumber: string) {
    return this.repository.findBySerialNumber(serialNumber);
  }

  async findOneBySerialNumber(serialNumber: string) {
    const module = await this.repository.findBySerialNumber(serialNumber);
    if (!module) {
      throw new NotFoundException(`Module with serial number '${serialNumber}' not found`);
    }
    return module;
  }

  async update(id: string, dto: UpdateModuleMasterDto) {
    await this.findById(id);

    if (dto.serialNumber) {
      const existing = await this.repository.findBySerialNumber(dto.serialNumber);
      if (existing && existing.id !== id) {
        throw new ConflictException(`Serial number '${dto.serialNumber}' is already in use`);
      }
    }

    return this.repository.update(id, {
      ...(dto.serialNumber && { serialNumber: dto.serialNumber }),
      updatedBy: dto.updatedBy,
      ...(dto.updateDate && { updateDate: new Date(dto.updateDate) }),
    });
  }

  async remove(id: string, updatedBy: string) {
    await this.findById(id);
    return this.repository.softDelete(id, updatedBy);
  }
}
