import { CanActivate, ExecutionContext, Injectable, UnauthorizedException } from '@nestjs/common';
import { Request } from 'express';

@Injectable()
export class BasicAuthGuard implements CanActivate {
  canActivate(context: ExecutionContext): boolean {
    const request = context.switchToHttp().getRequest<Request>();
    const authHeader = request.headers['authorization'];

    if (!authHeader || !authHeader.startsWith('Basic ')) {
      throw new UnauthorizedException('Basic authentication required');
    }

    const base64 = authHeader.slice(6);
    const decoded = Buffer.from(base64, 'base64').toString('utf8');
    const [username, ...rest] = decoded.split(':');
    const password = rest.join(':');

    const expectedUsername = process.env.DEVICE_BASIC_AUTH_USERNAME ?? 'fourfold';
    const expectedPassword = process.env.DEVICE_BASIC_AUTH_PASSWORD ?? 'fourfold';

    if (username !== expectedUsername || password !== expectedPassword) {
      throw new UnauthorizedException('Invalid credentials');
    }

    return true;
  }
}
