// Gives a light email a dark page (original view, dark theme, "Darken emails" on).
// The Mac app's dark_mail.js, as it is: keep the two the same.
//
// This is Nimbra's script, not the mail's: it runs in a WebKit world of its own while the
// page's scripts stay off. The mail is hostile input, so this file only reads computed
// colours and sets inline ones: no markup, no network, no messages to the app. The DOM is
// read through prototype getters, because an element named "style" or "body" shadows the
// property of that name.
//
// Colours keep their hue and have their lightness flipped (in OKLab). A light backdrop goes
// dark, and text changes only where its backdrop did. Pictures, form fields and whatever
// sits on a background image stay as sent, and so does a light box (a button, a card) on a
// dark background the mail painted itself: it was designed for the dark.
(() => {
  'use strict';

  const SURFACE = [14, 14, 20]; // bg/list (Dark): MailWebConfiguration sets it from the colour set
  const WHITE = [255, 255, 255];
  const DARK_CANVAS = [30, 30, 30]; // WebKit's own page for mail that declares it can be dark
  const MAX_ELEMENTS = 15000;
  const MAX_MS = 250;

  const getter = (proto, name) => Object.getOwnPropertyDescriptor(proto, name).get;
  const rootOf = getter(Document.prototype, 'documentElement');
  const bodyOf = getter(Document.prototype, 'body');
  const parentOf = getter(Node.prototype, 'parentNode');
  const styleOf = getter(HTMLElement.prototype, 'style');
  const tagOf = getter(Element.prototype, 'localName');
  const setSheets = Object.getOwnPropertyDescriptor(Document.prototype, 'adoptedStyleSheets').set;
  const queryAll = Document.prototype.querySelectorAll;
  const createWalker = Document.prototype.createTreeWalker;
  const attribute = Element.prototype.getAttribute;
  const setProperty = CSSStyleDeclaration.prototype.setProperty;

  const toLinear = (v) => {
    const x = v / 255;
    return x <= 0.04045 ? x / 12.92 : ((x + 0.055) / 1.055) ** 2.4;
  };
  const toGamma = (v) => {
    const x = v <= 0.0031308 ? 12.92 * v : 1.055 * v ** (1 / 2.4) - 0.055;
    return 255 * Math.min(1, Math.max(0, x));
  };
  const toLab = (rgb) => {
    const [r, g, b] = rgb.map(toLinear);
    const l = Math.cbrt(0.4122214708 * r + 0.5363325363 * g + 0.0514459929 * b);
    const m = Math.cbrt(0.2119034982 * r + 0.6806995451 * g + 0.1073969566 * b);
    const s = Math.cbrt(0.0883024619 * r + 0.2817188376 * g + 0.6299787005 * b);
    return [
      0.2104542553 * l + 0.793617785 * m - 0.0040720468 * s,
      1.9779984951 * l - 2.428592205 * m + 0.4505937099 * s,
      0.0259040371 * l + 0.7827717662 * m - 0.808675766 * s,
    ];
  };
  const fromLab = ([L, a, b]) => {
    const l = (L + 0.3963377774 * a + 0.2158037573 * b) ** 3;
    const m = (L - 0.1055613458 * a - 0.0638541728 * b) ** 3;
    const s = (L - 0.0894841775 * a - 1.291485548 * b) ** 3;
    return [
      4.0767416621 * l - 3.3077115913 * m + 0.2309699292 * s,
      -1.2684380046 * l + 2.6097574011 * m - 0.3413193965 * s,
      -0.0041960863 * l - 0.7034186147 * m + 1.707614701 * s,
    ].map(toGamma);
  };

  const luminance = (rgb) => {
    const [r, g, b] = rgb.map(toLinear);
    return 0.2126 * r + 0.7152 * g + 0.0722 * b;
  };
  const contrast = (one, two) => {
    const x = luminance(one);
    const y = luminance(two);
    return (Math.max(x, y) + 0.05) / (Math.min(x, y) + 0.05);
  };

  /// `rgb()`, `rgba()`, `color(srgb ...)`, `oklab()` or `oklch()` (as WebKit gives back
  /// colours written in them, which Tailwind and react-email do); null for anything else.
  const parse = (value) => {
    const match = /^(rgba?\(|color\(srgb |oklab\(|oklch\()([^)]+)\)$/.exec(value);
    if (!match) return null;
    const parts = match[2]
      .trim()
      .split(/[\s,/]+/)
      .map((part) => (part === 'none' ? 0 : part.endsWith('%') ? parseFloat(part) / 100 : Number(part)));
    if (parts.length < 3 || parts.some(Number.isNaN)) return null;
    const alpha = parts[3] ?? 1;
    const kind = match[1];
    if (kind === 'oklab(') return { rgb: fromLab(parts.slice(0, 3)), alpha };
    if (kind === 'oklch(') {
      const [L, C, H] = parts;
      const h = (H * Math.PI) / 180;
      return { rgb: fromLab([L, C * Math.cos(h), C * Math.sin(h)]), alpha };
    }
    const scale = kind.startsWith('color') ? 255 : 1;
    return { rgb: parts.slice(0, 3).map((v) => v * scale), alpha };
  };
  const css = (rgb, alpha = 1) => `rgba(${rgb.map(Math.round).join(',')},${alpha})`;
  const over = (top, alpha, under) => top.map((v, i) => v * alpha + under[i] * (1 - alpha));

  const surface = toLab(SURFACE);
  const darkBackground = (rgb) => {
    const [L, a, b] = toLab(rgb);
    // Dark already, or a brand colour.
    if (L < 0.62 || Math.hypot(a, b) > 0.12) return rgb;
    return fromLab([surface[0] + (1 - L) * 0.5, surface[1] + a * 0.8, surface[2] + b * 0.8]);
  };
  const lightText = (rgb) => {
    const [L, a, b] = toLab(rgb);
    const chroma = Math.hypot(a, b);
    if (chroma < 0.02) return fromLab([1 - 0.585 * L, a, b]);
    const keep = Math.min(1, 0.157 / chroma);
    return fromLab([Math.max(L, 1 - 0.73 * L), a * keep, b * keep]);
  };

  const PICTURES = new Set(['img', 'picture', 'video', 'canvas']);
  const CONTROLS = new Set(['input', 'textarea', 'select', 'button', 'meter', 'progress']);
  const SIDES = ['top', 'right', 'bottom', 'left'];

  const declaresDark = (root) => {
    if (getComputedStyle(root).colorScheme.includes('dark')) return true;
    for (const meta of queryAll.call(document, 'meta[name="color-scheme" i]')) {
      if (/\bdark\b/i.test(attribute.call(meta, 'content') || '')) return true;
    }
    return false;
  };

  /// Every change to make, worked out before any is made. Null: show the mail as sent.
  const plan = (root, body) => {
    const started = performance.now();
    const base = declaresDark(root) ? DARK_CANVAS : WHITE;

    // The page's background is html's, or body's when html has none.
    const rootStyle = getComputedStyle(root);
    const rootFill = parse(rootStyle.backgroundColor);
    if (!rootFill || rootStyle.backgroundImage !== 'none') return null;
    let fill = rootFill;
    let source = root;
    if (fill.alpha === 0 && body) {
      const bodyStyle = getComputedStyle(body);
      if (bodyStyle.backgroundImage !== 'none') return null;
      fill = parse(bodyStyle.backgroundColor);
      if (!fill) return null;
      source = body;
    }
    const pageWas = over(fill.rgb, fill.alpha, base);
    // With nothing of its own, the page is Nimbra's surface.
    const pageNow = fill.alpha === 0 ? SURFACE : darkBackground(pageWas);

    const changes = [];
    const contexts = new Map();
    // `dark`: the backdrop is a dark colour the mail painted (not the browser's canvas).
    const dark = fill.alpha > 0 && toLab(pageWas)[0] < 0.62;
    const page = { was: pageWas, now: pageNow, kept: false, dark };
    const walker = createWalker.call(document, root, NodeFilter.SHOW_ELEMENT);
    let count = 0;
    for (let el = root; el; el = walker.nextNode()) {
      count += 1;
      if (count > MAX_ELEMENTS) return null;
      if (count % 128 === 0 && performance.now() - started > MAX_MS) return null;
      if (!(el instanceof HTMLElement)) continue; // SVG and MathML keep their own colours

      const up = contexts.get(parentOf.call(el)) || page;
      const style = getComputedStyle(el);
      const tag = tagOf.call(el);
      const back = parse(style.backgroundColor);
      const text = parse(style.color);
      // Pinned, so that a media query, :hover or transition cannot undo half of the change.
      const set = [['transition', 'none']];
      let { was, now, kept, dark } = up;

      if (el === root) {
        set.push(['background-color', css(pageNow)]);
      } else if (el === body && source === body) {
        set.push(['background-color', 'transparent']); // it is the page's now
      } else if (!back) {
        // A colour this cannot read: left exactly as sent, and everything in it.
        kept = true;
      } else if (
        !text ||
        CONTROLS.has(tag) ||
        (style.backgroundImage !== 'none' && !PICTURES.has(tag))
      ) {
        // An island left as sent, on the backdrop it was designed for.
        was = over(back.rgb, back.alpha, up.was);
        now = was;
        set.push(['background-color', css(was)]);
        kept = true;
      } else if (back.alpha > 0) {
        was = over(back.rgb, back.alpha, up.was);
        dark = toLab(was)[0] < 0.62;
        if (!kept && up.dark && !dark && !PICTURES.has(tag)) {
          // Light on the mail's own dark: designed for the dark, so left as sent.
          now = was;
          set.push(['background-color', css(was)]);
          kept = true;
        } else if (kept || PICTURES.has(tag)) {
          now = over(back.rgb, back.alpha, up.now);
        } else {
          const dark = darkBackground(back.rgb);
          now = over(dark, back.alpha, up.now);
          set.push(['background-color', css(dark, back.alpha)]);
        }
      } else if (!kept) {
        set.push(['background-color', 'transparent']);
      }
      contexts.set(el, { was, now, kept, dark });

      const nowL = toLab(now)[0];
      const wasL = toLab(was)[0];
      const turned = !kept && nowL < 0.62 && wasL - nowL > 0.2;

      if (text) {
        let colour = text.rgb;
        let alpha = text.alpha;
        const recolour = (rgb, opacity) => {
          // Invisible as sent (preheaders, phishing filler): it stays invisible.
          if (contrast(over(rgb, opacity, was), was) < 1.15) return [now, 1];
          return [toLab(rgb)[0] < wasL ? lightText(rgb) : rgb, opacity];
        };
        if (turned && alpha > 0) [colour, alpha] = recolour(colour, alpha);
        set.push(['color', css(colour, alpha)]);

        // This one wins over `color` where it is set.
        const value = style.getPropertyValue('-webkit-text-fill-color');
        if (value && value !== style.color) {
          const own = parse(value);
          if (own) {
            const [c, o] = turned && own.alpha > 0 ? recolour(own.rgb, own.alpha) : [own.rgb, own.alpha];
            set.push(['-webkit-text-fill-color', css(c, o)]);
          }
        }
      }

      for (const side of SIDES) {
        if (parseFloat(style.getPropertyValue(`border-${side}-width`)) > 0) {
          const name = `border-${side}-color`;
          const edge = parse(style.getPropertyValue(name));
          if (!edge) continue;
          let colour = edge.rgb;
          if (turned && edge.alpha > 0) {
            colour = toLab(colour)[0] < 0.4 ? lightText(colour) : darkBackground(colour);
          }
          // Always written: left alone it would follow the new text colour.
          set.push([name, css(colour, edge.alpha)]);
        }
      }
      changes.push([el, set]);
    }
    return changes;
  };

  /// The web view is see-through while darkening, so mail shown as sent needs its white page.
  const asSent = (root, body) => {
    if (declaresDark(root)) return;
    const clear = (el) => !el || parse(getComputedStyle(el).backgroundColor)?.alpha === 0;
    if (clear(root) && clear(body)) {
      setProperty.call(styleOf.call(root), 'background-color', css(WHITE), 'important');
    }
  };

  const darken = () => {
    const root = rootOf.call(document);
    if (!(root instanceof HTMLElement)) return;
    const body = bodyOf.call(document);
    try {
      const changes = plan(root, body);
      if (!changes) {
        asSent(root, body);
        return;
      }
      for (const [el, set] of changes) {
        const style = styleOf.call(el);
        for (const [name, value] of set) setProperty.call(style, name, value, 'important');
      }
    } catch {
      asSent(root, body);
    }
  };

  // Out of sight until it is recoloured, so there is no white flash.
  const cover = new CSSStyleSheet();
  cover.replaceSync('html{opacity:0!important}');
  setSheets.call(document, [cover]);
  EventTarget.prototype.addEventListener.call(
    document,
    'DOMContentLoaded',
    () => {
      try {
        darken();
      } finally {
        setSheets.call(document, []);
      }
    },
    { once: true },
  );
})();
