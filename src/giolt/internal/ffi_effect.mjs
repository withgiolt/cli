// Wraps a Promise held as a value, so Effect(Effect(a)) does not collapse
// into Effect(a) the way nested Promises do.
class Layer {
  constructor(promise) {
    this.promise = promise;
  }
}

function wrap(value) {
  return value instanceof Promise ? new Layer(value) : value;
}

function unwrap(value) {
  return value instanceof Layer ? value.promise : value;
}

export function resolve(value) {
  return Promise.resolve(wrap(value));
}

export function map(effect, next) {
  return effect.then((value) => wrap(next(unwrap(value))));
}

export function await_effect(effect, next) {
  return effect.then((value) => next(unwrap(value)));
}
