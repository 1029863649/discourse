import Component from "@ember/component";
import { action } from "@ember/object";
import { tagName } from "@ember-decorators/component";
import discourseDebounce from "discourse-common/lib/debounce";
import { bind } from "discourse-common/utils/decorators";

@tagName("")
export default class CopyButton extends Component {
  copyIcon = "copy";
  copyClass = "btn-primary";

  @bind
  _restoreButton() {
    if (this.isDestroying || this.isDestroyed) {
      return;
    }

    this.set("copyIcon", "copy");
    this.set("copyClass", "btn-primary");
  }

  @action
  copy() {
    const target = document.querySelector(this.selector);
    target.select();
    target.setSelectionRange(0, target.value.length);

    try {
      document.execCommand("copy");

      if (this.copied) {
        this.copied();
      }

      this.set("copyIcon", "check");
      this.set("copyClass", "btn-primary ok");

      discourseDebounce(this._restoreButton, 3000);
    } catch (err) {}
  }
}
