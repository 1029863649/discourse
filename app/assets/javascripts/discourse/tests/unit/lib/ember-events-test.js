import { module, test } from "qunit";
import { setupRenderingTest } from "ember-qunit";
import { click, doubleClick, render } from "@ember/test-helpers";
import { hbs } from "ember-cli-htmlbars";

/* eslint-disable ember/require-tagless-components */
/* eslint-disable ember/no-classic-classes */
/* eslint-disable ember/no-classic-components */
import { default as ClassicComponent } from "@ember/component";
import { default as GlimmerComponent } from "@glimmer/component";
import { action } from "@ember/object";

// Configure test-local Classic and Glimmer components that
// will be immune from upgrades to actual Discourse components.
const ExampleClassicButton = ClassicComponent.extend({
  tagName: "button",
  type: "button",
  preventEventPropagation: false,
  onClick: null,
  onMouseDown: null,

  click(event) {
    event.preventDefault();
    if (this.preventEventPropagation) {
      event.stopPropagation();
    }
    this.onClick?.(event);
  },
});
const exampleClassicButtonTemplate = hbs`{{yield}}`;

class ExampleGlimmerButton extends GlimmerComponent {
  @action
  click(event) {
    event.preventDefault();
    if (this.args.preventEventPropagation) {
      event.stopPropagation();
    }
    this.args.onClick?.(event);
  }
}
const exampleGlimmerButtonTemplate = hbs`
<button {{on 'click' this.click}} type='button' ...attributes>
  {{yield}}
</button>
`;

