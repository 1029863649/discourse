import Component from "@glimmer/component";
import { cached, tracked } from "@glimmer/tracking";
import { hash } from "@ember/helper";
import { on } from "@ember/modifier";
import { action, set } from "@ember/object";
import { next } from "@ember/runloop";
import { service } from "@ember/service";
import { TrackedObject } from "@ember-compat/tracked-built-ins";
import { modifier as modifierFn } from "ember-modifier";
import DButton from "discourse/components/d-button";
import FKAlert from "discourse/form-kit/components/alert";
import FKContainer from "discourse/form-kit/components/container";
import FKControlConditionalContent from "discourse/form-kit/components/control/conditional-content";
import FKControlInputGroup from "discourse/form-kit/components/control/input-group";
import FKErrorsSummary from "discourse/form-kit/components/errors-summary";
import FKField from "discourse/form-kit/components/field";
import Row from "discourse/form-kit/components/row";
import FKSection from "discourse/form-kit/components/section";
import { VALIDATION_TYPES } from "discourse/form-kit/lib/constants";
import FieldData from "discourse/form-kit/lib/field-data";
import I18n from "I18n";

export default class Form extends Component {
  @service dialog;
  @service router;

  @tracked fieldsWithErrors;
  @tracked isLoading = false;

  fields = new Map();

  isDirtyForm = false;

  onValidation = modifierFn((element, [eventName, handler]) => {
    if (eventName) {
      element.addEventListener(eventName, handler);

      return () => element.removeEventListener(eventName, handler);
    }
  });

  transientData = new TrackedObject({});

  constructor() {
    super(...arguments);

    this.args.onRegisterApi?.({
      set: this.set,
      submit: this.onSubmit,
      reset: this.onReset,
    });

    this.router.on("routeWillChange", this.checkIsDirty);
  }

  willDestroy() {
    super.willDestroy();

    this.router.off("routeWillChange", this.checkIsDirty);
  }

  get mutable() {
    return this.args.mutable ?? false;
  }

  @action
  checkIsDirty(transition) {
    if (
      this.isDirtyForm &&
      !transition.isAborted &&
      !transition.queryParamsOnly
    ) {
      transition.abort();

      this.dialog.yesNoConfirm({
        message: I18n.t("form_kit.dirty_form"),
        didConfirm: () => {
          this.isDirtyForm = false;
          this.onReset();
          transition.retry();
        },
      });
    }
  }

  @cached
  get effectiveData() {
    const obj = this.args.data ?? {};

    if (this.mutable) {
      return obj;
    }

    const { transientData } = this;

    return new Proxy(obj, {
      get(target, prop) {
        return prop in transientData
          ? transientData[prop]
          : Reflect.get(target, prop);
      },

      set(target, property, value) {
        return Reflect.set(transientData, property, value);
      },

      has(target, prop) {
        return prop in transientData ? true : Reflect.has(target, prop);
      },

      getOwnPropertyDescriptor(target, prop) {
        return Reflect.getOwnPropertyDescriptor(
          prop in transientData ? transientData : target,
          prop
        );
      },

      ownKeys(target) {
        return (
          [...Reflect.ownKeys(target), ...Reflect.ownKeys(transientData)]
            // return only unique values
            .filter((value, index, array) => array.indexOf(value) === index)
        );
      },

      deleteProperty(target, prop) {
        if (prop in transientData) {
          delete transientData[prop];
        }

        return true;
      },
    });
  }

  get validateOn() {
    return this.args.validateOn ?? VALIDATION_TYPES.submit;
  }

  get fieldValidationEvent() {
    const { validateOn } = this;

    if (validateOn === VALIDATION_TYPES.submit) {
      return undefined;
    }

    return validateOn;
  }

  get hasErrors() {
    return Array.from(this.fields.values()).some((field) => field.hasErrors);
  }

  get errors() {
    const visibleErrors = {};
    for (const [name, field] of this.fields) {
      visibleErrors[name] = field.visibleErrors;
    }
    return visibleErrors;
  }

  @action
  addError(name, message) {
    const field = this.fields.get(name);
    field?.pushError(message);
  }

  @action
  async set(key, value) {
    this.isDirtyForm = true;
    set(this.effectiveData, key, value);

    if (this.fieldValidationEvent === VALIDATION_TYPES.change) {
      await this.handleFieldValidation(key);
    }

    await new Promise((resolve) => next(resolve));
  }

  @action
  registerField(name, field) {
    if (!name) {
      throw new Error("@name is required on `<form.Field />`.");
    }

    if (this.fields.has(name)) {
      throw new Error(
        `@name="${name}", is already in use. Names of \`<form.Field />\` must be unique!`
      );
    }

    const fieldModel = new FieldData(name, field);
    this.fields.set(name, fieldModel);

    return fieldModel;
  }

  @action
  unregisterField(name) {
    this.fields.delete(name);
  }

  @action
  async onSubmit(event) {
    event?.preventDefault();

    await this.validate(this.fields);

    if (!this.hasErrors) {
      this.isDirtyForm = false;
      await this.args.onSubmit?.(this.effectiveData);
    }
  }

  @action
  async onReset(event) {
    event?.preventDefault();

    for (const key of Object.keys(this.transientData)) {
      delete this.transientData[key];
    }

    this.fields.forEach((field) => {
      field.reset();
    });

    await new Promise((resolve) => next(resolve));
  }

  @action
  async triggerRevalidationFor(name) {
    const field = this.fields.get(name);

    if (!field) {
      return;
    }

    await this.validate(new Map([[name, field]]));
  }

  @action
  async handleFieldValidation(event) {
    let name;

    if (typeof event === "string") {
      name = event;
    } else {
      const { target } = event;
      name = target.name;
    }

    if (name) {
      const field = this.fields.get(name);

      if (field) {
        await this.validate(this.fields);
      }
    }
  }

  async validate(fields) {
    this.isLoading = true;

    try {
      for (const [name, field] of fields) {
        await field.validate?.(
          name,
          this.effectiveData[name],
          this.effectiveData
        );
      }

      await this.args.validate?.(this.effectiveData, {
        addError: this.addError,
      });

      this.fieldsWithErrors = Array.from(this.fields.values()).filter(
        (field) => field.hasErrors
      );
    } finally {
      this.isLoading = false;
    }
  }

  <template>
    <form
      novalidate
      class="form-kit"
      ...attributes
      {{on "submit" this.onSubmit}}
      {{on "reset" this.onReset}}
      {{this.onValidation this.fieldValidationEvent this.handleFieldValidation}}
    >
      <FKErrorsSummary @fields={{this.fieldsWithErrors}} />

      {{yield
        (hash
          Row=Row
          Section=FKSection
          ConditionalContent=(component FKControlConditionalContent)
          Container=FKContainer
          Actions=(component FKSection class="form-kit__actions")
          Button=(component DButton class="form-kit__button")
          Alert=FKAlert
          Submit=(component
            DButton
            action=this.onSubmit
            forwardEvent=true
            class="btn-primary form-kit__button"
            label="submit"
            type="submit"
            isLoading=this.isLoading
          )
          Field=(component
            FKField
            addError=this.addError
            data=this.effectiveData
            set=this.set
            registerField=this.registerField
            unregisterField=this.unregisterField
            triggerRevalidationFor=this.triggerRevalidationFor
          )
          InputGroup=(component
            FKControlInputGroup
            data=this.effectiveData
            set=this.set
            registerField=this.registerField
            unregisterField=this.unregisterField
          )
          set=this.set
        )
        this.effectiveData
      }}
    </form>
  </template>
}
