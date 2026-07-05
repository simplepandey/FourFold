export function normalizePhoneNumber(phoneNumber: string): string {
  return phoneNumber.replace(/\s+/g, '').trim();
}

export function isIndianPhoneNumber(phoneNumber: string): boolean {
  return /^\+91[6-9]\d{9}$/.test(phoneNumber);
}

export function isValidE164(phoneNumber: string): boolean {
  return /^\+[1-9]\d{1,14}$/.test(phoneNumber);
}
