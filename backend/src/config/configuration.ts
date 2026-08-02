export default () => ({
  nodeEnv: process.env.NODE_ENV || 'development',
  port: parseInt(process.env.PORT, 10) || 3000,
  database: {
    url: process.env.DATABASE_URL,
  },
  jwt: {
    secret: process.env.JWT_SECRET || 'fallback-secret-change-in-production',
    expiresIn: process.env.JWT_EXPIRES_IN || '7d',
  },
  otp: {
    expiryMinutes: parseInt(process.env.OTP_EXPIRY_MINUTES, 10) || 5,
    length: parseInt(process.env.OTP_LENGTH, 10) || 6,
  },
  sms: {
    provider: process.env.SMS_PROVIDER || 'console',
    twilio: {
      accountSid: process.env.TWILIO_ACCOUNT_SID,
      authToken: process.env.TWILIO_AUTH_TOKEN,
      fromNumber: process.env.TWILIO_FROM_NUMBER,
    },
    msg91: {
      authKey: process.env.MSG91_AUTH_KEY,
      widgetAuthKey: process.env.MSG91_WIDGET_AUTH_KEY,
      senderId: process.env.MSG91_SENDER_ID,
      templateId: process.env.MSG91_TEMPLATE_ID,
    },
    awsSns: {
      region: process.env.AWS_REGION,
      accessKeyId: process.env.AWS_ACCESS_KEY_ID,
      secretAccessKey: process.env.AWS_SECRET_ACCESS_KEY,
    },
  },
  device: {
    basicAuth: {
      username: process.env.DEVICE_BASIC_AUTH_USERNAME || 'fourfold',
      password: process.env.DEVICE_BASIC_AUTH_PASSWORD || 'fourfold',
    },
  },
  mqtt: {
    host: process.env.MQTT_HOST || 'localhost',
    port: parseInt(process.env.MQTT_PORT, 10) || 1883,
    username: process.env.MQTT_USERNAME,
    password: process.env.MQTT_PASSWORD,
    telemetryTopic: process.env.MQTT_TELEMETRY_TOPIC || 'motors/+/telemetry',
  },
});
