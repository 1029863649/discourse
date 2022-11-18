// NOTE: For future maintainers, the hashtag lookup here does not take
// into account mixed contexts -- for instance, a chat quote inside a post
// or a post quote inside a chat message, so hashtagTypesInPriorityOrder may
// not provide an accurate lookup for hashtags without a ::type suffix in those
// cases if there are conflcting types of resources with the same slug.

function addHashtag(buffer, matches, state) {
  const options = state.md.options.discourse;
  const slug = matches[1];
  const hashtagLookup = options.hashtagLookup;

  // NOTE: The lookup function is only run when cooking
  // server-side, and will only return a single result based on the
  // slug lookup.
  const result =
    hashtagLookup &&
    hashtagLookup(
      slug,
      options.currentUser,
      options.hashtagTypesInPriorityOrder
    );

  // NOTE: When changing the HTML structure here, you must also change
  // it in the placeholder HTML code inside lib/hashtag-autocomplete, and vice-versa.
  let token;
  if (result) {
    token = new state.Token("link_open", "a", 1);
    token.attrs = [
      ["class", "hashtag-cooked"],
      ["href", result.relative_url],
      ["data-type", result.type],
      ["data-slug", result.slug],
    ];
    token.block = false;
    buffer.push(token);

    token = new state.Token("svg_open", "svg", 1);
    token.block = false;
    token.attrs = [
      ["class", `fa d-icon d-icon-${result.icon} svg-icon svg-node`],
    ];
    buffer.push(token);

    token = new state.Token("use_open", "use", 1);
    token.block = false;
    token.attrs = [["href", `#${result.icon}`]];
    buffer.push(token);

    buffer.push(new state.Token("use_close", "use", -1));
    buffer.push(new state.Token("svg_close", "svg", -1));

    token = new state.Token("span_open", "span", 1);
    token.block = false;
    buffer.push(token);

    token = new state.Token("text", "", 0);
    token.content = result.text;
    buffer.push(token);

    buffer.push(new state.Token("span_close", "span", -1));

    buffer.push(new state.Token("link_close", "a", -1));
  } else {
    token = new state.Token("span_open", "span", 1);
    token.attrs = [["class", "hashtag-raw"]];
    buffer.push(token);

    token = new state.Token("svg_open", "svg", 1);
    token.block = false;
    token.attrs = [["class", `fa d-icon d-icon-hashtag svg-icon svg-node`]];
    buffer.push(token);

    token = new state.Token("use_open", "use", 1);
    token.block = false;
    token.attrs = [["href", `#hashtag`]];
    buffer.push(token);

    buffer.push(new state.Token("use_close", "use", -1));
    buffer.push(new state.Token("svg_close", "svg", -1));

    token = new state.Token("span_open", "span", 1);
    token = new state.Token("text", "", 0);
    token.content = matches[0].replace("#", "");
    buffer.push(token);
    token = new state.Token("span_close", "span", -1);

    token = new state.Token("span_close", "span", -1);
    buffer.push(token);
  }
}

export function setup(helper) {
  const opts = helper.getOptions();

  // we do this because plugins can register their own hashtag data
  // sources which specify an icon, and each icon must be allowlisted
  // or it will not render in the markdown pipeline
  const hashtagIconAllowList = opts.hashtagIcons
    ? opts.hashtagIcons
        .concat(["hashtag"])
        .map((icon) => {
          return [
            `svg[class=fa d-icon d-icon-${icon} svg-icon svg-node]`,
            `use[href=#${icon}]`,
          ];
        })
        .flat()
    : [];

  helper.registerPlugin((md) => {
    if (
      md.options.discourse.limitedSiteSettings
        .enableExperimentalHashtagAutocomplete
    ) {
      const rule = {
        matcher: /#([\u00C0-\u1FFF\u2C00-\uD7FF\w:-]{1,101})/,
        onMatch: addHashtag,
      };

      md.core.textPostProcess.ruler.push("hashtag-autocomplete", rule);
    }
  });

  helper.allowList(
    hashtagIconAllowList.concat([
      "a.hashtag-cooked",
      "span.hashtag-raw",
      "a[data-type]",
      "a[data-slug]",
    ])
  );
}
