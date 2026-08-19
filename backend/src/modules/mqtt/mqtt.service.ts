import { Injectable, OnModuleInit, OnModuleDestroy, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import * as mqtt from 'mqtt';
import { TopicPatternRepository } from './topic-pattern.repository';

const DEFAULT_SUBSCRIBE_PATTERNS = ['motors/+/telemetry', 'motors/+/alert', 'motors/+/heartbeat'];

export type MqttMessageHandler = (topic: string, payload: string) => Promise<void>;

@Injectable()
export class MqttService implements OnModuleInit, OnModuleDestroy {
  private readonly logger = new Logger(MqttService.name);
  private client: mqtt.MqttClient;
  // Keyed by the topic's last segment (telemetry/alert/heartbeat/...) — lets
  // any module register interest without MqttModule needing to import that
  // module directly (which is what caused a circular dependency back when
  // this imported TelemetryModule to call it directly).
  private readonly handlers = new Map<string, MqttMessageHandler>();

  constructor(
    private readonly configService: ConfigService,
    private readonly topicPatternRepository: TopicPatternRepository,
  ) {}

  registerHandler(topicSuffix: string, handler: MqttMessageHandler): void {
    this.handlers.set(topicSuffix, handler);
  }

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
    const handler = suffix ? this.handlers.get(suffix) : undefined;

    if (!handler) return;

    try {
      await handler(topic, raw);
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
