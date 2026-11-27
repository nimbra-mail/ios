// Fits a mail laid out wider than the iPhone (a 600px newsletter table) to the width, as
// Mail does: the viewport takes the mail's width, and WebKit scales the page to the
// screen. Narrower mail is left as it is.
//
// This is Nimbra's script, not the mail's: it runs in a WebKit world of its own while the
// page's scripts stay off. It only reads sizes and sets the viewport's content.
(() => {
  'use strict';

  const rootOf = Object.getOwnPropertyDescriptor(Document.prototype, 'documentElement').get;
  const queryAll = Document.prototype.querySelectorAll;
  const setAttribute = Element.prototype.setAttribute;

  const fit = () => {
    const root = rootOf.call(document);
    if (!(root instanceof HTMLElement)) return;
    const wide = Math.ceil(root.scrollWidth);
    const room = window.innerWidth;
    if (wide <= room + 1 || room <= 0) return;
    for (const meta of queryAll.call(document, 'meta[name="viewport" i]')) {
      setAttribute.call(meta, 'content', `width=${wide}, shrink-to-fit=yes`);
    }
  };

  EventTarget.prototype.addEventListener.call(window, 'load', fit, { once: true });
})();
