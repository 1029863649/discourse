import RestrictedUserRoute from "discourse/routes/restricted-user";
import Category from "discourse/models/category";

export default RestrictedUserRoute.extend({
  showFooter: true,

  setupController(controller, user) {
    const props = {
      model: user,
      selectedSidebarCategories: Category.findByIds(user.sidebarCategoryIds),
    };

    if (this.siteSettings.tagging_enabled) {
      props.selectedSidebarTagNames = user.sidebarTagNames;
    }
    props.newSidebarListDestination = user.sidebarListDestination;

    controller.setProperties(props);
  },
});
