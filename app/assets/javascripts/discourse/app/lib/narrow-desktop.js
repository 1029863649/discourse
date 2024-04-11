let narrowDesktopForced = true;

const NarrowDesktop = {
  narrowDesktopView: true,

  init() {
    this.narrowDesktopView =
      narrowDesktopForced ||
      this.isNarrowDesktopView(document.body.getBoundingClientRect().width);
  },

  isNarrowDesktopView(width) {
    return width < 768;
  },
};

export default NarrowDesktop;
