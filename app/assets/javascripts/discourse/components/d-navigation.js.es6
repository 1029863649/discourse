import computed from "ember-addons/ember-computed-decorators";

export default Ember.Component.extend({
  tagName: '',

  @computed('category')
  showCategoryNotifications(category) {
    return category && this.currentUser;
  },

  @computed()
  categories() {
    return Discourse.Category.list();
  },

  @computed("filterMode")
  navItems(filterMode) {
    // we don't want to show the period in the navigation bar since it's in a dropdown
    if (filterMode.indexOf("top/") === 0) { filterMode = filterMode.replace("top/", ""); }
    return Discourse.NavItem.buildList(null, { filterMode });
  }
});
