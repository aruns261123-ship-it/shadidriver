import { Body, Controller, Headers, HttpCode, Post, RawBodyRequest, Req } from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiTags } from '@nestjs/swagger';
import { IsIn, IsOptional, IsString, Length } from 'class-validator';
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
