import setupDeprecationWorkflow from "ember-cli-deprecation-workflow";

const DEPRECATION_WORKFLOW = [
  {
    handler: "silence",
    matchId: "ember-this-fallback.this-property-fallback",
  },
  { handler: "silence", matchId: "discourse.select-kit" },
  { handler: "silence", matchId: "discourse.d-section" },
  {
    handler: "silence",
    matchId: "discourse.decorate-widget.hamburger-widget-links",
  },
];

// We're using RAISE_ON_DEPRECATION in environment.js instead of
// `throwOnUnhandled` here since it is easier to toggle.
setupDeprecationWorkflow({ workflow: DEPRECATION_WORKFLOW });

export default DEPRECATION_WORKFLOW;
