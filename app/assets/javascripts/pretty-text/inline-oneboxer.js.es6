let _cache = {};

export const INLINE_ONEBOX_CSS_CLASS = "inline-onebox-loading";

export function applyInlineOneboxes(inline, ajax) {
  Object.keys(inline).forEach(url => {
    // cache a blank locally, so we never trigger a lookup
    _cache[url] = {};
  });

  return ajax("/inline-onebox", {
    data: { urls: Object.keys(inline) }
  }).then(result => {
    result["inline-oneboxes"].forEach(onebox => {
      if (onebox.title) {
        _cache[onebox.url] = onebox;
        let links = inline[onebox.url] || [];
        links.forEach(link => {
          link.text(onebox.title);
        });
      }
    });
  });
}

export function cachedInlineOnebox(url) {
  return _cache[url];
}
