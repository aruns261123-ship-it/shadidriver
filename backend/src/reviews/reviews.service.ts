import { Injectable } from '@nestjs/common';
import { Prisma, ReviewStatus } from '@prisma/client';
import { PrismaService } from '../database/prisma.service';
import {
  BadRequestAppException,
  ConflictAppException,
  NotFoundAppException,
} from '../auth/errors/auth.exceptions';
import { ErrorCode } from '../common/errors/error-codes';
import { AuthenticatedUser } from '../auth/domain/auth.types';
import { BookingStatus } from '../booking-state-machine/booking-status';
import { ModerationAction, SubmitReviewDto } from './dto/reviews.dto';

/** The public shape of a published review — no customer identity beyond a name. */
const PUBLIC_REVIEW_SELECT = {
  id: true,
  overallRating: true,
  punctualityRating: true,
  groomingRating: true,
  cleanlinessRating: true,
  drivingRating: true,
  vehicleQualityRating: true,
  feedbackText: true,
  createdAt: true,
  customer: { select: { fullName: true } },
} satisfies Prisma.ReviewSelect;

/**
 * Customer reviews for the managed-booking model.
 *
 * Eligibility is server-authoritative and deliberately strict:
 *   * only the booking's OWN customer may review it (404 otherwise — same
 *     response as a booking that does not exist, so ids cannot be probed);
 *   * only a COMPLETED booking is reviewable — never one still in the pipeline;
 *   * ONE review per vehicle per group booking (a convoy is rated per car);
 *   * every review enters moderation (PENDING_MODERATION) and only PUBLISHED
 *     reviews feed the public catalog aggregates.
 *
 * Chauffeur attribution is derived internally from the confirmed assignment —
 * the customer never has to know (or submit) a chauffeur id.
 */
@Injectable()
export class ReviewsService {
  constructor(private readonly prisma: PrismaService) {}

  async submit(dto: SubmitReviewDto, reviewer: AuthenticatedUser) {
    const group = await this.prisma.groupBooking.findUnique({
      where: { id: dto.groupBookingId },
      include: {
        assignments: {
          where: { vehicleId: dto.vehicleId },
          select: { id: true, driverId: true, assignmentStatus: true },
        },
      },
    });
    // Ownership + existence collapse into one 404: no oracle for probing ids.
    if (!group || group.customerFk !== reviewer.userId) {
      throw new NotFoundAppException(ErrorCode.GROUP_BOOKING_NOT_FOUND, 'Group booking not found.');
    }
    if (group.status !== BookingStatus.COMPLETED) {
      throw new ConflictAppException(
        ErrorCode.INVALID_TRANSITION,
        'Only a completed booking can be reviewed.',
      );
    }

    const assignment = group.assignments[0];
    if (!assignment) {
      throw new NotFoundAppException(
        ErrorCode.NOT_FOUND,
        'That vehicle was not part of this booking.',
      );
    }

    const duplicate = await this.prisma.review.findFirst({
      where: { groupBookingId: group.id, vehicleFk: dto.vehicleId },
      select: { id: true },
    });
    if (duplicate) {
      throw new ConflictAppException(ErrorCode.CONFLICT, 'You already reviewed this vehicle.');
    }

    const created = await this.prisma.review.create({
      data: {
        groupBookingId: group.id,
        assignmentId: assignment.id,
        customerFk: reviewer.userId,
        // Derived internally — never submitted by the client.
        driverFk: assignment.driverId,
        vehicleFk: dto.vehicleId,
        overallRating: dto.overallRating,
        punctualityRating: dto.punctualityRating,
        groomingRating: dto.groomingRating,
        cleanlinessRating: dto.cleanlinessRating,
        drivingRating: dto.drivingRating,
        vehicleQualityRating: dto.vehicleQualityRating,
        feedbackText: dto.feedbackText,
        status: ReviewStatus.PENDING_MODERATION,
      },
    });

    return this.toSelfView(created);
  }

