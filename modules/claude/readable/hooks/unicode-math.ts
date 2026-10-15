
const SYMBOLS: Record<string, string> = {
  alpha: 'α', beta: 'β', gamma: 'γ', delta: 'δ', epsilon: 'ε', varepsilon: 'ε', zeta: 'ζ', eta: 'η',
  theta: 'θ', vartheta: 'ϑ', iota: 'ι', kappa: 'κ', lambda: 'λ', mu: 'μ', nu: 'ν', xi: 'ξ', pi: 'π',
  varpi: 'ϖ', rho: 'ρ', varrho: 'ϱ', sigma: 'σ', varsigma: 'ς', tau: 'τ', upsilon: 'υ', phi: 'ϕ',
  varphi: 'φ', chi: 'χ', psi: 'ψ', omega: 'ω', Gamma: 'Γ', Delta: 'Δ', Theta: 'Θ', Lambda: 'Λ',
  Xi: 'Ξ', Pi: 'Π', Sigma: 'Σ', Upsilon: 'Υ', Phi: 'Φ', Psi: 'Ψ', Omega: 'Ω',
  varkappa: 'ϰ', digamma: 'ϝ', varGamma: 'Γ', varDelta: 'Δ', varTheta: 'Θ', varLambda: 'Λ',
  varXi: 'Ξ', varPi: 'Π', varSigma: 'Σ', varUpsilon: 'Υ', varPhi: 'Φ', varPsi: 'Ψ', varOmega: 'Ω',
  nabla: '∇', partial: '∂', infty: '∞', sum: '∑', prod: '∏', int: '∫', oint: '∮', sqrt: '√',
  coprod: '∐', iint: '∬', iiint: '∭', iiiint: '⨌', bigcup: '⋃', bigcap: '⋂', bigsqcup: '⨆',
  bigvee: '⋁', bigwedge: '⋀', bigoplus: '⨁', bigotimes: '⨂', bigodot: '⨀', biguplus: '⨄',
  cdot: '·', cdots: '⋯', ldots: '…', dots: '…', times: '×', div: '÷', pm: '±', mp: '∓', ast: '∗',
  dotsc: '…', dotso: '…', dotsb: '⋯', dotsm: '⋯', dotsi: '⋯', hdots: '…', vdots: '⋮', ddots: '⋱',
  cdotp: '·', ldotp: '.', colon: ':', centerdot: '·',
  circ: '∘', bullet: '•', star: '⋆', prime: '′', le: '≤', leq: '≤', ge: '≥', geq: '≥', ne: '≠',
  neq: '≠', approx: '≈', sim: '∼', simeq: '≃', cong: '≅', equiv: '≡', propto: '∝', ll: '≪', gg: '≫',
  leqq: '≦', geqq: '≧', leqslant: '⩽', geqslant: '⩾', lll: '⋘', ggg: '⋙', lesssim: '≲', gtrsim: '≳',
  lessapprox: '⪅', gtrapprox: '⪆', lessgtr: '≶', gtrless: '≷', lesseqgtr: '⋚', gtreqless: '⋛',
  prec: '≺', succ: '≻', preceq: '⪯', succeq: '⪰', preccurlyeq: '≼', succcurlyeq: '≽', precsim: '≾',
  succsim: '≿', nless: '≮', ngtr: '≯', nleq: '≰', ngeq: '≱', lneq: '⪇', gneq: '⪈', lneqq: '≨',
  gneqq: '≩', nprec: '⊀', nsucc: '⊁', approxeq: '≊', nsim: '≁', ncong: '≇', doteq: '≐', doteqdot: '≑',
  Doteq: '≑', triangleq: '≜', coloneqq: '≔', coloneq: '≔', eqqcolon: '≕', eqcirc: '≖', circeq: '≗',
  bumpeq: '≏', Bumpeq: '≎', asymp: '≍', varpropto: '∝', backsim: '∽', backsimeq: '⋍', thicksim: '∼',
  thickapprox: '≈', eqsim: '≂',
  in: '∈', notin: '∉', ni: '∋', subset: '⊂', subseteq: '⊆', supset: '⊃', supseteq: '⊇', cup: '∪',
  owns: '∋', nsubseteq: '⊈', nsupseteq: '⊉', subsetneq: '⊊', supsetneq: '⊋', subseteqq: '⫅',
  supseteqq: '⫆', subsetneqq: '⫋', supsetneqq: '⫌', Subset: '⋐', Supset: '⋑', sqsubset: '⊏',
  sqsupset: '⊐', sqsubseteq: '⊑', sqsupseteq: '⊒', setminus: '∖', smallsetminus: '∖', complement: '∁',
  cap: '∩', emptyset: '∅', varnothing: '∅', forall: '∀', exists: '∃', neg: '¬', lnot: '¬', land: '∧',
  wedge: '∧', lor: '∨', vee: '∨', oplus: '⊕', otimes: '⊗', to: '→', rightarrow: '→', leftarrow: '←',
  nexists: '∄', uplus: '⊎', sqcap: '⊓', sqcup: '⊔', wr: '≀', diamond: '⋄', bigtriangleup: '△',
  bigtriangledown: '▽', triangleleft: '◁', triangleright: '▷', lhd: '⊲', rhd: '⊳', unlhd: '⊴',
  unrhd: '⊵', ominus: '⊖', oslash: '⊘', odot: '⊙', bigcirc: '◯', amalg: '⨿', dotplus: '∔',
  ltimes: '⋉', rtimes: '⋊', leftthreetimes: '⋋', rightthreetimes: '⋌', Cap: '⋒', Cup: '⋓',
  doublecap: '⋒', doublecup: '⋓', barwedge: '⊼', veebar: '⊻', doublebarwedge: '⩞', boxplus: '⊞',
  boxminus: '⊟', boxtimes: '⊠', boxdot: '⊡', circledast: '⊛', circledcirc: '⊚', circleddash: '⊝',
  intercal: '⊺', divideontimes: '⋇', curlyvee: '⋎', curlywedge: '⋏', dag: '†', dagger: '†',
  ddag: '‡', ddagger: '‡',
  gets: '←', Rightarrow: '⇒', Leftarrow: '⇐', implies: '⟹', iff: '⟺', leftrightarrow: '↔',
  Leftrightarrow: '⇔', mapsto: '↦', uparrow: '↑', downarrow: '↓', langle: '⟨', rangle: '⟩',
  impliedby: '⟸', longmapsto: '⟼', longrightarrow: '⟶', longleftarrow: '⟵', longleftrightarrow: '⟷',
  Longrightarrow: '⟹', Longleftarrow: '⟸', Longleftrightarrow: '⟺', updownarrow: '↕', Uparrow: '⇑',
  Downarrow: '⇓', Updownarrow: '⇕', nearrow: '↗', searrow: '↘', swarrow: '↙', nwarrow: '↖',
  hookrightarrow: '↪', hookleftarrow: '↩', rightharpoonup: '⇀', rightharpoondown: '⇁',
  leftharpoonup: '↼', leftharpoondown: '↽', rightleftharpoons: '⇌', leftrightharpoons: '⇋',
  rightleftarrows: '⇄', leftrightarrows: '⇆', rightrightarrows: '⇉', leftleftarrows: '⇇',
  twoheadrightarrow: '↠', twoheadleftarrow: '↞', rightarrowtail: '↣', leftarrowtail: '↢',
  rightsquigarrow: '⇝', leadsto: '⇝', leftrightsquigarrow: '↭', nrightarrow: '↛', nleftarrow: '↚',
  nRightarrow: '⇏', nLeftarrow: '⇍', nleftrightarrow: '↮', nLeftrightarrow: '⇎',
  curvearrowright: '↷', curvearrowleft: '↶', circlearrowright: '↻', circlearrowleft: '↺',
  upharpoonright: '↾', upharpoonleft: '↿', downharpoonright: '⇂', downharpoonleft: '⇃',
  restriction: '↾', Lleftarrow: '⇚', Rrightarrow: '⇛', dashrightarrow: '⇢', dashleftarrow: '⇠',
  looparrowright: '↬', looparrowleft: '↫', Lsh: '↰', Rsh: '↱', upuparrows: '⇈', downdownarrows: '⇊',
  lfloor: '⌊', rfloor: '⌋', lceil: '⌈', rceil: '⌉', hbar: 'ℏ', ell: 'ℓ', Re: 'ℜ', Im: 'ℑ', aleph: 'ℵ',
  lbrace: '{', rbrace: '}', lbrack: '[', rbrack: ']', backslash: '\\', ulcorner: '⌜', urcorner: '⌝',
  llcorner: '⌞', lrcorner: '⌟', lgroup: '⟮', rgroup: '⟯', llbracket: '⟦', rrbracket: '⟧',
  hslash: 'ℏ', wp: '℘', imath: 'ı', jmath: 'ȷ', beth: 'ℶ', gimel: 'ℷ', daleth: 'ℸ', eth: 'ð',
  Bbbk: '𝕜', mho: '℧', Finv: 'Ⅎ', Game: '⅁', AA: 'Å',
  angle: '∠', perp: '⊥', parallel: '∥', mid: '∣', top: '⊤', bot: '⊥', vdash: '⊢', models: '⊨',
  measuredangle: '∡', sphericalangle: '∢', nmid: '∤', nparallel: '∦', shortmid: '∣',
  shortparallel: '∥', dashv: '⊣', vDash: '⊨', Vdash: '⊩', Vvdash: '⊪', nvdash: '⊬', nvDash: '⊭',
  nVdash: '⊮', nVDash: '⊯', bowtie: '⋈', Join: '⋈', smile: '⌣', frown: '⌢', between: '≬',
  pitchfork: '⋔', vartriangle: '△', vartriangleleft: '⊲', vartriangleright: '⊳',
  trianglelefteq: '⊴', trianglerighteq: '⊵', ntriangleleft: '⋪', ntriangleright: '⋫', multimap: '⊸',
  triangle: '△', triangledown: '▽', blacktriangle: '▲', blacktriangledown: '▼', square: '□',
  Box: '□', blacksquare: '■', lozenge: '◊', blacklozenge: '⧫', Diamond: '◇', diamondsuit: '♢',
  heartsuit: '♡', clubsuit: '♣', spadesuit: '♠', flat: '♭', natural: '♮', sharp: '♯', surd: '√',
  backprime: '‵', S: '§', P: '¶', copyright: '©', pounds: '£', yen: '¥', checkmark: '✓',
  maltese: '✠', circledS: 'Ⓢ', circledR: '®', bigstar: '★', therefore: '∴',
  because: '∵', diagup: '╱', diagdown: '╲',
  quad: '  ', qquad: '    ', lvert: '|', rvert: '|', vert: '|', Vert: '‖', lVert: '‖', rVert: '‖',
  enspace: ' ', enskip: ' ', thinspace: ' ', medspace: ' ', thickspace: ' ', negthinspace: '',
  negmedspace: '', negthickspace: '', mod: 'mod', bmod: 'mod', hfill: ' ', hfil: ' ', space: ' ',
  nobreakspace: ' ', over: '/', atop: '', choose: 'choose', relbar: '─', Relbar: '═', joinrel: '',
  liminf: 'lim inf', limsup: 'lim sup', injlim: 'inj lim', projlim: 'proj lim', varliminf: 'lim inf',
  varlimsup: 'lim sup', varinjlim: 'inj lim', varprojlim: 'proj lim', backepsilon: '϶',
  blacktriangleleft: '◀', blacktriangleright: '▶', curlyeqprec: '⋞', curlyeqsucc: '⋟',
  eqslantgtr: '⪖', eqslantless: '⪕', fallingdotseq: '≒', risingdotseq: '≓', gnapprox: '⪊',
  lnapprox: '⪉', gnsim: '⋧', lnsim: '⋦', gtrdot: '⋗', lessdot: '⋖', gtreqqless: '⪌',
  lesseqqgtr: '⪋', gvertneqq: '≩', lvertneqq: '≨', ngeqq: '≱', ngeqslant: '≱', nleqq: '≰',
  nleqslant: '≰', npreceq: '⋠', nsucceq: '⋡', nshortmid: '∤', nshortparallel: '∦',
  nsubseteqq: '⊈', nsupseteqq: '⊉', ntrianglelefteq: '⋬', ntrianglerighteq: '⋭', precapprox: '⪷',
  succapprox: '⪸', precnapprox: '⪹', succnapprox: '⪺', precneqq: '⪵', succneqq: '⪶', precnsim: '⋨',
  succnsim: '⋩', smallfrown: '⌢', smallsmile: '⌣', smallint: '∫', intop: '∫', ointop: '∮',
  idotsint: '∫⋯∫', varsubsetneq: '⊊', varsubsetneqq: '⫋', varsupsetneq: '⊋', varsupsetneqq: '⫌',
  varbigtriangledown: '▽', varbigtriangleup: '△', lmoustache: '⎰', rmoustache: '⎱', arrowvert: '|',
  Arrowvert: '‖', bracevert: '⎪', mathdollar: '$', mathellipsis: '…', mathparagraph: '¶',
  mathsection: '§', mathsterling: '£', mathunderscore: '_', And: '&', vcentcolon: ':',
}

