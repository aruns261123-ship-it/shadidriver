import { AppError, HttpStatus } from '../errors.js';
import { store } from '../store/memory-store.js';
import { newId } from '../utils/crypto.js';
import { pick } from '../utils/body.js';
import { isAdminRole, ROLES } from '../domain/roles.js';

function customerRecord(user) {
  let extra = store.customers.get(user.id);
  if (!extra) {
    extra = {
      id: user.id,
      city: '',
      preferredLanguage: 'en',
      emergencyContactName: null,
      emergencyContactPhone: null,
      weddingPreferences: null,
      profilePhotoUrl: null,
    };
    store.customers.set(user.id, extra);
  }
  return extra;
}

export const profilesService = {
  getCustomer(user) {
    const account = store.users.get(user.id);
    const extra = customerRecord(account);
    return {
      id: account.id,
      fullName: account.fullName,
      phone: account.phoneNumber,
      email: account.email,
      city: extra.city,
      preferredLanguage: extra.preferredLanguage,
      profilePhotoUrl: extra.profilePhotoUrl,
      emergencyContactName: extra.emergencyContactName,
      emergencyContactPhone: extra.emergencyContactPhone,
      weddingPreferences: extra.weddingPreferences,
      createdAt: account.createdAt,
      updatedAt: extra.updatedAt || account.createdAt,
    };
  },

  updateCustomer(user, body) {
    const account = store.users.get(user.id);
    const extra = customerRecord(account);
    if (body.fullName) account.fullName = body.fullName;
    if (body.phone) account.phoneNumber = body.phone;
    if (body.email !== undefined) account.email = body.email;
    extra.city = pick(body, 'city') ?? extra.city;
    extra.preferredLanguage = pick(body, 'preferredLanguage') ?? extra.preferredLanguage;
    extra.profilePhotoUrl = pick(body, 'profilePhotoUrl') ?? extra.profilePhotoUrl;
    extra.emergencyContactName = pick(body, 'emergencyContactName') ?? extra.emergencyContactName;
    extra.emergencyContactPhone = pick(body, 'emergencyContactPhone') ?? extra.emergencyContactPhone;
    extra.weddingPreferences = pick(body, 'weddingPreferences') ?? extra.weddingPreferences;
    extra.updatedAt = new Date().toISOString();
    if (account.accountStatus === 'profileIncomplete' && account.fullName && extra.city) {
      account.accountStatus = 'active';
    }
    return this.getCustomer(user);
  },

  getAdmin(user) {
    if (!isAdminRole(user.role)) {
      throw new AppError('ROLE_FORBIDDEN', 'Admin profile required.', HttpStatus.FORBIDDEN);
    }
    const account = store.users.get(user.id);
    const extra = store.admins.get(user.id) || { department: 'Operations', authorizationLevel: 'OPS', photoUrl: null };
    return {
      id: account.id,
      fullName: account.fullName,
      email: account.email,
      phone: account.phoneNumber,
      photoUrl: extra.photoUrl,
      role: account.role,
      department: extra.department,
      authorizationLevel: extra.authorizationLevel,
      createdAt: account.createdAt,
      updatedAt: extra.updatedAt || account.createdAt,
    };
  },

  updateAdmin(user, body) {
    const profile = this.getAdmin(user);
    const account = store.users.get(user.id);
    const extra = store.admins.get(user.id) || { department: profile.department, authorizationLevel: profile.authorizationLevel };
    if (body.fullName) account.fullName = body.fullName;
    if (body.phone) account.phoneNumber = body.phone;
    extra.photoUrl = pick(body, 'photoUrl') ?? extra.photoUrl;
    extra.updatedAt = new Date().toISOString();
    store.admins.set(user.id, extra);
    return this.getAdmin(user);
  },

  listAddresses(user) {
    return [...store.addresses.values()].filter((a) => a.customerId === user.id);
  },

  createAddress(user, body) {
    const address = {
      id: newId(),
      customerId: user.id,
      label: pick(body, 'label') || 'Other',
      address: pick(body, 'address'),
      landmark: pick(body, 'landmark') || null,
      type: pick(body, 'type') || 'other',
      isDefault: Boolean(pick(body, 'isDefault')),
    };
    if (!address.address) throw new AppError('VALIDATION_ERROR', 'Address is required.', HttpStatus.BAD_REQUEST);
    if (address.isDefault) {
      for (const a of store.addresses.values()) {
        if (a.customerId === user.id) a.isDefault = false;
      }
    }
    store.addresses.set(address.id, address);
    return address;
  },

  deleteAddress(user, id) {
    const address = store.addresses.get(id);
    if (!address || address.customerId !== user.id) {
      throw new AppError('NOT_FOUND', 'Address not found.', HttpStatus.NOT_FOUND);
    }
    store.addresses.delete(id);
    return { deleted: true };
  },
};

void ROLES;
