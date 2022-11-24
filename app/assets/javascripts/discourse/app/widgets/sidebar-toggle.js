import { createWidget } from "discourse/widgets/widget";

export default createWidget("sidebar-toggle", {
  tagName: "span.header-sidebar-toggle",

  html() {
    const attrs = this.attrs;
    return [
      this.attach("button", {
        title: attrs.showSidebar
          ? "sidebar.hide_sidebar"
          : "sidebar.show_sidebar",
        icon: "bars",
        action: "toggleSidebar",
        className: "btn btn-flat btn-sidebar-toggle",
        ariaExpanded: attrs.showSidebar ? "true" : "false",
        ariaControls: "d-sidebar",
      }),
    ];
  },
});
