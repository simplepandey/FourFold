import { Injectable, OnModuleInit, OnModuleDestroy, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import * as mqtt from 'mqtt';

@Injectable()
export class MqttService implements OnModuleInit, OnModuleDestroy {
  private readonly logger = new Logger(MqttService.name);
  private client: mqtt.MqttClient;

  constructor(private readonly configService: ConfigService) {}

  onModuleInit() {
    const host = this.configService.get<string>('mqtt.host');
    const port = this.configService.get<number>('mqtt.port');
    const username = this.configService.get<string>('mqtt.username');
    const password = this.configService.get<string>('mqtt.password');
    const topic = this.configService.get<string>('mqtt.telemetryTopic');

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
      this.client.subscribe(topic, (err) => {
        if (err) {
          this.logger.error(`Failed to subscribe to topic '${topic}': ${err.message}`);
        } else {
          this.logger.log(`Subscribed to topic '${topic}'`);
        }
      });
    });

    this.client.on('message', (topic, payload) => {
      this.handleMessage(topic, payload);
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

  private handleMessage(topic: string, payload: Buffer) {
    // Expected topic shape: societies/{societyCode}/motors/{motorId}/telemetry
    const segments = topic.split('/');
    const societyCode = segments[1];
    const motorId = segments[3];

    let data: unknown = payload.toString();
    try {
      data = JSON.parse(payload.toString());
    } catch {
      // payload wasn't JSON — keep it as a raw string
    }

    this.logger.log(
      `Telemetry received — society=${societyCode} motor=${motorId} topic=${topic} payload=${JSON.stringify(data)}`,
    );
  }

  onModuleDestroy() {
    if (this.client) {
      this.client.end();
      this.logger.log('MQTT client disconnected');
    }
  }
}