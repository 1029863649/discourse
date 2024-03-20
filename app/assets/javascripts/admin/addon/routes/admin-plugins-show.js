import Route from "@ember/routing/route";
import { inject as service } from "@ember/service";
import { ajax } from "discourse/lib/ajax";
import { sanitize } from "discourse/lib/text";
import AdminPlugin from "admin/models/admin-plugin";

export default class AdminPluginsShowRoute extends Route {
  @service router;
  @service adminPluginConfigNavManager;

  model(params) {
    const pluginId = sanitize(params.plugin_id).substring(0, 100);
    return ajax(`/admin/plugins/${pluginId}.json`).then((plugin) => {
      return AdminPlugin.create(plugin);
    });
  }

  afterModel(model) {
    this.adminPluginConfigNavManager.currentPlugin = model;
  }

  deactivate() {
    this.adminPluginConfigNavManager.currentPlugin = null;
  }
}
