import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { concat, fn, get } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import { service } from "@ember/service";
import { TrackedSet } from "@ember-compat/tracked-built-ins";
import { gt, has, includes, not } from "truth-helpers";
import EditNavigationMenuModal from "discourse/components/sidebar/edit-navigation-menu/modal";
import borderColor from "discourse/helpers/border-color";
import categoryBadge from "discourse/helpers/category-badge";
import dirSpan from "discourse/helpers/dir-span";
import loadingSpinner from "discourse/helpers/loading-spinner";
import { popupAjaxError } from "discourse/lib/ajax-error";
import Category from "discourse/models/category";
import { INPUT_DELAY } from "discourse-common/config/environment";
import i18n from "discourse-common/helpers/i18n";
import discourseDebounce from "discourse-common/lib/debounce";
import { eq } from "truth-helpers";

class ActionSerializer {
  constructor(perform) {
    this.perform = perform;
    this.processing = false;
    this.queued = false;
  }

  async trigger() {
    this.queued = true;

    if (!this.processing) {
      this.processing = true;

      while (this.queued) {
        this.queued = false;

        try {
          await this.perform();
        } catch (e) {}
      }

      this.processing = false;
    }
  }
}

// Given an async method that takes no parameters, produce a method that
// triggers the original method only if it is not currently executing it,
// otherwise it will queue up to one execution of the method
function serialized(target, key, descriptor) {
  const originalMethod = descriptor.value;

  descriptor.value = function() {
    this[`_${key}_serializer`] ||= new ActionSerializer(() => originalMethod.apply(this));
    this[`_${key}_serializer`].trigger();
  };

  return descriptor;
}

// Given a list, break into chunks starting a new chunk whenever the predicate
// is true for an element.
function splitWhere(elements, f) {
  return elements.reduce((acc, el, i) => {
    if (i === 0 || f(el)) {
      acc.push([]);
    }
    acc[acc.length - 1].push(el);
    return acc;
  }, []);
}

function addShowMore(categories) {
  const categoriesPerParent = new Map();

  return categories.reduce((acc, el, i) => {
    acc.push({type: "category", category: el});

    const count = (categoriesPerParent.get(el.parent_category_id) || 0) + 1;
    categoriesPerParent.set(el.parent_category_id, count)

    const elID = categories[i].id;
    const elParentID = categories[i].parent_category_id;
    const nextParentID = categories[i + 1]?.parent_category_id;

    const nextIsSibling = nextParentID === elParentID;
    const nextIsChild = nextParentID === elID;

    if (!nextIsSibling && !nextIsChild && count == 5) {
      acc.push({type: "show-more", level: el.level});
    }

    return acc;
  }, []);
}

export default class SidebarEditNavigationMenuCategoriesModal extends Component {
  @service currentUser;
  @service site;
  @service siteSettings;

  @tracked initialLoad = true;
  @tracked fetchedCategoriesGroupings = [];
  @tracked fetchedCategoryIds = [];
  @tracked
  selectedCategoryIds = new TrackedSet([
    ...this.currentUser.sidebar_category_ids,
  ]);
  selectedFilter = '';
  selectedMode = 'everything';
  loadedFilter;
  loadedMode;
  loadedPage;
  saving = false;
  loadAnotherPage = false;
  unseenCategoryIdsChanged = false;
  observer = new IntersectionObserver(
    ([entry]) => {
      if (entry.isIntersecting) {
        this.observer.disconnect();
        this.loadMore();
      }
    },
    {
      threshold: 1.0,
    }
  );

  constructor() {
    super(...arguments);
    this.performSearch();
  }

  setFetchedCategories(categories) {
    this.fetchedCategories = categories;

    this.fetchedCategoriesGroupings = splitWhere(
      categories,
      (category) => category.parent_category_id === undefined
    ).map(addShowMore);

    this.fetchedCategoryIds = categories.map((c) => c.id);
  }

  concatFetchedCategories(categories) {
    this.setFetchedCategories(this.fetchedCategories.concat(categories));
  }

  @action
  didInsert(element) {
    this.observer.disconnect();
    this.observer.observe(element);
  }

  @serialized
  async performSearch() {
    const requestedFilter = this.selectedFilter;
    const requestedMode = this.selectedMode;
    const requestedCategoryIds = [...this.selectedCategoryIds];
    const selectedCategoriesNeedsUpdate = this.unseenCategoryIdsChanged && requestedMode !== 'everything';

    // Is the current set of displayed categories up-to-date?
    if (requestedFilter === this.loadedFilter && requestedMode === this.loadedMode && !selectedCategoriesNeedsUpdate) {
      // The shown categories are up-to-date, so we can do elaboration
      if (this.loadAnotherPage && !this.lastPage) {
        const requestedPage = this.loadedPage + 1;
        const opts = {page: requestedPage};

        if (requestedMode === 'only-selected') {
          opts.only = requestedCategoryIds;
        } else if (requestedMode === 'only-unselected') {
          opts.except = requestedCategoryIds;
        }

        const categories = await Category.asyncHierarchicalSearch(requestedFilter, opts);

        if (categories.length === 0) {
          this.lastPage = true;
        } else {
          this.concatFetchedCategories(categories);
        }

        this.loadAnotherPage = false;
        this.loadedPage = requestedPage;
      }
    } else {
      // The shown categories are stale, refresh everything
      this.unseenCategoryIdsChanged = false;

      const opts = {};

      if (requestedMode === 'only-selected') {
        opts.only = requestedCategoryIds;
      } else if (requestedMode === 'only-unselected') {
        opts.except = requestedCategoryIds;
      }

      this.setFetchedCategories(await Category.asyncHierarchicalSearch(requestedFilter, opts));

      this.loadedFilter = requestedFilter;
      this.loadedMode = requestedMode;
      this.loadedCategoryIds = requestedCategoryIds;
      this.loadedPage = 1;
      this.lastPage = false;
      this.initialLoad = false;
      this.loadAnotherPage = false;
    }
  }

