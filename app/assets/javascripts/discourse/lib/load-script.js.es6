/* global assetPath */

const _loaded = {};

function loadWithTag(path, cb) {
  const head = document.getElementsByTagName('head')[0];

  let s = document.createElement('script');
  s.src = path;
  head.appendChild(s);

  s.onload = s.onreadystatechange = function(_, abort) {
    if (abort || !s.readyState || s.readyState === "loaded" || s.readyState === "complete") {
      s = s.onload = s.onreadystatechange = null;
      if (!abort) { cb(); }
    }
  };
}

export default function loadScript(url, opts) {
  opts = opts || {};

  return new Ember.RSVP.Promise(function(resolve) {
    url = Discourse.getURL((assetPath && assetPath(url)) || url);

    // If we already loaded this url
    if (_loaded[url]) { return resolve(); }

    const cb = function() {
      _loaded[url] = true;
      resolve();
    };

    // Some javascript depends on the path of where it is loaded (ace editor)
    // to dynamically load more JS. In that case, add the `scriptTag: true`
    // option.
    if (opts.scriptTag) {
      loadWithTag(url, cb);
    } else {
      $.getScript(url).then(cb);
    }
  });
}
