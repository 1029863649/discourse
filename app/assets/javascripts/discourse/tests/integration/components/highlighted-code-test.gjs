import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import HighlightedCode from "admin/components/highlighted-code";

module("Integration | Component | highlighted-code", function (hooks) {
  setupRenderingTest(hooks);

  test("highlighting code", async function (assert) {
    await render(<template>
      <HighlightedCode @lang="ruby" @code="def test; end" />
    </template>);

    assert.dom("code.lang-ruby.hljs .hljs-keyword").hasText("def");
  });

  test("large code blocks are not highlighted", async function (assert) {
    const longCodeBlock = "puts a\n".repeat(15000);

    await render(<template>
      <HighlightedCode @lang="ruby" @code={{longCodeBlock}} />
    </template>);

    assert.dom("code").hasText(longCodeBlock.trim());
  });

  test("highlighting code with lang=auto", async function (assert) {
    await render(<template>
      <HighlightedCode @lang="auto" @code="def test; end" />
    </template>);

    assert.dom("code.hljs").hasNoClass("lang-auto", "lang-auto is removed");
    assert.dom("code.hljs").hasClass(/language-/, "language is detected");

    assert
      .dom("code.hljs")
      .hasNoAttribute(
        "data-unknown-hljs-lang",
        "language is found from language- class"
      );
  });
});
