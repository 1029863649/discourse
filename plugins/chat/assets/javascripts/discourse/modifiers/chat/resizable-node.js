import Modifier from "ember-modifier";
import { registerDestructor } from "@ember/destroyable";
import { bind } from "discourse-common/utils/decorators";
import { throttle } from "@ember/runloop";

const MINIMUM_SIZE = 20;

export default class ResizableNode extends Modifier {
  element = null;
  resizerSelector = null;
  didResizeContainer = null;

  _originalWidth = 0;
  _originalHeight = 0;
  _originalX = 0;
  _originalY = 0;
  _originalMouseX = 0;
  _originalMouseY = 0;

  constructor(owner, args) {
    super(owner, args);
    registerDestructor(this, (instance) => instance.cleanup());
  }

  modify(element, [resizerSelector, didResizeContainer]) {
    this.resizerSelector = resizerSelector;
    this.element = element;
    this.didResizeContainer = didResizeContainer;

    this.element
      .querySelector(this.resizerSelector)
      ?.addEventListener("mousedown", this._startResize);
  }

  cleanup() {
    this.element
      .querySelector(this.resizerSelector)
      ?.removeEventListener("mousedown", this._startResize);
  }

  @bind
  _startResize(event) {
    event.preventDefault();

    this._originalWidth = parseFloat(
      getComputedStyle(this.element, null)
        .getPropertyValue("width")
        .replace("px", "")
    );
    this._originalHeight = parseFloat(
      getComputedStyle(this.element, null)
        .getPropertyValue("height")
        .replace("px", "")
    );
    this._originalX = this.element.getBoundingClientRect().left;
    this._originalY = this.element.getBoundingClientRect().top;
    this._originalMouseX = event.pageX;
    this._originalMouseY = event.pageY;

    window.addEventListener("mousemove", this._resize);
    window.addEventListener("mouseup", this._stopResize);
  }

  @bind
  _resize(event) {
    throttle(this, this._resizeThrottled, event, 24);
  }

  @bind
  _resizeThrottled(event) {
    const width = Math.ceil(
      this._originalWidth - (event.pageX - this._originalMouseX)
    );
    const height = Math.ceil(
      this._originalHeight - (event.pageY - this._originalMouseY)
    );

    const newStyle = {};

    if (width > MINIMUM_SIZE) {
      newStyle.width = width + "px";
      newStyle.left =
        Math.ceil(this._originalX + (event.pageX - this._originalMouseX)) +
        "px";
    }

    if (height > MINIMUM_SIZE) {
      newStyle.height = height + "px";
      newStyle.top =
        Math.ceil(this._originalY + (event.pageY - this._originalMouseY)) +
        "px";
    }

    Object.assign(this.element.style, newStyle);

    this.didResizeContainer?.(this.element, { width, height });
  }

  @bind
  _stopResize() {
    window.removeEventListener("mousemove", this._resize);
    window.removeEventListener("mouseup", this._stopResize);
  }
}
