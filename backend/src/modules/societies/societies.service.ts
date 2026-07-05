import { Injectable, NotFoundException, ConflictException } from '@nestjs/common';
import * as bcrypt from 'bcrypt';
import { SocietiesRepository } from './societies.repository';
import { CreateSocietyDto } from './dto/create-society.dto';
import { Society } from '@prisma/client';

@Injectable()
export class SocietiesService {
  constructor(private readonly societiesRepository: SocietiesRepository) {}

  async create(dto: CreateSocietyDto) {
    const existing = await this.societiesRepository.findByPhoneNumber(dto.phoneNumber);
    if (existing) {
      throw new ConflictException('A society with this phone number already exists');
    }

    const hashedPassword = await bcrypt.hash(dto.password, 10);

    const society = await this.societiesRepository.create({
      phoneNumber: dto.phoneNumber,
      name: dto.name,
      societyName: dto.societyName,
      blockOrWing: dto.blockOrWing,
      totalMembers: dto.totalMembers,
      password: hashedPassword,
    });

    return this.sanitize(society);
  }

  async findById(id: string) {
    const society = await this.societiesRepository.findById(id);
    if (!society) {
      throw new NotFoundException(`Society with id ${id} not found`);
    }
    return this.sanitize(society);
  }

  async findByPhoneNumber(phoneNumber: string): Promise<Society | null> {
    return this.societiesRepository.findByPhoneNumber(phoneNumber);
  }

  async findAll() {
    const societies = await this.societiesRepository.findAll();
    return societies.map((s) => this.sanitize(s));
  }

  private sanitize(society: Society) {
    const { password, ...rest } = society;
    return rest;
  }
}
