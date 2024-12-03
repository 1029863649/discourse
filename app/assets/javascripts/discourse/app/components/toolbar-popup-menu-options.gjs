import Component from "@glimmer/component";
import { array, concat, fn } from "@ember/helper";
import { action } from "@ember/object";
import DButton from "discourse/components/d-button";
import DropdownMenu from "discourse/components/dropdown-menu";
import concatClass from "discourse/helpers/concat-class";
import { PLATFORM_KEY_MODIFIER } from "discourse/lib/keyboard-shortcuts";
import { translateModKey } from "discourse/lib/utilities";
import { i18n } from "discourse-i18n";
import DMenu from "float-kit/components/d-menu";

export default class ToolbarPopupmenuOptions extends Component {
  dMenu;

  @action
  async onSelect(option) {
    await this.dMenu?.close();
    this.args.onChange?.(option);
  }

  @action
  onRegisterApi(api) {
    this.dMenu = api;
  }

  get convertedContent() {
    return this.args.content.map(convertMenuOption).filter(Boolean);
  }

  <template>
    <DMenu
      @identifier={{concat "toolbar-menu__" @id}}
      @groupIdentifier="toolbar-menu"
      @icon={{@icon}}
      @onRegisterApi={{this.onRegisterApi}}
      @onShow={{@onOpen}}
      @modalForMobile={{true}}
      @placement="top"
      @fallbackPlacements={{array "bottom"}}
      @offset={{5}}
      tabindex="-1"
      class={{concatClass @className}}
    >
      <:content>
        <DropdownMenu as |dropdown|>
          {{#each this.convertedContent as |option|}}
            <dropdown.item>
              <DButton
                @translatedLabel={{option.label}}
                @icon={{option.icon}}
                @translatedTitle={{option.title}}
                @action={{fn this.onSelect option}}
              />
            </dropdown.item>
          {{/each}}
        </DropdownMenu>
      </:content>
    </DMenu>
  </template>
}

export function convertMenuOption(content) {
  if (content.condition) {
    let label;
    if (content.label) {
      label = i18n(content.label);
      if (content.shortcut) {
        label += ` <kbd class="shortcut">${translateModKey(
          PLATFORM_KEY_MODIFIER + "+" + content.shortcut
        )}</kbd>`;
      }
    }

    let title;
    if (content.title) {
      title = i18n(content.title);
      if (content.shortcut) {
        title += ` (${translateModKey(
          PLATFORM_KEY_MODIFIER + "+" + content.shortcut
        )})`;
      }
    }

    let name = content.name;
    if (!name && content.label) {
      name = i18n(content.label);
    }

    return {
      icon: content.icon,
      label,
      title,
      name,
      action: content.action,
      shortcutAction: content.shortcutAction,
    };
  }
}
