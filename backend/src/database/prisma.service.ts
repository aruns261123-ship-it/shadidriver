import { Injectable, OnModuleDestroy, OnModuleInit } from '@nestjs/common';
import { PrismaClient } from '@prisma/client';

@Injectable()
export class PrismaService extends PrismaClient implements OnModuleInit, OnModuleDestroy {
  async onModuleInit(): Promise<void> {
    await this.$connect();
  }

  async onModuleDestroy(): Promise<void> {
    await this.$disconnect();
  }

  /**
   * Runs `fn` inside a serializable transaction — the isolation level used
   * for booking/assignment mutations that must prevent concurrent
   * double-allocation of the same vehicle or driver time window.
   */
  async withSerializableTransaction<T>(fn: (tx: PrismaService) => Promise<T>): Promise<T> {
    return this.$transaction(async (tx) => fn(tx as unknown as PrismaService), {
      isolationLevel: 'Serializable',
    });
  }
}
