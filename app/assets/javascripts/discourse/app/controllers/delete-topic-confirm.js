import I18n from "I18n";
import discourseComputed from "discourse-common/utils/decorators";
import Controller, { inject } from "@ember/controller";
import ModalFunctionality from "discourse/mixins/modal-functionality";

// Modal that displays confirmation text when user deletes a topic
// The modal will display only if the topic exceeds a certain amount of views
export default Controller.extend(ModalFunctionality, {
  topicController: inject("topic"),
  deletingTopic: false,

  @discourseComputed("deletingTopic")
  buttonTitle(deletingTopic) {
    return deletingTopic
      ? I18n.t("deleting")
      : I18n.t("post.controls.delete_topic_confirm_modal_yes");
  },

  onShow() {
    this.set("deletingTopic", false);
  },

  actions: {
    deleteTopic() {
      this.set("deletingTopic", true);

      this.topicController.model
        .destroy(this.currentUser)
        .then(() => this.send("closeModal"))
        .catch(() => {
          this.flash(I18n.t("post.controls.delete_topic_error"), "alert-error");
          this.set("deletingTopic", false);
        });

      return false;
    },
  },
});
