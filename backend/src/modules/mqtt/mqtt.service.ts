import { Injectable, OnModuleInit, OnModuleDestroy, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import * as mqtt from 'mqtt';
import { TelemetryService } from '../telemetry/telemetry.service';
import { TopicPatternRepository } from './topic-pattern.repository';

const DEFAULT_SUBSCRIBE_PATTERNS = ['motors/+/telemetry', 'motors/+/alert'];

@Injectable()
export class MqttService implements OnModuleInit, OnModuleDestroy {
  private readonly logger = new Logger(MqttService.name);
  private client: mqtt.MqttClient;

  constructor(
    private readonly configService: ConfigService,
    private readonly telemetryService: TelemetryService,
    private readonly topicPatternRepository: TopicPatternRepository,
  ) {}

  async onModuleInit(): Promise<void> {
    await this.topicPatternRepository.seedDefaults(DEFAULT_SUBSCRIBE_PATTERNS);
    const subscribeTopics = await this.topicPatternRepository.findAllPatterns();

    const host = this.configService.get<string>('mqtt.host');
    const port = this.configService.get<number>('mqtt.port');
    const username = this.configService.get<string>('mqtt.username');
    const password = this.configService.get<string>('mqtt.password');

    this.client = mqtt.connect({
      host,
      port,
      username,
      password,
      protocol: 'mqtt',
      reconnectPeriod: 5000,
    });

    this.client.on('connect', () => {
      this.logger.log(`Connected to MQTT broker at ${host}:${port}`);

      this.client.subscribe(subscribeTopics, (err) => {
        if (err) {
          this.logger.error(`Failed to subscribe: ${err.message}`);
        } else {
          this.logger.log(`Subscribed to: ${subscribeTopics.join(', ')}`);
        }
      });
    });

    this.client.on('message', (topic, payload) => {
      void this.handleMessage(topic, payload);
    });

    this.client.on('error', (err) => {
      this.logger.error(`MQTT client error: ${err.message}`);
    });

    this.client.on('reconnect', () => {
      this.logger.warn('Reconnecting to MQTT broker...');
    });

    this.client.on('close', () => {
      this.logger.warn('MQTT connection closed');
    });
  }

  private async handleMessage(topic: string, payload: Buffer): Promise<void> {
    const raw = payload.toString();
    const suffix = topic.split('/').pop();

    try {
      if (suffix === 'telemetry') {
        await this.telemetryService.processTelemetry(topic, raw);
      } else if (suffix === 'alert') {
        await this.telemetryService.processAlert(topic, raw);
      }
    } catch (err) {
      this.logger.error(`Error processing message on topic '${topic}': ${(err as Error).message}`);
    }
  }

  publish(topic: string, message: object | string): Promise<void> {
    return new Promise((resolve, reject) => {
      if (!this.client || !this.client.connected) {
        return reject(new Error('MQTT client is not connected'));
      }
      const p = typeof message === 'string' ? message : JSON.stringify(message);
      this.client.publish(topic, p, (err) => {
        if (err) {
          this.logger.error(`Failed to publish to '${topic}': ${err.message}`);
          reject(err);
        } else {
          this.logger.log(`Published to '${topic}': ${p}`);
          resolve();
        }
      });
    });
  }

  onModuleDestroy() {
    if (this.client) {
      this.client.end();
      this.logger.log('MQTT client disconnected');
    }
  }
}
