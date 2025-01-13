import { h } from "virtual-dom";
import attributeHook from "discourse/lib/attribute-hook";
import deprecated from "discourse/lib/deprecated";
import { isDevelopment } from "discourse/lib/environment";
import escape from "discourse/lib/escape";
import { i18n } from "discourse-i18n";

export const SVG_NAMESPACE = "http://www.w3.org/2000/svg";
let _renderers = [];

let warnMissingIcons = true;
let _iconList;

export const REPLACEMENTS = {
  "d-tracking": "bell",
  "d-muted": "discourse-bell-slash",
  "d-regular": "far-bell",
  "d-watching": "discourse-bell-exclamation",
  "d-watching-first": "discourse-bell-one",
  "d-drop-expanded": "caret-down",
  "d-drop-collapsed": "caret-right",
  "d-unliked": "far-heart",
  "d-liked": "heart",
  "d-post-share": "link",
  "d-topic-share": "link",
  "notification.mentioned": "at",
  "notification.group_mentioned": "users",
  "notification.quoted": "quote-right",
  "notification.replied": "reply",
  "notification.posted": "discourse-bell-exclamation",
  "notification.watching_category_or_tag": "discourse-bell-exclamation",
  "notification.edited": "pencil",
  "notification.bookmark_reminder": "discourse-bookmark-clock",
  "notification.liked": "heart",
  "notification.liked_2": "heart",
  "notification.liked_many": "heart",
  "notification.liked_consolidated": "heart",
  "notification.private_message": "envelope",
  "notification.invited_to_private_message": "envelope",
  "notification.invited_to_topic": "hand-point-right",
  "notification.invitee_accepted": "user",
  "notification.moved_post": "right-from-bracket",
  "notification.linked": "link",
  "notification.linked_consolidated": "link",
  "notification.granted_badge": "certificate",
  "notification.topic_reminder": "far-clock",
  "notification.watching_first_post": "discourse-bell-one",
  "notification.group_message_summary": "users",
  "notification.post_approved": "check",
  "notification.membership_request_accepted": "user-plus",
  "notification.membership_request_consolidated": "users",
  "notification.reaction": "bell",
  "notification.votes_released": "plus",
  "notification.chat_quoted": "quote-right",
  "user_menu.replies": "reply",
  "user_menu.drafts": "pencil",
  "sidebar.all_categories": "list",
};

export function replaceIcon(source, destination) {
  source = handleDeprecatedIcon(source);
  destination = handleDeprecatedIcon(destination);

  REPLACEMENTS[source] = destination;
}

export function disableMissingIconWarning() {
  warnMissingIcons = false;
}

export function enableMissingIconWarning() {
  warnMissingIcons = false;
}

export function renderIcon(renderType, id, params) {
  params ||= {};

  for (const renderer of _renderers) {
    const rendererForType = renderer[renderType];
    if (!rendererForType) {
      continue;
    }

    const icon = { id, replacementId: REPLACEMENTS[id] };
    const result = rendererForType(icon, params);

    if (result) {
      return result;
    }
  }
}

export function iconHTML(id, params) {
  return renderIcon("string", id, params);
}

export function iconNode(id, params) {
  return renderIcon("node", id, params);
}

export function convertIconClass(icon) {
  return icon
    .replace("far fa-", "far-")
    .replace("fab fa-", "fab-")
    .replace("fas fa-", "")
    .replace("fa-", "")
    .trim();
}

export function registerIconRenderer(renderer) {
  _renderers.unshift(renderer);
}

function iconClasses(icon, params) {
  // "notification." is invalid syntax for classes, use replacement instead
  const dClass =
    icon.replacementId && icon.id.includes("notification.")
      ? icon.replacementId
      : icon.id;

  let classNames = `fa d-icon d-icon-${dClass} svg-icon`;

  if (params && params["class"]) {
    classNames += " " + params["class"];
  }

  return classNames;
}

export function setIconList(iconList) {
  _iconList = iconList;
}

export function isExistingIconId(id) {
  return _iconList?.includes(id);
}

function handleDeprecatedIcon(id) {
  let newId = id;

  newId = convertIconClass(newId); // Remap from FA4
  newId = remapFromFA5(newId);

  if (newId !== id) {
    deprecated(
      `The icon name "${id}" has been updated to "${newId}". Please use the new name in your code. Old names will be removed in Q2 2025.`,
      {
        id: "discourse.fontawesome-6-upgrade",
      }
    );
  }

  return newId;
}

function warnIfMissing(id) {
  if (warnMissingIcons && isDevelopment() && !isExistingIconId(id)) {
    console.warn(`The icon "${id}" is missing from the SVG subset.`); // eslint-disable-line no-console
  }
}

