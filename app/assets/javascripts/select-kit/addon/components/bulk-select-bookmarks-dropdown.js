import { action } from "@ember/object";
import { service } from "@ember/service";
import { popupAjaxError } from "discourse/lib/ajax-error";
import Bookmark from "discourse/models/bookmark";
import i18n from "discourse-common/helpers/i18n";
import DropdownSelectBoxComponent from "select-kit/components/dropdown-select-box";

const _customButtons = [];
const _customActions = {};

export function addBulkDropdownAction(name, customAction) {
  _customActions[name] = customAction;
}

export function addBulkDropdownButton(opts) {
  _customButtons.push({
    id: opts.label,
    icon: opts.icon,
    name: i18n(opts.label),
    visible: opts.visible,
  });
  addBulkDropdownAction(opts.label, opts.action);
}

export default DropdownSelectBoxComponent.extend({
  classNames: ["bulk-select-bookmarks-dropdown"],
  headerIcon: null,
  showFullTitle: true,
  selectKitOptions: {
    showCaret: true,
    showFullTitle: true,
    none: "select_kit.components.bulk_select_bookmarks_dropdown.title",
  },

  router: service(),
  toasts: service(),
  dialog: service(),

  computeContent() {
    let options = [];
    options = options.concat([
      {
        id: "clear-reminders",
        icon: "tag",
        name: i18n("bookmark_bulk_actions.clear_reminders.name"),
      },
      {
        id: "delete-bookmarks",
        icon: "trash-alt",
        name: i18n("bookmark_bulk_actions.delete_bookmarks.name"),
      },
    ]);

    return [...options, ..._customButtons];
  },

  showBulkBookmarksActionsModal(operationType, description, successMessage) {
    this.dialog.yesNoConfirm({
      message: description,
      didConfirm: () => {
        Bookmark.bulkOperation(this.getSelectedBookmarks(), {
          type: operationType,
        })
          .then(() => {
            this.router.refresh();
            this.bulkSelectHelper.toggleBulkSelect();
            this.toasts.success({
              duration: 3000,
              data: { message: successMessage },
            });
          })
          .catch(popupAjaxError);
      },
    });
  },

  getSelectedBookmarks() {
    return this.bulkSelectHelper.selected;
  },

  @action
  onSelect(id) {
    switch (id) {
      case "clear-reminders":
        this.showBulkBookmarksActionsModal(
          "clear_reminder",
          i18n(`js.bookmark_bulk_actions.clear_reminders.description`, {
            count: this.getSelectedBookmarks().length,
          }),
          i18n("bookmarks.bulk.reminders_cleared")
        );
        break;
      case "delete-bookmarks":
        this.showBulkBookmarksActionsModal(
          "delete",
          i18n(`js.bookmark_bulk_actions.delete_bookmarks.description`, {
            count: this.getSelectedBookmarks().length,
          }),
          i18n("bookmarks.bulk.delete_completed")
        );
        break;
    }
  },
});
