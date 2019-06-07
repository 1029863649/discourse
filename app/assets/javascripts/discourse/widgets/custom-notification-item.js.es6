import { createWidgetFrom } from "discourse/widgets/widget";
import { DefaultNotificationItem } from "discourse/widgets/default-notification-item";
import { formatUsername } from "discourse/lib/utilities";
import { iconNode } from "discourse-common/lib/icon-library";

createWidgetFrom(DefaultNotificationItem, "custom-notification-item", {
  title(notificationName, data) {
    return data.title ? I18n.t(data.title) : "";
  },

  text(notificationType, notificationName) {
    const { attrs } = this;
    const data = attrs.data;

    const username = formatUsername(data.display_username);
    const description = this.description();

    return I18n.t(data.message, { description, username });
  },

  icon(notificationName, data) {
    return iconNode(`notification.${data.message}`);
  }
});
