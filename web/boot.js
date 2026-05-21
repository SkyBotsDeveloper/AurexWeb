var aurexBootDone = false;

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
