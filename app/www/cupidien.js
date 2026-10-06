$(document).on('click', '#navigation a[data-value="compatibilite"]', function() {
  var popup = document.getElementById('cupidien_overlay');
  if (!popup) {
    popup = document.createElement('div');
    popup.id = 'cupidien_overlay';
    popup.className = 'cupidien-overlay';
    popup.setAttribute('aria-hidden', 'true');
    popup.innerHTML = `<div class="cupidien-popup">
      <div class="cupidien-illustration">
        <img class="cupidien-drawing" src="https://shareprint.fr/wp-content/uploads/2020/02/cupidon.png" alt="Cupidon" />
      </div>
      <h2>Cupidon entre en scène !</h2>
      <p>À vous de tester votre compatibilité.</p>
    </div>`;
    document.body.appendChild(popup);
  }

  window.clearTimeout(window.cupidienHideTimer);
  window.clearTimeout(window.cupidienFadeTimer);
  popup.setAttribute('aria-hidden', 'false');
  popup.classList.remove('is-leaving');
  popup.classList.add('is-visible');
  window.cupidienHideTimer = window.setTimeout(function() {
    popup.classList.add('is-leaving');
    window.cupidienFadeTimer = window.setTimeout(function() {
      popup.classList.remove('is-visible', 'is-leaving');
      popup.setAttribute('aria-hidden', 'true');
    }, 450);
  }, 1600);
});
