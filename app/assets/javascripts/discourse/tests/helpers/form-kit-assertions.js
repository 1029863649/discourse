import { capitalize } from "@ember/string";
import QUnit from "qunit";
import { query } from "discourse/tests/helpers/qunit-helpers";

class FieldHelper {
  constructor(element, context) {
    this.element = element;
    this.context = context;
  }

  get value() {
    switch (this.element.dataset.controlType) {
      case "image": {
        return this.element
          .querySelector(".form-kit__control-image a.lightbox")
          .getAttribute("href");
      }
      case "radio-group": {
        return this.element.querySelector(".form-kit__control-radio:checked")
          ?.value;
      }
      case "input-number":
      case "input-text":
        return this.element.querySelector(".form-kit__control-input").value;
      case "icon": {
        return this.element.querySelector(
          ".form-kit__control-icon .select-kit-header"
        )?.dataset?.value;
      }
      case "question": {
        return (
          this.element.querySelector(".form-kit__control-radio:checked")
            ?.value === "true"
        );
      }
      case "toggle": {
        return (
          this.element.querySelector(".form-kit__control-toggle")
            .ariaChecked === "true"
        );
      }
      case "text": {
        return this.element.querySelector(".form-kit__control-textarea").value;
      }
      case "code": {
        return this.element.querySelector(
          ".form-kit__control-code .ace_text-input"
        ).value;
      }
      case "composer": {
        return this.element.querySelector(
          ".form-kit__control-composer .d-editor-input"
        ).value;
      }
      case "select": {
        return this.element.querySelector(".form-kit__control-select").value;
      }
      case "menu": {
        return this.element.querySelector(".form-kit__control-menu").dataset
          .value;
      }
      case "checkbox": {
        return this.element.querySelector(".form-kit__control-checkbox")
          .checked;
      }
    }
  }

  get isDisabled() {
    return this.element.dataset.disabled === "";
  }

  hasError(error, message) {
    this.context
      .dom(this.element.querySelector(".form-kit__errors"))
      .includesText(error, message);
  }

  hasNoError(message) {
    this.context
      .dom(this.element.querySelector(".form-kit__errors"))
      .doesNotExist(message);
  }
}

class FormHelper {
  constructor(selector, context) {
    this.context = context;
    if (selector instanceof HTMLElement) {
      this.element = selector;
    } else {
      this.element = query(selector);
    }
  }

  hasErrors(fields) {
    Object.keys(fields).forEach((name) => {
      const message = fields[name];
      this.context
        .dom(this.element.querySelector(".form-kit__errors-summary-list"))
        .includesText(`${capitalize(name)}: ${message}`);
    });
  }

  field(name) {
    return new FieldHelper(
      query(`.form-kit__field[data-name="${name}"]`, this.element),
      this.context
    );
  }
}

export function setupFormKitAssertions() {
  QUnit.assert.form = function (selector = "form") {
    const form = new FormHelper(selector, this);
    return {
      hasErrors: (fields) => {
        form.hasErrors(fields);
      },
      field: (name) => {
        const field = form.field(name);

        return {
          isDisabled: (message) => {
            this.ok(field.disabled, message);
          },
          hasError: (message) => {
            field.hasError(message);
          },
          hasNoError: (message) => {
            field.hasNoError(message);
          },
          hasValue: (value, message) => {
            this.deepEqual(field.value, value, message);
          },
        };
      },
    };
  };
}
