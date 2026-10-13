import { useState } from "react";

// Runs an async action, telling whether one is running, for a button's loading state.
export function useAction<A extends unknown[], R>(
  action: (...args: A) => Promise<R>,
): { run: (...args: A) => Promise<R>; isRunning: boolean } {
  const [isRunning, setIsRunning] = useState(false);

  async function run(...args: A): Promise<R> {
    setIsRunning(true);
    try {
      return await action(...args);
    } finally {
      setIsRunning(false);
    }
  }

  return { run, isRunning };
}
