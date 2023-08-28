import Component from "@glimmer/component";
import { action } from "@ember/object";
import { inject as service } from "@ember/service";
import { tracked } from "@glimmer/tracking";
import I18n from "I18n";
import { MAX_MESSAGE_LENGTH } from "discourse/models/post-action-type";
import { Promise } from "rsvp";
import User from "discourse/models/user";
import { classify } from "@ember/string";
import { reload } from "discourse/helpers/page-reloader";

export default class Flag extends Component {
  @service adminTools;
  @service currentUser;
  @service siteSettings;
  @service site;
  @service appEvents;

  @tracked userDetails;
  @tracked selected;
  @tracked message;
  @tracked isWarning = false;
  @tracked spammerDetails;

  constructor() {
    super(...arguments);

    this.adminTools
      ?.checkSpammer(this.args.model.flagModel.user_id)
      .then((result) => (this.spammerDetails = result));
  }

  get flagActions() {
    return {
      icon: "gavel",
      label: I18n.t("flagging.take_action"),
      actions: [
        {
          id: "agree_and_keep",
          icon: "thumbs-up",
          label: I18n.t("flagging.take_action_options.default.title"),
          description: I18n.t("flagging.take_action_options.default.details"),
        },
        {
          id: "agree_and_suspend",
          icon: "ban",
          label: I18n.t("flagging.take_action_options.suspend.title"),
          description: I18n.t("flagging.take_action_options.suspend.details"),
          client_action: "suspend",
        },
        {
          id: "agree_and_silence",
          icon: "microphone-slash",
          label: I18n.t("flagging.take_action_options.silence.title"),
          description: I18n.t("flagging.take_action_options.silence.details"),
          client_action: "silence",
        },
      ],
    };
  }

  get canSendWarning() {
    return (
      !this.args.model.flagTarget.targetsTopic() &&
      this.currentUser.staff &&
      this.selected?.name_key === "notify_user"
    );
  }

  get submitLabel() {
    if (this.selected?.is_custom_flag) {
      return this.args.model.flagTarget.customSubmitLabel();
    }

    return this.args.model.flagTarget.submitLabel();
  }

  get includeSeparator() {
    return (
      this.staffFlagsAvailable ||
      this.args.model.flagTarget.includeSeparator?.()
    );
  }

  get title() {
    return this.args.model.flagTarget.title();
  }

  get flagsAvailable() {
    return this.args.model.flagTarget.flagsAvailable(this);
  }

  get staffFlagsAvailable() {
    return this.args.model.flagModel.flagsAvailable?.length > 1;
  }

  get submitEnabled() {
    if (!this.selected) {
      return false;
    }

    if (this.selected.is_custom_flag) {
      const len = this.message?.length || 0;
      return (
        len >= this.siteSettings.min_personal_message_post_length &&
        len <= MAX_MESSAGE_LENGTH
      );
    }
    return true;
  }

  get notifyModeratorsFlag() {
    const notifyModeratorsID = 7;
    return this.flagsAvailable.find((f) => f.id === notifyModeratorsID);
  }

  get canTakeAction() {
    return (
      !this.args.model.flagTarget.targetsTopic() &&
      !this.selected?.is_custom_flag &&
      this.currentUser.staff
    );
  }

  @action
  onKeydown(event) {
    // CTRL+ENTER or CMD+ENTER
    if (event.key === "Enter" && (event.ctrlKey || event.metaKey)) {
      if (this.submitEnabled) {
        this.createFlag();
        return false;
      }
    }
  }

  @action
  async penalize(adminToolMethod, performAction) {
    if (this.adminTools) {
      const createdBy = await User.findByUsername(
        this.args.model.flagModel.username
      );
      const opts = { before: performAction };

      if (this.args.model.flagTarget.editable()) {
        opts.postId = this.args.model.flagModel.id;
        opts.postEdit = this.args.model.flagModel.cooked;
      }

      return this.adminTools[adminToolMethod](createdBy, opts);
    }
  }

  @action
  async deleteSpammer() {
    if (this.spammerDetails) {
      await this.spammerDetails.deleteUser();
      reload();
    }
  }

  @action
  async takeAction(actionable) {
    const performAction = async (o = {}) => {
      o.takeAction = true;
      this.createFlag(o);
    };

    if (actionable.client_action) {
      if (actionable.client_action === "suspend") {
        await this.penalize("showSuspendModal", () =>
          performAction({ skipClose: true })
        );
      } else if (actionable.client_action === "silence") {
        await this.penalize("showSilenceModal", () =>
          performAction({ skipClose: true })
        );
      } else {
        // eslint-disable-next-line no-console
        console.error(`No handler for ${actionable.client_action} found`);
      }
    } else {
      this.args.model.setHidden();
      await performAction();
    }
  }

  @action
  createFlag(opts) {
    const params = opts || {};
    if (this.selected.is_custom_flag) {
      params.message = this.message;
    }
    this.args.model.flagTarget.create(this, params);
  }

  @action
  createFlagAsWarning() {
    this.createFlag({ isWarning: true });
    this.args.model.setHidden();
  }

  @action
  flagForReview() {
    this.selected ||= this.notifyModeratorsFlag;
    this.createFlag({ queue_for_review: true });
    this.args.model.setHidden();
  }

  @action
  changePostActionType(actionType) {
    this.selected = actionType;
  }
}
