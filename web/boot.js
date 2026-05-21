window.addEventListener('flutter-first-frame', function () {
  var boot = document.getElementById('boot');
  if (boot) {
    boot.remove();
  }
  document.body.style.overflow = 'auto';
});
