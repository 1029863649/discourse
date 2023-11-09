import Component from "@glimmer/component";
import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import concatClass from "discourse/helpers/concat-class";
import I18n from "discourse-i18n";
import eq from "truth-helpers/helpers/eq";
import Channel from "./channel";
import ListAction from "./list-action";
import User from "./user";

export default class List extends Component {
  cantAddMoreMembersLabel = I18n.t(
    "chat.new_message_modal.cant_add_more_members"
  );

  componentForItem(type) {
    switch (type) {
      case "list-action":
        return ListAction;
      case "user":
        return User;
      case "channel":
        return Channel;
    }
  }

  @action
  handleEnter(item, event) {
    if (event.key !== "Enter") {
      return;
    }

    if (event.shiftKey && this.args.onShiftSelect) {
      this.args.onShiftSelect?.(item);
    } else {
      this.args.onSelect?.(item);
    }
  }

  @action
  handleClick(item, event) {
    if (event.shiftKey && this.args.onShiftSelect) {
      this.args.onShiftSelect?.(item);
    } else {
      this.args.onSelect?.(item);
    }
  }

  <template>
    {{#if @items}}
      <div class="chat-message-creator__list-container">
        {{#if @maxReached}}
          {{this.cantAddMoreMembersLabel}}
        {{else}}
          <ul class="chat-message-creator__list">
            {{#each @items as |item|}}
              <li
                class={{concatClass
                  "chat-message-creator__list-item"
                  (if
                    (eq item.identifier @highlightedItem.identifier)
                    "-highlighted"
                  )
                }}
                {{on "click" (fn this.handleClick item)}}
                {{on "keypress" (fn this.handleEnter item)}}
                {{on "mouseenter" (fn @onHighlight item)}}
                {{on "mouseleave" (fn @onHighlight null)}}
                role="button"
                tabindex="0"
                data-identifier={{item.identifier}}
                id={{item.id}}
              >
                {{component (this.componentForItem item.type) item=item}}
              </li>
            {{/each}}
          </ul>
        {{/if}}
      </div>
    {{/if}}
  </template>
}
