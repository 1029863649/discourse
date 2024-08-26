import { action } from "@ember/object";
import { equal } from "@ember/object/computed";
import { isEmpty } from "@ember/utils";
import { classNames } from "@ember-decorators/component";
import ComboBoxComponent from "select-kit/components/combo-box";
import {
  pluginApiIdentifiers,
  selectKitOptions,
} from "select-kit/components/select-kit";

export const FORMAT = "YYYY-MM-DD HH:mmZ";

@classNames("future-date-input-selector")
@selectKitOptions({
  autoInsertNoneItem: false,
  headerComponent:
    "future-date-input-selector/future-date-input-selector-header",
})
@pluginApiIdentifiers("future-date-input-selector")
export default class FutureDateInputSelector extends ComboBoxComponent {
  @equal("value", "custom") isCustom;

  userTimezone = null;

  init() {
    super.init(...arguments);
    this.userTimezone = this.currentUser.user_option.timezone;
  }

  modifyComponentForRow() {
    return "future-date-input-selector/future-date-input-selector-row";
  }

  @action
  _onChange(value) {
    if (value !== "custom" && !isEmpty(value)) {
      const { time } = this.content.find((x) => x.id === value);
      if (time) {
        this.onChangeInput?.(time.locale("en").format(FORMAT));
      }
    }

    this.onChange?.(value);
  }
}
