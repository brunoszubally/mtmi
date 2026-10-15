const test = require('node:test');
const assert = require('node:assert/strict');
const {merge, resolve, applyChanges, equal} = require('../frontend/form-concurrency.js');

test('different fields from two editors survive together', () => {
  const result = merge({a:'old', b:'old'}, {a:'mine', b:'old'}, {a:'old', b:'theirs'});
  assert.deepEqual(result, {data:{a:'mine', b:'theirs'}, conflicts:[]});
});
test('overlapping changes require an explicit choice', () => {
  const result = merge({a:'old'}, {a:'mine'}, {a:'theirs'});
  assert.equal(result.conflicts.length, 1);
  assert.throws(() => resolve(result, []));
  assert.deepEqual(resolve(result, ['mine']), {a:'mine'});
  assert.deepEqual(resolve(result, ['server']), {a:'theirs'});
});
test('deletion is a change, and conflicts with a simultaneous edit', () => {
  assert.deepEqual(merge({a:'old'}, {}, {a:'old'}).data, {});
  assert.equal(merge({a:'old'}, {}, {a:'new'}).conflicts.length, 1);
});
test('identical simultaneous edits do not conflict', () => {
  assert.equal(merge({a:'old'}, {a:'new'}, {a:'new'}).conflicts.length, 0);
});
test('legacy drafts cannot silently replace an existing server value', () => {
  const result = merge(null, {a:'stale', b:'draft only'}, {a:'current', c:'server only'});
  assert.equal(result.conflicts.length, 1);
  assert.deepEqual(resolve(result, ['server']), {a:'current', b:'draft only', c:'server only'});
});
test('a known old draft retains a later server edit it never changed', () => {
  assert.deepEqual(merge({a:'old', b:'old'}, {a:'old', b:'draft'}, {a:'new', b:'old'}).data,
    {a:'new', b:'draft'});
});
test('team reordering conflicts as a group instead of mixing people', () => {
  const base = {mtmi_csapat_letszam:'2', mtmi_csapat_tag1_nev:'Anna', mtmi_csapat_tag2_nev:'Béla'};
  const mine = {...base, mtmi_csapat_tag1_nev:'Béla', mtmi_csapat_tag2_nev:'Anna'};
  const theirs = {...base, mtmi_csapat_tag1_szak:['fizika']};
  const result = merge(base, mine, theirs);
  assert.equal(result.conflicts.length, 1);
  assert.deepEqual(resolve(result, ['server']), theirs);
  assert.deepEqual(resolve(result, ['mine']), mine);
});
test('unrendered fields survive normal UI saves', () => {
  assert.deepEqual(applyChanges({a:'old', future_field:'keep'}, {a:'old'}, {a:'new'}),
    {a:'new', future_field:'keep'});
});
test('typing while a save is in flight is retained against the sent UI snapshot', () => {
  assert.deepEqual(applyChanges({a:'sent', hidden:'keep'}, {a:'sent'}, {a:'typed later'}),
    {a:'typed later', hidden:'keep'});
});
test('empty UI values do not create artificial changes', () => {
  assert.equal(equal({a:'', b:[]}, {}), true);
  assert.deepEqual(applyChanges({hidden:'keep'}, {a:''}, {a:[]}), {hidden:'keep'});
});
