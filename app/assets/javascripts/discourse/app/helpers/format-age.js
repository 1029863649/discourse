import { htmlSafe } from "@ember/template";
import { autoUpdatingRelativeAge } from "discourse/lib/formatter";
import { registerUnbound } from "discourse-common/lib/helpers";

registerUnbound("format-age", function (dt) {
  dt = new Date(dt);
  return htmlSafe(autoUpdatingRelativeAge(dt));
});
