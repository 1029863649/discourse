import Component from "@glimmer/component";
import { getOwner } from "@ember/owner";
import PostMetaDataDate from "./meta-data/date";
import PostMetaDataEditsIndicator from "./meta-data/edits-indicator";
import PostEmailMetaDataIndicator from "./meta-data/email-indicator";
import PostLockedIndicator from "./meta-data/locked-indicator";
import PostMetaDataPosterName from "./meta-data/poster-name";
import PostMetaDataReplyToTab from "./meta-data/reply-to-tab";
import PostMetaDataSelectPost from "./meta-data/select-post";
import PostWhisperMetaDataIndicator from "./meta-data/whisper-indicator";

export default class PostMetaData extends Component {
  get displayPosterName() {
    return this.args.displayPosterName ?? true;
  }

  get shouldDisplayEditsIndicator() {
    return this.args.post.version > 1 || this.args.post.wiki;
  }

  get shouldDisplayReplyToTab() {
    return PostMetaDataReplyToTab.shouldRender(
      { post: this.args.post },
      null,
      getOwner(this)
    );
  }

  <template>
    <div class="topic-meta-data" role="heading" aria-level="2">
      {{#if this.displayPosterName}}
        <PostMetaDataPosterName @post={{@post}} />
      {{/if}}

      <div class="post-infos">
        {{#if @post.isWhisper}}
          <PostWhisperMetaDataIndicator @post={{@post}} />
        {{/if}}

        {{#if @post.via_email}}
          <PostEmailMetaDataIndicator
            @post={{@post}}
            @showRawEmail={{@showRawEmail}}
          />
        {{/if}}

        {{#if @post.locked}}
          <PostLockedIndicator @post={{@post}} />
        {{/if}}

        {{#if this.shouldDisplayEditsIndicator}}
          <PostMetaDataEditsIndicator
            @post={{@post}}
            @editPost={{@editPost}}
            @showHistory={{@showHistory}}
          />
        {{/if}}

        {{#if @multiSelect}}
          <PostMetaDataSelectPost
            @post={{@post}}
            @selected={{@selected}}
            @selectReplies={{@selectReplies}}
            @selectBelow={{@selectBelow}}
            @togglePostSelection={{@togglePostSelection}}
          />
        {{/if}}

        {{#if this.shouldDisplayReplyToTab}}
          <PostMetaDataReplyToTab
            @post={{@post}}
            @repliesAbove={{@repliesAbove}}
            @toggleReplyAbove={{@toggleReplyAbove}}
          />
        {{/if}}

        <PostMetaDataDate @post={{@post}} />
      </div>
    </div>
  </template>
}
