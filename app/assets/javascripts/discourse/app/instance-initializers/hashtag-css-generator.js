import { getHashtagTypeClasses } from "discourse/lib/hashtag-type-registry";

export default {
  after: "category-color-css-generator",

  /**
   * This generates CSS classes for each hashtag type,
   * which are used to color the hashtag icons in the composer,
   * cooked posts, and the sidebar.
   *
   * Each type has its own corresponding class, which is registered
   * with the hastag type via api.registerHashtagType. The default
   * ones in core are CategoryHashtagType and TagHashtagType.
   */
  initialize(owner) {
    this.site = owner.lookup("service:site");

    let generatedCssClasses = [];

    Object.values(getHashtagTypeClasses()).forEach((hashtagType) => {
      hashtagType.preloadedData.forEach((model) => {
        generatedCssClasses = generatedCssClasses.concat(
          hashtagType.generateColorCssClasses(model)
        );
      });
    });

    const cssTag = document.createElement("style");
    cssTag.type = "text/css";
    cssTag.id = "hashtag-css-generator";
    cssTag.innerHTML = generatedCssClasses.join("\n");
    document.head.appendChild(cssTag);
  },
};
