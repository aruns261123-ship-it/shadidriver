import {
  Body,
  Controller,
  Delete,
  Get,
  HttpCode,
  Param,
  ParseUUIDPipe,
  Patch,
  Post,
  Query,
  Res,
  UploadedFile,
  UseInterceptors,
} from '@nestjs/common';
import { FileInterceptor } from '@nestjs/platform-express';
import { ApiBearerAuth, ApiBody, ApiConsumes, ApiOperation, ApiTags } from '@nestjs/swagger';
import { Response } from 'express';
import { CurrentUser } from '../auth/decorators/current-user.decorator';
import { AuthenticatedUser } from '../auth/domain/auth.types';
import { Role } from '../auth/domain/roles';
import { Roles } from '../auth/guards/roles.guard';
import { PartnerService } from './partner.service';
import { PricingService } from './pricing.service';
import {
  IMAGE_MIME_TYPES,
  DOCUMENT_MIME_TYPES,
} from '../common/storage/storage-provider.interface';
import {
  AddPartnerDocumentDto,
  AddVehicleDocumentDto,
  AddVehicleDto,
  RegisterPartnerDto,
  UpdatePartnerProfileDto,
  UpdateVehicleDto,
} from './dto/partner.dto';
import { SubmitVehiclePricingDto } from './dto/pricing.dto';

/**
 * Supply side: partner onboarding and fleet management.
 *
 * The same surface serves a chauffeur who owns their own cars and a fleet
 * business with many — the schema does not assume one driver = one vehicle.
 * Nothing here can make a vehicle customer-bookable; only verification can.
 */
/** Multer upload payload (matches @types/multer's Express.Multer.File). */
interface MulterFile {
  /** Original file name from the user's system. */
  originalname: string;
  mimetype: string;
  size: number;
  buffer: Buffer;
  [key: string]: unknown;
}

@ApiTags('partner')
@ApiBearerAuth()
@Roles(Role.Driver, Role.FleetOwner)
@Controller('partner')
export class PartnerController {
  constructor(
    private readonly partnerService: PartnerService,
    private readonly pricingService: PricingService,
  ) {}

  // ------------------------------------------------------------ onboarding

  @Post('registration')
  @ApiOperation({ summary: 'Register as a ShadiDriver partner (idempotent)' })
  register(
    @CurrentUser() user: AuthenticatedUser,
    @Body() dto: RegisterPartnerDto,
  ) {
    return this.partnerService.register(user.userId, dto);
  }

  @Get('profile')
  @ApiOperation({ summary: 'Partner profile and verification state' })
  getProfile(@CurrentUser() user: AuthenticatedUser) {
    return this.partnerService.getProfile(user.userId);
  }

  @Patch('profile')
  @ApiOperation({ summary: 'Edit professional and legal details' })
  updateProfile(
    @CurrentUser() user: AuthenticatedUser,
    @Body() dto: UpdatePartnerProfileDto,
  ) {
    return this.partnerService.updateProfile(user.userId, dto);
  }

  @Post('submit')
  @HttpCode(200)
  @ApiOperation({ summary: 'Submit the partner and its fleet for verification' })
  submit(@CurrentUser() user: AuthenticatedUser) {
    return this.partnerService.submitForReview(user.userId);
  }

  @Post('documents')
  @ApiOperation({ summary: 'Upload/replace a partner-level document' })
  addDocument(
    @CurrentUser() user: AuthenticatedUser,
    @Body() dto: AddPartnerDocumentDto,
  ) {
    return this.partnerService.addPartnerDocument(user.userId, dto);
  }

  // ----------------------------------------------------------------- fleet

  @Get('vehicles')
  @ApiOperation({ summary: 'The caller’s own fleet (never another partner’s)' })
  listVehicles(@CurrentUser() user: AuthenticatedUser) {
    return this.partnerService.listVehicles(user.userId);
  }

  @Post('vehicles')
  @ApiOperation({
    summary: 'Add one vehicle to the fleet (starts unverified and unbookable)',
  })
  addVehicle(@CurrentUser() user: AuthenticatedUser, @Body() dto: AddVehicleDto) {
    return this.partnerService.addVehicle(user.userId, dto);
  }

  @Patch('vehicles/:vehicleId')
  @ApiOperation({ summary: 'Edit a vehicle (an approved vehicle is re-reviewed)' })
  updateVehicle(
    @CurrentUser() user: AuthenticatedUser,
    // Rejected before it can reach SQL: a malformed id is a client error, not
    // a database error, so it must never surface as a 500.
    @Param('vehicleId', ParseUUIDPipe) vehicleId: string,
    @Body() dto: UpdateVehicleDto,
  ) {
    return this.partnerService.updateVehicle(user.userId, vehicleId, dto);
  }

  @Delete('vehicles/:vehicleId')
  @HttpCode(200)
  @ApiOperation({
    summary: 'Remove a vehicle from the fleet (refused if it is committed)',
  })
  removeVehicle(
    @CurrentUser() user: AuthenticatedUser,
    @Param('vehicleId', ParseUUIDPipe) vehicleId: string,
  ) {
    return this.partnerService.removeVehicle(user.userId, vehicleId);
  }