const FUNCTIONS = new Set([
  'arccos', 'arcsin', 'arctan', 'arg', 'cos', 'cosh', 'cot', 'coth', 'csc', 'deg', 'det', 'dim', 'exp',
  'gcd', 'hom', 'inf', 'ker', 'lg', 'lim', 'ln', 'log', 'max', 'min', 'Pr', 'sec', 'sin', 'sinh',
  'sup', 'tan', 'tanh', 'argmin', 'argmax',
])

const ACCENTS: Record<string, string> = {
  hat: '\u0302', widehat: '\u0302', check: '\u030c', widecheck: '\u030c', tilde: '\u0303',
  widetilde: '\u0303', acute: '\u0301', grave: '\u0300', breve: '\u0306', bar: '\u0304',
  mathring: '\u030a', dot: '\u0307', ddot: '\u0308', dddot: '\u20db', ddddot: '\u20dc', vec: '\u20d7',
  overrightarrow: '\u20d7', overleftarrow: '\u20d6', overleftrightarrow: '\u20e1', overline: '\u0305',
  underline: '\u0332', underbar: '\u0332', cancel: '\u0338', bcancel: '\u0338', xcancel: '\u0338',
  sout: '\u0336', underrightarrow: '\u20ef', underleftarrow: '\u20ee', underleftrightarrow: '\u034d',
  Hat: '\u0302', Check: '\u030c', Tilde: '\u0303', Acute: '\u0301', Grave: '\u0300', Breve: '\u0306',
  Bar: '\u0304', Dot: '\u0307', Ddot: '\u0308', Vec: '\u20d7',
}

