import NotificationOptionsComponent from "select-box-kit/components/notifications-button";

export default NotificationOptionsComponent.extend({
  classNames: "category-notifications-button",
  isHidden: Ember.computed.or("category.deleted", "site.isMobileDevice"),
  i18nPrefix: "category.notifications",
  value: Ember.computed.alias("category.notification_level"),
  headerComponent: "category-notifications-button/category-notifications-button-header",

  computeValue() {
    return this.get("category.notification_level");
  },

  mutateValue(value) {
    this.get("category").setNotification(value);
  }
});
