import { hbs } from "ember-cli-htmlbars";
import { registerWidgetShim } from "discourse/widgets/render-glimmer";

registerWidgetShim(
  "home-logo-wrapper-outlet",
  "div.home-logo-wrapper-outlet",
  hbs`<PluginOutlet @name="home-logo-wrapper"><MountWidget @widget="home-logo" @args={{@data}} /></PluginOutlet>`
);
