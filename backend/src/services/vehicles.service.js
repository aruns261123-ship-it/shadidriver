import { AppError, HttpStatus } from '../errors.js';
import { store } from '../store/memory-store.js';
import { pick } from '../utils/body.js';

function toSummary(vehicle) {
  const driver = vehicle.independentDriverId ? store.drivers.get(vehicle.independentDriverId) : null;
  return {
    id: vehicle.id,
    make: vehicle.make,
    model: vehicle.model,
    year: vehicle.year,
    vehicleClass: vehicle.vehicleClass,
    registrationNumber: vehicle.registrationNumber,
    seatingCapacity: vehicle.seatingCapacity,
    verificationStatus: vehicle.verificationStatus,
    imageUrl: vehicle.imageUrl,
    rating: driver?.averageRating || 0,
    reviewCount: driver?.totalTripsCompleted || 0,
    hasVerifiedChauffeur: driver?.verificationStatus === 'APPROVED',
    pricing: {
      basePriceCents: vehicle.basePricePaise,
      currencyCode: 'INR',
      billingUnit: 'HOUR',
      isStartingPrice: true,
    },
    transmission: vehicle.transmission,
    amenities: vehicle.amenities,
    isAvailableNow: vehicle.isAvailable && ['AVAILABLE', 'AVAILABLE_NOW'].includes(driver?.dutyStatus || 'OFFLINE'),
    chauffeurId: vehicle.independentDriverId,
    color: vehicle.color,
    fuelType: vehicle.fuelType,
    city: vehicle.city,
  };
}

function toDetails(vehicle) {
  const summary = toSummary(vehicle);
  const driver = vehicle.independentDriverId ? store.drivers.get(vehicle.independentDriverId) : null;
  const user = vehicle.independentDriverId ? store.users.get(vehicle.independentDriverId) : null;
  return {
    ...summary,
    galleryUrls: vehicle.galleryUrls,
    suitabilityInfo: vehicle.suitabilityInfo,
    suitableCeremonies: vehicle.suitableCeremonies,
    chauffeurName: user?.fullName || '',
    chauffeurRating: driver?.averageRating || 0,
    ceremonialAddons: catalogAddons(),
  };
}

function catalogAddons() {
  return [...store.addons.values()]
    .filter((a) => a.isActive)
    .slice(0, 8)
    .map((a) => ({
      id: a.id,
      name: a.name,
      description: a.description,
      features: a.features || [],
      pricing: {
        basePriceCents: a.pricePaise,
        currencyCode: 'INR',
        billingUnit: 'PACKAGE',
        isStartingPrice: false,
      },
    }));
}

function matches(vehicle, query = {}) {
  if (!vehicle.isActive) return false;
  if (query.city && String(vehicle.city).toLowerCase() !== String(query.city).toLowerCase()) return false;
  const categories = query.vehicleCategories || query.vehicleClass;
  if (Array.isArray(categories) && categories.length && !categories.includes(vehicle.vehicleClass)) return false;
  if (typeof categories === 'string' && categories && vehicle.vehicleClass !== categories) return false;
  if (query.occasionId && !(vehicle.suitableCeremonies || []).includes(query.occasionId)) return false;
  if (query.minModelYear && vehicle.year < Number(query.minModelYear)) return false;
  if (query.maxModelYear && vehicle.year > Number(query.maxModelYear)) return false;
  if (query.minPriceCents && vehicle.basePricePaise < Number(query.minPriceCents)) return false;
  if (query.maxPriceCents && vehicle.basePricePaise > Number(query.maxPriceCents)) return false;
  if (query.transmission && vehicle.transmission !== query.transmission) return false;
  if (query.passengerCount && vehicle.seatingCapacity < Number(query.passengerCount)) return false;
  if (query.verifiedVehicleOnly === true && vehicle.verificationStatus !== 'APPROVED') return false;
  if (query.verifiedChauffeurOnly === true) {
    const driver = vehicle.independentDriverId ? store.drivers.get(vehicle.independentDriverId) : null;
    if (driver?.verificationStatus !== 'APPROVED') return false;
  }
  if (query.availableNow === true && !vehicle.isAvailable) return false;
  if (query.pickupLocation) {
    const hay = `${vehicle.city} ${vehicle.make} ${vehicle.model}`.toLowerCase();
    if (!hay.includes(String(query.pickupLocation).toLowerCase()) && vehicle.city.toLowerCase() !== 'delhi') {
      return false;
    }
  }
  return true;
}

export const vehiclesService = {
  featured() {
    return [...store.vehicles.values()]
      .filter((v) => v.isActive && v.isAvailable && v.verificationStatus === 'APPROVED')
      .map(toSummary);
  },

  search(query) {
    return [...store.vehicles.values()]
      .filter((v) => matches(v, query))
      .sort((a, b) => a.basePricePaise - b.basePricePaise)
      .slice(0, 50)
      .map(toSummary);
  },

  byId(id) {
    const vehicle = store.vehicles.get(id);
    if (!vehicle) throw new AppError('NOT_FOUND', 'Vehicle not found.', HttpStatus.NOT_FOUND);
    return toDetails(vehicle);
  },

  searchFromRequest(req) {
    const q = { ...req.query, ...req.body };
    return this.search({
      pickupLocation: pick(q, 'pickupLocation', 'pickup_location'),
      occasionId: pick(q, 'occasionId', 'occasion_id'),
      vehicleCategories: pick(q, 'vehicleCategories', 'vehicle_categories'),
      minModelYear: pick(q, 'minModelYear', 'min_model_year'),
      maxModelYear: pick(q, 'maxModelYear', 'max_model_year'),
      minPriceCents: pick(q, 'minPriceCents', 'min_price_cents'),
      maxPriceCents: pick(q, 'maxPriceCents', 'max_price_cents'),
      transmission: pick(q, 'transmission'),
      minRating: pick(q, 'minRating', 'min_rating'),
      verifiedChauffeurOnly: pick(q, 'verifiedChauffeurOnly', 'verified_chauffeur_only'),
      verifiedVehicleOnly: pick(q, 'verifiedVehicleOnly', 'verified_vehicle_only'),
      availableNow: pick(q, 'availableNow', 'available_now'),
      passengerCount: pick(q, 'passengerCount', 'passenger_count'),
      city: pick(q, 'city'),
    });
  },
};
