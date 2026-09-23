import { Controller, Get, Param, Query } from '@nestjs/common';
import { ApiOperation, ApiTags } from '@nestjs/swagger';
import { Public } from '../auth/guards/jwt-auth.guard';
import { VehiclesService, VehicleSearchInput } from './vehicles.service';

@ApiTags('vehicles')
@Controller('vehicles')
export class VehiclesController {
  constructor(private readonly vehiclesService: VehiclesService) {}

  @Public()
  @Get()
  @ApiOperation({ summary: 'Search the verified vehicle catalog' })
  search(
    @Query('city') city?: string,
    @Query('vehicleTypeId') vehicleTypeId?: string,
    @Query('vehicleClass') vehicleClass?: string,
    @Query('minSeatingCapacity') minSeatingCapacity?: string,
    @Query('page') page = '1',
    @Query('limit') limit = '20',
  ) {
    const input: VehicleSearchInput = {
      city: city || undefined,
      vehicleTypeIds: vehicleTypeId ? vehicleTypeId.split(',').filter(Boolean) : undefined,
      vehicleClass: vehicleClass || undefined,
      minSeatingCapacity: minSeatingCapacity ? Number(minSeatingCapacity) : undefined,
      page: Math.max(1, Number(page) || 1),
      limit: Math.min(50, Math.max(1, Number(limit) || 20)),
    };
    return this.vehiclesService.searchVehicles(input);
  }

  @Public()
  @Get('types')
  @ApiOperation({ summary: 'List active vehicle types (fleet picker source)' })
  getTypes() {
    return this.vehiclesService.getVehicleTypes();
  }

  @Public()
  @Get('availability')
  @ApiOperation({ summary: 'Available verified vehicle count per type (optionally by city)' })
  availabilityByType(@Query('city') city?: string) {
    return this.vehiclesService.getAvailabilityByType(city || undefined);
  }

  @Public()
  @Get(':id')
  @ApiOperation({ summary: 'Vehicle details including chauffeur and document status' })
  getById(@Param('id') id: string) {
    return this.vehiclesService.getVehicleById(id);
  }
}