const SPREAD = new Set(['overline', 'underline', 'underbar', 'cancel', 'bcancel', 'xcancel', 'sout'])

type Alphabet = {
  upper?: number
  lower?: number
  digit?: number
  Greek?: number
  greek?: number
  holes?: Record<string, string>
}

const ALPHABETS: Record<string, Alphabet> = {
  bb: {
    upper: 0x1d538, lower: 0x1d552, digit: 0x1d7d8,
    holes: { C: 'ℂ', H: 'ℍ', N: 'ℕ', P: 'ℙ', Q: 'ℚ', R: 'ℝ', Z: 'ℤ' },
  },
  cal: {
    upper: 0x1d49c, lower: 0x1d4b6,
    holes: { B: 'ℬ', E: 'ℰ', F: 'ℱ', H: 'ℋ', I: 'ℐ', L: 'ℒ', M: 'ℳ', R: 'ℛ', e: 'ℯ', g: 'ℊ', o: 'ℴ' },
  },
  frak: { upper: 0x1d504, lower: 0x1d51e, holes: { C: 'ℭ', H: 'ℌ', I: 'ℑ', R: 'ℜ', Z: 'ℨ' } },
  bf: { upper: 0x1d400, lower: 0x1d41a, digit: 0x1d7ce, Greek: 0x1d6a8, greek: 0x1d6c2 },
  bm: { upper: 0x1d468, lower: 0x1d482, digit: 0x1d7ce, Greek: 0x1d71c, greek: 0x1d736 },
  sf: { upper: 0x1d5a0, lower: 0x1d5ba, digit: 0x1d7e2 },
  tt: { upper: 0x1d670, lower: 0x1d68a, digit: 0x1d7f6 },
}

