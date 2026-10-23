export const md = markdownit({
  html: false,
  linkify: true,
  breaks: true,
  highlight: (code, lang) =>
    hljs.getLanguage(lang) ? hljs.highlight(code, { language: lang, ignoreIllegals: true }).value : "",
})
  .use(texmath, { engine: katex, delimiters: "dollars", katexOptions: { throwOnError: false } })
  .use(markdownitFootnote)
  .use(markdownitTaskLists)
