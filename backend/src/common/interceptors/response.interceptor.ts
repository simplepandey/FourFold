import { Injectable, NestInterceptor, ExecutionContext, CallHandler } from '@nestjs/common';
import { Observable } from 'rxjs';
import { map } from 'rxjs/operators';
import { ApiResponse } from '../interfaces/api-response.interface';

@Injectable()
export class ResponseInterceptor<T> implements NestInterceptor<T, ApiResponse<T>> {
  intercept(context: ExecutionContext, next: CallHandler): Observable<ApiResponse<T>> {
    return next.handle().pipe(
      map((data) => {
        // Pass through if already a formatted response (has success field)
        if (data && typeof data === 'object' && 'success' in data) {
          return data;
        }
        return {
          success: true,
          message: 'Request successful',
          data,
        };
      }),
    );
  }
}