const FONTS: Record<string, string> = {
  mathbb: 'bb', mathds: 'bb', mathbbm: 'bb', Bbb: 'bb', mathcal: 'cal', mathscr: 'cal', mathfrak: 'frak',
  frak: 'frak', mathbf: 'bf', textbf: 'bf', bold: 'bf', boldsymbol: 'bm', bm: 'bm', pmb: 'bm', mathbfit: 'bm', mathsf: 'sf',
  textsf: 'sf', mathtt: 'tt', texttt: 'tt',
}

const RAW = new Set([
  'text', 'textrm', 'textit', 'textnormal', 'textup', 'textbf', 'textsf', 'texttt', 'mbox', 'hbox',
  'textsc', 'emph', 'intertext', 'shortintertext',
])

const PASS = new Set([
  'mathrm', 'mathit', 'mathnormal', 'operatorname', 'mathop', 'mathrel', 'mathbin', 'mathord',
  'mathopen', 'mathclose', 'mathpunct', 'mathinner', 'ensuremath', 'smash', 'mathclap', 'mathllap', 'mathrlap', 'clap', 'llap', 'rlap',
  'substack', 'sideset', 'operatornamewithlimits', 'shoveleft', 'shoveright', 'ref',
])

const NOOP = new Set([
  'left', 'right', 'middle', 'big', 'Big', 'bigg', 'Bigg', 'bigl', 'bigr', 'bigm', 'Bigl', 'Bigr',
  'Bigm', 'biggl', 'biggr', 'biggm', 'Biggl', 'Biggr', 'Biggm', 'displaystyle', 'textstyle',
  'scriptstyle', 'scriptscriptstyle', 'limits', 'nolimits', 'nonumber', 'notag', 'mathstrut', 'strut',
  'relax', 'protect', 'allowbreak', 'nobreak', 'rm', 'it', 'bf', 'sf', 'tt', 'cal', 'normalsize',
  'tiny', 'scriptsize', 'footnotesize', 'small', 'large', 'Large', 'null', 'displaybreak',
  'allowdisplaybreaks', 'nobreakdash',
])

