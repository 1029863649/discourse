import { next } from "@ember/runloop";
import { service } from "@ember/service";
import cookie from "discourse/lib/cookie";
import Group from "discourse/models/group";
import DiscourseRoute from "discourse/routes/discourse";
import I18n from "discourse-i18n";

export default DiscourseRoute.extend({
  dialog: service(),
  composer: service(),
  router: service(),

  beforeModel(transition) {
    const params = transition.to.queryParams;
    const userName = params.username;
    const groupName = params.groupname || params.group_name;

    if (this.currentUser) {
      if (transition.from) {
        transition.abort();

        if (userName) {
          this.openComposer(transition, userName);
        } else if (groupName) {
          // send a message to a group
          Group.messageable(groupName)
            .then((result) => {
              if (result.messageable) {
                this.openComposer(transition, groupName);
              } else {
                this.dialog.alert(
                  I18n.t("composer.cant_send_pm", { username: groupName })
                );
              }
            })
            .catch(() => this.dialog.alert(I18n.t("generic_error")));
        } else {
          this.openComposer(transition);
        }
      } else {
        this.router
          .replaceWith("discovery.latest")
          .followRedirects()
          .then(() => {
            if (userName) {
              this.openComposer(transition, userName);
            } else if (groupName) {
              // send a message to a group
              Group.messageable(groupName)
                .then((result) => {
                  if (result.messageable) {
                    this.openComposer(transition, groupName);
                  } else {
                    this.dialog.alert(
                      I18n.t("composer.cant_send_pm", { username: groupName })
                    );
                  }
                })
                .catch(() => this.dialog.alert(I18n.t("generic_error")));
            } else {
              this.openComposer(transition);
            }
          });
      }
    } else {
      cookie("destination_url", window.location.href);
      this.router.replaceWith("login");
    }
  },

  openComposer(transition, recipients) {
    next(() => {
      this.composer.openNewMessage({
        recipients,
        title: transition.to.queryParams.title,
        body: transition.to.queryParams.body,
      });
    });
  },
});
