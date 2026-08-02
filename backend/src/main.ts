import { NestFactory, Reflector } from '@nestjs/core';
import { ValidationPipe, VersioningType, Logger } from '@nestjs/common';
import { SwaggerModule, DocumentBuilder } from '@nestjs/swagger';
import { ConfigService } from '@nestjs/config';
import { AppModule } from './app.module';
import { HttpExceptionFilter } from './common/filters/http-exception.filter';
import { LoggingInterceptor } from './common/interceptors/logging.interceptor';
import { ResponseInterceptor } from './common/interceptors/response.interceptor';
import { JwtAuthGuard } from './common/guards/jwt-auth.guard';

async function bootstrap() {
  const logger = new Logger('Bootstrap');
  const app = await NestFactory.create(AppModule);

  const configService = app.get(ConfigService);
  const port = configService.get<number>('port', 3000);
  const nodeEnv = configService.get<string>('nodeEnv', 'development');

  // CORS
  app.enableCors({
    origin: '*',
    methods: 'GET,HEAD,PUT,PATCH,POST,DELETE,OPTIONS',
    preflightContinue: false,
    optionsSuccessStatus: 204,
  });

  // Global prefix
  app.setGlobalPrefix('api');

  // URI versioning — routes become /api/v1/...
  app.enableVersioning({
    type: VersioningType.URI,
    prefix: 'v',
    defaultVersion: '1',
  });

  // Global validation pipe — strips unknown fields and auto-transforms types
  app.useGlobalPipes(
    new ValidationPipe({
      whitelist: true,
      forbidNonWhitelisted: true,
      transform: true,
      transformOptions: { enableImplicitConversion: true },
    }),
  );

  // Global exception filter
  app.useGlobalFilters(new HttpExceptionFilter());

  // Global interceptors: logging + unified response envelope
  app.useGlobalInterceptors(new LoggingInterceptor(), new ResponseInterceptor());

  // Global JWT guard — use @Public() decorator to opt out individual routes
  const reflector = app.get(Reflector);
  app.useGlobalGuards(new JwtAuthGuard(reflector));

  // Swagger
  {
    const swaggerConfig = new DocumentBuilder()
      .setTitle('FourFold API')
      .setDescription(
        '## FourFold Backend API\n\n' +
          '### How to authenticate\n' +
          '1. Call **POST /api/v1/auth/send-otp** with your phone number\n' +
          '2. Call **POST /api/v1/auth/verify-otp** with the OTP — copy the `token` from the response\n' +
          '3. Click the **Authorize 🔒** button at the top right\n' +
          '4. Paste the token in the **Value** field and click **Authorize**\n' +
          '5. All protected endpoints will now send the token automatically',
      )
      .setVersion('1.0')
      .addBearerAuth(
        {
          type: 'http',
          scheme: 'bearer',
          bearerFormat: 'JWT',
          name: 'JWT',
          description:
            'Paste the JWT token from the verify-otp response (without the "Bearer" prefix)',
          in: 'header',
        },
        'JWT-auth',
      )
      .addBasicAuth(
        {
          type: 'http',
          scheme: 'basic',
          description: 'Device Basic Auth — Username: user-fourfold / Password: password-fourfold',
        },
        'basic-auth',
      )
      .addTag('Auth', 'OTP-based authentication — no token required')
      .addTag('Users', 'User profile — requires JWT token')
      .addTag('Societies', 'Society registration — requires JWT token')
      .build();

    const document = SwaggerModule.createDocument(app, swaggerConfig);
    SwaggerModule.setup('api/docs', app, document, {
      swaggerOptions: {
        persistAuthorization: true,
        displayRequestDuration: true,
        filter: true,
        tryItOutEnabled: true,
      },
      customCss: `
        .swagger-ui .dialog-ux .modal-ux,
        .swagger-ui .dialog-ux .modal-ux-content,
        .swagger-ui .dialog-ux .modal-ux-header {
          background: #fff !important;
          color: #3b4151 !important;
        }
        .swagger-ui .dialog-ux .modal-ux-header h3,
        .swagger-ui .dialog-ux .modal-ux-content h4,
        .swagger-ui .dialog-ux .modal-ux-content p,
        .swagger-ui .dialog-ux .modal-ux-content label {
          color: #3b4151 !important;
        }
        .swagger-ui .dialog-ux .modal-ux-content input[type=text],
        .swagger-ui .dialog-ux .modal-ux-content input[type=password] {
          background: #fff !important;
          color: #3b4151 !important;
          border: 1px solid #d9d9d9 !important;
        }
        .swagger-ui .auth-container .scopes h2,
        .swagger-ui .auth-container .auth-btn-wrapper p {
          color: #3b4151 !important;
        }
      `,
    });

    logger.log(`Swagger UI: http://localhost:${port}/api/docs`);
  }

  await app.listen(port);
  logger.log(`Server running on http://localhost:${port}`);
  logger.log(`Environment: ${nodeEnv}`);
}

bootstrap();
