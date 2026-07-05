export interface JwtPayload {
  sub: string;
  phoneNumber: string;
  type: 'user' | 'society';
  iat?: number;
  exp?: number;
}
