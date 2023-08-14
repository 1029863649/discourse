import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import I18n from "I18n";
import { inject as service } from "@ember/service";
import { action } from "@ember/object";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { cookAsync } from "discourse/lib/text";
import { shortDateNoYear } from "discourse/lib/formatter";

const MIN_POST_READ_TIME = 4;

export default class SummaryBox extends Component {
  @service siteSettings;

  @tracked summary = "";
  @tracked summarizedOn = null;
  @tracked summarizedBy = null;
  @tracked newPostsSinceSummary = null;
  @tracked outdated = false;
  @tracked canRegenerate = false;

  @tracked regenerated = false;
  @tracked showSummaryBox = false;
  @tracked canCollapseSummary = false;
  @tracked loadingSummary = false;

  get generateSummaryTitle() {
    const title = this.canRegenerate
      ? "summary.buttons.regenerate"
      : "summary.buttons.generate";

    return I18n.t(title);
  }

  get generateSummaryIcon() {
    return this.canRegenerate ? "sync" : "magic";
  }

  get outdatedSummaryWarningText() {
    let outdatedText = I18n.t("summary.outdated");

    if (
      !this.args.postAttrs.hasTopRepliesSummary &&
      this.newPostsSinceSummary > 0
    ) {
      outdatedText += " ";
      outdatedText += I18n.t("summary.outdated_posts", {
        count: this.newPostsSinceSummary,
      });
    }

    return outdatedText;
  }

  get topRepliesSummaryEnabled() {
    return this.args.postAttrs.topicSummaryEnabled;
  }

  get topRepliesSummaryInfo() {
    if (this.args.postAttrs.topicSummaryEnabled) {
      return I18n.t("summary.enabled_description");
    }

    const wordCount = this.args.postAttrs.topicWordCount;
    if (wordCount && this.siteSettings.read_time_word_count > 0) {
      const readingTime = Math.ceil(
        Math.max(
          wordCount / this.siteSettings.read_time_word_count,
          (this.args.postAttrs.topicPostsCount * MIN_POST_READ_TIME) / 60
        )
      );
      return I18n.messageFormat("summary.description_time_MF", {
        replyCount: this.args.postAttrs.topicReplyCount,
        readingTime,
      });
    }
    return I18n.t("summary.description", {
      count: this.args.postAttrs.topicReplyCount,
    });
  }

  get topRepliesTitle() {
    if (this.topRepliesSummaryEnabled) {
      return;
    }

    return I18n.t("summary.short_title");
  }

  get topRepliesLabel() {
    const label = this.topRepliesSummaryEnabled
      ? "summary.disable"
      : "summary.enable";

    return I18n.t(label);
  }

  get topRepliesIcon() {
    if (this.topRepliesSummaryEnabled) {
      return;
    }

    return "layer-group";
  }

  @action
  toggleTopRepliesFilter() {
    const filterFunction = this.topRepliesSummaryEnabled
      ? "cancelFilter"
      : "showTopReplies";

    this.args.topRepliesToggle(filterFunction);
  }

  @action
  collapseSummary() {
    this.showSummaryBox = false;
    this.canCollapseSummary = false;
  }

  @action
  generateSummary() {
    this.showSummaryBox = true;

    if (this.summary && !this.canRegenerate) {
      this.canCollapseSummary = true;
      return;
    } else {
      this.loadingSummary = true;
    }

    let fetchURL = `/t/${this.args.postAttrs.topicId}/strategy-summary`;

    if (this.canRegenerate) {
      fetchURL += "?skip_age_check=true";
    }

    ajax(fetchURL)
      .then((data) => {
        cookAsync(data.summary).then((cooked) => {
          this.summary = cooked;
          this.summarizedOn = shortDateNoYear(data.summarized_on);
          this.summarizedBy = data.summarized_by;
          this.newPostsSinceSummary = data.new_posts_since_summary;
          this.outdated = data.outdated;
          this.newPostsSinceSummary = data.new_posts_since_summary;
          this.canRegenerate = data.outdated && data.can_regenerate;

          this.canCollapseSummary = !this.canRegenerate;
        });
      })
      .catch(popupAjaxError)
      .finally(() => (this.loadingSummary = false));
  }
}
