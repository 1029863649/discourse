import { render, triggerEvent } from "@ember/test-helpers";
import { hbs } from "ember-cli-htmlbars";
import { module, skip, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import DToastInstance from "float-kit/lib/d-toast-instance";

module(
  "Integration | Component | FloatKit | d-default-toast",
  function (hooks) {
    setupRenderingTest(hooks);

    test("icon", async function (assert) {
      this.toast = new DToastInstance(this, { data: { icon: "check" } });

      await render(hbs`<DDefaultToast @data={{this.toast.options.data}} />`);

      assert.dom(".fk-d-default-toast__icon-container .d-icon-check").exists();
    });

    test("no icon", async function (assert) {
      this.toast = new DToastInstance(this, {});

      await render(hbs`<DDefaultToast @data={{this.toast.options.data}} />`);

      assert.dom(".fk-d-default-toast__icon-container").doesNotExist();
    });

    test("progress bar", async function (assert) {
      this.toast = new DToastInstance(this, {});

      await render(
        hbs`<DDefaultToast @data={{this.toast.options.data}} @showProgressBar={{true}} @onRegisterProgressBar={{(noop)}} />`
      );

      assert.dom(".fk-d-default-toast__progress-bar").exists();
    });

    test("no progress bar", async function (assert) {
      this.toast = new DToastInstance(this, {});

      await render(
        hbs`<DDefaultToast @data={{this.toast.options.data}} @showProgressBar={{false}} />`
      );

      assert.dom(".fk-d-default-toast__progress-bar").doesNotExist();
    });

    test("title", async function (assert) {
      this.toast = new DToastInstance(this, { data: { title: "Title" } });

      await render(hbs`<DDefaultToast @data={{this.toast.options.data}} />`);

      assert
        .dom(".fk-d-default-toast__title")
        .hasText(this.toast.options.data.title);
    });

    test("no title", async function (assert) {
      this.toast = new DToastInstance(this, {});

      await render(hbs`<DDefaultToast @data={{this.toast.options.data}} />`);

      assert.dom(".fk-d-default-toast__title").doesNotExist();
    });

    test("message", async function (assert) {
      this.toast = new DToastInstance(this, { data: { message: "Message" } });

      await render(hbs`<DDefaultToast @data={{this.toast.options.data}} />`);

      assert
        .dom(".fk-d-default-toast__message")
        .hasText(this.toast.options.data.message);
    });

    test("no message", async function (assert) {
      this.toast = new DToastInstance(this, {});

      await render(hbs`<DDefaultToast @data={{this.toast.options.data}} />`);

      assert.dom(".fk-d-default-toast__message").doesNotExist();
    });

    test("actions", async function (assert) {
      this.toast = new DToastInstance(this, {
        data: {
          actions: [
            {
              label: "cancel",
              icon: "times",
              class: "btn-danger",
              action: () => {},
            },
          ],
        },
      });

      await render(hbs`<DDefaultToast @data={{this.toast.options.data}} />`);

      assert
        .dom(".fk-d-default-toast__actions .btn.btn-danger")
        .exists()
        .hasText("cancel");
    });

    skip("swipe up to close", async function (assert) {
      const TOAST_SELECTOR = ".fk-d-default-toast";
      this.site.mobileView = true;
      this.hasClosed = false;

      this.onClose = () => {
        this.hasClosed = true;
      };

      this.toast = new DToastInstance(this, {});
      await render(hbs`<DDefaultToast @close={{this.onClose}} />`);

      assert.dom(TOAST_SELECTOR).exists();

      await triggerEvent(TOAST_SELECTOR, "touchstart", {
        touches: [{ clientX: 0, clientY: 0 }],
        changedTouches: [{ clientX: 0, clientY: 0 }],
      });

      await triggerEvent(TOAST_SELECTOR, "touchmove", {
        touches: [{ clientX: 0, clientY: -20 }],
      });

      await triggerEvent(TOAST_SELECTOR, "touchend", {
        changedTouches: [{ clientX: 0, clientY: -20 }],
      });

      assert.strictEqual(this.hasClosed, true);
    });
  }
);