  /** The caller's own reviews, newest first. */
  async listMine(reviewer: AuthenticatedUser, page = 1, limit = 20) {
    const [rows, total] = await this.prisma.$transaction([
      this.prisma.review.findMany({
        where: { customerFk: reviewer.userId },
        orderBy: { createdAt: 'desc' },
        skip: (page - 1) * limit,
        take: limit,
        include: {
          vehicle: { include: { vehicleType: { select: { displayName: true } } } },
        },
      }),
      this.prisma.review.count({ where: { customerFk: reviewer.userId } }),
    ]);
    return {
      items: rows.map((r) => this.toSelfView(r)),
      page,
      limit,
      total,
    };
  }

  /**
   * The reviews the customer can still write: one per completed, un-reviewed
   * vehicle across their booking history. Drives the "rate your cars" screen.
   */
  async pendingForMe(customerId: string) {
    const completed = await this.prisma.groupBooking.findMany({
      where: { customerFk: customerId, status: BookingStatus.COMPLETED },
      orderBy: { serviceEndTime: 'desc' },
      take: 20,
      include: {
        assignments: {
          include: {
            vehicle: { include: { vehicleType: { select: { displayName: true } } } },
          },
        },
        reviews: { select: { vehicleFk: true } },
      },
    });

    const items: Array<Record<string, unknown>> = [];
    for (const group of completed) {
      const reviewed = new Set(group.reviews.map((r) => r.vehicleFk));
      for (const assignment of group.assignments) {
        if (!reviewed.has(assignment.vehicleId)) {
          items.push({
            group_booking_id: group.id,
            reference_code: group.referenceCode,
            ceremony_type: group.ceremonyType,
            service_end_time: group.serviceEndTime,
            vehicle: {
              id: assignment.vehicleId,
              fleet_code: assignment.vehicle.fleetCode,
              display_name: assignment.vehicle.vehicleType?.displayName ?? null,
            },
          });
        }
      }
    }
    return { items, total: items.length };
  }

  /** Published reviews for ONE vehicle (public catalog detail surface). */
  async listForVehicle(vehicleId: string, page = 1, limit = 10) {
    const [rows, total, agg] = await this.prisma.$transaction([
      this.prisma.review.findMany({
        where: { vehicleFk: vehicleId, status: ReviewStatus.PUBLISHED },
        orderBy: { createdAt: 'desc' },
        skip: (page - 1) * limit,
        take: limit,
        select: PUBLIC_REVIEW_SELECT,
      }),
      this.prisma.review.count({
        where: { vehicleFk: vehicleId, status: ReviewStatus.PUBLISHED },
      }),
      this.prisma.review.aggregate({
        where: { vehicleFk: vehicleId, status: ReviewStatus.PUBLISHED },
        _avg: { overallRating: true },
      }),
    ]);
    return {
      items: rows.map((r) => ({
        id: r.id,
        rating: r.overallRating,
        punctuality: r.punctualityRating,
        grooming: r.groomingRating,
        cleanliness: r.cleanlinessRating,
        driving: r.drivingRating,
        vehicle_quality: r.vehicleQualityRating,
        comment: r.feedbackText,
        // First name only — a review must not hand out full customer identity.
        author: (r.customer.fullName ?? '').split(' ')[0] ?? 'Guest',
        created_at: r.createdAt,
      })),
      average_rating:
        agg._avg.overallRating != null
          ? Math.round(agg._avg.overallRating * 100) / 100
          : null,
      total,
      page,
      limit,
    };
  }

  // ------------------------------------------------------------- moderation

