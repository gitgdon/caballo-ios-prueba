'use strict';
const test = require('node:test');
const assert = require('node:assert');
const { TECNICAS, ENCUENTROS, CONSEJOS } = require('../Resources/tecnicas.js');

const len = (s) => Array.from(s).length;

test('15 técnicas, una por nivel del 1 al 15', () => {
  assert.strictEqual(TECNICAS.length, 15);
  assert.deepStrictEqual(TECNICAS.map((t) => t.nivel).sort((a, b) => a - b), Array.from({ length: 15 }, (_, i) => i + 1));
  assert.deepStrictEqual(TECNICAS.map((t) => t.id), TECNICAS.map((t) => 't' + String(t.nivel).padStart(2, '0')));
});

test('textos de técnica dentro del límite', () => {
  for (const t of TECNICAS) {
    assert.ok(t.titulo && t.fuentes, t.id);
    assert.ok(len(t.mision) <= 90, t.id + ' mision ' + len(t.mision));
    assert.ok(len(t.variante) <= 40, t.id + ' variante ' + len(t.variante));
    assert.ok(t.variante.startsWith('·'), t.id + ' variante empieza por ·');
    assert.ok(len(t.texto) <= 280, t.id + ' texto ' + len(t.texto));
  }
});

test('20 encuentros con xp entre 40 y 80', () => {
  assert.strictEqual(ENCUENTROS.length, 20);
  ENCUENTROS.forEach((e, i) => {
    assert.strictEqual(e.id, 'e' + String(i + 1).padStart(2, '0'));
    assert.ok(e.texto && e.fuente, e.id);
    assert.ok(e.xp >= 40 && e.xp <= 80, e.id + ' xp ' + e.xp);
    assert.strictEqual(typeof e.video, 'boolean', e.id);
  });
});

test('15 consejos de 140 caracteres o menos', () => {
  assert.strictEqual(CONSEJOS.length, 15);
  CONSEJOS.forEach((c, i) => {
    assert.strictEqual(c.id, 'c' + String(i + 1).padStart(2, '0'));
    assert.ok(c.autor && c.video, c.id);
    assert.ok(len(c.texto) <= 140, c.id + ' texto ' + len(c.texto));
  });
});
