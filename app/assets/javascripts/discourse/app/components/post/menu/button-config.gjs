import { helperContext } from "discourse-common/lib/helpers";
import { bind } from "discourse-common/utils/decorators";

export default class PostMenuButtonConfig {
  #Component;
  #apiAdded;
  #key;
  #owner;
  #position;
  #replacementMap;

  constructor({ key, Component, apiAdded, owner, position, replacementMap }) {
    this.#Component = Component;
    this.#apiAdded = apiAdded;
    this.#key = key;
    this.#owner = owner;
    this.#position = position;
    this.#replacementMap = replacementMap;
  }

  get Component() {
    return this.#Component;
  }

  get apiAdded() {
    return this.#apiAdded;
  }

  @bind
  alwaysShow(args) {
    return this.#staticPropertyWithReplacementFallback({
      property: "alwaysShow",
      args,
      defaultValue: false,
    });
  }

  @bind
  delegateShouldRenderToTemplate(args) {
    return this.#staticPropertyWithReplacementFallback({
      property: "delegateShouldRenderToTemplate",
      args,
      defaultValue: false,
    });
  }

  @bind
  extraControls(args) {
    return this.#staticPropertyWithReplacementFallback({
      property: "extraControls",
      args,
      defaultValue: false,
    });
  }

  get key() {
    return this.#key;
  }

  get position() {
    return this.#position;
  }

  @bind
  shouldRender(args) {
    return this.#staticPropertyWithReplacementFallback({
      property: "shouldRender",
      args,
      defaultValue: true,
    });
  }

  @bind
  showLabel(args) {
    return this.#staticPropertyWithReplacementFallback({
      property: "showLabel",
      args,
      defaultValue: false,
    });
  }

  #staticPropertyWithReplacementFallback(
    { klass = this.#Component, property, args, defaultValue },
    _usedKlasses = new WeakSet()
  ) {
    // fallback to the default value if the klass is not defined, i.e., the button was not replaced
    // or if the klass was already used to avoid an infinite recursion in case of a circular reference
    if (!klass || _usedKlasses.has(klass)) {
      return defaultValue;
    }

    let value;
    if (typeof klass[property] === "function") {
      value = klass[property](args, helperContext(), this.#owner);
    } else {
      value = klass[property];
    }

    return (
      value ??
      this.#staticPropertyWithReplacementFallback(
        {
          klass: this.#replacementMap.get(klass) || null, // passing null explicitly to avoid using the default value
          property,
          args,
          defaultValue,
        },
        _usedKlasses.add(klass)
      )
    );
  }
}
