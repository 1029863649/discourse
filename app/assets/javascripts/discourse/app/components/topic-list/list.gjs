import Component from "@glimmer/component";
import { cached } from "@glimmer/tracking";
import { hash } from "@ember/helper";
import { service } from "@ember/service";
import { eq, or } from "truth-helpers";
import PluginOutlet from "discourse/components/plugin-outlet";
import TopicListHeader from "discourse/components/topic-list/topic-list-header";
import TopicListItem from "discourse/components/topic-list/topic-list-item";
import concatClass from "discourse/helpers/concat-class";
import { applyValueTransformer } from "discourse/lib/transformer";
import { i18n } from "discourse-i18n";
import { createColumns } from "./dag";
import HeaderBulkSelectCell from "./header/bulk-select-cell";
import HeaderLikesCell from "./header/likes-cell";
import HeaderOpLikesCell from "./header/op-likes-cell";
import HeaderPostersCell from "./header/posters-cell";
import ItemBulkSelectCell from "./item/bulk-select-cell";
import ItemLikesCell from "./item/likes-cell";
import ItemOpLikesCell from "./item/op-likes-cell";
import ItemPostersCell from "./item/posters-cell";

export default class TopicList extends Component {
  @service currentUser;
  @service topicTrackingState;

  @cached
  get columns() {
    const self = this;
    const context = {
      get category() {
        return self.topicTrackingState.get("filterCategory");
      },

      get filter() {
        return self.topicTrackingState.get("filter");
      },
    };

    const defaultColumns = createColumns();

    if (this.bulkSelectEnabled) {
      defaultColumns.add(
        "bulk-select",
        {
          header: HeaderBulkSelectCell,
          item: ItemBulkSelectCell,
        },
        { before: "topic" }
      );
    }

    if (this.args.showPosters) {
      defaultColumns.add(
        "posters",
        {
          header: HeaderPostersCell,
          item: ItemPostersCell,
        },
        { before: "replies" }
      );
    }

    if (this.args.order === "likes") {
      defaultColumns.add(
        "likes",
        {
          header: HeaderLikesCell,
          item: ItemLikesCell,
        },
        { after: "replies" }
      );
    } else if (this.args.order === "op_likes") {
      defaultColumns.add(
        "op-likes",
        {
          header: HeaderOpLikesCell,
          item: ItemOpLikesCell,
        },
        { after: "replies" }
      );
    }

    return applyValueTransformer(
      "topic-list-columns",
      defaultColumns,
      context
    ).resolve();
  }

  get selected() {
    return this.args.bulkSelectHelper?.selected;
  }

  get bulkSelectEnabled() {
    return this.args.bulkSelectHelper?.bulkSelectEnabled;
  }

  get canDoBulkActions() {
    return this.currentUser?.canManageTopic && this.selected?.length;
  }

  get toggleInTitle() {
    return !this.bulkSelectEnabled && this.args.canBulkSelect;
  }

  get sortable() {
    return !!this.args.changeSort;
  }

  get showTopicPostBadges() {
    return this.args.showTopicPostBadges ?? true;
  }

  get lastVisitedTopic() {
    const { topics, order, ascending, top, hot } = this.args;

    if (
      !this.args.highlightLastVisited ||
      top ||
      hot ||
      ascending ||
      !topics ||
      topics.length === 1 ||
      (order && order !== "activity") ||
      !this.currentUser?.get("previous_visit_at")
    ) {
      return;
    }

    // work backwards
    // this is more efficient cause we keep appending to list
    const start = topics.findIndex((topic) => !topic.get("pinned"));
    let lastVisitedTopic, topic;

    for (let i = topics.length - 1; i >= start; i--) {
      if (topics[i].get("bumpedAt") > this.currentUser.get("previousVisitAt")) {
        lastVisitedTopic = topics[i];
        break;
      }
      topic = topics[i];
    }

    if (!lastVisitedTopic || !topic) {
      return;
    }

    // end of list that was scanned
    if (topic.get("bumpedAt") > this.currentUser.get("previousVisitAt")) {
      return;
    }

    return lastVisitedTopic;
  }

  <template>
    {{! template-lint-disable table-groups }}
    <table
      class={{concatClass
        "topic-list"
        (if this.bulkSelectEnabled "sticky-header")
      }}
    >
      <caption class="sr-only">{{i18n "sr_topic_list_caption"}}</caption>
      <thead class="topic-list-header">
        <TopicListHeader
          @columns={{this.columns}}
          @canBulkSelect={{@canBulkSelect}}
          @toggleInTitle={{this.toggleInTitle}}
          @category={{@category}}
          @hideCategory={{@hideCategory}}
          @order={{@order}}
          @changeSort={{@changeSort}}
          @ascending={{@ascending}}
          @sortable={{this.sortable}}
          @listTitle={{or @listTitle "topic.title"}}
          @bulkSelectHelper={{@bulkSelectHelper}}
          @canDoBulkActions={{this.canDoBulkActions}}
          @showTopicsAndRepliesToggle={{@showTopicsAndRepliesToggle}}
          @newListSubset={{@newListSubset}}
          @newRepliesCount={{@newRepliesCount}}
          @newTopicsCount={{@newTopicsCount}}
          @changeNewListSubset={{@changeNewListSubset}}
        />
      </thead>

      <PluginOutlet
        @name="before-topic-list-body"
        @outletArgs={{hash
          topics=@topics
          selected=this.selected
          bulkSelectEnabled=this.bulkSelectEnabled
          lastVisitedTopic=this.lastVisitedTopic
          discoveryList=@discoveryList
          hideCategory=@hideCategory
        }}
      />

      <tbody class="topic-list-body">
        {{#each @topics as |topic index|}}
          <TopicListItem
            @columns={{this.columns}}
            @topic={{topic}}
            @bulkSelectHelper={{@bulkSelectHelper}}
            @showTopicPostBadges={{this.showTopicPostBadges}}
            @hideCategory={{@hideCategory}}
            @expandGloballyPinned={{@expandGloballyPinned}}
            @expandAllPinned={{@expandAllPinned}}
            @lastVisitedTopic={{this.lastVisitedTopic}}
            @selected={{this.selected}}
            @tagsForUser={{@tagsForUser}}
            @focusLastVisitedTopic={{@focusLastVisitedTopic}}
            @index={{index}}
          />

          {{#if (eq topic this.lastVisitedTopic)}}
            <tr class="topic-list-item-separator">
              <td class="topic-list-data" colspan="6">
                <span>
                  {{i18n "topics.new_messages_marker"}}
                </span>
              </td>
            </tr>
          {{/if}}

          <PluginOutlet
            @name="after-topic-list-item"
            @outletArgs={{hash topic=topic index=index}}
            @connectorTagName="tr"
          />
        {{/each}}
      </tbody>

      <PluginOutlet
        @name="after-topic-list-body"
        @outletArgs={{hash
          topics=@topics
          selected=this.selected
          bulkSelectEnabled=this.bulkSelectEnabled
          lastVisitedTopic=this.lastVisitedTopic
          discoveryList=@discoveryList
          hideCategory=@hideCategory
        }}
      />
    </table>
  </template>
}
