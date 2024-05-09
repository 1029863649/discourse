import { tracked } from "@glimmer/tracking";
import { A } from "@ember/array";
import { registerDestructor } from "@ember/destroyable";
import Service, { service } from "@ember/service";
import { TrackedSet } from "@ember-compat/tracked-built-ins";
import { disableImplicitInjections } from "discourse/lib/implicit-injections";
import {
  currentPanelKey,
  customPanels as panels,
} from "discourse/lib/sidebar/custom-sections";
import {
  COMBINED_MODE,
  MAIN_PANEL,
  SEPARATED_MODE,
} from "discourse/lib/sidebar/panels";

@disableImplicitInjections
export default class SidebarState extends Service {
  @service keyValueStore;
  @service currentUser;
  @service siteSettings;

  @tracked currentPanelKey = currentPanelKey;
  @tracked panels = panels;
  @tracked mode = COMBINED_MODE;
  @tracked displaySwitchPanelButtons = false;
  @tracked filter = "";
  @tracked collapsedSections = A([]);

  previousState = {};
  #hiders = new TrackedSet();

  constructor() {
    super(...arguments);
    this.#reset();
  }

  get sidebarHidden() {
    return this.#hiders.size > 0;
  }

  registerHider(ref) {
    this.#hiders.add(ref);

    registerDestructor(ref, () => {
      this.#hiders.delete(ref);
    });
  }

  setPanel(name) {
    if (this.currentPanelKey) {
      this.setPreviousState();
    }
    this.currentPanelKey = name;
    this.restorePreviousState();
  }

  get currentPanel() {
    return this.panels.find((panel) => panel.key === this.currentPanelKey);
  }

  setSeparatedMode() {
    this.mode = SEPARATED_MODE;
    this.showSwitchPanelButtons();
  }

  setCombinedMode() {
    this.mode = COMBINED_MODE;
    this.currentPanelKey = MAIN_PANEL;
    this.hideSwitchPanelButtons();
  }

  showSwitchPanelButtons() {
    this.displaySwitchPanelButtons = true;
  }

  hideSwitchPanelButtons() {
    this.displaySwitchPanelButtons = false;
  }

  setPreviousState() {
    this.previousState[this.currentPanelKey] = {
      mode: this.mode,
      displaySwitchPanelButtons: this.displaySwitchPanelButtons,
    };
  }

  collapseSection(sectionKey) {
    const collapsedSidebarSectionKey = `sidebar-section-${sectionKey}-collapsed`;
    this.keyValueStore.setItem(collapsedSidebarSectionKey, true);
    this.collapsedSections.pushObject(collapsedSidebarSectionKey);
  }

  expandSection(sectionKey) {
    const collapsedSidebarSectionKey = `sidebar-section-${sectionKey}-collapsed`;
    this.keyValueStore.setItem(collapsedSidebarSectionKey, false);
    this.collapsedSections.removeObject(collapsedSidebarSectionKey);
  }

  isCurrentPanel(panel) {
    return this.currentPanel.key === panel;
  }

  restorePreviousState() {
    const state = this.previousState[this.currentPanelKey];
    if (!state) {
      return;
    }

    if (state.mode === SEPARATED_MODE) {
      this.setSeparatedMode();
    } else if (state.mode === COMBINED_MODE) {
      this.setCombinedMode();
    }

    if (state.displaySwitchPanelButtons) {
      this.showSwitchPanelButtons();
    } else {
      this.hideSwitchPanelButtons();
    }
  }

  get combinedMode() {
    return this.mode === COMBINED_MODE;
  }

  get showMainPanel() {
    return this.currentPanelKey === MAIN_PANEL;
  }

  get adminSidebarAllowedWithLegacyNavigationMenu() {
    return (
      this.currentUser?.use_admin_sidebar &&
      this.siteSettings.navigation_menu === "header dropdown"
    );
  }

  #reset() {
    this.currentPanelKey = currentPanelKey;
    this.panels = panels;
    this.mode = COMBINED_MODE;
  }

  clearFilter() {
    this.filter = "";
  }
}
