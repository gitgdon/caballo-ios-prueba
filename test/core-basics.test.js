const test = require('node:test');
const assert = require('node:assert');
const c = require('../Resources/core.js');

test('dayKey usa fecha local', () => {
  assert.strictEqual(c.dayKey(new Date(2026, 9, 21, 23, 59)), '2026-10-21');
});
test('daysBetween atraviesa el cambio de hora', () => {
  assert.strictEqual(c.daysBetween('2026-10-20', '2026-11-03'), 14);
  assert.strictEqual(c.addDays('2026-10-24', 2), '2026-10-26');
});
test('blockOf', () => {
  assert.strictEqual(c.blockOf(new Date(2026, 9, 21, 13, 59)), 'mañana');
  assert.strictEqual(c.blockOf(new Date(2026, 9, 21, 14, 0)), 'tarde');
  assert.strictEqual(c.blockOf(new Date(2026, 9, 21, 20, 0)), 'noche');
});
test('levelInfo', () => {
  assert.deepStrictEqual(c.levelInfo(0), { level: 1, rank: 'Jinete novato', xpInLevel: 0, xpForNext: 100 });
  assert.deepStrictEqual(c.levelInfo(650), { level: 4, rank: 'Jinete', xpInLevel: 50, xpForNext: 400 });
  assert.strictEqual(c.levelInfo(50 * 15 * 14).rank, 'Leyenda');
});
test('parseState tolera basura', () => {
  assert.deepStrictEqual(c.parseState(null), c.newState());
  assert.deepStrictEqual(c.parseState('{roto'), c.newState());
  assert.deepStrictEqual(c.parseState('{"version":99}'), c.newState());
});