const BRACES = new Set(['underbrace', 'overbrace', 'underbracket', 'overbracket'])

const DROP = new Set(['label', 'vphantom', 'color', 'textcolor', 'colorbox', 'vspace', 'leftroot', 'uproot', 'skew', 'raisetag'])

const FILLERS: Record<string, string> = { hspace: ' ', mspace: ' ', hdotsfor: '…' }

const STARRED = new Set(['operatorname', 'hspace', 'vspace', 'tag'])

const XARROWS: Record<string, [string, string]> = {
  xrightarrow: ['─', '→'], xleftarrow: ['←', '─'], xRightarrow: ['═', '⇒'], xLeftarrow: ['⇐', '═'],
  xleftrightarrow: ['←', '→'], xLeftrightarrow: ['⇐', '⇒'], xmapsto: ['├', '→'],
  xhookrightarrow: ['↪', '→'], xhookleftarrow: ['←', '↩'],
}

const ENVS: Record<string, [string, string]> = {
  pmatrix: ['(', ')'], bmatrix: ['[', ']'], Bmatrix: ['{', '}'], vmatrix: ['|', '|'],
  Vmatrix: ['‖', '‖'], cases: ['{ ', ''], dcases: ['{ ', ''], rcases: ['', ' }'],
}

const SUP: Record<string, string> = {
  0: '⁰', 1: '¹', 2: '²', 3: '³', 4: '⁴', 5: '⁵', 6: '⁶', 7: '⁷', 8: '⁸', 9: '⁹', '+': '⁺', '-': '⁻',
  '=': '⁼', '(': '⁽', ')': '⁾', a: 'ᵃ', b: 'ᵇ', c: 'ᶜ', d: 'ᵈ', e: 'ᵉ', f: 'ᶠ', g: 'ᵍ', h: 'ʰ', i: 'ⁱ',
  j: 'ʲ', k: 'ᵏ', l: 'ˡ', m: 'ᵐ', n: 'ⁿ', o: 'ᵒ', p: 'ᵖ', r: 'ʳ', s: 'ˢ', t: 'ᵗ', u: 'ᵘ', v: 'ᵛ',
  w: 'ʷ', x: 'ˣ', y: 'ʸ', z: 'ᶻ', T: 'ᵀ', '∗': '*', '*': '*', '′': '′', 'θ': 'ᶿ', 'β': 'ᵝ', 'γ': 'ᵞ', 'δ': 'ᵟ',
  'φ': 'ᵠ', 'χ': 'ᵡ', ' ': ' ',
  A: 'ᴬ', B: 'ᴮ', D: 'ᴰ', E: 'ᴱ', G: 'ᴳ', H: 'ᴴ', I: 'ᴵ', J: 'ᴶ', K: 'ᴷ', L: 'ᴸ', M: 'ᴹ', N: 'ᴺ',
  O: 'ᴼ', P: 'ᴾ', R: 'ᴿ', U: 'ᵁ', V: 'ⱽ', W: 'ᵂ', 'α': 'ᵅ', 'ε': 'ᵋ', 'ι': 'ᶥ', 'ϕ': 'ᶲ', '∘': '°',
  '⊤': 'ᵀ', '⊥': '⊥', '†': '†', '‡': '‡', '⋆': '⋆',
}

