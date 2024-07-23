import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import willDestroy from "@ember/render-modifiers/modifiers/will-destroy";
import { service } from "@ember/service";
import { modifier as modifierFn } from "ember-modifier";
import DButton from "discourse/components/d-button";
import concatClass from "discourse/helpers/concat-class";
import htmlClass from "discourse/helpers/html-class";
import { postRNWebviewMessage } from "discourse/lib/utilities";
import { SCROLLED_UP, UNSCROLLED } from "discourse/services/scroll-direction";
import { bind } from "discourse-common/utils/decorators";
import not from "truth-helpers/helpers/not";

class FooterNav extends Component {
  @service appEvents;
  @service capabilities;
  @service scrollDirection;
  @service composer;
  @service modal;

  @tracked shouldToggleMobileFooter = false;
  @tracked canGoBack = false;
  @tracked canGoForward = false;

  currentRouteIndex = 0;
  routeHistory = [];
  backForwardClicked = false;

  registerAppEvents = modifierFn(() => {
    this.appEvents.on("page:changed", this, "_routeChanged");

    return () => {
      this.appEvents.off("page:changed", this, "_routeChanged");
    };
  });

  @bind
  registerDirectionObserver() {
    this.scrollDirection.addObserver(
      "lastScrollDirection",
      this.toggleMobileFooter
    );
  }

  @bind
  unregisterDirectionObserver() {
    this.scrollDirection.removeObserver(
      "lastScrollDirection",
      this.toggleMobileFooter
    );
  }

  @action
  _routeChanged(route) {
    // only update route history if not using back/forward nav
    if (this.backForwardClicked) {
      this.backForwardClicked = null;
      return;
    }

    this.routeHistory.push(route.url);
    this.currentRouteIndex = this.routeHistory.length;
    this.setBackForward();
  }

  get isFooterVisible() {
    return !this.composer.isOpen && this.shouldToggleMobileFooter;
  }

  _modalOn() {
    const backdrop = document.querySelector(".modal-backdrop");
    if (backdrop) {
      postRNWebviewMessage(
        "headerBg",
        getComputedStyle(backdrop)["background-color"]
      );
    }
  }

  _modalOff() {
    const dheader = document.querySelector(".d-header");
    if (!dheader) {
      return;
    }

    postRNWebviewMessage(
      "headerBg",
      getComputedStyle(dheader)["background-color"]
    );
  }

  @action
  setDiscourseHubHeaderBg(hasAnActiveModal) {
    if (!this.capabilities.isAppWebview) {
      return;
    }

    if (hasAnActiveModal) {
      this._modalOn();
    } else {
      this._modalOff();
    }
  }

  @action
  dismiss() {
    postRNWebviewMessage("dismiss", true);
  }

  @action
  share() {
    postRNWebviewMessage("shareUrl", window.location.href);
  }

  @action
  goBack() {
    this.currentRouteIndex = this.currentRouteIndex - 1;
    this.setBackForward();
    this.backForwardClicked = true;
    window.history.back();
  }

  @action
  goForward() {
    this.currentRouteIndex = this.currentRouteIndex + 1;
    this.setBackForward();
    this.backForwardClicked = true;
    window.history.forward();
  }

  @bind
  toggleMobileFooter() {
    this.shouldToggleMobileFooter = [UNSCROLLED, SCROLLED_UP].includes(
      this.scrollDirection.lastScrollDirection
    );
  }

  setBackForward() {
    this.canGoBack =
      this.currentRouteIndex > 1 || document.referrer ? true : false;
    this.canGoForward =
      this.currentRouteIndex < this.routeHistory.length ? true : false;
  }

  <template>
    {{this.setDiscourseHubHeaderBg this.modal.activeModal}}

    {{#if this.capabilities.isIpadOS}}
      {{htmlClass "footer-nav-ipad"}}
    {{else}}
      {{#unless this.mobileScrollDirection}}
        {{htmlClass "footer-nav-visible"}}
      {{/unless}}
    {{/if}}

    <div
      class={{concatClass "footer-nav" (if this.isFooterVisible "visible")}}
      {{didInsert this.registerDirectionObserver}}
      {{willDestroy this.unregisterDirectionObserver}}
      {{this.registerAppEvents}}
    >
      <div class="footer-nav-widget">
        <DButton
          @action={{this.goBack}}
          @icon="chevron-left"
          class="btn-flat btn-large"
          @disabled={{not this.canGoBack}}
          @title="footer_nav.back"
        />

        <DButton
          @action={{this.goForward}}
          @icon="chevron-right"
          class="btn-flat btn-large"
          @disabled={{not this.canGoForward}}
          @title="footer_nav.forward"
        />

        {{#if this.capabilities.isAppWebview}}
          <DButton
            @action={{this.share}}
            @icon="link"
            class="btn-flat btn-large"
            @title="footer_nav.share"
          />

          <DButton
            @action={{this.dismiss}}
            @icon="chevron-down"
            class="btn-flat btn-large"
            @title="footer_nav.dismiss"
          />
        {{/if}}
      </div>
    </div>
  </template>
}

export default FooterNav;
