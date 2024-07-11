import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { Input } from "@ember/component";
import { hash } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { and, gt } from "@ember/object/computed";
import { htmlSafe } from "@ember/template";
import { classNameBindings, classNames } from "@ember-decorators/component";
import PluginOutlet from "discourse/components/plugin-outlet";
import icon from "discourse-common/helpers/d-icon";
import i18n from "discourse-common/helpers/i18n";
import escape from "discourse-common/lib/escape";
import { iconHTML } from "discourse-common/lib/icon-library";

const MAX_COMPONENTS = 4;

@classNames("themes-list-container__item")
@classNameBindings("theme.selected:selected")
export default class ThemesListItem extends Component {
  @tracked childrenExpanded = false;

  get displayHasMore() {
    return this.args.theme?.childThemes?.length > MAX_COMPONENTS;
  }

  get displayComponents() {
    return this.hasComponents && this.args.theme?.isActive;
  }

  get hasComponents() {
    return this.children.length > 0;
  }

  click(e) {
    if (!e.target.classList.contains("others-count")) {
      this.navigateToTheme();
    }
  }

  get children() {
    let children = this.args.theme?.childThemes;
    if (this.args.theme?.component || !children) {
      return [];
    }
    children = this.childrenExpanded
      ? children
      : children.slice(0, MAX_COMPONENTS);
    return children.map((t) => {
      const name = escape(t.name);
      return t.enabled ? name : `${iconHTML("ban")} ${name}`;
    });
  }

  get childrenString() {
    return this.children.join(", ");
  }

  get moreCount() {
    const childrenCount = this.args.theme?.childThemes?.length;
    if (this.args.theme?.component || !childrenCount || this.childrenExpanded) {
      return 0;
    }
    return childrenCount - MAX_COMPONENTS;
  }

  @action
  toggleChildrenExpanded(event) {
    event?.preventDefault();
    this.toggleProperty("childrenExpanded");
  }

  <template>
    <div class="themes-list-container__item">
      <div class="inner-wrapper">
        <span>
          <PluginOutlet
            @name="admin-customize-themes-list-item"
            @connectorTagName="span"
            @outletArgs={{hash theme=@theme}}
          />
        </span>

        <div class="info">
          {{#if @selectInactiveMode}}
            <Input
              @checked={{@theme.markedToDelete}}
              id={{@theme.id}}
              @type="checkbox"
            />
          {{/if}}
          <span class="name">
            {{@theme.name}}
          </span>

          <span class="icons">
            {{#if @theme.selected}}
              {{icon "caret-right"}}
            {{else}}
              {{#if @theme.default}}
                {{icon
                  "check"
                  class="default-indicator"
                  title="admin.customize.theme.default_theme_tooltip"
                }}
              {{/if}}
              {{#if @theme.isPendingUpdates}}
                {{icon
                  "sync"
                  title="admin.customize.theme.updates_available_tooltip"
                  class="light-grey-icon"
                }}
              {{/if}}
              {{#if @theme.isBroken}}
                {{icon
                  "exclamation-circle"
                  class="broken-indicator"
                  title="admin.customize.theme.broken_theme_tooltip"
                }}
              {{/if}}
              {{#unless @theme.enabled}}
                {{icon
                  "ban"
                  class="light-grey-icon"
                  title="admin.customize.theme.disabled_component_tooltip"
                }}
              {{/unless}}
            {{/if}}
          </span>
        </div>

        {{#if this.displayComponents}}
          <div class="components-list">
            <span class="components">{{htmlSafe this.childrenString}}</span>

            {{#if this.displayHasMore}}
              <a
                href
                {{on "click" this.toggleChildrenExpanded}}
                class="others-count"
              >
                {{#if this.childrenExpanded}}
                  {{i18n "admin.customize.theme.collapse"}}
                {{else}}
                  {{i18n
                    "admin.customize.theme.and_x_more"
                    count=this.moreCount
                  }}
                {{/if}}
              </a>
            {{/if}}
          </div>
        {{/if}}
      </div>
    </div>
  </template>
}
