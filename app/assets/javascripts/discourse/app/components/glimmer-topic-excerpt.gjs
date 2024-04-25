import dirSpan from "discourse/helpers/dir-span";
import i18n from "discourse-common/helpers/i18n";

const GlimmerTopicExcerpt = <template>
  {{#if @topic.hasExcerpt}}
    <a href={{@topic.url}} class="topic-excerpt">
      {{dirSpan @topic.escapedExcerpt htmlSafe="true"}}

      {{#if @topic.excerptTruncated}}
        <span class="topic-excerpt-more">{{i18n "read_more"}}</span>
      {{/if}}
    </a>
  {{/if}}
</template>;

export default GlimmerTopicExcerpt;
