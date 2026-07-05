import { Injectable, NotFoundException } from '@nestjs/common';
import { UsersRepository } from './users.repository';
import { User } from '@prisma/client';

@Injectable()
export class UsersService {
  constructor(private readonly usersRepository: UsersRepository) {}

  async findById(id: string): Promise<User> {
    const user = await this.usersRepository.findById(id);
    if (!user) {
      throw new NotFoundException(`User with id ${id} not found`);
    }
    return user;
  }

  async findByPhoneNumber(phoneNumber: string): Promise<User | null> {
    return this.usersRepository.findByPhoneNumber(phoneNumber);
  }

  async create(data: { phoneNumber: string; name?: string }): Promise<User> {
    return this.usersRepository.create(data);
  }

  async markAsVerified(id: string): Promise<User> {
    return this.usersRepository.update(id, { isVerified: true });
  }

  async updateProfile(id: string, data: { name?: string }): Promise<User> {
    return this.usersRepository.update(id, data);
  }

  async findAll(): Promise<User[]> {
    return this.usersRepository.findAll();
  }
}
