var aurexBootDone = false;

// Flutter parses navigator.languages before Dart starts; keep invalid browser
// locale values from blocking the engine in strict browsers.
(function normalizeNavigatorLanguages() {
  var fallbackLanguage = 'en-US';
  var nav = window.navigator;

  function isValidLanguageTag(value) {
    if (typeof value !== 'string') {
      return false;
    }
    var tag = value.trim();
    if (!tag || tag === 'undefined' || tag === 'null') {
      return false;
    }
    try {
      new Intl.Locale(tag);
      return true;
    } catch (_) {
      return false;
    }
  }

  var browserLanguages = [];
  if (nav.languages && typeof nav.languages.length === 'number') {
    browserLanguages = Array.prototype.slice.call(nav.languages);
  }

  var cleanLanguages = browserLanguages.filter(isValidLanguageTag);
  if (!cleanLanguages.length && isValidLanguageTag(nav.language)) {
    cleanLanguages = [nav.language.trim()];
  }
  if (!cleanLanguages.length) {
    cleanLanguages = [fallbackLanguage];
  }

  var needsPatch =
    cleanLanguages.length !== browserLanguages.length ||
    cleanLanguages[0] !== nav.language;

  if (!needsPatch) {
    return;
  }

  try {
    Object.defineProperty(nav, 'languages', {
      configurable: true,
      get: function () {
        return cleanLanguages.slice();
      },
    });
    Object.defineProperty(nav, 'language', {
      configurable: true,
      get: function () {
        return cleanLanguages[0];
      },
    });
  } catch (_) {
    window.__aurexLanguages = cleanLanguages;
  }
})();

function removeAurexBoot() {
  aurexBootDone = true;
  var boot = document.getElementById('boot');
  if (boot) {
    boot.remove();
  }
  document.body.style.overflow = 'auto';
}

function updateBootCopy(message, showReload) {
  if (aurexBootDone) {
    return;
  }
  var copy = document.querySelector('.boot-copy');
  if (copy) {
    copy.textContent = message;
  }
  var shell = document.querySelector('.boot-shell');
  if (!shell || !showReload || document.getElementById('boot-reload')) {
    return;
  }
  var button = document.createElement('button');
  button.id = 'boot-reload';
  button.type = 'button';
  button.textContent = 'Reload';
  button.style.marginTop = '18px';
  button.style.width = '100%';
  button.style.minHeight = '44px';
  button.style.border = '0';
  button.style.borderRadius = '8px';
  button.style.background = '#FF4D8D';
  button.style.color = '#05070A';
  button.style.font = '700 14px "Segoe UI", sans-serif';
  button.style.cursor = 'pointer';
  button.addEventListener('click', function () {
    window.location.reload();
  });
  shell.appendChild(button);
}

window.addEventListener('flutter-first-frame', removeAurexBoot);

window.setTimeout(function () {
  updateBootCopy('Still loading Aurex. Checking the connection...', false);
}, 8000);

window.setTimeout(function () {
  updateBootCopy('This is taking longer than expected.', true);
}, 20000);
