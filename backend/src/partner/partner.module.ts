import { Module } from '@nestjs/common';
import { PartnerController } from './partner.controller';
import { PartnerService } from './partner.service';
import { PricingService } from './pricing.service';

@Module({
  controllers: [PartnerController],
  providers: [PartnerService, PricingService],
  exports: [PartnerService, PricingService],
})
export class PartnerModule {}
