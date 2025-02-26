import { registerRichEditorExtension } from "discourse/lib/composer/rich-editor-extensions";
import typographerReplacements from "./typographer-replacements";

/**
 * List of default extensions
 * ProsemirrorEditor autoloads them when includeDefault=true (the default)
 *
 * @type {RichEditorExtension[]}
 */
const defaultExtensions = [typographerReplacements];

defaultExtensions.forEach(registerRichEditorExtension);