const SUB: Record<string, string> = {
  0: '₀', 1: '₁', 2: '₂', 3: '₃', 4: '₄', 5: '₅', 6: '₆', 7: '₇', 8: '₈', 9: '₉', '+': '₊', '-': '₋',
  '=': '₌', '(': '₍', ')': '₎', a: 'ₐ', e: 'ₑ', h: 'ₕ', i: 'ᵢ', j: 'ⱼ', k: 'ₖ', l: 'ₗ', m: 'ₘ', n: 'ₙ',
  o: 'ₒ', p: 'ₚ', r: 'ᵣ', s: 'ₛ', t: 'ₜ', u: 'ᵤ', v: 'ᵥ', x: 'ₓ', 'β': 'ᵦ', 'γ': 'ᵧ', 'ρ': 'ᵨ',
  'φ': 'ᵩ', 'χ': 'ᵪ', ' ': ' ',
}

function arg(s: string, i: number): [string, number] {
  while (s[i] === ' ') i++
  if (s[i] === '{') {
    let depth = 1
    let j = i + 1
    while (j < s.length && depth > 0) {
      if (s[j] === '{') depth++
      else if (s[j] === '}') depth--
      j++
    }
    return [s.slice(i + 1, depth > 0 ? j : j - 1), j]
  }
  const command = /^\\[a-zA-Z]+/.exec(s.slice(i))
  return command ? [command[0], i + command[0].length] : [s[i] ?? '', i + 1]
}

function opt(s: string, i: number): [string | undefined, number] {
  const j = s[i] === '[' ? s.indexOf(']', i) : -1
  return j < 0 ? [undefined, i] : [s.slice(i + 1, j), j + 1]
}

const script = (text: string, table: Record<string, string>, mark: string) => {
  const chars = [...text]
  return chars.every(c => table[c]) ? chars.map(c => table[c]).join('')
    : `${mark}${chars.length > 1 ? `(${text})` : text}`
}

const GREEK_VARIANTS = '∂ϵϑϰϕϱϖ'

function restyle(text: string, a: Alphabet): string {
  const at = (ch: string, base: number | undefined, offset: number) =>
    base === undefined ? ch : String.fromCodePoint(base + offset)
  return [...text].map(ch => {
    const code = ch.codePointAt(0) ?? 0
    if (a.holes?.[ch]) return a.holes[ch]
    if (ch >= 'A' && ch <= 'Z') return at(ch, a.upper, code - 0x41)
    if (ch >= 'a' && ch <= 'z') return at(ch, a.lower, code - 0x61)
    if (ch >= '0' && ch <= '9') return at(ch, a.digit, code - 0x30)
    if (ch >= 'Α' && ch <= 'Ω') return at(ch, a.Greek, code - 0x391)
    if (ch >= 'α' && ch <= 'ω') return at(ch, a.greek, code - 0x3b1)
    if (ch === '∇') return at(ch, a.Greek, 25)
    const variant = GREEK_VARIANTS.indexOf(ch)
    return variant < 0 ? ch : at(ch, a.greek, 25 + variant)
  }).join('')
}

function environment(name: string, body: string): string {
  const env = name.replace('*', '')
  const [open, close] = ENVS[env] ?? ['', '']
  const rows = (/^(array|alignedat|subarray)$/.test(env) ? body.slice(arg(body, 0)[1]) : body)
    .split('\\\\')
    .map(row => row.split('&').map(cell => unicodeMath(cell.trim())).filter(Boolean).join(' '))
    .filter(Boolean)
  return `${open}${rows.join('; ')}${close}`
}

