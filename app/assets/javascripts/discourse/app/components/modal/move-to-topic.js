import Component from "@glimmer/component";
import { action } from "@ember/object";
import { tracked } from "@glimmer/tracking";
import { mergeTopic, movePosts } from "discourse/models/topic";
import DiscourseURL from "discourse/lib/url";
import I18n from "I18n";
import { isEmpty } from "@ember/utils";
import { inject as service } from "@ember/service";

export default class MoveToTopic extends Component {
  @service currentUser;
  @service site;

  @tracked topicName;
  @tracked saving = false;
  @tracked categoryId;
  @tracked tags;
  @tracked participants = [];
  @tracked chronologicalOrder = false;
  @tracked selection = "new_topic";
  @tracked selectedTopicId;

  saveAttrNames = [
    "newTopic",
    "existingTopic",
    "newMessage",
    "existingMessage",
  ];
  moveTypes = ["newTopic", "existingTopic", "newMessage", "existingMessage"];

  constructor() {
    super(...arguments);
    if (this.args.model.topic.isPrivateMessage) {
      this.selection = this.canSplitToPM ? "new_message" : "existing_message";
    } else if (!this.canSplitTopic) {
      this.selection = "existing_topic";
    }
  }

  get newTopic() {
    return this.selection === "new_topic";
  }

  get existingTopic() {
    return this.selection === "existing_topic";
  }

  get newMessage() {
    return this.selection === "new_message";
  }

  get existingMessage() {
    return this.selection === "existing_message";
  }

  get buttonDisabled() {
    return (
      this.saving || (isEmpty(this.selectedTopicId) && isEmpty(this.topicName))
    );
  }

  get buttonTitle() {
    if (this.newTopic) {
      return "topic.split_topic.title";
    } else if (this.existingTopic) {
      return "topic.merge_topic.title";
    } else if (this.newMessage) {
      return "topic.move_to_new_message.title";
    } else if (this.existingMessage) {
      return "topic.move_to_existing_message.title";
    } else {
      return "saving";
    }
  }

  get canSplitTopic() {
    return (
      !this.args.model.selectedAllPosts &&
      this.args.model.selectedPosts.length > 0 &&
      this.args.model.selectedPosts.sort(
        (a, b) => a.post_number - b.post_number
      )[0].post_type === this.site.get("post_types.regular")
    );
  }

  get canSplitToPM() {
    return this.canSplitTopic && this.currentUser?.admin;
  }

  @action
  performMove() {
    this.moveTypes.forEach((type) => {
      if (this[type]) {
        this.movePostsTo(type);
      }
    });
  }

  @action
  async movePostsTo(type) {
    this.saving = true;
    this.flash = null;
    let mergeOptions, moveOptions;

    if (type === "existingTopic") {
      mergeOptions = {
        destination_topic_id: this.selectedTopicId,
        chronological_order: this.chronologicalOrder,
      };
      moveOptions = {
        post_ids: this.args.model.selectedPostIds,
        ...mergeOptions,
      };
    } else if (type === "existingMessage") {
      mergeOptions = {
        destination_topic_id: this.selectedTopicId,
        participants: this.participants.join(","),
        archetype: "private_message",
        chronological_order: this.chronologicalOrder,
      };
      moveOptions = {
        post_ids: this.args.model.selectedPostIds,
        ...mergeOptions,
      };
    } else if (type === "newTopic") {
      mergeOptions = {};
      moveOptions = {
        title: this.topicName,
        post_ids: this.args.model.selectedPostIds,
        category_id: this.categoryId,
        tags: this.tags,
      };
    } else {
      mergeOptions = {};
      moveOptions = {
        title: this.topicName,
        post_ids: this.args.model.selectedPostIds,
        tags: this.tags,
        archetype: "private_message",
      };
    }

    try {
      let result;
      if (this.args.model.selectedAllPosts) {
        result = await mergeTopic(this.args.model.topic.id, mergeOptions);
      } else {
        result = await movePosts(this.args.model.topic.id, moveOptions);
      }

      this.args.closeModal();
      this.args.model.toggleMultiSelect();
      DiscourseURL.routeTo(result.url);
    } catch {
      this.flash = I18n.t("topic.move_to.error");
    } finally {
      this.saving = false;
    }
  }
}
