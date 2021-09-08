import DiscourseRoute from "discourse/routes/discourse";
import I18n from "I18n";

export default DiscourseRoute.extend({
  model() {
    const user = this.modelFor("user");
    const userDraftsStream = user.get("userDraftsStream");

    userDraftsStream.set("isAnotherUsersPage", this.isAnotherUsersPage(user));
    userDraftsStream.set("emptyState", this.emptyState());

    return userDraftsStream.load(this.site).then(() => userDraftsStream);
  },

  renderTemplate() {
    this.render("user_stream");
  },

  setupController(controller, model) {
    controller.set("model", model);
  },

  emptyState() {
    const title = I18n.t("user_activity.no_drafts_title");
    const body = I18n.t("user_activity.no_drafts_body");
    return { title, body };
  },

  activate() {
    this.appEvents.on("draft:destroyed", this, this.refresh);
  },

  deactivate() {
    this.appEvents.off("draft:destroyed", this, this.refresh);
  },

  actions: {
    didTransition() {
      this.controllerFor("user-activity")._showFooter();
      return true;
    },
  },
});
