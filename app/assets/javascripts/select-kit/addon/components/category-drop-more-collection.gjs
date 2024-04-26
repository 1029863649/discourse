import Component from "@glimmer/component";
import { hash } from "@ember/helper";
import { LinkTo } from "@ember/routing";
import { inject as service } from "@ember/service";
import icon from "discourse-common/helpers/d-icon";
import i18n from "discourse-common/helpers/i18n";
import {
  ALL_CATEGORIES_ID,
  NO_CATEGORIES_ID,
} from "select-kit/components/category-drop";

export default class CategoryDropMoreCollection extends Component {
  @service site;

  tagName = "";

  get moreCount() {
    if (!this.args.selectKit.totalCount) {
      return 0;
    }

    const currentCount = this.args.collection.content.filter(
      (category) =>
        category.id !== NO_CATEGORIES_ID && category.id !== ALL_CATEGORIES_ID
    ).length;

    return this.args.selectKit.totalCount - currentCount;
  }

  get parentCategoryId() {
    return this.args.selectKit.options.parentCategory?.id;
  }

  <template>
    {{#if this.moreCount}}
      <div class="category-drop-footer">
        <span>
          {{i18n "categories.plus_more_count" (hash count=this.moreCount)}}
        </span>

        {{#if this.parentCategoryId}}
          <LinkTo
            @route="discovery.subcategories"
            @model={{this.parentCategoryId}}
          >
            {{i18n "categories.view_all"}}
            {{icon "external-link-alt"}}
          </LinkTo>
        {{else}}
          <LinkTo @route="discovery.categories">
            {{i18n "categories.view_all"}}
            {{icon "external-link-alt"}}
          </LinkTo>
        {{/if}}
      </div>
    {{/if}}
  </template>
}
