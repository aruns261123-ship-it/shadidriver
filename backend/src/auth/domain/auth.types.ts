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
  /** Injected by the JWT library via the sign options `issuer` (TokenService). */
  iss?: string;
  iat?: number;
  exp?: number;
}

export interface TokenPair {
  accessToken: string;
  refreshToken: string;
  accessTokenExpiresIn: number;
}
