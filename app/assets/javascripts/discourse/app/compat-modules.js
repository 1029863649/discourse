import compatModules from "@embroider/virtual/compat-modules";

const seenNames = new Set();

loadCompatModules({
  ...compatModules,
  ...import.meta.glob(
    [
      "./**/*.{gjs,js}",
      "./**/*.{hbs,hbr}",
      "!./static/**/*",
      "../../discourse-common/addon/**/*.{gjs,js}",
      "../../discourse-common/addon/**/*.hbs",
      "../../float-kit/addon/**/*.{gjs,js}",
      "../../float-kit/addon/**/*.hbs",
      "../../select-kit/addon/**/*.{gjs,js}",
      "../../select-kit/addon/**/*.hbs",
      "../../dialog-holder/addon/**/*.{gjs,js}",
      "../../dialog-holder/addon/**/*.hbs",
    ],
    { eager: true }
  ),
});

export function loadCompatModules(modules) {
  const allKeys = new Set();
  for (const [path, module] of Object.entries(modules)) {
    // Todo: move this logic into the build
    // Also need handling for template-only components.
    // Essentially, we need a version of Embroider's compatModules which
    // works for all our other namespaces.
    if (path.endsWith(".hbs") && allKeys.has(path.replace(".hbs", ".js"))) {
      continue;
    }

    let name = path
      .replace("../../", "")
      .replace("./", "discourse/")
      .replace("/addon/", "/")
      .replace(/\.\w+$/, "");

    if (!seenNames.has(name)) {
      seenNames.add(name);
      window.define(name, [], () => module);
    }
  }
}
