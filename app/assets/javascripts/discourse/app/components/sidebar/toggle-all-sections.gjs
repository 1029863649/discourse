import Component from "@glimmer/component";
import { action } from "@ember/object";
import { service } from "@ember/service";
import DButton from "discourse/components/d-button";
import { ADMIN_NAV_MAP } from "discourse/lib/sidebar/admin-nav-map";

export default class ToggleAllSections extends Component {
  @service sidebarState;
  @service keyValueStore;

  get allSectionsExpanded() {
    return ADMIN_NAV_MAP.every((adminNav) => {
      return !this.sidebarState.collapsedSections.has(
        `sidebar-section-${this.sidebarState.currentPanel.key}-${adminNav.name}-collapsed`
      );
    });
  }

  get title() {
    return this.allSectionsExpanded
      ? "admin.collapse_all_sections"
      : "admin.expand_all_sections";
  }

  get icon() {
    return this.allSectionsExpanded
      ? "discourse-chevron-collapse"
      : "discourse-chevron-expand";
  }

  @action
  toggleAllSections() {
    const collapseOrExpand = this.allSectionsExpanded
      ? this.sidebarState.collapseSection.bind(this)
      : this.sidebarState.expandSection.bind(this);
    ADMIN_NAV_MAP.forEach((adminNav) => {
      collapseOrExpand(
        `${this.sidebarState.currentPanel.key}-${adminNav.name}`
      );
    });
  }

  <template>
    <DButton
      @action={{this.toggleAllSections}}
      @icon={{this.icon}}
      @title={{this.title}}
      class="btn-transparent sidebar-toggle-all-sections"
    />
  </template>
}
