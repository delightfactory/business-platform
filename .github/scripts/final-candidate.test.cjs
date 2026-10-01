const { test } = require('node:test');
const assert = require('node:assert/strict');
const { verifyCandidate } = require('./final-candidate.cjs');

function fixture() {
  const candidate = {
    number: 42, state: 'open', draft: false, head: { sha: 'candidate-head' },
    base: { ref: 'integration', sha: 'candidate-base', repo: { full_name: 'owner/repo' } },
  };
  return {
    event: { action: 'ready_for_review', pull_request: structuredClone(candidate) },
    current: structuredClone(candidate), expectedBase: 'integration', repository: 'owner/repo',
    sha: 'merge-snapshot', checkout: 'merge-snapshot', parents: ['candidate-base', 'candidate-head'],
  };
}

test('accepts only the pinned merge snapshot of the unchanged final head and base', () => {
  assert.deepEqual(verifyCandidate(fixture()), {
    head: 'candidate-head', base: 'candidate-base', merge: 'merge-snapshot',
  });
});

const rejectedCases = {
  'new head during validation': x => { x.current.head.sha = 'new-head'; },
  'base advances during validation': x => { x.current.base.sha = 'new-base'; },
  'PR retargeted': x => { x.current.base.ref = 'production'; },
  'event targets forbidden base': x => { x.event.pull_request.base.ref = 'production'; },
  'repository differs': x => { x.current.base.repo.full_name = 'other/repo'; },
  'closed PR': x => { x.current.state = 'closed'; },
  'returned to draft': x => { x.current.draft = true; },
  'ordinary synchronize event': x => { x.event.action = 'synchronize'; },
  'different PR': x => { x.current.number = 43; },
  'checkout follows moving branch': x => { x.checkout = 'new-merge'; },
  'head-only checkout would mark merge snapshot green': x => { x.parents = ['candidate-base']; },
  'different head in merge snapshot': x => { x.parents[1] = 'new-head'; },
  'different base in merge snapshot': x => { x.parents[0] = 'new-base'; },
};

for (const [name, mutate] of Object.entries(rejectedCases)) {
  test(`rejects ${name}`, () => {
    const input = fixture();
    mutate(input);
    assert.throws(() => verifyCandidate(input));
  });
}