  /** Oldest pending first — a review waiting is a partner waiting on trust. */
  async moderationQueue() {
    const rows = await this.prisma.review.findMany({
      where: { status: ReviewStatus.PENDING_MODERATION },
      orderBy: { createdAt: 'asc' },
      take: 100,
      include: {
        customer: { select: { fullName: true, phoneNumber: true } },
        vehicle: {
          select: {
            fleetCode: true,
            vehicleType: { select: { displayName: true } },
            fleetOwner: { select: { companyName: true } },
          },
        },
        driver: { include: { user: { select: { fullName: true } } } },
        groupBooking: { select: { referenceCode: true, ceremonyType: true } },
      },
    });
    return {
      items: rows.map((r) => ({
        id: r.id,
        created_at: r.createdAt,
        group_reference: r.groupBooking?.referenceCode ?? null,
        ceremony_type: r.groupBooking?.ceremonyType ?? null,
        vehicle: {
          fleet_code: r.vehicle.fleetCode,
          display_name: r.vehicle.vehicleType?.displayName ?? null,
          partner: r.vehicle.fleetOwner?.companyName ?? null,
        },
        chauffeur: r.driver ? { name: r.driver.user?.fullName ?? null } : null,
        customer: { name: r.customer.fullName, phone: r.customer.phoneNumber },
        ratings: {
          overall: r.overallRating,
          punctuality: r.punctualityRating,
          grooming: r.groomingRating,
          cleanliness: r.cleanlinessRating,
          driving: r.drivingRating,
          vehicle_quality: r.vehicleQualityRating,
        },
        comment: r.feedbackText,
      })),
      total: rows.length,
    };
  }

  /**
   * PUBLISH makes the review public (and moves the catalog aggregates).
   * HIDE withdraws it from public view without destroying the record — the
   * customer's history keeps it with its moderation trail. Both are audited.
   */
  async moderate(reviewId: string, action: ModerationAction, admin: AuthenticatedUser, reason?: string) {
    const review = await this.prisma.review.findUnique({ where: { id: reviewId } });
    if (!review) {
      throw new NotFoundAppException(ErrorCode.NOT_FOUND, 'Review not found.');
    }

    const status =
      action === 'PUBLISH'
        ? ReviewStatus.PUBLISHED
        : action === 'HIDE'
          ? ReviewStatus.HIDDEN
          : ReviewStatus.PENDING_MODERATION;

    if (action === 'HIDE' && !reason?.trim()) {
      throw new BadRequestAppException(
        ErrorCode.VALIDATION_FAILED,
        'A reason is required to hide a review.',
      );
    }
    if (review.status === status) {
      throw new ConflictAppException(
        ErrorCode.CONFLICT,
        `This review is already ${status}.`,
      );
    }

    const updated = await this.prisma.$transaction(async (tx) => {
      const row = await tx.review.update({
        where: { id: reviewId },
        data: {
          status,
          moderatedByUserId: admin.userId,
          moderatedAt: new Date(),
          moderationReason: reason ?? null,
        },
      });
      await tx.auditLog.create({
        data: {
          actorId: admin.userId,
          actorRole: admin.role,
          action: `REVIEW_${action}`,
          targetEntity: 'reviews',
          targetId: reviewId,
          changes: { from: review.status, to: status, reason: reason ?? null },
        },
      });
      return row;
    });

    return {
      id: updated.id,
      status: updated.status,
      moderated_at: updated.moderatedAt,
    };
  }

  private toSelfView(review: {
    id: string;
    status: string;
    overallRating: number;
    punctualityRating: number | null;
    groomingRating: number | null;
    cleanlinessRating: number | null;
    drivingRating: number | null;
    vehicleQualityRating: number | null;
    feedbackText: string | null;
    createdAt: Date;
    moderatedAt: Date | null;
    moderationReason: string | null;
    vehicle?: { fleetCode: string; vehicleType: { displayName: string } | null } | null;
  }) {
    return {
      id: review.id,
      status: review.status,
      ratings: {
        overall: review.overallRating,
        punctuality: review.punctualityRating,
        grooming: review.groomingRating,
        cleanliness: review.cleanlinessRating,
        driving: review.drivingRating,
        vehicle_quality: review.vehicleQualityRating,
      },
      comment: review.feedbackText,
      vehicle: review.vehicle
        ? {
            fleet_code: review.vehicle.fleetCode,
            display_name: review.vehicle.vehicleType?.displayName ?? null,
          }
        : null,
      moderated_at: review.moderatedAt,
      moderation_reason: review.moderationReason,
      created_at: review.createdAt,
    };
  }
}
