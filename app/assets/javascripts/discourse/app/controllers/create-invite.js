import Controller from "@ember/controller";
import { action } from "@ember/object";
import { equal } from "@ember/object/computed";
import discourseComputed from "discourse-common/utils/decorators";
import { extractError } from "discourse/lib/ajax-error";
import { bufferedProperty } from "discourse/mixins/buffered-content";
import ModalFunctionality from "discourse/mixins/modal-functionality";
import { getNativeContact } from "discourse/lib/pwa-utils";
import Group from "discourse/models/group";
import Invite from "discourse/models/invite";
import I18n from "I18n";

export default Controller.extend(
  ModalFunctionality,
  bufferedProperty("invite"),
  {
    allGroups: null,

    invite: null,
    invites: null,

    showAdvanced: false,
    limitToEmail: false,
    autogenerated: false,

    type: "link",

    onShow() {
      Group.findAll().then((groups) => {
        this.set("allGroups", groups.filterBy("automatic", false));
      });

      this.setProperties({
        invite: null,
        invites: null,
        showAdvanced: false,
        limitToEmail: false,
        autogenerated: false,
      });

      this.setInvite(Invite.create());
    },

    onClose() {
      if (this.autogenerated) {
        this.invite
          .destroy()
          .then(() => this.invites && this.invites.removeObject(this.invite));
      }
    },

    setInvite(invite) {
      this.setProperties({
        invite,
        type: invite.email ? "email" : "link",
      });
    },

    setAutogenerated(value) {
      if (this.invites && (this.autogenerated || !this.invite.id) && !value) {
        this.invites.unshiftObject(this.invite);
      }

      this.set("autogenerated", value);
    },

    save(opts) {
      const data = { ...this.buffered.buffer };

      if (data.groupIds !== undefined) {
        data.group_ids = data.groupIds;
        delete data.groupIds;
      }

      if (data.topicId !== undefined) {
        data.topic_id = data.topicId;
        delete data.topicId;
        delete data.topicTitle;
      }

      if (this.type === "link") {
        if (this.buffered.get("email")) {
          data.email = "";
          data.custom_message = "";
        }
      } else if (this.type === "email") {
        if (this.buffered.get("max_redemptions_allowed") > 1) {
          data.max_redemptions_allowed = 1;
        }

        if (opts.sendEmail) {
          data.send_email = true;
        } else {
          data.skip_email = true;
        }
      }

      return this.invite
        .save(data)
        .then(() => {
          this.rollbackBuffer();
          this.setAutogenerated(opts.autogenerated);
          if (!this.autogenerated) {
            if (this.type === "email" && opts.sendEmail) {
              this.send("closeModal");
            } else {
              this.appEvents.trigger("modal-body:flash", {
                text: opts.copy
                  ? I18n.t("user.invited.invite.invite_copied")
                  : I18n.t("user.invited.invite.invite_saved"),
                messageClass: "success",
              });
            }
          }
        })
        .catch((e) =>
          this.appEvents.trigger("modal-body:flash", {
            text: extractError(e),
            messageClass: "error",
          })
        );
    },

    isLink: equal("type", "link"),
    isEmail: equal("type", "email"),

    @discourseComputed(
      "currentUser.staff",
      "siteSettings.invite_link_max_redemptions_limit",
      "siteSettings.invite_link_max_redemptions_limit_users"
    )
    maxRedemptionsAllowedLimit(staff, staffLimit, usersLimit) {
      return staff ? staffLimit : usersLimit;
    },

    @discourseComputed("buffered.expires_at")
    expiresAtLabel(expires_at) {
      const expiresAt = moment(expires_at);

      return expiresAt.isBefore()
        ? I18n.t("user.invited.invite.expired_at_time", {
            time: expiresAt.format("LLL"),
          })
        : I18n.t("user.invited.invite.expires_in_time", {
            time: moment.duration(expiresAt - moment()).humanize(),
          });
    },

    @discourseComputed("type", "buffered.email")
    disabled(type, email) {
      if (type === "email") {
        return !email;
      }

      return false;
    },

    @discourseComputed("buffered.hasBufferedChanges", "invite.email", "type")
    changed(hasBufferedChanges, inviteEmail, type) {
      return hasBufferedChanges || (inviteEmail ? "email" : "link") !== type;
    },

    @action
    copied() {
      if (this.type === "email" && !this.buffered.get("email")) {
        return this.appEvents.trigger("modal-body:flash", {
          text: I18n.t("user.invited.invite.blank_email"),
          messageClass: "error",
        });
      }

      this.save({ sendEmail: false, copy: true });
    },

    @action
    toggleLimitToEmail() {
      const limitToEmail = !this.limitToEmail;
      this.setProperties({
        limitToEmail,
        type: limitToEmail ? "email" : "link",
      });
    },

    @action
    saveInvite(sendEmail) {
      this.appEvents.trigger("modal-body:clearFlash");

      this.save({ sendEmail });
    },

    @action
    searchContact() {
      getNativeContact(this.capabilities, ["email"], false).then((result) => {
        this.set("buffered.email", result[0].email[0]);
      });
    },

    @action
    toggleAdvanced() {
      this.toggleProperty("showAdvanced");
    },
  }
);
