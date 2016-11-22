// Ember 2.0 removes buffered rendering, but we can still implement it ourselves.
// In the long term we'll want to remove this.

const Mixin = {
  __bufferTimeout: null,

  _customRender() {
    Ember.run.cancel(this.__bufferTimeout);
    if (!this.element || this.isDestroying || this.isDestroyed) { return; }

    const buffer = [];
    this.buildBuffer(buffer);
    this.element.innerHTML = buffer.join('');
  },

  rerenderBuffer() {
    Ember.run.scheduleOnce('render', this, this._customRender);
  }
};

export function bufferedRender(obj) {

  if (!obj.buildBuffer) {
    Ember.warn('Missing `buildBuffer` method');
    return obj;
  }

  const caller = { };

  // True in 1.13 or greater
  if (Ember.Helper) {
    caller.didRender = function() {
      this._super();
      this._customRender();
    };
  } else {
    caller.didInsertElement = function() {
      this._super();
      this._customRender();
    };
  }

  const triggers = obj.rerenderTriggers;
  if (triggers) {
    caller.init = function() {
      this._super();
      triggers.forEach(k => this.addObserver(k, this.rerenderBuffer));
    };
  }
  delete obj.rerenderTriggers;

  return Ember.Mixin.create(Mixin, caller, obj);
}
