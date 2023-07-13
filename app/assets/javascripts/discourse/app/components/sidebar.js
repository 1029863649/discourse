import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { bind } from "discourse-common/utils/decorators";
import { inject as service } from "@ember/service";
import {
  currentPanelKey,
  customPanels as sidebarCustomPanels,
} from "discourse/lib/sidebar/custom-sections";
import { action } from "@ember/object";

export default class Sidebar extends Component {
  @service appEvents;
  @service site;
  @service currentUser;
  @service router;
  @tracked currentPanelKey = currentPanelKey;

  constructor() {
    super(...arguments);

    if (this.site.mobileView) {
      document.addEventListener("click", this.collapseSidebar);
    }
  }

  get showMainPanel() {
    return this.currentPanelKey === "main";
  }

  get currentPanel() {
    return sidebarCustomPanels.find(
      (panel) => panel.key === this.currentPanelKey
    );
  }

  get switchPanelButtons() {
    if (sidebarCustomPanels.length === 1 || !this.currentUser) {
      return [];
    }

    return sidebarCustomPanels.filter((panel) => panel !== this.currentPanel);
  }

  @bind
  collapseSidebar(event) {
    let shouldCollapseSidebar = false;

    const isClickWithinSidebar = event.composedPath().some((element) => {
      if (
        element?.className !== "sidebar-section-header-caret" &&
        ["A", "BUTTON"].includes(element.nodeName)
      ) {
        shouldCollapseSidebar = true;
        return true;
      }

      return element.className && element.className === "sidebar-wrapper";
    });

    if (shouldCollapseSidebar || !isClickWithinSidebar) {
      this.args.toggleSidebar();
    }
  }

  willDestroy() {
    if (this.site.mobileView) {
      document.removeEventListener("click", this.collapseSidebar);
    }
  }

  @action
  switchPanel(panel) {
    this.currentPanel.lastKnownURL = this.router.currentURL;
    this.currentPanelKey = panel.key;
    this.router.transitionTo(
      panel.lastKnownURL || panel.switchButtonDefaultUrl
    );
  }
}