module("Unit | Lib | ember-events", function (hooks) {
  setupRenderingTest(hooks);

  hooks.beforeEach(function () {
    this.owner.register(
      "component:example-classic-button",
      ExampleClassicButton
    );
    this.owner.register(
      "template:components/example-classic-button",
      exampleClassicButtonTemplate
    );

    this.owner.register(
      "component:example-glimmer-button",
      ExampleGlimmerButton
    );
    this.owner.register(
      "template:components/example-glimmer-button",
      exampleGlimmerButtonTemplate
    );
  });

  module("nested glimmer inside classic", function () {
    test("it handles click events and allows propagation by default", async function (assert) {
      let i = 0;

      this.setProperties({
        onParentClick: () => this.set("parentClicked", i++),
        onChildClick: () => this.set("childClicked", i++),
        parentClicked: undefined,
        childClicked: undefined,
      });

      await render(hbs`
        <ExampleClassicButton id="parentButton" @onClick={{this.onParentClick}}>
          <ExampleGlimmerButton id="childButton" @onClick={{this.onChildClick}} />
        </ExampleClassicButton>
      `);

      await click("#childButton");

      assert.strictEqual(this.childClicked, 0);
      assert.strictEqual(this.parentClicked, 1);
    });

    test("it handles click events and can prevent event propagation", async function (assert) {
      let i = 0;

      this.setProperties({
        onParentClick: () => this.set("parentClicked", i++),
        onChildClick: () => this.set("childClicked", i++),
        parentClicked: undefined,
        childClicked: undefined,
      });

      await render(hbs`
        <ExampleClassicButton id="parentButton" @onClick={{this.onParentClick}}>
          <ExampleGlimmerButton id="childButton" @preventEventPropagation={{true}} @onClick={{this.onChildClick}} />
        </ExampleClassicButton>
      `);

      await click("#childButton");

      assert.strictEqual(this.childClicked, 0);
      assert.strictEqual(this.parentClicked, undefined);
    });
  });

  module("nested classic inside glimmer", function () {
    test("it handles click events and allows propagation by default", async function (assert) {
      let i = 0;

      this.setProperties({
        onParentClick: () => this.set("parentClicked", i++),
        onChildClick: () => this.set("childClicked", i++),
        parentClicked: undefined,
        childClicked: undefined,
      });

      await render(hbs`
        <ExampleGlimmerButton id="parentButton" @onClick={{this.onParentClick}}>
          <ExampleClassicButton id="childButton" @onClick={{this.onChildClick}} />
        </ExampleGlimmerButton>
      `);

      await click("#childButton");

      assert.strictEqual(this.childClicked, 0);
      assert.strictEqual(this.parentClicked, 1);
    });

    test("it handles click events and can prevent event propagation", async function (assert) {
      let i = 0;

      this.setProperties({
        onParentClick: () => this.set("parentClicked", i++),
        onChildClick: () => this.set("childClicked", i++),
        parentClicked: undefined,
        childClicked: undefined,
      });

      await render(hbs`
        <ExampleGlimmerButton id="parentButton" @onClick={{this.onParentClick}}>
          <ExampleClassicButton id="childButton" @preventEventPropagation={{true}} @onClick={{this.onChildClick}} />
        </ExampleGlimmerButton>
      `);

      await click("#childButton");

      assert.strictEqual(this.childClicked, 0);
      assert.strictEqual(this.parentClicked, undefined);
    });
  });

  module("custom `action` modifier", function () {
    test("`action` can target a function", async function (assert) {
      let i = 0;

      this.setProperties({
        onChildClick: () => this.set("childClicked", i++),
        childClicked: undefined,
      });

      await render(hbs`
        <button id="childButton" {{action this.onChildClick}} />
      `);

      await click("#childButton");

      assert.strictEqual(this.childClicked, 0);
    });

    test("`action` can target a method on the current context by name", async function (assert) {
      let i = 0;

      this.setProperties({
        onChildClick: () => this.set("childClicked", i++),
        childClicked: undefined,
      });

      await render(hbs`
        <button id="childButton" {{action 'onChildClick'}} />
      `);

      await click("#childButton");

      assert.strictEqual(this.childClicked, 0);
    });

    test("`action` can specify an event other than `click` via `on`", async function (assert) {
      let i = 0;

      this.setProperties({
        onDblClick: () => this.set("dblClicked", i++),
        dblClicked: undefined,
      });

      await render(hbs`
        <button id="childButton" {{action this.onDblClick on='dblclick'}} />
      `);

      await doubleClick("#childButton");

      assert.strictEqual(this.dblClicked, 0);
    });

    module("nested `action` usage inside classic", function () {
      test("it handles click events and allows propagation by default", async function (assert) {
        let i = 0;

        this.setProperties({
          onParentClick: () => this.set("parentClicked", i++),
          onChildClick: () => this.set("childClicked", i++),
          parentClicked: undefined,
          childClicked: undefined,
        });

        await render(hbs`
          <ExampleClassicButton id="parentButton" @onClick={{this.onParentClick}}>
            <button id="childButton" {{action this.onChildClick}} />
          </ExampleClassicButton>
        `);

        await click("#childButton");

        assert.strictEqual(this.childClicked, 0);
        assert.strictEqual(this.parentClicked, 1);
      });

      test("it handles click events and can prevent event propagation", async function (assert) {
        let i = 0;

        this.setProperties({
          onParentClick: () => this.set("parentClicked", i++),
          onChildClick: (event) => {
            event.stopPropagation();
            this.set("childClicked", i++);
          },
          parentClicked: undefined,
          childClicked: undefined,
        });

        await render(hbs`
          <ExampleClassicButton id="parentButton" @onClick={{this.onParentClick}}>
            <button id="childButton" {{action this.onChildClick}} />
          </ExampleClassicButton>
        `);

        await click("#childButton");

        assert.strictEqual(this.childClicked, 0);
        assert.strictEqual(this.parentClicked, undefined);
      });
    });

    module("nested `action` usage inside glimmer", function () {
      test("it handles click events and allows propagation by default", async function (assert) {
        let i = 0;

        this.setProperties({
          onParentClick: () => this.set("parentClicked", i++),
          onChildClick: () => this.set("childClicked", i++),
          parentClicked: undefined,
          childClicked: undefined,
        });

        await render(hbs`
          <ExampleGlimmerButton id="parentButton" @onClick={{this.onParentClick}}>
            <button id="childButton" {{action this.onChildClick}} />
          </ExampleGlimmerButton>
        `);

        await click("#childButton");

        assert.strictEqual(this.childClicked, 0);
        assert.strictEqual(this.parentClicked, 1);
      });

      test("it handles click events and can prevent event propagation", async function (assert) {
        let i = 0;

        this.setProperties({
          onParentClick: () => this.set("parentClicked", i++),
          onChildClick: (event) => {
            event.stopPropagation();
            this.set("childClicked", i++);
          },
          parentClicked: undefined,
          childClicked: undefined,
        });

        await render(hbs`
          <ExampleGlimmerButton id="parentButton" @onClick={{this.onParentClick}}>
            <button id="childButton" {{action this.onChildClick}} />
          </ExampleGlimmerButton>
        `);

        await click("#childButton");

        assert.strictEqual(this.childClicked, 0);
        assert.strictEqual(this.parentClicked, undefined);
      });
    });
  });
});
