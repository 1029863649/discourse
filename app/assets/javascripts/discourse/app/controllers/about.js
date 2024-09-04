import Controller from "@ember/controller";
import { alias, gt } from "@ember/object/computed";
import discourseComputed from "discourse-common/utils/decorators";
import I18n from "discourse-i18n";

// TODO(osama): remove all of these methods when the legacy about page is
// removed
const customStats = [];
export function addLegacyStat(name) {
  customStats.push(name);
}

export function clearCustomStats() {
  customStats.clear();
}

export default class AboutController extends Controller {
  @gt("siteSettings.faq_url.length", 0) faqOverridden;

  @alias("siteSettings.experimental_rename_faq_to_guidelines")
  renameFaqToGuidelines;

  @discourseComputed("model.contact_url", "model.contact_email")
  contactInfo(url, email) {
    if (url) {
      return I18n.t("about.contact_info", {
        contact_info: `<a href='${url}' target='_blank'>${url}</a>`,
      });
    } else if (email) {
      return I18n.t("about.contact_info", {
        contact_info: email,
      });
    } else {
      return null;
    }
  }

  @discourseComputed(
    "model.stats.visitors_30_days",
    "model.stats.eu_visitors_30_days"
  )
  statsTableFooter(all, eu) {
    return I18n.messageFormat("about.traffic_info_footer_MF", {
      total_visitors: all,
      eu_visitors: eu,
    });
  }

  @discourseComputed("site.displayed_about_plugin_stat_groups")
  statGroups() {
    return Array.from(
      new Set(customStats).union(
        new Set(this.site.displayed_about_plugin_stat_groups || [])
      )
    );
  }
}
