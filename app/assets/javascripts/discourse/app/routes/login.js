import { next } from "@ember/runloop";
import { service } from "@ember/service";
import { defaultHomepage } from "discourse/lib/utilities";
import StaticPage from "discourse/models/static-page";
import DiscourseRoute from "discourse/routes/discourse";

export default class LoginRoute extends DiscourseRoute {
  @service siteSettings;
  @service router;

  // `login-page` because `login` controller is the one for
  // the login modal
  controllerName = "login-page";

  beforeModel() {
    if (
      !this.siteSettings.login_required &&
      !this.siteSettings.experimental_full_page_login
    ) {
      this.router
        .replaceWith(`/${defaultHomepage()}`)
        .followRedirects()
        .then((e) => next(() => e.send("showLogin")));
    }
  }

  model() {
    if (!this.siteSettings.experimental_full_page_login) {
      return StaticPage.find("login");
    }
  }

  setupController(controller) {
    const { canSignUp } = this.controllerFor("application");
    controller.set("canSignUp", canSignUp);
    controller.set("flashType", "");
    controller.set("flash", "");
  }
}
