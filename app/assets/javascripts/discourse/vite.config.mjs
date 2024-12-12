import {
  assets,
  compatPrebuild,
  contentFor,
  hbs,
  optimizeDeps,
  resolver,
  scripts,
  templateTag,
} from "@embroider/vite";
import { babel } from "@rollup/plugin-babel";
import basicSsl from "@vitejs/plugin-basic-ssl";
import { defineConfig } from "vite";
import mkcert from "vite-plugin-mkcert";
import transformHbr from "discourse-hbr/vite-plugin";
import customProxy from "../custom-proxy";

const extensions = [
  ".mjs",
  ".gjs",
  ".js",
  ".mts",
  ".gts",
  ".ts",
  ".hbs",
  ".json",
];
export default defineConfig(({ mode }) => {
  return {
    base: "/@vite/",
    resolve: {
      extensions,
      alias: [
        { find: "discourse-common", replacement: "/../discourse-common/addon" },
        { find: "pretty-text", replacement: "/../pretty-text/addon" },
        {
          find: "discourse-widget-hbs",
          replacement: "/../discourse-widget-hbs/addon",
        },
        { find: "select-kit", replacement: "/../select-kit/addon" },
        { find: "float-kit", replacement: "/../float-kit/addon" },
        { find: "discourse", replacement: "/app" },
        // { find: "@ember-decorators", replacement: "ember-decorators" },
      ],
    },
    plugins: [
      // Standard Ember stuff
      hbs(),
      templateTag(),
      scripts(),
      resolver(),
      compatPrebuild(),
      assets(),
      contentFor(),

      transformHbr(),

      babel({
        babelHelpers: "runtime",
        extensions,
      }),

      // Discourse-specific
      // viteProxy(),
      // mkcert(),
    ],
    optimizeDeps: {
      ...optimizeDeps(),
      include: ["virtual-dom"],
    },
    server: {
      port: 4200,
      strictPort: true,

      proxy: {
        "^/(?!@vite/)": customProxy,
      },

      // https: {
      //   maxSessionMemory: 1000,
      // },
    },
    preview: {
      port: 4200,
      strictPort: true,
    },
    build: {
      manifest: true,
      outDir: "dist",
      rollupOptions: {
        input: {
          main: "index.html",
          ...(shouldBuildTests(mode)
            ? { tests: "tests/index.html" }
            : undefined),
        },
        output: {
          manualChunks(id, { getModuleInfo }) {
            if (id.includes("node_modules")) {
              return "vendor";
            }
          },
        },
      },
    },
    clearScreen: false,
  };
});

function shouldBuildTests(mode) {
  return mode !== "production" || process.env.FORCE_BUILD_TESTS;
}
