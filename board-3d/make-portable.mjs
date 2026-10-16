import { readFile, writeFile } from 'node:fs/promises';

const indexUrl = new URL('./dist/index.html', import.meta.url);
let html = await readFile(indexUrl, 'utf8');
const scriptPattern = /<script type="module" crossorigin src="(\.\/assets\/[^"]+\.js)"><\/script>/;
const scriptMatch = html.match(scriptPattern);

if (!scriptMatch) {
  throw new Error('Portable build expected one relative Vite module script');
}

const scriptUrl = new URL(scriptMatch[1], indexUrl);
const script = await readFile(scriptUrl, 'utf8');
if (/\bimport\.meta\b|^\s*(?:import|export)\s/m.test(script)) {
  throw new Error('Generated bundle still contains ESM-only syntax');
}

html = html
  .replace(scriptPattern, `<script defer src="${scriptMatch[1]}"></script>`)
  .replace(/<link rel="stylesheet" crossorigin href="(\.\/assets\/[^"]+\.css)">/, '<link rel="stylesheet" href="$1">');

if (/\b(?:src|href)="\//.test(html)) {
  throw new Error('Generated index still contains root-absolute assets');
}

await writeFile(indexUrl, html, 'utf8');
console.log('Portable file build ready: dist/index.html');
