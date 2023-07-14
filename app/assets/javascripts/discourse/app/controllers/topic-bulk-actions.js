import Controller, { inject as controller } from "@ember/controller";
import { tracked } from "@glimmer/tracking";
import { inject as service } from "@ember/service";
import { action } from "@ember/object";
import I18n from "I18n";
import ModalFunctionality from "discourse/mixins/modal-functionality";
import { Promise } from "rsvp";
import Topic from "discourse/models/topic";
import ChangeCategory from "../components/bulk-actions/change-category";
import NotificationLevel from "../components/bulk-actions/notification-level";
import ChangeTags from "../components/bulk-actions/change-tags";
import AppendTags from "../components/bulk-actions/append-tags";

const _customButtons = [];

export function _addBulkButton(opts) {
  _customButtons.push({
    label: opts.label,
    icon: opts.icon,
    class: opts.class,
    visible: opts.visible,
    action: opts.action,
  });
}

export function clearBulkButtons() {
  _customButtons.length = 0;
}

// Modal for performing bulk actions on topics
export default class TopicBulkActions extends Controller.extend(
  ModalFunctionality
) {
  @service dialog;
  @controller("user-private-messages") userPrivateMessages;

  @tracked loading = false;
  @tracked showProgress = false;
  @tracked processedTopicCount = 0;
  @tracked activeComponent = null;

  defaultButtons = [
    {
      label: "topics.bulk.change_category",
      icon: "pencil-alt",
      class: "btn-default",
      visible: (topics) => !topics.some((t) => t.isPrivateMessage),
      action() {
        this.activeComponent = ChangeCategory;
      },
    },
    {
      label: "topics.bulk.close_topics",
      icon: "lock",
      class: "btn-default",
      visible: (topics) => !topics.some((t) => t.isPrivateMessage),
      action() {
        this.forEachPerformed({ type: "close" }, (t) => t.set("closed", true));
      },
    },
    {
      label: "topics.bulk.archive_topics",
      icon: "folder",
      class: "btn-default",
      visible: (topics) => !topics.some((t) => t.isPrivateMessage),
      action() {
        this.forEachPerformed({ type: "archive" }, (t) =>
          t.set("archived", true)
        );
      },
    },
    {
      label: "topics.bulk.archive_topics",
      icon: "folder",
      class: "btn-default",
      visible: (topics) => topics.some((t) => t.isPrivateMessage),
      action() {
        let params = { type: "archive_messages" };
        if (this.userPrivateMessages.isGroup) {
          params.group = this.userPrivateMessages.groupFilter;
        }
        this.performAndRefresh(params);
      },
    },
    {
      label: "topics.bulk.move_messages_to_inbox",
      icon: "folder",
      class: "btn-default",
      visible: (topics) => topics.some((t) => t.isPrivateMessage),
      action() {
        let params = { type: "move_messages_to_inbox" };
        if (this.userPrivateMessages.isGroup) {
          params.group = this.userPrivateMessages.groupFilter;
        }
        this.performAndRefresh(params);
      },
    },
    {
      label: "topics.bulk.notification_level",
      icon: "d-regular",
      class: "btn-default",
      action() {
        this.activeComponent = NotificationLevel;
      },
    },
    {
      label: "topics.bulk.defer",
      icon: "circle",
      class: "btn-default",
      visible: () => this.currentUser.user_option.enable_defer,
      action() {
        this.performAndRefresh({ type: "destroy_post_timing" });
      },
    },
    {
      label: "topics.bulk.unlist_topics",
      icon: "far-eye-slash",
      class: "btn-default",
      visible: (topics) =>
        topics.some((t) => t.visible) &&
        !topics.some((t) => t.isPrivateMessage),
      action() {
        this.forEachPerformed({ type: "unlist" }, (t) =>
          t.set("visible", false)
        );
      },
    },
    {
      label: "topics.bulk.relist_topics",
      icon: "far-eye",
      class: "btn-default",
      visible: (topics) =>
        topics.some((t) => !t.visible) &&
        !topics.some((t) => t.isPrivateMessage),
      action() {
        this.forEachPerformed({ type: "relist" }, (t) =>
          t.set("visible", true)
        );
      },
    },
    {
      label: "topics.bulk.reset_bump_dates",
      icon: "anchor",
      class: "btn-default",
      visible: () => this.currentUser.canManageTopic,
      action() {
        this.performAndRefresh({ type: "reset_bump_dates" });
      },
    },
    {
      label: "topics.bulk.change_tags",
      icon: "tag",
      class: "btn-default",
      visible: () =>
        this.siteSettings.tagging_enabled && this.currentUser.canManageTopic,
      action() {
        this.activeComponent = ChangeTags;
      },
    },
    {
      label: "topics.bulk.append_tags",
      icon: "tag",
      class: "btn-default",
      visible: () =>
        this.siteSettings.tagging_enabled && this.currentUser.canManageTopic,
      action() {
        this.activeComponent = AppendTags;
      },
    },
    {
      label: "topics.bulk.remove_tags",
      icon: "tag",
      class: "btn-default",
      visible: () =>
        this.siteSettings.tagging_enabled && this.currentUser.canManageTopic,
      action() {
        this.dialog.deleteConfirm({
          message: I18n.t("topics.bulk.confirm_remove_tags", {
            count: this.model.topics.length,
          }),
          didConfirm: () => this.performAndRefresh({ type: "remove_tags" }),
        });
      },
    },
    {
      label: "topics.bulk.delete",
      icon: "trash-alt",
      class: "btn-danger delete-topics",
      visible: () => this.currentUser.staff,
      action() {
        this.performAndRefresh({ type: "delete" });
      },
    },
  ];

  get buttons() {
    return [...this.defaultButtons, ..._customButtons]
      .filter(({ visible }) => {
        if (visible) {
          return visible.call(this, this.model.topics);
        } else {
          return true;
        }
      })
      .map((button) => ({ ...button, action: button.action.bind(this) }));
  }

  onShow() {
    this.modal.set("modalClass", "topic-bulk-actions-modal small");
    this.activeComponent = null;
  }

  async perform(operation) {
    this.loading = true;

    if (this.model.topics.length > 20) {
      this.showProgress = true;
    }

    try {
      return this._processChunks(operation);
    } catch {
      this.dialog.alert(I18n.t("generic_error"));
    } finally {
      this.loading = false;
      this.processedTopicCount = 0;
      this.showProgress = false;
    }
  }

  _generateTopicChunks(allTopics) {
    let startIndex = 0;
    const chunkSize = 30;
    const chunks = [];

    while (startIndex < allTopics.length) {
      const topics = allTopics.slice(startIndex, startIndex + chunkSize);
      chunks.push(topics);
      startIndex += chunkSize;
    }

    return chunks;
  }

  _processChunks(operation) {
    const allTopics = this.model.topics;
    const topicChunks = this._generateTopicChunks(allTopics);
    const topicIds = [];

    const tasks = topicChunks.map((topics) => async () => {
      const result = await Topic.bulkOperation(topics, operation);
      this.processedTopicCount = this.processedTopicCount + topics.length;
      return result;
    });

    return new Promise((resolve, reject) => {
      const resolveNextTask = async () => {
        if (tasks.length === 0) {
          const topics = topicIds.map((id) => allTopics.findBy("id", id));
          return resolve(topics);
        }

        const task = tasks.shift();

        try {
          const result = await task();
          if (result?.topic_ids) {
            topicIds.push(...result.topic_ids);
          }
          resolveNextTask();
        } catch {
          reject();
        }
      };

      resolveNextTask();
    });
  }

  @action
  async forEachPerformed(operation, cb) {
    const topics = await this.perform(operation);

    if (topics) {
      topics.forEach(cb);
      this.refreshClosure?.();
      this.send("closeModal");
    }
  }

  @action
  async performAndRefresh(operation) {
    await this.perform(operation);

    this.refreshClosure?.();
    this.send("closeModal");
  }
}
