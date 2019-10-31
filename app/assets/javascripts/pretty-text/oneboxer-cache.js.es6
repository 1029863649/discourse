export let localCache = {};
export let failedCache = {};

// Sometimes jQuery will return URLs with trailing slashes when the
// `href` didn't have them.
export function normalize(url) {
  return url.replace(/\/$/, "");
}

export function lookupCache(url) {
  const cached = localCache[normalize(url)];
  return cached && cached.prop("outerHTML");
}

