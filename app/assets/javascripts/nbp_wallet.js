let templateValidity = 0;
let intervalID;
let timeoutID;

const checkStatus = async () => {
  try {
    const response = await fetch(Routes.nbp_wallet_relationship_status_users_path());
    const json = await response.json();

    if (json.status === 'ready' && window.location.pathname === Routes.nbp_wallet_connect_users_path()) {
      window.location.pathname = Routes.nbp_wallet_finalize_users_path();
    }
  } catch (error) {
    console.error(error);
  }
  timeoutID = setTimeout(checkStatus, 1000);
};

const countdownValidity = () => {
  if (templateValidity > 0) {
    templateValidity -= 1;
  }
  if (templateValidity === 0 && window.location.pathname === Routes.nbp_wallet_connect_users_path()) {
    window.location.reload();
  }
};

window.addEventListener("turbolinks:before-render", () => {
  clearInterval(intervalID);
  clearTimeout(timeoutID);
});

window.addEventListener("beforeunload", () => {
  clearInterval(intervalID);
  clearTimeout(timeoutID);
});

$(document).on('turbolinks:load', function () {
  if (window.location.pathname !== Routes.nbp_wallet_connect_users_path()) {
    return;
  }

  document.querySelector('[data-behavior=reload-on-click]').addEventListener('click', () => {
    window.location.reload();
  });

  // Subtract 5 seconds to make sure the displayed code is always valid (accounting for loading times)
  templateValidity = document.querySelector('[data-id="nbp_wallet_qr_code"]').dataset.remainingValidity - 5;
  checkStatus();
  intervalID = setInterval(countdownValidity, 1000);
});