const LATEX: Record<string, string> = {
  '−': '-', '′': "'", '″': "''", '°': '^{\\circ}', 'ε': '\\varepsilon', 'ϵ': '\\epsilon', '√': '\\surd',
  'ο': 'o', '∎': '\\blacksquare', '≢': '\\not\\equiv', '≉': '\\not\\approx', '✗': '\\text{\\ding{55}}',
  '✘': '\\text{\\ding{56}}', '✔': '\\text{\\ding{52}}', '⋅': '\\cdot', '∙': '\\bullet', '◦': '\\circ',
  '∶': ':', '∕': '/', '⁄': '/', '〈': '\\langle', '〉': '\\rangle', '⌀': '\\varnothing', '∆': '\\Delta',
  'µ': '\\mu', 'Ω': '\\Omega', '➝': '\\to', '➔': '\\to', '☆': '\\star', '‐': '-', '‑': '-', '–': '-',
  '½': '\\tfrac{1}{2}', '⅓': '\\tfrac{1}{3}', '⅔': '\\tfrac{2}{3}', '¼': '\\tfrac{1}{4}',
  '¾': '\\tfrac{3}{4}', '∛': '\\sqrt[3]{\\,}', '∜': '\\sqrt[4]{\\,}', '\u2009': '\\,', '\u200a': '\\,',
  '\u202f': '\\,', '\u2005': '\\,', '\u2003': '\\quad', '\u200b': '',
}
for (const pair of 'ΑA ΒB ΕE ΖZ ΗH ΙI ΚK ΜM ΝN ΟO ΡP ΤT ΧX'.split(' ')) LATEX[pair[0]] = pair[1]
for (const [name, ch] of Object.entries(SYMBOLS)) {
  if (ch > '\u007f' && [...ch].length === 1) LATEX[ch] ??= `\\${name}`
}
for (const [font, key, ranges] of [
  ['mathbb', 'bb', 'A'], ['mathcal', 'cal', 'A'], ['mathfrak', 'frak', 'Aa'], ['mathbf', 'bf', 'Aa0'],
  ['boldsymbol', 'bm', 'Aa'], ['mathsf', 'sf', 'Aa0'], ['mathtt', 'tt', 'Aa0'],
]) {
  for (const first of ranges) {
    for (let n = 0; n < (first === '0' ? 10 : 26); n++) {
      const ch = String.fromCharCode(first.charCodeAt(0) + n)
      LATEX[restyle(ch, ALPHABETS[key])] ??= `\\${font}{${ch}}`
    }
  }
}

const invert = (table: Record<string, string>) =>
  Object.fromEntries(Object.entries(table).filter(([from, to]) => to !== from && to !== '*' && to !== '°').reverse().map(([from, to]) => [to, from]))
const RAISED = invert(SUP)
const LOWERED = invert(SUB)

export function latexMath(src: string): string {
  const scripts = (text: string, table: Record<string, string>, mark: string) =>
    text.replace(new RegExp(`[${Object.keys(table).join('')}]+`, 'gu'), run => `${mark}{${[...run].map(ch => table[ch]).join('')}}`)
  return [...scripts(scripts(src, RAISED, '^'), LOWERED, '_')]
    .map(ch => (LATEX[ch] === undefined ? ch : LATEX[ch] && `\\ensuremath{${LATEX[ch]}}`))
    .join('')
}

