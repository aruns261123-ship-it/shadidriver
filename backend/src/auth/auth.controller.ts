import { Body, Controller, Get, HttpCode, Post, Req, UseGuards } from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiTags } from '@nestjs/swagger';
import { Request } from 'express';
import { CurrentUser } from './decorators/current-user.decorator';
import { JwtAuthGuard, Public, REQUEST_USER_KEY } from './guards/jwt-auth.guard';
import { AuthService } from './auth.service';
import { GoogleAuthService } from './services/google-auth.service';
import { RequestOtpDto, RefreshTokenDto, SignUpDto, VerifyOtpDto } from './dto/auth.dto';
import { AuthenticatedUser } from './domain/auth.types';
import { IsOptional, IsString, Length } from 'class-validator';

export class GoogleSignInDto {
  /** Google ID token from the client SDK (google_sign_in). Verified here. */
  @IsString() @Length(20, 4096) idToken!: string;
  @IsOptional() @IsString() @Length(4, 128) deviceId?: string;
}

@ApiTags('auth')
@Controller('auth')
export class AuthController {
  constructor(
    private readonly authService: AuthService,
    private readonly googleAuthService: GoogleAuthService,
  ) {}

  @Public()
  @Post('google')
  @HttpCode(200)
  @ApiOperation({
    summary:
      'Customer sign-in with a Google ID token (verified server-side; same session architecture as OTP)',
  })
  async googleSignIn(@Body() dto: GoogleSignInDto) {
    const result = await this.googleAuthService.signInWithIdToken(dto.idToken, dto.deviceId);
    return {
      access_token: result.accessToken,
      refresh_token: result.refreshToken,
      expires_in: result.accessTokenExpiresIn,
      user: {
        id: result.user.id,
        phone_number: result.user.phoneNumber,
        full_name: result.user.fullName,
        role: result.user.role,
        account_status: result.user.accountStatus,
        is_new_user: result.user.isNewUser,
      },
    };
  }

  @Post('google/link')
  @UseGuards(JwtAuthGuard)
  @ApiBearerAuth()
  @HttpCode(200)
  @ApiOperation({ summary: 'Link a verified Google identity to the signed-in account' })
  async googleLink(
    @CurrentUser() user: AuthenticatedUser,
    @Body() dto: GoogleSignInDto,
  ) {
    return this.googleAuthService.linkToUser(user.userId, dto.idToken);
  }

  @Public()
  @Post('otp/request')
  @HttpCode(200)
  @ApiOperation({ summary: 'Request a one-time password (rate limited)' })
  async requestOtp(@Body() dto: RequestOtpDto) {
    const session = await this.authService.requestOtp(dto.phoneNumber, dto.purpose ?? 'LOGIN');
    return {
      session_id: session.sessionId,
      expires_in_seconds: session.expiresInSeconds,
      resend_available_in_seconds: session.resendAvailableInSeconds,
      ...(session.debugCode ? { debug_code: session.debugCode } : {}),
    };
  }

  @Public()
  @Post('signup')
  @HttpCode(200)
  @ApiOperation({ summary: 'Register a customer or driver account (admins are provisioned internally only)' })
  async signUp(@Body() dto: SignUpDto) {
    const result = await this.authService.signUp(dto.phoneNumber, dto.displayName, dto.role);
    return { session_id: result.sessionId, expires_in_seconds: result.expiresInSeconds, next_step: 'VERIFY_OTP' };
  }

  @Public()
  @Post('otp/verify')
  @HttpCode(200)
  @ApiOperation({ summary: 'Verify OTP and receive access + refresh tokens' })
  async verifyOtp(@Body() dto: VerifyOtpDto) {
    const result = await this.authService.verifyOtp(dto.sessionId, dto.otpCode, dto.deviceId);
    return {
      access_token: result.accessToken,
      refresh_token: result.refreshToken,
      expires_in: result.accessTokenExpiresIn,
      user: {
        id: result.user.id,
        phone_number: result.user.phoneNumber,
        full_name: result.user.fullName,
        role: result.user.role,
        account_status: result.user.accountStatus,
        is_new_user: result.user.isNewUser,
      },
    };
  }

  @Public()
  @Post('refresh')
  @HttpCode(200)
  @ApiOperation({ summary: 'Rotate refresh token and receive a new token pair' })
  async refresh(@Body() dto: RefreshTokenDto) {
    const result = await this.authService.refreshSession(dto.refreshToken, dto.deviceId);
    return {
      access_token: result.accessToken,
      refresh_token: result.refreshToken,
      expires_in: result.accessTokenExpiresIn,
      user: {
        id: result.user.id,
        role: result.user.role,
        account_status: result.user.accountStatus,
      },
    };
  }

  @Public()
  @Post('logout')
  @HttpCode(200)
  @ApiOperation({ summary: 'Revoke refresh token (or all sessions when authenticated)' })
  async logout(
    @Body() dto: Partial<RefreshTokenDto>,
    @Req() request: Request & { [REQUEST_USER_KEY]?: AuthenticatedUser },
  ) {
    await this.authService.logout(dto?.refreshToken, request[REQUEST_USER_KEY]?.userId);
    return { revoked: true };
  }

  @Get('me')
  @UseGuards(JwtAuthGuard)
  @ApiBearerAuth()
  @ApiOperation({ summary: 'Resolve the authenticated identity (server-authoritative role)' })
  async me(@Req() request: Request & { [REQUEST_USER_KEY]?: AuthenticatedUser }) {
    return this.authService.me(request[REQUEST_USER_KEY]!.userId);
  }
}
