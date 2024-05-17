/**
 * Runs `callback` shortly after the next browser Frame is produced.
 * ref: https://webperf.tips/tip/measuring-paint-time
 */
export default function runAfterFramePaint(callback) {
  // Queue a "before Render Steps" callback via requestAnimationFrame.
  requestAnimationFrame(() => {
    // MessageChannel is one of the highest priority task queues
    // which will be executed after the frame has painted.
    const messageChannel = new MessageChannel();

    // Setup the callback to run in a Task
    messageChannel.port1.onmessage = callback;

    // Queue the Task on the Task Queue
    messageChannel.port2.postMessage(undefined);
  });
}
