import { click, visit } from "@ember/test-helpers";
import { test } from "qunit";
import {
  acceptance,
  updateCurrentUser,
  queryAll,
} from "discourse/tests/helpers/qunit-helpers";

acceptance("Opening the hamburger menu with some reviewables", function (
  needs
) {
  needs.user();
  needs.pretender((server, helper) => {
    server.get("/review/count.json", () => helper.response({ count: 3 }));
  });
  test("As a staff member", async function (assert) {
    updateCurrentUser({ moderator: true, admin: false });

    await visit("/");
    await click(".hamburger-dropdown");

    assert.equal(
      queryAll(".review .badge-notification.reviewables").text(),
      "3"
    );
  });
});
