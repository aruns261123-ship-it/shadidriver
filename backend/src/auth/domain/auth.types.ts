import { Role } from './roles';

export interface AuthenticatedUser {
  userId: string;
  role: Role;
  phoneNumber: string;
  accountStatus: string;
}

export interface AccessTokenPayload {
  sub: string;
  role: Role;
  phone: string;
  iss: string;
  iat?: number;
  exp?: number;
}

export interface TokenPair {
  accessToken: string;
  refreshToken: string;
  accessTokenExpiresIn: number;
}
