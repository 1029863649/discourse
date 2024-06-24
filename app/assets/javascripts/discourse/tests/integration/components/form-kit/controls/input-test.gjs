import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import Form from "discourse/components/form";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import formKit from "discourse/tests/helpers/form-kit-helper";

module(
  "Integration | Component | FormKit | Controls | Input",
  function (hooks) {
    setupRenderingTest(hooks);

    test("default", async function (assert) {
      let data = { foo: "" };

      await render(<template>
        <Form @mutable={{true}} @data={{data}} as |form|>
          <form.Field @name="foo" @title="Foo" as |field|>
            <field.Input />
          </form.Field>
        </Form>
      </template>);

      assert.form().field("foo").hasValue("");

      await formKit().field("foo").fillIn("bar");

      assert.form().field("foo").hasValue("bar");
      assert.deepEqual(data.foo, "bar");
    });

    test("@type", async function (assert) {
      let data = { foo: "" };

      await render(<template>
        <Form @mutable={{true}} @data={{data}} as |form|>
          <form.Field @name="foo" @title="Foo" as |field|>
            <field.Input @type="number" />
          </form.Field>
        </Form>
      </template>);

      assert.form().field("foo").hasValue("");

      await formKit().field("foo").fillIn(1);

      assert.form().field("foo").hasValue("1");
      assert.deepEqual(data.foo, 1);
    });
  }
);
