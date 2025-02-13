import Component from "@glimmer/component";
import { cached } from "@glimmer/tracking";
import { TrackedAsyncData } from "ember-async-data";
import ConditionalLoadingSpinner from "discourse/components/conditional-loading-spinner";
import { popupAjaxError } from "discourse/lib/ajax-error";
import discourseDebounce from "discourse/lib/debounce";
import { INPUT_DELAY } from "discourse/lib/environment";

export default class AsyncContent extends Component {
  #debounce = false;

  @cached
  get data() {
    const asyncData = this.args.asyncData;
    const context = this.args.context;

    if (this.isDestroying || this.isDestroyed) {
      return;
    }

    let value;

    if (typeof asyncData === "function") {
      value = this.args.debounce
        ? new Promise((resolve, reject) => {
            discourseDebounce(
              this,
              this.#resolveAsyncData,
              asyncData,
              context,
              resolve,
              reject,
              this.#debounce
            );
          })
        : this.#resolveAsyncData(asyncData, context);

      // value is null if we skipped loading the data on init
      // in this case, we don't want to return a TrackedAsyncData instance
      if (!value) {
        return;
      }
    } else if (asyncData instanceof Promise) {
      value = asyncData;
    }

    if (!(value instanceof Promise)) {
      throw new Error(
        `\`<AsyncContent />\` expects @asyncData to be an async function or a promise`
      );
    }

    return new TrackedAsyncData(value);
  }

  // a stable reference to a function to use the `debounce` method
  #resolveAsyncData(asyncData, context, resolve, reject) {
    this.#debounce =
      this.args.debounce === true ? INPUT_DELAY : this.args.debounce;

    // when a resolve function is provided, we need to resolve the promise, once asyncData is done
    // otherwise, we just call asyncData
    return resolve
      ? asyncData(context).then(resolve).catch(reject)
      : asyncData(context);
  }

  <template>
    {{#if this.data.isPending}}
      {{#if (has-block "loading")}}
        {{yield to="loading"}}
      {{else}}
        <ConditionalLoadingSpinner @condition={{this.data.isPending}} />
      {{/if}}
    {{else if this.data.isResolved}}
      {{#if this.data.value}}
        {{yield this.data.value to="content"}}
      {{else if (has-block "empty")}}
        {{yield to="empty"}}
      {{else}}
        {{yield this.data.value to="content"}}
      {{/if}}
    {{else if this.data.isRejected}}
      {{#if (has-block "error")}}
        {{yield this.data.error to="error"}}
      {{else}}
        {{popupAjaxError this.data.error}}
      {{/if}}
    {{/if}}
  </template>
}
