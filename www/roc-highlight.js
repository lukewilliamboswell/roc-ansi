import { Language, Parser, Query } from "./vendor/tree-sitter/tree-sitter-0.25.10.min.js";

const assets = {
  grammar: new URL("./vendor/tree-sitter/tree-sitter-roc.wasm", import.meta.url),
  query: new URL("./vendor/tree-sitter/roc-highlights.scm", import.meta.url),
};

const captureClass = (capture) => {
  const scope = capture.split(".")[0];
  return {
    comment: "comment",
    constant: "constant",
    constructor: "type",
    function: "function",
    keyword: "keyword",
    namespace: "namespace",
    operator: "operator",
    punctuation: "punctuation",
    special: "special",
    string: "string",
    tag: "type",
    type: "type",
    variable: "variable",
  }[scope];
};

const loadHighlighter = async () => {
  await Parser.init();
  const [language, querySource] = await Promise.all([
    Language.load(assets.grammar),
    fetch(assets.query).then((response) => {
      if (!response.ok) throw new Error(`could not load Roc highlight query (${response.status})`);
      return response.text();
    }),
  ]);
  const parser = new Parser();
  parser.setLanguage(language);
  return { parser, query: new Query(language, querySource) };
};

const render = (element, source, captures) => {
  const boundaries = new Set([0, source.length]);
  const ranges = captures.flatMap(({ name, node }, priority) => {
    const className = captureClass(name);
    if (!className) return [];
    boundaries.add(node.startIndex);
    boundaries.add(node.endIndex);
    return [{ className, start: node.startIndex, end: node.endIndex, priority }];
  });
  const points = [...boundaries].sort((left, right) => left - right);
  const fragment = document.createDocumentFragment();

  for (let index = 0; index < points.length - 1; index += 1) {
    const start = points[index];
    const end = points[index + 1];
    if (start === end) continue;
    const active = ranges
      .filter((range) => range.start <= start && end <= range.end)
      .sort((left, right) => left.priority - right.priority)
      .at(-1);
    const text = document.createTextNode(source.slice(start, end));
    if (!active) {
      fragment.append(text);
      continue;
    }
    const span = document.createElement("span");
    span.className = `syntax-${active.className}`;
    span.append(text);
    fragment.append(span);
  }

  element.replaceChildren(fragment);
  element.dataset.rocHighlighted = "true";
};

const blocks = [...document.querySelectorAll("code.language-roc, samp.language-roc, pre > samp")]
  .filter((element) => element.dataset.rocHighlighted !== "true");

if (blocks.length > 0) {
  loadHighlighter()
    .then(({ parser, query }) => {
      for (const element of blocks) {
        const source = element.textContent;
        const tree = parser.parse(source);
        render(element, source, query.captures(tree.rootNode));
        tree.delete();
      }
    })
    .catch((error) => console.warn("Roc syntax highlighting unavailable:", error));
}
