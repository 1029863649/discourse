import Controller from "@ember/controller";
import { action } from "@ember/object";
import { tracked } from "@glimmer/tracking";
import I18n from "I18n";

import { popupAjaxError } from "discourse/lib/ajax-error";

export default class extends Controller {
  @tracked saved = false;
  @tracked selectedSidebarCategories = [];
  @tracked selectedSidebarTagNames = [];
  @tracked newSidebarTopicDestination =
    this.currentUser.user_option.sidebar_topic_destination;
  @tracked sidebarTopicDestionations = [
    {
      name: I18n.t("user.experimental_sidebar.topic_destination_latest"),
      value: "latest",
    },
    {
      name: I18n.t("user.experimental_sidebar.topic_destination_unread"),
      value: "unread",
    },
  ];

  @action
  save() {
    const initialSidebarCategoryIds = this.model.sidebarCategoryIds;

    this.model.set(
      "sidebarCategoryIds",
      this.selectedSidebarCategories.mapBy("id")
    );

    this.model.set("sidebar_tag_names", this.selectedSidebarTagNames);

    this.model.set(
      "user_option.sidebar_topic_destination",
      this.newSidebarTopicDestination
    );

    this.model
      .save()
      .then((result) => {
        if (result.user.sidebar_tags) {
          this.model.set("sidebar_tags", result.user.sidebar_tags);
        }
        this.model.set(
          "user_option.sidebar_topic_destination",
          result.user.user_option.sidebar_topic_destination
        );

        this.saved = true;
      })
      .catch((error) => {
        this.model.set("sidebarCategoryIds", initialSidebarCategoryIds);
        popupAjaxError(error);
      })
      .finally(() => {
        this.model.set("sidebar_tag_names", []);
      });
  }
}