export function unicodeMath(src: string): string {
  let out = ''
  let i = 0
  while (i < src.length) {
    const c = src[i]
    if (c === '^' || c === '_') {
      const [a, next] = arg(src, i + 1)
      out += script(unicodeMath(a), c === '^' ? SUP : SUB, c)
      i = next
    } else if (c === '{' || c === '}') {
      i++
    } else if (c === '\\') {
      const name = /^\\([a-zA-Z]+|.)/.exec(src.slice(i))?.[1] ?? ''
      i += name.length + 1
      if (src[i] === '*' && STARRED.has(name)) i++
      if (['frac', 'dfrac', 'tfrac', 'cfrac', 'genfrac'].includes(name)) {
        if (name === 'genfrac') for (let skipped = 0; skipped < 4; skipped++) i = arg(src, i)[1]
        const [num, a] = arg(src, i)
        const [den, b] = arg(src, a)
        const wrap = (t: string) => (t.length > 1 ? `(${t})` : t)
        out += `${wrap(unicodeMath(num))}/${wrap(unicodeMath(den))}`
        i = b
      } else if (['binom', 'dbinom', 'tbinom'].includes(name)) {
        const [n, a] = arg(src, i)
        const [k, b] = arg(src, a)
        out += `C(${unicodeMath(n)}, ${unicodeMath(k)})`
        i = b
      } else if (name === 'sqrt') {
        const [n, start] = opt(src, i)
        const [a, next] = arg(src, start)
        const inner = unicodeMath(a)
        const root = n === undefined || n === '2' ? '√' : n === '3' ? '∛' : n === '4' ? '∜'
          : `${script(unicodeMath(n), SUP, '^')}√`
        out += inner.length > 1 ? `${root}(${inner})` : `${root}${inner}`
        i = next
      } else if (['overset', 'underset', 'stackrel'].includes(name)) {
        const [mark, a] = arg(src, i)
        const [base, b] = arg(src, a)
        out += unicodeMath(base) + (name === 'underset' ? script(unicodeMath(mark), SUB, '_') : script(unicodeMath(mark), SUP, '^'))
        i = b
      } else if (name === 'overunderset') {
        const [over, a] = arg(src, i)
        const [under, b] = arg(src, a)
        const [base, next] = arg(src, b)
        out += unicodeMath(base) + script(unicodeMath(over), SUP, '^') + script(unicodeMath(under), SUB, '_')
        i = next
      } else if (XARROWS[name]) {
        const [a, next] = arg(src, opt(src, i)[1])
        out += `${XARROWS[name][0]}${unicodeMath(a)}${XARROWS[name][1]}`
        i = next
      } else if (name === 'not') {
        const [a, next] = arg(src, i)
        const [first = '', ...rest] = [...unicodeMath(a)]
        out += `${first}\u0338`.normalize('NFC') + rest.join('')
        i = next
      } else if (['pmod', 'pod', 'tag', 'eqref'].includes(name)) {
        const [a, next] = arg(src, i)
        out += name === 'pmod' ? `(mod ${unicodeMath(a)})` : `(${name === 'pod' ? unicodeMath(a) : a})`
        i = next
      } else if (name === 'textsuperscript' || name === 'textsubscript') {
        const [a, next] = arg(src, i)
        out += name === 'textsuperscript' ? script(a, SUP, '^') : script(a, SUB, '_')
        i = next
      } else if (name === 'boxed' || name === 'fbox') {
        const [a, next] = arg(src, i)
        out += `[${unicodeMath(a)}]`
        i = next
      } else if (BRACES.has(name)) {
        const [a, next] = arg(src, i)
        const inner = unicodeMath(a)
        out += [...inner].length > 1 ? `(${inner})` : inner
        i = next
      } else if (name === 'phantom' || name === 'hphantom') {
        const [a, next] = arg(src, i)
        out += ' '.repeat([...unicodeMath(a)].length)
        i = next
      } else if (FILLERS[name]) {
        out += FILLERS[name]
        i = arg(src, i)[1]
      } else if (name === 'begin') {
        const [env, start] = arg(src, i)
        const close = `\\end{${env}}`
        const end = src.indexOf(close, start)
        out += environment(env, src.slice(start, end < 0 ? src.length : end))
        i = end < 0 ? src.length : end + close.length
      } else if (FONTS[name] || RAW.has(name) || PASS.has(name)) {
        const [a, next] = arg(src, i)
        const inner = RAW.has(name) ? a : unicodeMath(a)
        out += FONTS[name] ? restyle(inner, ALPHABETS[FONTS[name]]) : inner
        i = next
      } else if (ACCENTS[name]) {
        const [a, next] = arg(src, i)
        const inner = unicodeMath(a)
        out += SPREAD.has(name) ? [...inner].map(ch => ch + ACCENTS[name]).join('') : inner + ACCENTS[name]
        i = next
      } else if (DROP.has(name)) {
        i = arg(src, i)[1]
      } else if (NOOP.has(name)) {
        if (['left', 'right', 'middle'].includes(name) && src[i] === '.') i++
      } else if ([',', ';', ':', ' ', '>', '\\'].includes(name)) {
        out += ' '
      } else if (name === '!' || name === '/' || name === '-') {
      } else if (name === '|') {
        out += '‖'
      } else if (name === '{' || name === '}' || name === '$' || name === '%' || name === '#' || name === '&' || name === '_') {
        out += name
      } else {
        out += SYMBOLS[name] ?? (FUNCTIONS.has(name) ? name : `\\${name}`)
        while (SYMBOLS[name] === undefined && !FUNCTIONS.has(name) && src[i] === '{') {
          const [a, next] = arg(src, i)
          out += `{${a}}`
          i = next
        }
      }
    } else if (c === "'") {
      out += '′'
      i++
    } else if (c === '~') {
      out += ' '
      i++
    } else {
      out += c
      i++
    }
  }
  return out
}
