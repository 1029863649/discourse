import GlimmerComponent from "@glimmer/component";
import { htmlSafe } from "@ember/template";

export default class SectionLink extends GlimmerComponent {
  willDestroy() {
    if (this.args.willDestroy) {
      this.args.willDestroy();
    }
  }

  get classNames() {
    return `${this.args.class} sidebar-section-link sidebar-section-link-${this.args.linkName}`;
  }

  get prefixCSS() {
    const color = this.args.prefixColor;

    if (!color || !color.match(/^\w{6}$/)) {
      return htmlSafe("");
    }

    return htmlSafe("color: #" + color);
  }
}
