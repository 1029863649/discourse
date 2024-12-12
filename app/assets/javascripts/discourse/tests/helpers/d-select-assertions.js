import QUnit from "qunit";
import { query } from "discourse/tests/helpers/qunit-helpers";

class DSelect {
  constructor(selector, context) {
    this.context = context;
    if (selector instanceof HTMLElement) {
      this.element = selector;
    } else {
      this.element = query(selector);
    }
  }

  hasOption({ value, label }, assertionMessage) {
    const option = this.element.querySelector(
      `.d-select__option[value="${value}"]`
    );

    this.context.dom(option).exists(assertionMessage);
    this.context.dom(option).hasText(label, assertionMessage);
  }

  hasNoOption(value, assertionMessage) {
    const option = this.element.querySelector(
      `.d-select__option[value="${value}"]`
    );

    this.context.dom(option).doesNotExist(assertionMessage);
  }

  hasSelectedOption({ value, label }, assertionMessage) {
    this.context
      .dom(this.element.options[this.element.selectedIndex])
      .hasText(label, assertionMessage);

    this.context.dom(this.element).hasValue(value, assertionMessage);
  }

  hasNoSelectedOption({ value, label }, assertionMessage) {
    this.context
      .dom(this.element.options[this.element.selectedIndex])
      .hasNoText(label, assertionMessage);

    this.context.dom(this.element).hasNoValue(value, assertionMessage);
  }
}

export function setupDSelectAssertions() {
  QUnit.assert.dselect = function (selector = ".d-select") {
    return new DSelect(selector, this);
  };
}
