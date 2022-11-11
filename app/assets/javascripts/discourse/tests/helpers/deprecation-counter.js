import { registerDeprecationHandler } from "@ember/debug";
import { bind } from "discourse-common/utils/decorators";

export default class DeprecationCounter {
  counts = new Map();
  #configById = new Map();

  constructor(config) {
    for (const c of config) {
      this.#configById.set(c.matchId, c.handler);
    }
  }

  start() {
    registerDeprecationHandler(this.handleDeprecation);
  }

  @bind
  handleDeprecation(message, options, next) {
    const { id } = options;
    const matchingConfig = this.#configById.get(id);

    if (matchingConfig !== "silence") {
      const existingCount = this.counts.get(id) || 0;
      this.counts.set(id, existingCount + 1);
    }

    next(message, options);
  }

  get hasDeprecations() {
    return this.counts.size > 0;
  }

  generateTable() {
    const maxIdLength = Math.max(
      ...Array.from(this.counts.keys()).map((k) => k.length)
    );

    let msg = `| ${"id".padEnd(maxIdLength)} | count |\n`;
    msg += `| ${"".padEnd(maxIdLength, "-")} | ----- |\n`;

    for (const [id, count] of this.counts.entries()) {
      const countString = count.toString();
      msg += `| ${id.padEnd(maxIdLength)} | ${countString.padStart(5)} |\n`;
    }

    return msg;
  }
}

function reportToTestem(counts) {
  window.Testem.useCustomAdapter(function (socket) {
    socket.emit("test-metadata", "deprecation-counts", {
      counts: Array.from(counts.entries()),
    });
  });
}

export function setupDeprecationCounter(qunit) {
  const config = window.deprecationWorkflow?.config?.workflow || {};
  const deprecationCounter = new DeprecationCounter(config);

  qunit.begin(() => deprecationCounter.start());

  qunit.done(() => {
    if (window.Testem) {
      reportToTestem(deprecationCounter.counts);
    } else if (deprecationCounter.hasDeprecations) {
      // eslint-disable-next-line no-console
      console.warn(
        `[Discourse Deprecation Counter] Test run completed with deprecations:\n\n${deprecationCounter.generateTable()}`
      );
    } else {
      // eslint-disable-next-line no-console
      console.log("[Discourse Deprecation Counter] No deprecations found");
    }
  });
}
