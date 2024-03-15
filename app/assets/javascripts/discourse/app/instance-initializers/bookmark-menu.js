import { withPluginApi } from "discourse/lib/plugin-api";
import PostBookmarkManager from "discourse/lib/post-bookmark-manager";

export default {
  name: "discourse-bookmark-menu",

  initialize(container) {
    const currentUser = container.lookup("service:current-user");

    withPluginApi("0.10.1", (api) => {
      api.replacePostMenuButton("bookmark", {
        name: "bookmark-menu-shim",
        shouldRender: () => true,
        buildAttrs: (widget) => {
          if (!currentUser) {
            return {};
          }

          return {
            post: widget.findAncestorModel(),
            bookmarkManager: new PostBookmarkManager(
              container,
              widget.findAncestorModel()
            ),
          };
        },
      });
    });
  },
};
