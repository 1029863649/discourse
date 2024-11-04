export default {
  markSpec: {
    strikethrough: {
      parseDOM: [
        { tag: "s" },
        { tag: "del" },
        {
          getAttrs: (value) =>
            /(^|[\s])line-through([\s]|$)/u.test(value) && null,
          style: "text-decoration",
        },
      ],
      toDOM() {
        return ["s"];
      },
    },
  },
  inputRules: ({ schema, markInputRule }) =>
    markInputRule(/~~([^~]+)~~$/, schema.marks.strikethrough),
  parse: {
    s: { mark: "strikethrough" },
    bbcode_s: { mark: "strikethrough" },
  },
  serializeMark: {
    strikethrough: {
      open: "~~",
      close: "~~",
      mixable: true,
      expelEnclosingWhitespace: true,
    },
  },
};
