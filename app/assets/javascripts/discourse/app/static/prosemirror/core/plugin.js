import { Plugin } from "prosemirror-state";

export function extractNodeViews(extensions) {
  const allNodeViews = {};
  for (const { nodeViews } of extensions){
    if (nodeViews) {
      for(const [name, NodeViewClass] of Object.entries(nodeViews)){
        allNodeViews[name] = (node, view, getPos) => new NodeViewClass(node, view, getPos);
      }
    }
  }
  return allNodeViews;
}

export function extractPlugins(extensions, params, view) {
  return (
    extensions
      .reduce((acc, extension) => {
        if (extension.plugins instanceof Array) {
          acc.push(...extension.plugins);
        } else if (extension.plugins) {
          acc.push(extension.plugins);
        }
        return acc;
      }, [])
      .flatMap((plugin) => processPlugin(plugin, params, view))
      // filter async plugins from initial load
      .filter(Boolean)
  );
}

function processPlugin(pluginArg, params, handleAsyncPlugin) {
  if (typeof pluginArg === "function") {
    const ret = pluginArg(params);

    if (ret instanceof Promise) {
      ret.then((plugin) => handleAsyncPlugin(processPlugin(plugin, params)));
      return;
    }

    return processPlugin(ret, params, handleAsyncPlugin);
  }

  if (pluginArg instanceof Array) {
    return pluginArg.map((plugin) =>
      processPlugin(plugin, params, handleAsyncPlugin)
    );
  }

  if (pluginArg instanceof Plugin) {
    return pluginArg;
  }

  return new Plugin(pluginArg);
}
