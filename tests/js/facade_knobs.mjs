// Vérification du potard rotatif de la fiche matériel.
//
// Lancé par tests/test_facade_js.py, qui rend la page et passe le JS extrait.
// Un faux DOM minimal suffit : ce qui se teste ici, c'est la sémantique —
// « pas relevé » doit rester vide, un potard touché doit porter une valeur, et
// l'aiguille doit tourner dans le bon sens.
//
// Cette vérification existe parce qu'un test Python ne pouvait pas la faire :
// il postait le formulaire directement, sans exécuter la moindre ligne de page.
import fs from 'fs';
const src = fs.readFileSync(process.argv[2], 'utf8');

let rates = 0;
const ok = (cond, nom) => { if (!cond) rates++; console.log((cond ? '  ok   ' : '  ÉCHEC ') + nom); };

// ── Faux DOM ─────────────────────────────────────────────────────────────────
const ecouteurs = new Map();
function el(cls = '', attrs = {}) {
    let _valeur = '';
    const n = {
        classes: new Set(cls.split(' ').filter(Boolean)),
        attrs: { ...attrs }, style: {}, dataset: {}, textContent: '',
        // Un vrai input.value convertit toujours en chaîne : sans ça le harnais
        // comparerait 5 à '5' et validerait un code qui ne marche pas pareil.
        get value() { return _valeur; },
        set value(v) { _valeur = String(v); },
        enfants: [], parentNode: null,
        classList: {
            add: c => n.classes.add(c), remove: c => n.classes.delete(c),
            contains: c => n.classes.has(c),
            toggle: (c, on) => { const v = on === undefined ? !n.classes.has(c) : on;
                                 v ? n.classes.add(c) : n.classes.delete(c); return v; },
        },
        setAttribute: (k, v) => n.attrs[k] = v,
        removeAttribute: k => delete n.attrs[k],
        getAttribute: k => n.attrs[k],
        setPointerCapture() {},
        addEventListener: (type, fn) => {
            if (!ecouteurs.has(n)) ecouteurs.set(n, {});
            (ecouteurs.get(n)[type] = ecouteurs.get(n)[type] || []).push(fn);
        },
        querySelector: sel => n.enfants.find(c => c.classes.has(sel.replace('.', ''))
                              || (sel.includes('hidden') && c.attrs.type === 'hidden')) || null,
        querySelectorAll: () => [],
    };
    return n;
}
function feu(noeud, type, ev = {}) {
    (ecouteurs.get(noeud)?.[type] || []).forEach(fn =>
        fn({ preventDefault() {}, stopPropagation() {}, ...ev }));
}

const aiguille = el('fa-aig'), arc = el('fa-arc'), valeur = el('fa-val');
const knob = el('fa-knob');
knob.enfants = [aiguille, arc, valeur];
const champ = el('', { type: 'hidden' });
champ.value = '';
const parent = el();
parent.enfants = [knob, champ];
knob.parentNode = parent;

globalThis.document = {
    querySelectorAll: sel => sel.includes('fa-lecture') && !sel.includes(':not') ? [] : [knob],
    addEventListener() {},
};

new Function(src)();

// ── Sémantique ───────────────────────────────────────────────────────────────
ok(champ.value === '', "au chargement, le champ est vide — « pas relevé »");
ok(!knob.classes.has('fa-pose'), "et le potard n'est pas marqué comme posé");
ok(valeur.textContent === '—', "la valeur affichée est un tiret, pas 0");

const angleInitial = aiguille.style.transform;
ok(/rotate\(0deg\)/.test(angleInitial), "l'aiguille attend au milieu (0° = midi)");

feu(knob, 'keydown', { key: 'ArrowUp', shiftKey: false });
ok(champ.value === '5.5', "une flèche haut relève à 5.5 depuis l'attente");
ok(knob.classes.has('fa-pose'), "et marque le potard comme posé");

feu(knob, 'keydown', { key: 'ArrowDown', shiftKey: true });
ok(champ.value === '4.5', "shift + flèche bas recule d'un cran entier");

for (let i = 0; i < 30; i++) feu(knob, 'keydown', { key: 'ArrowDown', shiftKey: true });
ok(champ.value === '0', "la valeur est bornée à 0 par le bas");
ok(knob.classes.has('fa-pose'), "0 posé volontairement reste un vrai réglage");

for (let i = 0; i < 40; i++) feu(knob, 'keydown', { key: 'ArrowUp', shiftKey: true });
ok(champ.value === '10', "et à 10 par le haut");
ok(/rotate\(135deg\)/.test(aiguille.style.transform), "à 10, l'aiguille est à +135°");

feu(knob, 'keydown', { key: 'Escape' });
ok(champ.value === '', "Échap efface — on revient à « pas relevé »");
ok(!knob.classes.has('fa-pose'), "et le potard redevient non posé");

feu(knob, 'pointerdown', { clientY: 100, pointerId: 1 });
ok(champ.value === '5', "toucher un potard le relève, même sans le bouger");
feu(knob, 'pointermove', { clientY: 80 });
ok(champ.value === '7', "monter de 20 px ajoute 2");
feu(knob, 'pointerup', {});
feu(knob, 'pointermove', { clientY: 0 });
ok(champ.value === '7', "après relâche, le déplacement ne bouge plus rien");

feu(knob, 'dblclick', {});
ok(champ.value === '', "double-clic efface aussi");

process.exit(rates ? 1 : 0);
