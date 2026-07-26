import { BusinessError } from '@kit.BasicServicesKit';
import { connection } from '@kit.NetworkKit';
import { AppLogger } from '../logging/DiagnosticLogStore';

export type NetworkAvailabilityListener = (available: boolean) => void;

export interface NetworkAvailabilityProvider {
  isNetworkAvailable(): boolean;
}

export interface NetworkStatusMonitor extends NetworkAvailabilityProvider {
  start(listener: NetworkAvailabilityListener): void;

  stop(): void;
}

export class AlwaysAvailableNetworkProvider implements NetworkAvailabilityProvider {
  public isNetworkAvailable(): boolean {
    return true;
  }
}

export class SystemNetworkStatusMonitor implements NetworkStatusMonitor {
  private netConnection: connection.NetConnection | null = null;
  private listener: NetworkAvailabilityListener | null = null;
  private available: boolean = true;

  public constructor() {
    this.available = this.readSystemAvailability();
  }

  public isNetworkAvailable(): boolean {
    return this.available;
  }

  public start(listener: NetworkAvailabilityListener): void {
    this.listener = listener;
    this.available = this.readSystemAvailability();
    listener(this.available);
    if (this.netConnection !== null) {
      return;
    }

    try {
      const netConnection: connection.NetConnection = connection.createNetConnection();
      this.netConnection = netConnection;
      netConnection.on('netAvailable', (): void => {
        if (this.netConnection === netConnection) {
          this.publish(true);
        }
      });
      netConnection.on('netLost', (): void => {
        if (this.netConnection === netConnection) {
          this.publish(this.readSystemAvailability());
        }
      });
      netConnection.on('netUnavailable', (): void => {
        if (this.netConnection === netConnection) {
          this.publish(false);
        }
      });
      netConnection.register((error: BusinessError): void => {
        if (error) {
          AppLogger.warning('NetworkStatus', `Network listener registration failed with code ${error.code}`);
          if (this.netConnection === netConnection) {
            this.netConnection = null;
          }
        }
      });
    } catch (error) {
      AppLogger.warning('NetworkStatus', `Network listener unavailable: ${JSON.stringify(error)}`);
      this.netConnection = null;
    }
  }

  public stop(): void {
    const netConnection: connection.NetConnection | null = this.netConnection;
    this.netConnection = null;
    this.listener = null;
    if (netConnection === null) {
      return;
    }
    try {
      netConnection.unregister((error: BusinessError): void => {
        if (error) {
          AppLogger.warning('NetworkStatus', `Network listener cleanup failed with code ${error.code}`);
        }
      });
    } catch (error) {
      AppLogger.warning('NetworkStatus', `Network listener cleanup failed: ${JSON.stringify(error)}`);
    }
  }

  private readSystemAvailability(): boolean {
    try {
      return connection.hasDefaultNetSync();
    } catch (error) {
      AppLogger.warning('NetworkStatus', `Default network query failed: ${JSON.stringify(error)}`);
      return true;
    }
  }

  private publish(available: boolean): void {
    if (this.available === available) {
      return;
    }
    this.available = available;
    AppLogger.info('NetworkStatus', available ? 'Default network available' : 'Default network unavailable');
    this.listener?.(available);
  }
}
