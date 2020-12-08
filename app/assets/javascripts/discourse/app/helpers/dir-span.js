import { helperContext, registerUnbound } from "discourse-common/lib/helpers";
import { htmlSafe } from "@ember/template";
import { isRTL } from "discourse/lib/text-direction";

function setDir(text) {
  let content = text ? text : "";
  let siteSettings = helperContext().siteSettings;
  if (content && siteSettings.support_mixed_text_direction) {
    let textDir = isRTL(content) ? "rtl" : "ltr";
    return `<span dir="${textDir}">${content}</span>`;
  }
  return content;
}

export default registerUnbound("dir-span", function (str) {
  return htmlSafe(setDir(str));
});
