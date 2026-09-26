import { Body, Controller, Get, Headers, HttpCode, Param, ParseUUIDPipe, Post, RawBodyRequest, Req } from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiTags } from '@nestjs/swagger';
import { IsIn, IsOptional, IsString, IsUUID, Length } from 'class-validator';
import { Request } from 'express';
import { CurrentUser } from '../auth/decorators/current-user.decorator';
import { AuthenticatedUser } from '../auth/domain/auth.types';
import { Public } from '../auth/guards/jwt-auth.guard';
import { PaymentsService } from './payments.service';

export class CreateOrderDto {
  @IsString() @Length(8, 64) bookingId!: string;
  @IsString() @Length(8, 100) idempotencyKey!: string;
  @IsOptional() @IsIn(['ADVANCE_TOKEN', 'BALANCE_SETTLEMENT']) paymentType?: string;
}

export class VerifyPaymentDto {
  @IsString() @Length(8, 64) paymentId!: string;
  @IsString() @Length(4, 128) gatewayOrderId!: string;
  @IsString() @Length(4, 128) gatewayPaymentId!: string;
  @IsString() @Length(8, 512) signature!: string;
}

/** Managed (group) booking payment order — the type decides the stage. */
export class CreateGroupOrderDto {
  @IsUUID()
  groupBookingId!: string;

  @IsIn(['ADVANCE_TOKEN', 'BALANCE_SETTLEMENT'])
  paymentType!: 'ADVANCE_TOKEN' | 'BALANCE_SETTLEMENT';

  @IsString() @Length(8, 100) idempotencyKey!: string;
}

export class DevGroupCheckoutDto {
  @IsString() @Length(8, 64) paymentId!: string;
  @IsString() @Length(4, 128) gatewayOrderId!: string;
}

@ApiTags('payments')
@ApiBearerAuth()
@Controller('payments')
export class PaymentsController {
  constructor(private readonly paymentsService: PaymentsService) {}

  @Post('advance-token/order')
  @HttpCode(200)
  @ApiOperation({ summary: 'Create an advance-token order (amount comes from the booking row)' })
  createOrder(@CurrentUser() user: AuthenticatedUser, @Body() dto: CreateOrderDto) {
    return this.paymentsService.createAdvanceTokenOrder(
      dto.bookingId,
      user.userId,
      dto.idempotencyKey,
    );
  }

  @Post('verify')
  @HttpCode(200)
  @ApiOperation({ summary: 'Capture a client-claimed payment (gateway signature MANDATORY)' })
  verify(@CurrentUser() user: AuthenticatedUser, @Body() dto: VerifyPaymentDto) {
    return this.paymentsService.verifyAndCapture({
      paymentDbId: dto.paymentId,
      customerId: user.userId,
      gatewayOrderId: dto.gatewayOrderId,
      gatewayPaymentId: dto.gatewayPaymentId,
      signature: dto.signature,
    });
  }

  // ------------------------------------------------- managed (group) path

  @Post('group/order')
  @HttpCode(200)
  @ApiOperation({
    summary:
      'Create an ADVANCE_TOKEN or BALANCE_SETTLEMENT order for a managed booking (amount from the booking row)',
  })
  createGroupOrder(@CurrentUser() user: AuthenticatedUser, @Body() dto: CreateGroupOrderDto) {
    return dto.paymentType === 'ADVANCE_TOKEN'
      ? this.paymentsService.createGroupAdvanceOrder(
          dto.groupBookingId,
          user.userId,
          dto.idempotencyKey,
        )
      : this.paymentsService.createGroupBalanceOrder(
          dto.groupBookingId,
          user.userId,
          dto.idempotencyKey,
        );
  }

  @Post('group/verify')
  @HttpCode(200)
  @ApiOperation({
    summary: 'Capture a managed-booking payment (gateway signature MANDATORY; advance capture confirms the booking)',
  })
  verifyGroup(@CurrentUser() user: AuthenticatedUser, @Body() dto: VerifyPaymentDto) {
    return this.paymentsService.captureGroupPayment({
      paymentDbId: dto.paymentId,
      customerId: user.userId,
      gatewayOrderId: dto.gatewayOrderId,
      gatewayPaymentId: dto.gatewayPaymentId,
      signature: dto.signature,
    });
  }

  @Post('group/dev/checkout')
  @HttpCode(200)
  @ApiOperation({ summary: 'DEV ONLY: simulate a successful hosted checkout for a managed booking' })
  devGroupCheckout(@CurrentUser() user: AuthenticatedUser, @Body() dto: DevGroupCheckoutDto) {
    return this.paymentsService.devGroupCheckout({
      paymentDbId: dto.paymentId,
      customerId: user.userId,
      gatewayOrderId: dto.gatewayOrderId,
    });
  }

  @Get('group/:groupBookingId')
  @ApiOperation({ summary: 'Payment history + settlement state for a managed booking (owner or admin)' })
  groupPayments(
    @CurrentUser() user: AuthenticatedUser,
    @Param('groupBookingId', ParseUUIDPipe) groupBookingId: string,
  ) {
    return this.paymentsService.listGroupPayments(groupBookingId, {
      userId: user.userId,
      isAdmin: ['operationsAdmin', 'verificationAdmin', 'financeAdmin', 'superAdmin'].includes(
        user.role,
      ),
    });
  }

  /**
   * DEV-ONLY simulated hosted-checkout: the SERVER signs the payment
   * (devSignPayment is forbidden in production) and immediately runs the
   * real capture path. The client never touches gateway secrets. With the
   * real Razorpay gateway this endpoint is replaced by the hosted flow.
   */
  @Post('dev/checkout')
  @HttpCode(200)
  @ApiOperation({ summary: 'DEV ONLY: simulate a successful hosted checkout (server-signed)' })
  devCheckout(@CurrentUser() user: AuthenticatedUser, @Body() dto: VerifyPaymentDto) {
    return this.paymentsService.devHostedCheckout({
      paymentDbId: dto.paymentId,
      customerId: user.userId,
      gatewayOrderId: dto.gatewayOrderId,
    });
  }

  @Public()
  @Post('webhook')
  @HttpCode(200)
  @ApiOperation({ summary: 'Gateway webhook ingestion (HMAC-verified over raw body)' })
  webhook(
    @Req() request: RawBodyRequest<Request>,
    @Headers('x-gateway-signature') signature?: string,
  ) {
    const rawBody =
      request.rawBody?.toString('utf8') ?? JSON.stringify(request.body ?? {});
    return this.paymentsService.ingestWebhook({ rawBody, signature: signature ?? '' });
  }
}
