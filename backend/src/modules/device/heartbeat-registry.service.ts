import { Injectable } from '@nestjs/common';

export interface PendingHeartbeat {
  productCode: string;
  resolve: () => void;
}

/**
 * Correlates an outbound SEND_HEARTBEAT command (module-status module) with
 * its inbound MQTT reply — so a heartbeat message is only trusted if it's
 * actually answering a request we just sent, not some stray/unsolicited
 * message on the topic.
 *
 * consume() does NOT call resolve() itself — it hands back the callback so
 * the caller can invoke it only once their own DB write is actually done.
 * Resolving synchronously inside consume() was tried first and had a real
 * race: it woke up the GET request's `await settled` before processHeartbeat's
 * `upsert()` had finished, so the subsequent status read could beat the
 * write and return stale data.
 */
@Injectable()
export class HeartbeatRegistryService {
  private readonly pending = new Map<string, PendingHeartbeat>();

  register(cmdId: string, productCode: string, resolve: () => void): void {
    this.pending.set(cmdId, { productCode, resolve });
  }

  /** Removes and returns the pending entry, or null if already consumed/unknown. */
  consume(cmdId: string): PendingHeartbeat | null {
    const entry = this.pending.get(cmdId);
    if (!entry) return null;
    this.pending.delete(cmdId);
    return entry;
  }
}