function handleIconId(icon) {
  let id = icon.replacementId || icon.id || "";

  // TODO: clean up "thumbtack unpinned" at source instead of here
  id = id.replace(" unpinned", "");

  id = handleDeprecatedIcon(id); // Automatically remap deprecated icon names

  warnIfMissing(id);
  return id;
}

// default resolver is font awesome
registerIconRenderer({
  name: "font-awesome",

  string(icon, params) {
    const id = escape(handleIconId(icon));
    let html = `<svg class='${escape(iconClasses(icon, params))} svg-string'`;

    if (params.label) {
      html += " aria-hidden='true'";
    } else if (params["aria-label"]) {
      html += ` aria-hidden='false' aria-label='${escape(
        params["aria-label"]
      )}'`;
    }
    html += ` xmlns="${SVG_NAMESPACE}"><use href="#${id}" /></svg>`;
    if (params.label) {
      html += `<span class='sr-only'>${escape(params.label)}</span>`;
    }
    if (params.title) {
      html = `<span class="svg-icon-title" title='${escape(
        i18n(params.title)
      )}'>${html}</span>`;
    }

    if (params.translatedtitle) {
      deprecated(`use 'translatedTitle' option instead of 'translatedtitle'`, {
        since: "2.9.0.beta6",
        dropFrom: "2.10.0.beta1",
        id: "discourse.icon-renderer-translatedtitle",
      });
      params.translatedTitle = params.translatedtitle;
    }

    if (params.translatedTitle) {
      html = `<span class="svg-icon-title" title='${escape(
        params.translatedTitle
      )}'>${html}</span>`;
    }
    return html;
  },

  node(icon, params) {
    const id = handleIconId(icon);
    const classes = iconClasses(icon, params) + " svg-node";

    const svg = h(
      "svg",
      {
        attributes: { class: classes, "aria-hidden": true },
        namespace: SVG_NAMESPACE,
      },
      [
        h("use", {
          href: attributeHook("http://www.w3.org/1999/xlink", `#${escape(id)}`),
          namespace: SVG_NAMESPACE,
        }),
      ]
    );

    if (params.title) {
      return h(
        "span",
        {
          title: params.title,
          attributes: { class: "svg-icon-title" },
        },
        [svg]
      );
    } else {
      return svg;
    }
  },
});

function remapFromFA5(id) {
  let lookupId = id;
  let prefix;

  if (id.startsWith("far-")) {
    prefix = "far";
    lookupId = id.replace("far-", "");
  } else if (id.startsWith("fab-")) {
    prefix = "fab";
    lookupId = id.replace("fab-", "");
  }

  if (FA5_REMAPS.hasOwnProperty(lookupId)) {
    let newId = FA5_REMAPS[lookupId];

    if (prefix) {
      newId = `${prefix}-${newId}`;
    }
    return newId;
  }
  return id;
}

