import { supabase } from './supabase';

export class NetworkHelper {
    /**
     * Helper for retrying network operations with exponential backoff
     * @param operation Function to retry
     * @param maxRetries Maximum number of attempts
     * @param initialDelay Initial wait time in ms
     * @param backoffFactor Multiplier for delay on each retry
     */
    static async retry<T>(
        operation: () => Promise<T>,
        maxRetries: number = 3,
        initialDelay: number = 1000,
        backoffFactor: number = 2
    ): Promise<T> {
        let retries = 0;
        let currentDelay = initialDelay;

        while (true) {
            try {
                return await operation();
            } catch (error) {
                if (retries >= maxRetries) {
                    throw new Error(`Max retries reached: ${(error as Error).message}`);
                }

                await new Promise((resolve) => setTimeout(resolve, currentDelay));

                retries += 1;
                currentDelay *= backoffFactor;
            }
        }
    }
}
