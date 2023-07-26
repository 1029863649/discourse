import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { inject as service } from "@ember/service";
import I18n from "I18n";

// Modal that displays confirmation text when user deletes a topic
// The modal will display only if the topic exceeds a certain amount of views
export default class DeleteTopicConfirm extends Component {
  @service currentUser;

  @tracked deletingTopic = false;
  @tracked flash;

  @action
  deleteTopic() {
    this.deletingTopic = true;
    this.args.model
      .destroy(this.currentUser)
      .then(() => this.args.closeModal())
      .catch(() => {
        this.flash = I18n.t("post.controls.delete_topic_error");
        this.deletingTopic = false;
      });
  }
}
