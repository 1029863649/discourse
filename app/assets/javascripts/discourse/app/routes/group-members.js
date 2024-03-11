import { service } from "@ember/service";
import DiscourseRoute from "discourse/routes/discourse";

export default DiscourseRoute.extend({
  router: service(),

  beforeModel() {
    this.router.transitionTo("group.index");
  },
});
