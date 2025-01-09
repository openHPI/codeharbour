let templateValidity = 0;
let finalizing = false;

const checkStatus = async () => {
  if (!finalizing) {
    try {
      const response = await fetch('/nbp_wallet/relationship_status');
      const json = await response.json();

      if (json.status === 'ready' && !finalizing) {
        finalizing = true;
        window.location.pathname = '/nbp_wallet/finalize';
      }
    } catch (error) {
      console.error(error);
    }
  }
  setTimeout(checkStatus, 1000);
};

const countdownValidity = () => {
  if (templateValidity > 0) {
    templateValidity -= 1;
  }
  if (templateValidity === 0) {
    window.location.reload();
  }
};

$(document).on('turbolinks:load', function () {
  if (window.location.pathname !== '/nbp_wallet/connect') {
    return;
  }

  document.querySelector('.regenerate-qr-code-button').addEventListener('click', () => {
    window.location.reload();
  });

  // Subtract 5 seconds to make sure the displayed code is always valid (accounting for loading times)
  templateValidity = document.querySelector('[data-id="nbp_wallet_qr_code"]').dataset.remainingValidity - 5;
  checkStatus();
  setInterval(countdownValidity, 1000);
});
