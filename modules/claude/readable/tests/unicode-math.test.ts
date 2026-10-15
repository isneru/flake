import { expect, test } from 'claude-code/testing'

import { latexMath, unicodeMath } from '../hooks/unicode-math'

test('converts inline LaTeX to Unicode', () => {
  expect(unicodeMath('L(\\theta)')).toBe('L(θ)')
  expect(unicodeMath('\\nabla_\\theta L(\\theta_t)')).toBe('∇_θ L(θₜ)')
  expect(unicodeMath('x^2 + y^{n+1}')).toBe('x² + yⁿ⁺¹')
  expect(unicodeMath('\\theta_{t+1}')).toBe('θₜ₊₁')
  expect(unicodeMath('\\frac{1}{n^2}')).toBe('1/(n²)')
  expect(unicodeMath('x \\in \\mathbb{R}^n')).toBe('x ∈ ℝⁿ')
  expect(unicodeMath('\\sqrt{2}')).toBe('√2')
  expect(unicodeMath('x_{bq}')).toBe('x_(bq)')
  expect(unicodeMath('m\\ddot{x} + c\\dot x')).toBe('mx\u0308 + cx\u0307')
})

test('covers accents, alphabets and structures', () => {
  expect(unicodeMath('\\dddot{y} \\hat{\\imath} \\overline{AB}')).toBe('y\u20db ı\u0302 A\u0305B\u0305')
  expect(unicodeMath('\\mathcal{L} \\mathfrak{g} \\mathbb{1} \\mathbf{W} \\boldsymbol{\\theta}')).toBe('ℒ 𝔤 𝟙 𝐖 𝜽')
  expect(unicodeMath('\\sqrt[3]{x} + \\binom{n}{k}')).toBe('∛x + C(n, k)')
  expect(unicodeMath('a \\not= b \\not\\in C \\pmod{n}')).toBe('a ≠ b ∉ C (mod n)')
  expect(unicodeMath('\\left. f\\right|_{x=0}')).toBe(' f|ₓ₌₀')
  expect(unicodeMath("f'(x), 90^\\circ, A^\\top")).toBe('f′(x), 90°, Aᵀ')
  expect(unicodeMath('\\begin{pmatrix} a & b \\\\ c & d \\end{pmatrix}')).toBe('(a b; c d)')
  expect(unicodeMath('A \\xrightarrow{f} B \\overset{\\text{def}}{=} C')).toBe('A ─f→ B =ᵈᵉᶠ C')
  expect(unicodeMath('\\underbrace{a+b}_{n} \\leqslant \\liminf_n a_n')).toBe('(a+b)ₙ ⩽ lim infₙ aₙ')
  expect(unicodeMath('\\unknown{x}_1')).toBe('\\unknown{x}₁')
})

test('turns raw Unicode back into LaTeX for the display renderer', () => {
  expect(latexMath('x² ≤ αy')).toBe('x^{2} \\ensuremath{\\le} \\ensuremath{\\alpha}y')
  expect(latexMath('aᵢ₊₁ ∈ ℝ')).toBe('a_{i+1} \\ensuremath{\\in} \\ensuremath{\\mathbb{R}}')
  expect(latexMath('\\text{falha ✗, é}')).toBe('\\text{falha \\ensuremath{\\text{\\ding{55}}}, é}')
  expect(latexMath('\\frac{a}{b}')).toBe('\\frac{a}{b}')
})
