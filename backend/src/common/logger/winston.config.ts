import * as fs from 'fs';
import * as path from 'path';
import * as winston from 'winston';
import 'winston-daily-rotate-file';
import { utilities as nestWinstonUtilities } from 'nest-winston';

export const LOGS_DIR = path.join(process.cwd(), 'logs');

if (!fs.existsSync(LOGS_DIR)) {
  fs.mkdirSync(LOGS_DIR, { recursive: true });
}

const fileFormat = winston.format.combine(
  winston.format.timestamp(),
  winston.format.json(),
);

// One file per day (app-2026-08-05.log, error-2026-08-05.log, ...).
// Retention is handled by a server-side cron (see deploy.md), not here —
// deliberately no `maxFiles` so this config alone never deletes anything.
export const winstonLoggerOptions: winston.LoggerOptions = {
  transports: [
    new winston.transports.Console({
      format: winston.format.combine(
        winston.format.timestamp(),
        nestWinstonUtilities.format.nestLike('FourFold', {
          colors: true,
          prettyPrint: true,
        }),
      ),
    }),
    new winston.transports.DailyRotateFile({
      dirname: LOGS_DIR,
      filename: 'app-%DATE%.log',
      datePattern: 'YYYY-MM-DD',
      maxSize: '20m',
      format: fileFormat,
    }),
    new winston.transports.DailyRotateFile({
      dirname: LOGS_DIR,
      filename: 'error-%DATE%.log',
      datePattern: 'YYYY-MM-DD',
      level: 'error',
      maxSize: '20m',
      format: fileFormat,
    }),
  ],
};
