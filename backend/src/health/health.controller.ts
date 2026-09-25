import { Controller, Get } from '@nestjs/common';
import { ApiTags } from '@nestjs/swagger';
import { PrismaService } from '../database/prisma.service';
import { Public } from '../auth/guards/jwt-auth.guard';

@ApiTags('health')
@Controller('health')
export class HealthController {
  constructor(private readonly prisma: PrismaService) {}

  /** Liveness probe — process is up. */
  @Public()
  @Get()
  health(): {
    status: string;
    service: string;
    timestamp: string;
  } {
    return {
      status: 'ok',
      service: 'shadidriver-backend',
      timestamp: new Date().toISOString(),
    };
  }

  /** Readiness probe — verifies database connectivity. */
  @Public()
  @Get('ready')
  async ready(): Promise<{
    status: string;
    database: string;
    timestamp: string;
  }> {
    let database = 'up';

    try {
      await this.prisma.$queryRaw`SELECT 1`;
    } catch {
      database = 'down';
    }

    return {
      status: database === 'up' ? 'ok' : 'degraded',
      database,
      timestamp: new Date().toISOString(),
    };
  }
}