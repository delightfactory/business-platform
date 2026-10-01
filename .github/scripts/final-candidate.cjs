const { readFileSync, appendFileSync } = require('node:fs');
const { execFileSync } = require('node:child_process');

function verifyCandidate({ event, current, expectedBase, repository, sha, checkout, parents }) {
  const candidate = event.pull_request;
  if (event.action !== 'ready_for_review' || !candidate || current.state !== 'open' || current.draft) {
    throw new Error('Validation requires an open, ready final-candidate PR.');
  }
  if (candidate.base.ref !== expectedBase || current.base.ref !== expectedBase ||
      candidate.base.repo.full_name !== repository || current.base.repo.full_name !== repository) {
    throw new Error('Unexpected target repository or integration branch.');
  }
  if (current.number !== candidate.number || current.head.sha !== candidate.head.sha ||
      current.base.sha !== candidate.base.sha) {
    throw new Error('PR head or base changed: freeze and request fresh final-candidate validation.');
  }
  if (checkout !== sha || parents.length !== 2 ||
      parents[0] !== candidate.base.sha || parents[1] !== candidate.head.sha) {
    throw new Error('Checkout is not the exact event merge snapshot of this head and base.');
  }
  return { head: candidate.head.sha, base: candidate.base.sha, merge: sha };
}

async function main() {
  const event = JSON.parse(readFileSync(process.env.GITHUB_EVENT_PATH, 'utf8'));
  const number = event.pull_request?.number;
  const repository = process.env.GITHUB_REPOSITORY;
  if (process.env.GITHUB_EVENT_NAME !== 'pull_request' || !Number.isInteger(number) ||
      !/^[\w.-]+\/[\w.-]+$/.test(repository) || !process.env.GH_TOKEN) {
    throw new Error('Missing authenticated PR event context.');
  }
  const response = await fetch(`https://api.github.com/repos/${repository}/pulls/${number}`, {
    headers: { Authorization: `Bearer ${process.env.GH_TOKEN}`, Accept: 'application/vnd.github+json' },
    signal: AbortSignal.timeout(30000),
  });
  if (!response.ok) throw new Error(`Cannot verify current PR: HTTP ${response.status}`);
  const git = (...args) => execFileSync('git', args, { encoding: 'utf8' }).trim();
  const result = verifyCandidate({
    event, current: await response.json(), expectedBase: process.argv[2], repository,
    sha: process.env.GITHUB_SHA, checkout: git('rev-parse', 'HEAD'),
    parents: git('show', '-s', '--format=%P', 'HEAD').split(' '),
  });
  const evidence = `Final candidate head: ${result.head}\nBase: ${result.base}\nTested merge snapshot: ${result.merge}\n`;
  console.log(evidence);
  if (process.env.GITHUB_STEP_SUMMARY) appendFileSync(process.env.GITHUB_STEP_SUMMARY, `\n${evidence}\n`);
}

if (require.main === module) main().catch(error => {
  console.error(error.message);
  process.exitCode = 1;
});

module.exports = { verifyCandidate };
