import { store } from '../store/memory-store.js';
import { pick } from '../utils/body.js';
import { quote } from './pricing.service.js';

export const catalogService = {
  categories() {
    return [...store.categories.values()]
      .filter((c) => c.isActive)
      .sort((a, b) => a.displayOrder - b.displayOrder)
      .map(({ id, name, description, iconUrl, assetPath, displayOrder }) => ({
        id,
        name,
        description,
        iconUrl,
        assetPath,
        displayOrder,
      }));
  },

  addons() {
    return [...store.addons.values()]
      .filter((a) => a.isActive)
      .map((a) => ({
        id: a.id,
        serviceCategoryId: a.serviceCategoryId,
        name: a.name,
        description: a.description,
        pricePaise: a.pricePaise,
        features: a.features,
        assetPath: a.assetPath,
        pricing: {
          basePriceCents: a.pricePaise,
          currencyCode: 'INR',
          billingUnit: 'PACKAGE',
          isStartingPrice: false,
        },
      }));
  },

  estimate(body) {
    const start = pick(body, 'eventStartTime', 'event_start_time', 'serviceStartDateTime');
    const end = pick(body, 'eventEndTime', 'event_end_time', 'serviceEndDateTime');
    return quote({
      serviceCategoryId: pick(body, 'serviceCategoryId', 'service_category_id'),
      vehicleClass: pick(body, 'vehicleClass', 'vehicle_class'),
      cityCode: pick(body, 'cityCode', 'city_code'),
      city: pick(body, 'city'),
      eventStartTime: start,
      eventEndTime: end,
      selectedAddonIds: pick(body, 'selectedAddonIds', 'selected_addon_ids') || [],
      routeDistanceKm: pick(body, 'routeDistanceKm', 'route_distance_km'),
    });
  },
};
