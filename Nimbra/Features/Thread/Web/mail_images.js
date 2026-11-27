// Points a mail's remote images at Nimbra's image scheme, once the person allows them.
//
// This is Nimbra's script, not the mail's: it runs in a WebKit world of its own while the
// page's scripts stay off. The page's policy blocks https images, so each one is asked of
// `nimbra-image:`, which the app answers with the engine's fetch (https on a public host
// only, size-capped). Plain http images stay blocked. Only attributes are set.
(() => {
  'use strict';

  const PREFIX = 'nimbra-image:';
  const remote = /^\s*https:\/\//i;
  const queryAll = Document.prototype.querySelectorAll;
  const attribute = Element.prototype.getAttribute;
  const setAttribute = Element.prototype.setAttribute;
  const removeAttribute = Element.prototype.removeAttribute;

  const swap = () => {
    for (const el of queryAll.call(document, 'img[src], input[type="image" i][src]')) {
      const src = attribute.call(el, 'src') || '';
      if (remote.test(src)) setAttribute.call(el, 'src', PREFIX + src.trim());
    }
    // A srcset would be asked of the web; the src alone is enough for a mail.
    for (const el of queryAll.call(document, 'img[srcset], source[srcset]')) {
      removeAttribute.call(el, 'srcset');
    }
    for (const el of queryAll.call(document, '[background]')) {
      const background = attribute.call(el, 'background') || '';
      if (remote.test(background)) setAttribute.call(el, 'background', PREFIX + background.trim());
    }
  };

  if (document.readyState === 'loading') {
    EventTarget.prototype.addEventListener.call(document, 'DOMContentLoaded', swap, { once: true });
  } else {
    swap();
  }
})();
