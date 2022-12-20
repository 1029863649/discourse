import Service, { inject as service } from "@ember/service";
import Promise from "rsvp";
import ChatChannel from "discourse/plugins/chat/discourse/models/chat-channel";
import { tracked } from "@glimmer/tracking";

const DIRECT_MESSAGE_CHANNELS_LIMIT = 20;

export default class ChatChannelsManager extends Service {
  @service chatSubscriptionsManager;
  @service chatApi;
  @service currentUser;
  @tracked _cached = {};

  get channels() {
    return Object.values(this._cached);
  }

  async find(id) {
    const existingChannel = this.#findStale(id);
    if (existingChannel) {
      return Promise.resolve(existingChannel);
    } else {
      return this.#find(id);
    }
  }

  store(channelObject) {
    let model = this.#findStale(channelObject.id);

    if (!model) {
      model = ChatChannel.create(channelObject);
      this.#cache(model);
    }

    return model;
  }

  async follow(model) {
    this.chatSubscriptionsManager.startChannelSubscription(model);

    if (!model.currentUserMembership.following) {
      return this.chatApi.followChannel(model.id).then((membership) => {
        model.currentUserMembership = membership;
        this.notifyPropertyChange("_cached");
        return model;
      });
    } else {
      this.notifyPropertyChange("_cached");
      return Promise.resolve(model);
    }
  }

  async unfollow(model) {
    this.chatSubscriptionsManager.stopChannelSubscription(model);

    return this.chatApi.unfollowChannel(model.id).then((membership) => {
      model.currentUserMembership = membership;
      this.notifyPropertyChange("_cached");
      return model;
    });
  }

  get unreadCount() {
    let count = 0;
    this.publicMessageChannels.forEach((channel) => {
      count += channel.currentUserMembership.unread_count || 0;
    });
    return count;
  }

  get unreadUrgentCount() {
    let count = 0;
    this.channels.forEach((channel) => {
      if (channel.isDirectMessageChannel) {
        count += channel.currentUserMembership.unread_count || 0;
      }
      count += channel.currentUserMembership.unread_mentions || 0;
    });
    return count;
  }

  get publicMessageChannels() {
    return this.channels.filter(
      (channel) =>
        channel.isCategoryChannel && channel.currentUserMembership.following
    );
  }

  get directMessageChannels() {
    return this.#sortDirectMessageChannels(
      this.channels.filter((channel) => {
        const membership = channel.currentUserMembership;
        return channel.isDirectMessageChannel && membership.following;
      })
    );
  }

  get truncatedDirectMessageChannels() {
    return this.directMessageChannels.slice(0, DIRECT_MESSAGE_CHANNELS_LIMIT);
  }

  async #find(id) {
    return this.chatApi.getChannel(id).then((channel) => {
      this.#cache(channel);
      return channel;
    });
  }

  #cache(channel) {
    this._cached[channel.id] = channel;
  }

  #findStale(id) {
    return this._cached[id];
  }

  #sortDirectMessageChannels(channels) {
    return channels.sort((a, b) => {
      const unreadCountA = a.currentUserMembership.unread_count || 0;
      const unreadCountB = b.currentUserMembership.unread_count || 0;
      if (unreadCountA === unreadCountB) {
        return new Date(a.get("last_message_sent_at")) >
          new Date(b.get("last_message_sent_at"))
          ? -1
          : 1;
      } else {
        return unreadCountA > unreadCountB ? -1 : 1;
      }
    });
  }
}
