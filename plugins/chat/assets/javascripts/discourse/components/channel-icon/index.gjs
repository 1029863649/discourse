import Component from "@glimmer/component";
import { htmlSafe } from "@ember/template";
import icon from "discourse-common/helpers/d-icon";
import ChatUserAvatar from "discourse/plugins/chat/discourse/components/chat-user-avatar";

export default class ChatChannelIcon extends Component {
  get firstUser() {
    return this.args.channel.chatable.users[0];
  }

  get groupDirectMessage() {
    return (
      this.args.channel.isDirectMessageChannel &&
      this.args.channel.chatable.group
    );
  }

  get channelColorStyle() {
    return htmlSafe(`color: #${this.args.channel.chatable.color}`);
  }

  <template>
    {{#if @channel.isDirectMessageChannel}}
      <div class="chat-channel-icon is-dm">
        {{#if this.groupDirectMessage}}
          <span class="chat-channel-icon__users-count">
            {{@channel.membershipsCount}}
          </span>
        {{else}}
          <div class="chat-channel-icon__avatar">
            <ChatUserAvatar @user={{this.firstUser}} @interactive={{false}} />
          </div>
        {{/if}}
      </div>
    {{else if @channel.isCategoryChannel}}
      <div class="chat-channel-icon is-category">
        <span
          class="chat-channel-icon__category-badge"
          style={{this.channelColorStyle}}
        >
          {{icon "d-chat"}}
          {{#if @channel.chatable.read_restricted}}
            {{icon "lock" class="chat-channel-icon__restricted-category-icon"}}
          {{/if}}
        </span>
      </div>
    {{/if}}
  </template>
}
