import NotificationAvatar from "discourse/components/user-menu/notification-avatar";
import { setTransientHeader } from "discourse/lib/ajax";
import cookie from "discourse/lib/cookie";
import { getRenderDirector } from "discourse/lib/notification-types-manager";
import UserMenuBaseItem from "discourse/lib/user-menu/base-item";
import getURL from "discourse-common/lib/get-url";

export default class UserMenuNotificationItem extends UserMenuBaseItem {
  constructor({ notification, appEvents, currentUser, siteSettings, site }) {
    super(...arguments);
    this.appEvents = appEvents;
    this.notification = notification;
    this.currentUser = currentUser;
    this.siteSettings = siteSettings;
    this.site = site;

    this.renderDirector = getRenderDirector(
      this.#notificationName,
      notification,
      currentUser,
      siteSettings,
      site
    );
  }

  get className() {
    return this.renderDirector.classNames?.join(" ") || "";
  }

  get linkHref() {
    return this.renderDirector.linkHref;
  }

  get linkTitle() {
    return this.renderDirector.linkTitle;
  }

  get icon() {
    return this.renderDirector.icon;
  }

  get label() {
    return this.renderDirector.label;
  }

  get labelClass() {
    return this.renderDirector.labelClasses?.join(" ") || "";
  }

  get description() {
    return this.renderDirector.description;
  }

  get descriptionClass() {
    return this.renderDirector.descriptionClasses?.join(" ") || "";
  }

  get topicId() {
    return this.notification.topic_id;
  }

  get iconComponent() {
    return this.iconComponentArgs.avatarTemplate ? NotificationAvatar : null;
  }

  get iconComponentArgs() {
    return {
      avatarTemplate: this.notification.acting_user_avatar_template,
      icon: this.icon,
    };
  }

  get #notificationName() {
    return this.site.notificationLookup[this.notification.notification_type];
  }

  onClick() {
    this.renderDirector.onClick?.();
    this.appEvents.trigger("user-menu:notification-click", this.notification);

    if (!this.notification.read) {
      this.notification.set("read", true);

      const groupedUnreadNotifications = {
        ...this.currentUser.grouped_unread_notifications,
      };
      const unreadCount =
        groupedUnreadNotifications &&
        groupedUnreadNotifications[this.notification.notification_type];
      if (unreadCount > 0) {
        groupedUnreadNotifications[this.notification.notification_type] =
          unreadCount - 1;
        this.currentUser.set(
          "grouped_unread_notifications",
          groupedUnreadNotifications
        );
      }

      setTransientHeader("Discourse-Clear-Notifications", this.notification.id);
      cookie("cn", this.notification.id, { path: getURL("/") });
    }
    super.onClick(...arguments);
  }
}
