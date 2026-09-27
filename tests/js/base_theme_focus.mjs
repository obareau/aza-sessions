// Vérification du JS de base.html — thème personnalisé et mode focus.
//
// Lancé par tests/test_base_js.py, qui rend la page et passe le chemin du JS
// extrait en argument. Un faux DOM minimal suffit : on ne teste pas le rendu
// (aucun navigateur ici), seulement la logique — quelle classe est posée, quelle
// variable est retirée, ce qui est persisté. C'est exactement ce qui casse
// silencieusement, et ce qu'aucun test Python ne peut atteindre.
//
// Sort en code 1 dès un échec, et imprime « ÉCHEC » sur la ligne fautive.
import fs from 'fs';
const src = fs.readFileSync(process.argv[2], 'utf8');

const store = {};
const el = (id) => ({ id, value: '', style: { setProperty(){}, removeProperty(){} },
                      classList: { add(){}, remove(){}, contains(){return false}, toggle(){} },
                      textContent: '', innerHTML: '', dataset: {}, children: [],
                      setAttribute(){}, addEventListener(){}, contains(){return false},
                      closest(){return null}, querySelectorAll(){return []}, querySelector(){return null},
                      appendChild(c){ this.children.push(c); return c }, append(){}, remove(){},
                      insertBefore(){}, scrollIntoView(){},
                      getBoundingClientRect(){ return { top:0, left:0, width:0, height:0 } } });
const classes = new Set();
const styleProps = {};
const body = {
  classList: {
    add: c => classes.add(c), remove: c => classes.delete(c),
    contains: c => classes.has(c),
    toggle: (c, on) => { const v = on === undefined ? !classes.has(c) : on; v ? classes.add(c) : classes.delete(c); return v; },
  },
  style: { setProperty: (k, v) => styleProps[k] = v, removeProperty: k => delete styleProps[k] },
};
globalThis.localStorage = { getItem: k => store[k] ?? null, setItem: (k, v) => store[k] = String(v), removeItem: k => delete store[k] };
globalThis.document = {
  body, documentElement: el('html'),
  getElementById: id => el(id),   // tout élément existe : on ne teste pas le DOM réel
  querySelectorAll: () => [], querySelector: () => null, addEventListener: () => {},
  createElement: () => el('x'), activeElement: { tagName: 'BODY' },
};
globalThis.window = { location: { href: '', pathname: '/' }, addEventListener: () => {}, matchMedia: () => ({ matches: false }) };
globalThis.getComputedStyle = () => ({ getPropertyValue: () => '#000000' });
globalThis.requestAnimationFrame = fn => fn();
globalThis.MutationObserver = class { observe(){} };
globalThis.fetch = () => Promise.resolve({ json: () => Promise.resolve({}) });
globalThis.Chart = function () {}; Chart.defaults = { font: {} };
globalThis.setInterval = () => 0; globalThis.clearInterval = () => {};

const run = new Function(src + `
  return { applyTheme, setTheme, toggleFocus, customTheme, customLu, CUSTOM_DEFAUT };
`);
const api = run();

let rates = 0;
const ok = (cond, nom) => {
    if (!cond) rates++;
    console.log((cond ? '  ok   ' : '  ÉCHEC ') + nom);
};

// ── Thème perso
api.applyTheme('custom');
ok(classes.has('t-custom'), "applyTheme('custom') pose la classe t-custom");
ok(styleProps['--bg'] === api.CUSTOM_DEFAUT.bg, "les 5 variables sont posées en inline");

api.applyTheme('t-nord');
ok(classes.has('t-nord') && !classes.has('t-custom'), "un thème fixe retire t-custom");
ok(styleProps['--bg'] === undefined, "et retire les variables inline (sinon le thème fixe serait écrasé)");

store['aza_theme_custom'] = JSON.stringify({ bg: '#000000', accent: '#FF0000' });
ok(api.customLu().bg === '#000000' && api.customLu().text === api.CUSTOM_DEFAUT.text,
   "customLu complète les couleurs absentes par le défaut");
store['aza_theme_custom'] = '{pas du json';
ok(api.customLu().bg === api.CUSTOM_DEFAUT.bg, "un localStorage corrompu retombe sur le défaut");

// ── Mode focus
delete store['aza_focus'];
classes.clear();
api.toggleFocus();
ok(classes.has('focus-mode') && store['aza_focus'] === '1', "toggleFocus allume et persiste");
api.toggleFocus();
ok(!classes.has('focus-mode') && store['aza_focus'] === '0', "toggleFocus éteint et persiste");
api.toggleFocus(false);
ok(!classes.has('focus-mode'), "toggleFocus(false) est idempotent — Esc ne rallume pas");

process.exit(rates ? 1 : 0);
