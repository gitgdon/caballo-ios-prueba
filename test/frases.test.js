'use strict';
const test = require('node:test');
const assert = require('node:assert');
const { FRASES } = require('../Resources/frases.js');

const CATEGORIAS = [
  'constancia', 'disciplina', 'accion', 'verguenza', 'sacrificio', 'imperfecto',
  'sin-resultados', 'ser-el-mejor', 'estatus', 'dinero', 'desde-cero', 'otros',
];
const CATEGORIAS_REGLAS = [
  'sin-resultados', 'imperfecto', 'desde-cero', 'constancia',
  'verguenza', 'accion', 'disciplina', 'sacrificio',
];

test('hay al menos 409 frases', () => {
  assert.ok(FRASES.length >= 409, `solo hay ${FRASES.length}`);
});

test('los id son únicos', () => {
  const ids = FRASES.map((f) => f.id);
  assert.strictEqual(new Set(ids).size, ids.length);
});

test('no hay dos frases con el mismo texto', () => {
  const textos = FRASES.map((f) => f.texto.trim().toLowerCase());
  const repes = textos.filter((t, i) => textos.indexOf(t) !== i);
  assert.deepStrictEqual(repes, []);
});

test('cada texto ocupa entre 1 y 80 caracteres', () => {
  for (const f of FRASES) {
    assert.strictEqual(typeof f.texto, 'string', f.id);
    const len = [...f.texto].length;
    assert.ok(len > 0 && len <= 80, `${f.id} tiene ${len} caracteres`);
  }
});

test('autor y vídeo no están vacíos', () => {
  for (const f of FRASES) {
    assert.ok(typeof f.autor === 'string' && f.autor.trim(), f.id);
    assert.ok(f.video && typeof f.video.id === 'string' && f.video.id.trim(), f.id);
    assert.ok(typeof f.video.titulo === 'string' && f.video.titulo.trim(), f.id);
  }
});

test('la categoría es válida', () => {
  for (const f of FRASES) assert.ok(CATEGORIAS.includes(f.categoria), `${f.id}: ${f.categoria}`);
});

test('cada categoría de las reglas tiene al menos 10 frases', () => {
  for (const c of CATEGORIAS_REGLAS) {
    const n = FRASES.filter((f) => f.categoria === c).length;
    assert.ok(n >= 10, `${c} solo tiene ${n}`);
  }
});

test('si hay detalle, es un string no vacío', () => {
  for (const f of FRASES) {
    if ('detalle' in f) assert.ok(typeof f.detalle === 'string' && f.detalle.trim(), f.id);
  }
});
