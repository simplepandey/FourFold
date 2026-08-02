import { Injectable } from '@nestjs/common';
import { PrismaService } from '../../prisma/prisma.service';

@Injectable()
export class TopicPatternRepository {
  constructor(private readonly prisma: PrismaService) {}

  /** Inserts any patterns not already present; existing rows are left untouched. */
  async seedDefaults(patterns: string[]): Promise<void> {
    await this.prisma.topicPatternToSubscribe.createMany({
      data: patterns.map((pattern) => ({ pattern })),
      skipDuplicates: true,
    });
  }

  async findAllPatterns(): Promise<string[]> {
    const rows = await this.prisma.topicPatternToSubscribe.findMany();
    return rows.map((r) => r.pattern);
  }
}
