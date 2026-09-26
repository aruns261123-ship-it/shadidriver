import { Module } from '@nestjs/common';
import { ReviewsController } from './reviews.controller';
import { ReviewsService } from './reviews.service';

/**
 * Customer reviews for completed managed bookings, with an admin moderation
 * queue. Only PUBLISHED reviews feed the public catalog aggregates, so a
 * defamatory or spam review cannot reach the catalog before a human decides.
 */
@Module({
  controllers: [ReviewsController],
  providers: [ReviewsService],
  exports: [ReviewsService],
})
export class ReviewsModule {}
