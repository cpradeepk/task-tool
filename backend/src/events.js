let ioInstance = null;

export function registerIO(io) {
  ioInstance = io;
}

export function emitEvent(event, payload) {
  if (ioInstance) ioInstance.emit(event, payload);
}

export function emitTaskCreated(task) {
  emitEvent('task.created', task);
}

export function emitTaskUpdated(task) {
  emitEvent('task.updated', task);
}

export function emitMessageCreated(message) {
  emitEvent('chat.message', message);
}