  async loadMore() {
    this.loadAnotherPage = true;
    this.debouncedSendRequest();
  }

  debouncedSendRequest() {
    discourseDebounce(this, this.performSearch, INPUT_DELAY);
  }

  @action
  resetFilter() {
    this.selectedMode = "everything";
    this.debouncedSendRequest();
  }

  @action
  filterSelected() {
    this.selectedMode = "only-selected";
    this.debouncedSendRequest();
  }

  @action
  filterUnselected() {
    this.selectedMode = "only-unselected";
    this.debouncedSendRequest();
  }

  @action
  onFilterInput(filter) {
    this.selectedFilter = filter.toLowerCase().trim();
    this.debouncedSendRequest();
  }

  @action
  deselectAll() {
    this.selectedCategoryIds.clear();
    this.unseenCategoryIdsChanged = true;
    this.debouncedSendRequest();
  }

  @action
  toggleCategory(categoryId) {
    if (this.selectedCategoryIds.has(categoryId)) {
      this.selectedCategoryIds.delete(categoryId);
    } else {
      this.selectedCategoryIds.add(categoryId);
    }
  }

  @action
  resetToDefaults() {
    this.selectedCategoryIds = new TrackedSet(
      this.siteSettings.default_navigation_menu_categories
        .split("|")
        .map((id) => parseInt(id, 10))
    );

    this.unseenCategoryIdsChanged = true;
    this.debouncedSendRequest();
  }

  @action
  async save() {
    this.saving = true;
    const initialSidebarCategoryIds = this.currentUser.sidebar_category_ids;

    this.currentUser.set("sidebar_category_ids", [
      ...this.selectedCategoryIds,
    ]);

    try {
      await this.currentUser.save(["sidebar_category_ids"]);
      this.args.closeModal();
    } catch (error) {
      this.currentUser.set("sidebar_category_ids", initialSidebarCategoryIds);
      popupAjaxError(error);
    } finally {
      this.saving = false;
    }
  }

  <template>
    <EditNavigationMenuModal
      @title="sidebar.categories_form_modal.title"
      @disableSaveButton={{this.saving}}
      @save={{this.save}}
      @showResetDefaultsButton={{gt
        this.siteSettings.default_navigation_menu_categories.length
        0
      }}
      @resetToDefaults={{this.resetToDefaults}}
      @deselectAll={{this.deselectAll}}
      @deselectAllText={{i18n "sidebar.categories_form_modal.subtitle.text"}}
      @inputFilterPlaceholder={{i18n
        "sidebar.categories_form_modal.filter_placeholder"
      }}
      @onFilterInput={{this.onFilterInput}}
      @resetFilter={{this.resetFilter}}
      @filterSelected={{this.filterSelected}}
      @filterUnselected={{this.filterUnselected}}
      @closeModal={{@closeModal}}
      class="sidebar__edit-navigation-menu__categories-modal"
    >
      <form class="sidebar-categories-form">
        {{#if this.initialLoad}}
          <div class="sidebar-categories-form__loading">
            {{loadingSpinner size="small"}}
          </div>
        {{else}}
          {{#each this.fetchedCategoriesGroupings as |categories|}}
            <div
              style={{borderColor (get categories "0.category.color") "left"}}
              class="sidebar-categories-form__row"
            >
              {{#each categories as |c|}}
                {{#if (eq c.type "category")}}
                  {{#with c.category as |category|}}
                    <div
                      {{didInsert this.didInsert}}
                      data-category-id={{category.id}}
                      data-category-level={{category.level}}
                      class="sidebar-categories-form__category-row"
                    >
                      <label
                        for={{concat
                          "sidebar-categories-form__input--"
                          category.id
                        }}
                        class="sidebar-categories-form__category-label"
                      >
                        <div class="sidebar-categories-form__category-wrapper">
                          <div class="sidebar-categories-form__category-badge">
                            {{categoryBadge category}}
                          </div>

                          {{#unless category.parentCategory}}
                            <div
                              class="sidebar-categories-form__category-description"
                            >
                              {{dirSpan
                                category.description_excerpt
                                htmlSafe="true"
                              }}
                            </div>
                          {{/unless}}
                        </div>

                        <input
                          {{on "click" (fn this.toggleCategory category.id)}}
                          type="checkbox"
                          checked={{has
                            this.selectedCategoryIds
                            category.id
                          }}
                          id={{concat
                            "sidebar-categories-form__input--"
                            category.id
                          }}
                          class="sidebar-categories-form__input"
                        />
                      </label>
                    </div>
                  {{/with}}
                {{else}}
                  <div
                    {{didInsert this.didInsert}}
                    data-category-level={{c.level}}
                    class="sidebar-categories-form__category-row"
                  >
                    <label
                      class="sidebar-categories-form__category-label"
                    >
                      <div class="sidebar-categories-form__category-wrapper">
                        <div class="sidebar-categories-form__category-badge">
                          <a>
                            {{i18n "sidebar.categories_form_modal.show_more"}}
                          </a>
                        </div>
                      </div>
                    </label>
                  </div>
                {{/if}}
              {{/each}}
            </div>
          {{else}}
            <div class="sidebar-categories-form__no-categories">
              {{i18n "sidebar.categories_form_modal.no_categories"}}
            </div>
          {{/each}}
        {{/if}}
      </form>
    </EditNavigationMenuModal>
  </template>
}
