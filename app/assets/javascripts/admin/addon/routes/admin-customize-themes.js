import { action } from "@ember/object";
import { inject as service } from "@ember/service";
import Route from "@ember/routing/route";
import I18n from "I18n";
import InstallThemeModal from "../components/modal/install-theme";

export default class AdminCustomizeThemesRoute extends Route {
  @service dialog;
  @service router;
  @service modal;

  queryParams = {
    repoUrl: null,
    repoName: null,
  };

  model() {
    return this.store.findAll("theme");
  }

  @action
  routeRefreshModel() {
    this.refresh();
  }

  setupController(controller, model) {
    super.setupController(controller, model);
    controller.set("editingTheme", false);

    if (controller.repoUrl) {
      this.modal.show(InstallThemeModal, {
        model: {
          uploadUrl: controller.repoUrl,
          uploadName: controller.repoName,
          selection: "directRepoInstall",
          selectedType: controller.currentTab,
          installedThemes: controller.installedThemes,
          addTheme: this.addTheme,
        },
      });
    }
  }

  @action
  installModal() {
    const currentTheme = this.modelFor("adminCustomizeThemes");
    if (this.currentModel?.warnUnassignedComponent) {
      this.dialog.yesNoConfirm({
        message: I18n.t("admin.customize.theme.unsaved_parent_themes"),
        didConfirm: () => {
          currentTheme.set("recentlyInstalled", false);
          this.modal.show(InstallThemeModal, {
            model: {
              selectedType: this.currentTab,
              installedThemes: this.installedThemes,
              content: currentTheme.content,
              userId: currentTheme.userId,
              addTheme: this.addTheme,
            },
          });
        },
      });
    } else {
      this.modal.show(InstallThemeModal, {
        model: {
          selectedType: this.controller.currentTab,
          installedThemes: this.controller.installedThemes,
          content: currentTheme.content,
          userId: currentTheme.userId,
          addTheme: this.addTheme,
        },
      });
    }
  }

  @action
  addTheme(theme) {
    this.refresh();
    theme.setProperties({ recentlyInstalled: true });
    this.router.transitionTo("adminCustomizeThemes.show", theme.get("id"), {
      queryParams: {
        repoName: null,
        repoUrl: null,
      },
    });
  }
}
