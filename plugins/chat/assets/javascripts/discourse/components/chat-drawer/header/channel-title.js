import Component from "@glimmer/component";
import { inject as service } from "@ember/service";

export default class ChatDrawerChannelHeaderTitle extends Component {
  @service chatStateManager;
  @service chatTrackingState;

  get channelUnreadCount() {
    return this.chatTrackingState.getChannelState(this.args.channel.id)
      .unreadCount;
  }
}
