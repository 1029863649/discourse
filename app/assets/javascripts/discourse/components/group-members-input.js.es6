import computed from "ember-addons/ember-computed-decorators";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { propertyEqual } from "discourse/lib/computed";

export default Ember.Component.extend({
  classNames: ["group-members-input"],
  addButton: true,

  @computed("model.limit", "model.offset", "model.user_count")
  currentPage(limit, offset, userCount) {
    if (userCount === 0) {
      return 0;
    }

    return Math.floor(offset / limit) + 1;
  },

  @computed("model.limit", "model.user_count")
  totalPages(limit, userCount) {
    if (userCount === 0) {
      return 0;
    }
    return Math.ceil(userCount / limit);
  },

  @computed("model.usernames")
  disableAddButton(usernames) {
    return !usernames || !(usernames.length > 0);
  },

  showingFirst: Ember.computed.lte("currentPage", 1),
  showingLast: propertyEqual("currentPage", "totalPages"),

  actions: {
    next() {
      if (this.showingLast) {
        return;
      }

      const group = this.model;
      const offset = Math.min(
        group.offset + group.limit,
        group.user_count
      );
      group.set("offset", offset);

      return group.findMembers();
    },

    previous() {
      if (this.showingFirst) {
        return;
      }

      const group = this.model;
      const offset = Math.max(group.offset - group.limit, 0);
      group.set("offset", offset);

      return group.findMembers();
    },

    addMembers() {
      if (Ember.isEmpty(this.get("model.usernames"))) {
        return;
      }
      this.model.addMembers(this.get("model.usernames")).catch(popupAjaxError);
      this.set("model.usernames", null);
    },

    removeMember(member) {
      const message = I18n.t("groups.manage.delete_member_confirm", {
        username: member.username,
        group: this.get("model.name")
      });

      return bootbox.confirm(
        message,
        I18n.t("no_value"),
        I18n.t("yes_value"),
        confirm => {
          if (confirm) {
            this.model.removeMember(member);
          }
        }
      );
    }
  }
});
