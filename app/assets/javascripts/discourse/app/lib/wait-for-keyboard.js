import { getOwner } from "@ember/application";

export async function waitForKeyboard(context) {
  return new Promise((resolve) => {
    if (!window.visualViewport) {
      return resolve({ visible: false });
    }

    const owner = getOwner(context);
    const site = owner.lookup("service:site");
    const capabilities = owner.lookup("service:capabilities");

    if (!capabilities.isIpadOS && site.desktopView) {
      return resolve({ visible: false });
    }

    if (!document.documentElement.classList.contains("keyboard-visible")) {
      return resolve({ visible: false });
    }

    const safeguard = setTimeout(() => {
      // eslint-disable-next-line no-console
      console.warn("Keyboard visibility didnt change after 1s.");

      resolve({
        visible:
          document.documentElement.classList.contains("keyboard-visible"),
      });
    }, 1000);

    const initialWindowHeight = window.innerHeight;

    const onViewportResize = () => {
      clearTimeout(safeguard);

      if ("virtualKeyboard" in navigator) {
        if (navigator.virtualKeyboard.boundingRect.height > 0) {
          return resolve({ visible: true });
        }
      } else if (capabilities.isFirefox && capabilities.isAndroid) {
        const KEYBOARD_DETECT_THRESHOLD = 150;
        if (
          Math.abs(
            initialWindowHeight -
              Math.min(window.innerHeight, window.visualViewport.height)
          ) > KEYBOARD_DETECT_THRESHOLD
        ) {
          return resolve({ visible: true });
        }
      } else {
        let viewportWindowDiff =
          initialWindowHeight - window.visualViewport.height;
        if (viewportWindowDiff > 0) {
          return resolve({ visible: true });
        }
      }

      return resolve({ visible: false });
    };

    window.visualViewport.addEventListener("resize", onViewportResize, {
      once: true,
      passive: true,
    });
  });
}