// We don't want to carry this list forever, so let's remove it a little after the 3.4 stable release ~Q2 2025
const FA5_REMAPS = {
  adjust: "circle-half-stroke",
  "air-freshener": "spray-can-sparkles",
  "alien-monster": "alien-8bit",
  allergies: "hand-dots",
  ambulance: "truck-medical",
  "american-sign-language-interpreting": "hands-asl-interpreting",
  analytics: "chart-mixed",
  "angle-double-down": "angles-down",
  "angle-double-left": "angles-left",
  "angle-double-right": "angles-right",
  "angle-double-up": "angles-up",
  angry: "face-angry",
  "apple-alt": "apple-whole",
  "apple-crate": "crate-apple",
  archive: "box-archive",
  "arrow-alt-circle-down": "circle-down",
  "arrow-alt-circle-left": "circle-left",
  "arrow-alt-circle-right": "circle-right",
  "arrow-alt-circle-up": "circle-up",
  "arrow-alt-down": "down",
  "arrow-alt-from-bottom": "up-from-line",
  "arrow-alt-from-left": "right-from-line",
  "arrow-alt-from-right": "left-from-line",
  "arrow-alt-from-top": "down-from-line",
  "arrow-alt-left": "left",
  "arrow-alt-right": "right",
  "arrow-alt-square-down": "square-down",
  "arrow-alt-square-left": "square-left",
  "arrow-alt-square-right": "square-right",
  "arrow-alt-square-up": "square-up",
  "arrow-alt-to-bottom": "down-to-line",
  "arrow-alt-to-left": "left-to-line",
  "arrow-alt-to-right": "right-to-line",
  "arrow-alt-to-top": "up-to-line",
  "arrow-alt-up": "up",
  "arrow-circle-down": "circle-arrow-down",
  "arrow-circle-left": "circle-arrow-left",
  "arrow-circle-right": "circle-arrow-right",
  "arrow-circle-up": "circle-arrow-up",
  "arrow-from-bottom": "arrow-up-from-line",
  "arrow-from-left": "arrow-right-from-line",
  "arrow-from-right": "arrow-left-from-line",
  "arrow-from-top": "arrow-down-from-line",
  "arrow-square-down": "square-arrow-down",
  "arrow-square-left": "square-arrow-left",
  "arrow-square-right": "square-arrow-right",
  "arrow-square-up": "square-arrow-up",
  "arrow-to-bottom": "arrow-down-to-line",
  "arrow-to-left": "arrow-left-to-line",
  "arrow-to-right": "arrow-right-to-line",
  "arrow-to-top": "arrow-up-to-line",
  arrows: "arrows-up-down-left-right",
  "arrows-alt": "up-down-left-right",
  "arrows-alt-h": "left-right",
  "arrows-alt-v": "up-down",
  "arrows-h": "arrows-left-right",
  "arrows-v": "arrows-up-down",
  "assistive-listening-systems": "ear-listen",
  atlas: "book-atlas",
  "atom-alt": "atom-simple",
  backspace: "delete-left",
  "balance-scale": "scale-balanced",
  "balance-scale-left": "scale-unbalanced",
  "balance-scale-right": "scale-unbalanced-flip",
  "band-aid": "bandage",
  "barcode-alt": "rectangle-barcode",
  "baseball-ball": "baseball",
  "basketball-ball": "basketball",
  "bed-alt": "bed-front",
  beer: "beer-mug-empty",
  betamax: "cassette-betamax",
  bible: "book-bible",
  biking: "person-biking",
  "biking-mountain": "person-biking-mountain",
  "birthday-cake": "cake-candles",
  blind: "person-walking-with-cane",
  "book-alt": "book-blank",
  "book-dead": "book-skull",
  "book-reader": "book-open-reader",
  "book-spells": "book-sparkles",
  "border-style": "border-top-left",
  "border-style-alt": "border-bottom-right",
  "box-alt": "box-taped",
  "box-fragile": "square-fragile",
  "box-full": "box-open-full",
  "box-up": "square-this-way-up",
  "box-usd": "box-dollar",
  boxes: "boxes-stacked",
  "boxes-alt": "boxes-stacked",
  brackets: "brackets-square",
  "broadcast-tower": "tower-broadcast",
  burn: "fire-flame-simple",
  "bus-alt": "bus-simple",
  "calculator-alt": "calculator-simple",
  "calendar-alt": "calendar-days",
  "calendar-edit": "calendar-pen",
  "calendar-times": "calendar-xmark",
  "camera-alt": "camera",
  "camera-home": "camera-security",
  "car-alt": "car-rear",
  "car-crash": "car-burst",
  "car-mechanic": "car-wrench",
  "caravan-alt": "caravan-simple",
  "caret-circle-down": "circle-caret-down",
  "caret-circle-left": "circle-caret-left",
  "caret-circle-right": "circle-caret-right",
  "caret-circle-up": "circle-caret-up",
  "caret-square-down": "square-caret-down",
  "caret-square-left": "square-caret-left",
  "caret-square-right": "square-caret-right",
  "caret-square-up": "square-caret-up",
  cctv: "camera-cctv",
  "chalkboard-teacher": "chalkboard-user",
  "chart-pie-alt": "chart-pie-simple",
  "check-circle": "circle-check",
  "check-square": "square-check",
  cheeseburger: "burger-cheese",
  "chess-bishop-alt": "chess-bishop-piece",
  "chess-clock-alt": "chess-clock-flip",
  "chess-king-alt": "chess-king-piece",
  "chess-knight-alt": "chess-knight-piece",
  "chess-pawn-alt": "chess-pawn-piece",
  "chess-queen-alt": "chess-queen-piece",
  "chess-rook-alt": "chess-rook-piece",
  "chevron-circle-down": "circle-chevron-down",
  "chevron-circle-left": "circle-chevron-left",
  "chevron-circle-right": "circle-chevron-right",
  "chevron-circle-up": "circle-chevron-up",
  "chevron-double-down": "chevrons-down",
  "chevron-double-left": "chevrons-left",
  "chevron-double-right": "chevrons-right",
  "chevron-double-up": "chevrons-up",
  "chevron-square-down": "square-chevron-down",
  "chevron-square-left": "square-chevron-left",
  "chevron-square-right": "square-chevron-right",
  "chevron-square-up": "square-chevron-up",
  "clinic-medical": "house-chimney-medical",
  "cloud-download": "cloud-arrow-down",
  "cloud-download-alt": "cloud-arrow-down",
  "cloud-upload": "cloud-arrow-up",
  "cloud-upload-alt": "cloud-arrow-up",
  cocktail: "martini-glass-citrus",
  coffee: "mug-saucer",
  "coffee-togo": "cup-togo",
  cog: "gear",
  cogs: "gears",
  columns: "table-columns",
  "comment-alt": "message",
  "comment-alt-check": "message-check",
  "comment-alt-dollar": "message-dollar",
  "comment-alt-dots": "message-dots",
  "comment-alt-edit": "message-pen",
  "comment-alt-exclamation": "message-exclamation",
  "comment-alt-lines": "message-lines",
  "comment-alt-medical": "message-medical",
  "comment-alt-minus": "message-minus",
  "comment-alt-music": "message-music",
  "comment-alt-plus": "message-plus",
  "comment-alt-slash": "message-slash",
  "comment-alt-smile": "message-smile",
  "comment-alt-times": "message-xmark",
  "comment-edit": "comment-pen",
  "comment-times": "comment-xmark",
  "comments-alt": "messages",
  "comments-alt-dollar": "messages-dollar",
  "compress-alt": "down-left-and-up-right-to-center",
  "compress-arrows-alt": "minimize",
  "concierge-bell": "bell-concierge",
  construction: "triangle-person-digging",
  "conveyor-belt-alt": "conveyor-belt-boxes",
  "cowbell-more": "cowbell-circle-plus",
  cricket: "cricket-bat-ball",
  "crop-alt": "crop-simple",
  curling: "curling-stone",
  cut: "scissors",
  deaf: "ear-deaf",
  debug: "ban-bug",
  "desktop-alt": "desktop",
  dewpoint: "droplet-degree",
  diagnoses: "person-dots-from-line",
  digging: "person-digging",
  "digital-tachograph": "tachograph-digital",
  directions: "diamond-turn-right",
  dizzy: "face-dizzy",
  "dolly-flatbed": "cart-flatbed",
  "dolly-flatbed-alt": "cart-flatbed-boxes",
  "dolly-flatbed-empty": "cart-flatbed-empty",
  donate: "circle-dollar-to-slot",
  "dot-circle": "circle-dot",
  "drafting-compass": "compass-drafting",
  "drone-alt": "drone-front",
  "dryer-alt": "dryer-heat",
  "eclipse-alt": "moon-over-sun",
  edit: "pen-to-square",
  "ellipsis-h": "ellipsis",
  "ellipsis-h-alt": "ellipsis-stroke",
  "ellipsis-v": "ellipsis-vertical",
  "ellipsis-v-alt": "ellipsis-stroke-vertical",
  "envelope-square": "square-envelope",
  exchange: "arrow-right-arrow-left",
  "exchange-alt": "right-left",
  "exclamation-circle": "circle-exclamation",
  "exclamation-square": "square-exclamation",
  "exclamation-triangle": "triangle-exclamation",
  "expand-alt": "up-right-and-down-left-from-center",
  "expand-arrows": "arrows-maximize",
  "expand-arrows-alt": "maximize",
  "external-link": "arrow-up-right-from-square",
  "external-link-alt": "up-right-from-square",
  "external-link-square": "square-arrow-up-right",
  "external-link-square-alt": "square-up-right",
  eyedropper: "eye-dropper",
  "fast-backward": "backward-fast",
  "fast-forward": "forward-fast",
  "feather-alt": "feather-pointed",
  female: "person-dress",
  "field-hockey": "field-hockey-stick-ball",
  "fighter-jet": "jet-fighter",
  "file-alt": "file-lines",
  "file-archive": "file-zipper",
  "file-chart-line": "file-chart-column",
  "file-download": "file-arrow-down",
  "file-edit": "file-pen",
  "file-medical-alt": "file-waveform",
  "file-search": "file-magnifying-glass",
  "file-times": "file-xmark",
  "file-upload": "file-arrow-up",
  "film-alt": "film-simple",
  "fire-alt": "fire-flame-curved",
  "first-aid": "kit-medical",
  "fist-raised": "hand-fist",
  "flag-alt": "flag-swallowtail",
  flame: "fire-flame",
  "flask-poison": "flask-round-poison",
  "flask-potion": "flask-round-potion",
  flushed: "face-flushed",
  fog: "cloud-fog",
  "folder-download": "folder-arrow-down",
  "folder-times": "folder-xmark",
  "folder-upload": "folder-arrow-up",
  "font-awesome-alt": "square-font-awesome-stroke",
  "font-awesome-flag": "font-awesome",
  "font-awesome-logo-full": "font-awesome",
  "football-ball": "football",
  fragile: "wine-glass-crack",
  "frosty-head": "snowman-head",
  frown: "face-frown",
  "frown-open": "face-frown-open",
  "funnel-dollar": "filter-circle-dollar",
  "game-board-alt": "game-board-simple",
  "gamepad-alt": "gamepad-modern",
  "glass-champagne": "champagne-glass",
  "glass-cheers": "champagne-glasses",
  "glass-martini": "martini-glass-empty",
  "glass-martini-alt": "martini-glass",
  "glass-whiskey": "whiskey-glass",
  "glass-whiskey-rocks": "whiskey-glass-ice",
  "glasses-alt": "glasses-round",
  "globe-africa": "earth-africa",
  "globe-americas": "earth-americas",
  "globe-asia": "earth-asia",
  "globe-europe": "earth-europe",
  "golf-ball": "golf-ball-tee",
  grimace: "face-grimace",
  grin: "face-grin",
  "grin-alt": "face-grin-wide",
  "grin-beam": "face-grin-beam",
  "grin-beam-sweat": "face-grin-beam-sweat",
  "grin-hearts": "face-grin-hearts",
  "grin-squint": "face-grin-squint",
  "grin-squint-tears": "face-grin-squint-tears",
  "grin-stars": "face-grin-stars",
  "grin-tears": "face-grin-tears",
  "grin-tongue": "face-grin-tongue",
  "grin-tongue-squint": "face-grin-tongue-squint",
  "grin-tongue-wink": "face-grin-tongue-wink",
  "grin-wink": "face-grin-wink",
  "grip-horizontal": "grip",
  "h-square": "square-h",
  hamburger: "burger",
  "hand-holding-usd": "hand-holding-dollar",
  "hand-holding-water": "hand-holding-droplet",
  "hand-paper": "hand",
  "hand-receiving": "hands-holding-diamond",
  "hand-rock": "hand-back-fist",
  "hands-heart": "hands-holding-heart",
  "hands-helping": "handshake-angle",
  "hands-usd": "hands-holding-dollar",
  "hands-wash": "hands-bubbles",
  "handshake-alt": "handshake-simple",
  "handshake-alt-slash": "handshake-simple-slash",
  "hard-hat": "helmet-safety",
  hdd: "hard-drive",
  "head-vr": "head-side-goggles",
  "headphones-alt": "headphones-simple",
  "heart-broken": "heart-crack",
  "heart-circle": "circle-heart",
  "heart-rate": "wave-pulse",
  "heart-square": "square-heart",
  heartbeat: "heart-pulse",
  hiking: "person-hiking",
  history: "clock-rotate-left",
  home: "house",
  "home-alt": "house",
  "home-heart": "house-heart",
  "home-lg": "house-chimney",
  "home-lg-alt": "house",
  "hospital-alt": "hospital",
  "hospital-symbol": "circle-h",
  "hot-tub": "hot-tub-person",
  "hourglass-half": "hourglass",
  "house-damage": "house-chimney-crack",
  "house-leave": "house-person-leave",
  "house-return": "house-person-return",
  hryvnia: "hryvnia-sign",
  humidity: "droplet-percent",
  "icons-alt": "symbols",
  "id-card-alt": "id-card-clip",
  "industry-alt": "industry-windows",
  "info-circle": "circle-info",
  "info-square": "square-info",
  innosoft: "42-group",
  inventory: "shelves",
  "journal-whills": "book-journal-whills",
  kiss: "face-kiss",
  "kiss-beam": "face-kiss-beam",
  "kiss-wink-heart": "face-kiss-wink-heart",
  "landmark-alt": "landmark-dome",
  "laptop-house": "house-laptop",
  laugh: "face-laugh",
  "laugh-beam": "face-laugh-beam",
  "laugh-squint": "face-laugh-squint",
  "laugh-wink": "face-laugh-wink",
  "level-down": "arrow-turn-down",
  "level-down-alt": "turn-down",
  "level-up": "arrow-turn-up",
  "level-up-alt": "turn-up",
  "list-alt": "rectangle-list",
  location: "location-crosshairs",
  "location-circle": "circle-location-arrow",
  "location-slash": "location-crosshairs-slash",
  "lock-alt": "lock-keyhole",
  "lock-open-alt": "lock-keyhole-open",
  "long-arrow-alt-down": "down-long",
  "long-arrow-alt-left": "left-long",
  "long-arrow-alt-right": "right-long",
  "long-arrow-alt-up": "up-long",
  "long-arrow-down": "arrow-down-long",
  "long-arrow-left": "arrow-left-long",
  "long-arrow-right": "arrow-right-long",
  "long-arrow-up": "arrow-up-long",
  "low-vision": "eye-low-vision",
  luchador: "luchador-mask",
  "luggage-cart": "cart-flatbed-suitcase",
  magic: "wand-magic",
  "mail-bulk": "envelopes-bulk",
  male: "person",
  "map-marked": "map-location",
  "map-marked-alt": "map-location-dot",
  "map-marker": "location-pin",
  "map-marker-alt": "location-dot",
  "map-marker-alt-slash": "location-dot-slash",
  "map-marker-check": "location-check",
  "map-marker-edit": "location-pen",
  "map-marker-exclamation": "location-exclamation",
  "map-marker-minus": "location-minus",
  "map-marker-plus": "location-plus",
  "map-marker-question": "location-question",
  "map-marker-slash": "location-pin-slash",
  "map-marker-smile": "location-smile",
  "map-marker-times": "location-xmark",
  "map-signs": "signs-post",
  "mars-stroke-h": "mars-stroke-right",
  "mars-stroke-v": "mars-stroke-up",
  "medium-m": "medium",
  medkit: "suitcase-medical",
  meh: "face-meh",
  "meh-blank": "face-meh-blank",
  "meh-rolling-eyes": "face-rolling-eyes",
  "microphone-alt": "microphone-lines",
  "microphone-alt-slash": "microphone-lines-slash",
  "mind-share": "brain-arrow-curved-right",
  "minus-circle": "circle-minus",
  "minus-hexagon": "hexagon-minus",
  "minus-octagon": "octagon-minus",
  "minus-square": "square-minus",
  "mobile-alt": "mobile-screen-button",
  "mobile-android": "mobile",
  "mobile-android-alt": "mobile-screen",
  "money-bill-alt": "money-bill-1",
  "money-bill-wave-alt": "money-bill-1-wave",
  "money-check-alt": "money-check-dollar",
  "money-check-edit": "money-check-pen",
  "money-check-edit-alt": "money-check-dollar-pen",
  "monitor-heart-rate": "monitor-waveform",
  mouse: "computer-mouse",
  "mouse-alt": "computer-mouse-scrollwheel",
  "mouse-pointer": "arrow-pointer",
  "music-alt": "music-note",
  "music-alt-slash": "music-note-slash",
  "oil-temp": "oil-temperature",
  "page-break": "file-dashed-line",
  "paint-brush": "paintbrush",
  "paint-brush-alt": "paintbrush-fine",
  "paint-brush-fine": "paintbrush-fine",
  "pallet-alt": "pallet-boxes",
  "paragraph-rtl": "paragraph-left",
  parking: "square-parking",
  "parking-circle": "circle-parking",
  "parking-circle-slash": "ban-parking",
  "parking-slash": "square-parking-slash",
  pastafarianism: "spaghetti-monster-flying",
  "pause-circle": "circle-pause",
  "paw-alt": "paw-simple",
  "pen-alt": "pen-clip",
  "pen-square": "square-pen",
  "pencil-alt": "pencil",
  "pencil-paintbrush": "pen-paintbrush",
  "pencil-ruler": "pen-ruler",
  pennant: "flag-pennant",
  "people-arrows": "people-arrows-left-right",
  "people-carry": "people-carry-box",
  percentage: "percent",
  "person-carry": "person-carry-box",
  "phone-alt": "phone-flip",
  "phone-laptop": "laptop-mobile",
  "phone-square": "square-phone",
  "phone-square-alt": "square-phone-flip",
  "photo-video": "photo-film",
  "plane-alt": "plane-engines",
  "play-circle": "circle-play",
  "plus-circle": "circle-plus",
  "plus-hexagon": "hexagon-plus",
  "plus-octagon": "octagon-plus",
  "plus-square": "square-plus",
  poll: "square-poll-vertical",
  "poll-h": "square-poll-horizontal",
  "portal-enter": "person-to-portal",
  "portal-exit": "person-from-portal",
  portrait: "image-portrait",
  "pound-sign": "sterling-sign",
  pray: "person-praying",
  "praying-hands": "hands-praying",
  "prescription-bottle-alt": "prescription-bottle-medical",
  presentation: "presentation-screen",
  "print-search": "print-magnifying-glass",
  procedures: "bed-pulse",
  "project-diagram": "diagram-project",
  "question-circle": "circle-question",
  "question-square": "square-question",
  quran: "book-quran",
  "rabbit-fast": "rabbit-running",
  "radiation-alt": "circle-radiation",
  "radio-alt": "radio-tuner",
  random: "shuffle",
  "rectangle-landscape": "rectangle",
  "rectangle-portrait": "rectangle-vertical",
  redo: "arrow-rotate-right",
  "redo-alt": "rotate-right",
  "remove-format": "text-slash",
  "repeat-1-alt": "arrows-repeat-1",
  "repeat-alt": "arrows-repeat",
  "retweet-alt": "arrows-retweet",
  "rss-square": "square-rss",
  running: "person-running",
  "sad-cry": "face-sad-cry",
  "sad-tear": "face-sad-tear",
  save: "floppy-disk",
  "sax-hot": "saxophone-fire",
  "scalpel-path": "scalpel-line-dashed",
  "scanner-image": "scanner",
  search: "magnifying-glass",
  "search-dollar": "magnifying-glass-dollar",
  "search-location": "magnifying-glass-location",
  "search-minus": "magnifying-glass-minus",
  "search-plus": "magnifying-glass-plus",
  "sensor-alert": "sensor-triangle-exclamation",
  "sensor-smoke": "sensor-cloud",
  "share-alt": "share-nodes",
  "share-alt-square": "square-share-nodes",
  "share-square": "share-from-square",
  "shield-alt": "shield-halved",
  "shipping-fast": "truck-fast",
  "shipping-timed": "truck-clock",
  "shopping-bag": "bag-shopping",
  "shopping-basket": "basket-shopping",
  "shopping-cart": "cart-shopping",
  "shuttle-van": "van-shuttle",
  sign: "sign-hanging",
  "sign-in": "arrow-right-to-bracket",
  "sign-in-alt": "right-to-bracket",
  "sign-language": "hands",
  "sign-out": "arrow-right-from-bracket",
  "sign-out-alt": "right-from-bracket",
  "signal-1": "signal-weak",
  "signal-2": "signal-fair",
  "signal-3": "signal-good",
  "signal-4": "signal-strong",
  "signal-alt": "signal-bars",
  "signal-alt-1": "signal-bars-weak",
  "signal-alt-2": "signal-bars-fair",
  "signal-alt-3": "signal-bars-good",
  "signal-alt-slash": "signal-bars-slash",
  skating: "person-skating",
  "ski-jump": "person-ski-jumping",
  "ski-lift": "person-ski-lift",
  skiing: "person-skiing",
  "skiing-nordic": "person-skiing-nordic",
  "slack-hash": "slack",
  sledding: "person-sledding",
  "sliders-h": "sliders",
  "sliders-h-square": "square-sliders",
  "sliders-v": "sliders-up",
  "sliders-v-square": "square-sliders-vertical",
  smile: "face-smile",
  "smile-beam": "face-smile-beam",
  "smile-plus": "face-smile-plus",
  "smile-wink": "face-smile-wink",
  "smoking-ban": "ban-smoking",
  sms: "comment-sms",
  "snapchat-ghost": "snapchat",
  snowboarding: "person-snowboarding",
  snowmobile: "person-snowmobiling",
  "sort-alpha-down": "arrow-down-a-z",
  "sort-alpha-down-alt": "arrow-down-z-a",
  "sort-alpha-up": "arrow-up-a-z",
  "sort-alpha-up-alt": "arrow-up-z-a",
  "sort-alt": "arrow-down-arrow-up",
  "sort-amount-down": "arrow-down-wide-short",
  "sort-amount-down-alt": "arrow-down-short-wide",
  "sort-amount-up": "arrow-up-wide-short",
  "sort-amount-up-alt": "arrow-up-short-wide",
  "sort-circle": "circle-sort",
  "sort-circle-down": "circle-sort-down",
  "sort-circle-up": "circle-sort-up",
  "sort-numeric-down": "arrow-down-1-9",
  "sort-numeric-down-alt": "arrow-down-9-1",
  "sort-numeric-up": "arrow-up-1-9",
  "sort-numeric-up-alt": "arrow-up-9-1",
  "sort-shapes-down": "arrow-down-triangle-square",
  "sort-shapes-down-alt": "arrow-down-square-triangle",
  "sort-shapes-up": "arrow-up-triangle-square",
  "sort-shapes-up-alt": "arrow-up-square-triangle",
  "sort-size-down": "arrow-down-big-small",
  "sort-size-down-alt": "arrow-down-small-big",
  "sort-size-up": "arrow-up-big-small",
  "sort-size-up-alt": "arrow-up-small-big",
  soup: "bowl-hot",
  "space-shuttle": "shuttle-space",
  "space-station-moon-alt": "space-station-moon-construction",
  "square-root-alt": "square-root-variable",
  "star-half-alt": "star-half-stroke",
  "starfighter-alt": "starfighter-twin-ion-engine",
  "step-backward": "backward-step",
  "step-forward": "forward-step",
  "sticky-note": "note-sticky",
  "stop-circle": "circle-stop",
  "store-alt": "shop",
  "store-alt-slash": "shop-slash",
  stream: "bars-staggered",
  subway: "train-subway",
  surprise: "face-surprise",
  swimmer: "person-swimming",
  "swimming-pool": "water-ladder",
  sync: "arrows-rotate",
  "sync-alt": "rotate",
  "table-tennis": "table-tennis-paddle-ball",
  "tablet-alt": "tablet-screen-button",
  "tablet-android": "tablet",
  "tablet-android-alt": "tablet-screen",
  tachometer: "gauge-simple",
  "tachometer-alt": "gauge",
  "tachometer-alt-average": "gauge-med",
  "tachometer-alt-fast": "gauge",
  "tachometer-alt-fastest": "gauge-max",
  "tachometer-alt-slow": "gauge-low",
  "tachometer-alt-slowest": "gauge-min",
  "tachometer-average": "gauge-simple-med",
  "tachometer-fast": "gauge-simple",
  "tachometer-fastest": "gauge-simple-max",
  "tachometer-slow": "gauge-simple-low",
  "tachometer-slowest": "gauge-simple-min",
  tanakh: "book-tanakh",
  tasks: "list-check",
  "tasks-alt": "bars-progress",
  "telegram-plane": "telegram",
  "temperature-down": "temperature-arrow-down",
  "temperature-frigid": "temperature-snow",
  "temperature-hot": "temperature-sun",
  "temperature-up": "temperature-arrow-up",
  tenge: "tenge-sign",
  th: "table-cells",
  "th-large": "table-cells-large",
  "th-list": "table-list",
  "theater-masks": "masks-theater",
  "thermometer-empty": "temperature-empty",
  "thermometer-full": "temperature-full",
  "thermometer-half": "temperature-half",
  "thermometer-quarter": "temperature-quarter",
  "thermometer-three-quarters": "temperature-three-quarters",
  "thumb-tack": "thumbtack",
  thunderstorm: "cloud-bolt",
  "thunderstorm-moon": "cloud-bolt-moon",
  "thunderstorm-sun": "cloud-bolt-sun",
  "ticket-alt": "ticket-simple",
  times: "xmark",
  "times-circle": "circle-xmark",
  "times-hexagon": "hexagon-xmark",
  "times-octagon": "octagon-xmark",
  "times-square": "square-xmark",
  tint: "droplet",
  "tint-slash": "droplet-slash",
  tired: "face-tired",
  "toilet-paper-alt": "toilet-paper-blank",
  "tombstone-alt": "tombstone-blank",
  tools: "screwdriver-wrench",
  torah: "scroll-torah",
  tram: "train-tram",
  "transgender-alt": "transgender",
  "trash-alt": "trash-can",
  "trash-restore": "trash-arrow-up",
  "trash-restore-alt": "trash-can-arrow-up",
  "trash-undo-alt": "trash-can-undo",
  "tree-alt": "tree-deciduous",
  "triangle-music": "triangle-instrument",
  "trophy-alt": "trophy-star",
  "truck-couch": "truck-ramp-couch",
  "truck-loading": "truck-ramp-box",
  tshirt: "shirt",
  "tv-alt": "tv",
  undo: "arrow-rotate-left",
  "undo-alt": "rotate-left",
  university: "building-columns",
  unlink: "link-slash",
  "unlock-alt": "unlock-keyhole",
  "usd-circle": "circle-dollar",
  "usd-square": "square-dollar",
  "user-alt": "user-large",
  "user-alt-slash": "user-large-slash",
  "user-chart": "chart-user",
  "user-circle": "circle-user",
  "user-cog": "user-gear",
  "user-edit": "user-pen",
  "user-friends": "user-group",
  "user-hard-hat": "user-helmet-safety",
  "user-md": "user-doctor",
  "user-md-chat": "user-doctor-message",
  "user-times": "user-xmark",
  "users-class": "screen-users",
  "users-cog": "users-gear",
  "users-crown": "user-group-crown",
  "utensil-fork": "fork",
  "utensil-knife": "knife",
  "utensil-spoon": "spoon",
  "utensils-alt": "fork-knife",
  vhs: "cassette-vhs",
  "volleyball-ball": "volleyball",
  "volume-down": "volume-low",
  "volume-mute": "volume-xmark",
  "volume-up": "volume-high",
  "vote-nay": "xmark-to-slot",
  "vote-yea": "check-to-slot",
  walking: "person-walking",
  "warehouse-alt": "warehouse-full",
  washer: "washing-machine",
  "water-lower": "water-arrow-down",
  "water-rise": "water-arrow-up",
  "waveform-path": "waveform-lines",
  webcam: "camera-web",
  "webcam-slash": "camera-web-slash",
  weight: "weight-scale",
  "wifi-1": "wifi-weak",
  "wifi-2": "wifi-fair",
  "window-alt": "window-flip",
  "window-close": "rectangle-xmark",
  "wine-glass-alt": "wine-glass-empty",
};
