import { test } from 'node:test';
import assert from 'node:assert/strict';
import { verifyCandidate, readCheckout } from './final-candidate.mjs';
import { mkdtempSync, writeFileSync, rmSync } from 'node:fs';
import { execFileSync } from 'node:child_process';
import { tmpdir } from 'node:os';
import { join, resolve, basename, sep } from 'node:path';
import { pathToFileURL } from 'node:url';

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

test('validates real merge parents in a depth-one checkout and rejects stale heads', t => {
  const directory = mkdtempSync(join(tmpdir(), 'final-candidate-shallow-'));
  t.after(() => {
    if (resolve(directory).startsWith(resolve(tmpdir()) + sep) &&
        basename(directory).startsWith('final-candidate-shallow-')) {
      rmSync(directory, { recursive: true, force: true });
    }
  });
  const source = join(directory, 'source');
  const shallow = join(directory, 'shallow');
  const git = (cwd, ...args) => execFileSync('git', args, {
    cwd, encoding: 'utf8', stdio: ['ignore', 'pipe', 'pipe'],
  }).trim();
  git(directory, 'init', '-b', 'integration', source);
  git(source, 'config', 'user.name', 'Candidate guard test');
  git(source, 'config', 'user.email', 'candidate-test@example.invalid');
  const commit = (file, message) => {
    writeFileSync(join(source, file), message);
    git(source, 'add', file);
    git(source, 'commit', '-m', message);
    return git(source, 'rev-parse', 'HEAD');
  };
  const base = commit('base.txt', 'base');
  git(source, 'switch', '-c', 'candidate');
  const head = commit('candidate.txt', 'candidate');
  git(source, 'switch', 'integration');
  git(source, 'merge', '--no-ff', 'candidate', '-m', 'candidate merge');
  const merge = git(source, 'rev-parse', 'HEAD');
  git(directory, 'clone', '--depth=1', '--no-local', pathToFileURL(source).href, shallow);
  assert.equal(git(shallow, 'rev-parse', '--is-shallow-repository'), 'true');
  assert.equal(git(shallow, 'show', '-s', '--format=%P', 'HEAD'), '');
  const checkout = readCheckout(shallow);
  assert.deepEqual(checkout, { checkout: merge, parents: [base, head] });
  const input = fixture();
  for (const candidate of [input.event.pull_request, input.current]) {
    candidate.head.sha = head;
    candidate.base.sha = base;
  }
  Object.assign(input, checkout, { sha: merge });
  assert.deepEqual(verifyCandidate(input), { head, base, merge });
  input.current.head.sha = base;
  assert.throws(() => verifyCandidate(input), /head or base changed/);
});
