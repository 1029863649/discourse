import discourseComputed from "discourse-common/utils/decorators";
import Component from "@ember/component";

export default Component.extend({
  @discourseComputed("field.choices")
  choices(choices) {
    choices.forEach(choice => {
      choice.style = `font-family: ${choice.data.font_stack}`.htmlSafe();
    });

    return choices;
  },

  actions: {
    changed(value) {
      this.set("field.value", value);
    }
  }
});
