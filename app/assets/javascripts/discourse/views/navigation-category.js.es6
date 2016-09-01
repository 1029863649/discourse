import AddCategoryClass from 'discourse/mixins/add-category-class';

export default Ember.View.extend(AddCategoryClass, {
  categoryFullSlug: Ember.computed.alias('controller.category.fullSlug'),
  categoryBackgroundUrl: Ember.computed.alias('controller.category.background_url')
});