  @Post('vehicles/:vehicleId/documents')
  @ApiOperation({ summary: 'Register a vehicle document from a stored file key (re-reviewed)' })
  addVehicleDocument(
    @CurrentUser() user: AuthenticatedUser,
    @Param('vehicleId', ParseUUIDPipe) vehicleId: string,
    @Body() dto: AddVehicleDocumentDto,
  ) {
    return this.partnerService.addVehicleDocument(user.userId, vehicleId, dto);
  }

  /** REAL multipart photo upload → managed storage → primary/gallery update. */
  @Post('vehicles/:vehicleId/photos')
  @Roles(Role.Driver, Role.FleetOwner)
  @UseInterceptors(FileInterceptor('file'))
  @ApiConsumes('multipart/form-data')
  @ApiBody({
    schema: {
      type: 'object',
      properties: {
        file: { type: 'string', format: 'binary' },
        setPrimary: { type: 'boolean' },
        slot: { type: 'string', enum: ['EXTERIOR', 'INTERIOR', 'ADDITIONAL'] },
      },
    },
  })
  @ApiOperation({
    summary: 'Upload a vehicle photo (multipart). setPrimary=true makes it the card image.',
  })
  uploadVehiclePhoto(
    @CurrentUser() user: AuthenticatedUser,
    @Param('vehicleId', ParseUUIDPipe) vehicleId: string,
    @UploadedFile() file?: MulterFile,
    @Body('setPrimary') setPrimary?: string,
    @Body('slot') slot?: 'EXTERIOR' | 'INTERIOR' | 'ADDITIONAL',
  ) {
    if (!file) {
      return import('../auth/errors/auth.exceptions').then(({ BadRequestAppException }) => {
        throw new BadRequestAppException('VALIDATION_FAILED' as never, 'No file received.');
      });
    }
    return this.partnerService.uploadVehiclePhoto(user.userId, vehicleId, file, {
      setPrimary: setPrimary === 'true' || setPrimary === '1',
      slot,
    });
  }

  @Delete('vehicles/:vehicleId/photos')
  @Roles(Role.Driver, Role.FleetOwner)
  @ApiOperation({ summary: 'Remove a vehicle photo by URL (primary demotes to the next gallery shot)' })
  removeVehiclePhoto(
    @CurrentUser() user: AuthenticatedUser,
    @Param('vehicleId', ParseUUIDPipe) vehicleId: string,
    @Query('url') url: string,
    @Res() res: Response,
  ) {
    return this.partnerService
      .removeVehiclePhoto(user.userId, vehicleId, url ?? '')
      .then((result) => res.status(200).json(result));
  }

  /** REAL multipart document upload (RC / insurance / PUC / permit / fitness). */
  @Post('vehicles/:vehicleId/documents/upload')
  @Roles(Role.Driver, Role.FleetOwner)
  @UseInterceptors(FileInterceptor('file'))
  @ApiConsumes('multipart/form-data')
  @ApiBody({
    schema: {
      type: 'object',
      properties: {
        file: { type: 'string', format: 'binary' },
        documentType: {
          type: 'string',
          enum: ['REGISTRATION_CERTIFICATE', 'COMMERCIAL_INSURANCE', 'PUC_CERTIFICATE', 'PERMIT', 'FITNESS_CERTIFICATE', 'OTHER'],
        },
        documentNumber: { type: 'string' },
        issuedDate: { type: 'string', format: 'date' },
        expiryDate: { type: 'string', format: 'date' },
      },
      required: ['file', 'documentType'],
    },
  })
  @ApiOperation({ summary: 'Upload a vehicle document file (managed storage; re-enters review)' })
  uploadVehicleDocument(
    @CurrentUser() user: AuthenticatedUser,
    @Param('vehicleId', ParseUUIDPipe) vehicleId: string,
    @Body() dto: Omit<AddVehicleDocumentDto, 'storagePath' | 'mimeType'>,
    @UploadedFile() file?: MulterFile,
  ) {
    if (!file) {
      return import('../auth/errors/auth.exceptions').then(({ BadRequestAppException }) => {
        throw new BadRequestAppException('VALIDATION_FAILED' as never, 'No file received.');
      });
    }
    return this.partnerService.uploadVehicleDocument(
      user.userId,
      vehicleId,
      {
        documentType: dto.documentType,
        documentNumber: dto.documentNumber,
        issuedDate: dto.issuedDate,
        expiryDate: dto.expiryDate,
      },
      file,
    );
  }

  // ---------------------------------------------------------------- pricing

  @Post('vehicles/:vehicleId/pricing')
  @ApiOperation({
    summary: 'Submit a new tariff version (starts PENDING_REVIEW — never live immediately)',
  })
  submitPricing(
    @CurrentUser() user: AuthenticatedUser,
    @Param('vehicleId', ParseUUIDPipe) vehicleId: string,
    @Body() dto: SubmitVehiclePricingDto,
  ) {
    return this.pricingService.submitPricing(user.userId, vehicleId, dto);
  }

  @Get('vehicles/:vehicleId/pricing')
  @ApiOperation({
    summary: 'Tariff history for one of my vehicles (newest first, live version flagged)',
  })
  listPricing(
    @CurrentUser() user: AuthenticatedUser,
    @Param('vehicleId', ParseUUIDPipe) vehicleId: string,
  ) {
    return this.pricingService.listPricing(user.userId, vehicleId);
  }
}
