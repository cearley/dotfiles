import { expect, test } from 'claude-code/testing';

const HOME = '/Users/x';
const SRC = '/Users/x/dotfiles/home';

function run(stdout: string, exitCode = 0) {
  return { value: { exitCode, stdout, stderr: '', isStdoutTruncated: false, isStderrTruncated: false } };
}

function envMocks(on: any, managed: Record<string, string>) {
  on('tool.check', () => ({ decision: 'allow' }));
  on('process.run', (_: unknown, e: { argv: readonly string[] }) => {
    const [cmd, ...rest] = e.argv;
    if (cmd === 'printenv' && rest[0] === 'HOME') return run(`${HOME}\n`);
    if (cmd === 'chezmoi' && rest[0] === 'source-path' && rest.length === 1) return run(`${SRC}\n`);
    if (cmd === 'chezmoi' && rest[0] === 'managed') {
      const path = rest[rest.length - 1];
      return path in managed ? run(`${path}\n`) : run('', 1);
    }
    if (cmd === 'chezmoi' && rest[0] === 'source-path') {
      const path = rest[rest.length - 1];
      return path in managed ? run(`${managed[path]}\n`) : run('', 1);
    }
    throw new Error(`unexpected argv ${JSON.stringify(e.argv)}`);
  });
}

function fsMocks(on: any, files: Record<string, string> = {}) {
  on('fs.stat', (_: unknown, e: { path: string }) => ({ value: { kind: 'file' as const, size: 0, mtimeMs: 0, isLink: false, realPath: e.path } }));
  on('fs.read', (_: unknown, e: { path: string }) =>
    e.path in files ? { value: files[e.path] } : Promise.reject(new Error('not found')),
  );
}

test('Write to a managed non-settings file is denied', async ($, on) => {
  const target = `${HOME}/.claude/rules/global-preferences.md`;
  envMocks(on, { [target]: `${SRC}/dot_claude/rules/global-preferences.md.tmpl` });
  fsMocks(on);

  const result = await $.tool.check({ tool: 'Write', input: { file_path: target } });

  expect(result.decision).toBe('deny');
});

test('Write of a managed settings.json is always denied', async ($, on) => {
  const target = `${HOME}/.claude-work/settings.json`;
  envMocks(on, { [target]: `${SRC}/dot_claude-work/.claude-settings.json` });
  fsMocks(on);

  const result = await $.tool.check({ tool: 'Write', input: { file_path: target } });

  expect(result.decision).toBe('deny');
  expect(result.reason).toContain('modify_ merge model');
});

test('Edit of settings.json touching a managed key is denied', async ($, on) => {
  const target = `${HOME}/.claude-work/settings.json`;
  envMocks(on, { [target]: `${SRC}/dot_claude-work/.claude-settings.json` });
  fsMocks(on, { [target]: JSON.stringify({ permissions: { ask: ['Bash(git push *)'] }, other: 1 }) });

  const result = await $.tool.check({
    tool: 'Edit',
    input: { file_path: target, old_string: '"permissions"', new_string: '"permissions2"' },
  });

  expect(result.decision).toBe('deny');
});

test('Edit of settings.json touching an unmanaged key is left alone', async ($, on) => {
  const target = `${HOME}/.claude-work/settings.json`;
  envMocks(on, { [target]: `${SRC}/dot_claude-work/.claude-settings.json` });
  fsMocks(on, { [target]: JSON.stringify({ permissions: {}, other: { foo: 1 } }) });

  const result = await $.tool.check({
    tool: 'Edit',
    input: { file_path: target, old_string: '{"foo":1}', new_string: '{"foo":2}' },
  });

  expect(result.decision).toBe('allow');
});

test('Edit of an unmanaged file is left alone', async ($, on) => {
  const target = `${HOME}/.claude/some-unmanaged-note.md`;
  envMocks(on, {});
  fsMocks(on);

  const result = await $.tool.check({ tool: 'Edit', input: { file_path: target, old_string: 'a', new_string: 'b' } });

  expect(result.decision).toBe('allow');
});

test('a path outside any .claude*/dot_claude*/ tree is out of scope', async ($, on) => {
  envMocks(on, {});
  fsMocks(on);

  const result = await $.tool.check({ tool: 'Write', input: { file_path: `${HOME}/projects/app/README.md` } });

  expect(result.decision).toBe('allow');
});

test('Bash: mv of a managed file is denied', async ($, on) => {
  const target = `${HOME}/.claude/rules/global-preferences.md`;
  envMocks(on, { [target]: `${SRC}/dot_claude/rules/global-preferences.md.tmpl` });
  fsMocks(on);

  const result = await $.tool.check({
    tool: 'Bash',
    input: { command: `mv ${target} /tmp/out.md` },
  });

  expect(result.decision).toBe('deny');
});

test('Bash: an unrelated command is left alone', async ($, on) => {
  envMocks(on, {});
  fsMocks(on);

  const result = await $.tool.check({ tool: 'Bash', input: { command: 'git status' } });

  expect(result.decision).toBe('allow');
});

test('Bash: chezmoi add of a profile settings.json is denied', async ($, on) => {
  envMocks(on, {});
  fsMocks(on);

  const result = await $.tool.check({
    tool: 'Bash',
    input: { command: `chezmoi add --force ${HOME}/.claude-personal/settings.json` },
  });

  expect(result.decision).toBe('deny');
  expect(result.reason).toContain('modify_');
});

test('Bash: a read-only chezmoi command near managed settings.json still denies (no key-filter in Bash)', async ($, on) => {
  const target = `${HOME}/.claude/settings.json`;
  envMocks(on, { [target]: `${SRC}/dot_claude/.claude-settings.json` });
  fsMocks(on);

  const result = await $.tool.check({
    tool: 'Bash',
    input: { command: `chezmoi status ${target}` },
  });

  // Not the add rule, but it IS a scanned candidate path into a managed
  // settings.json -- Bash has no old_string/new_string to key-filter
  // against, so every Bash candidate into a managed settings.json takes the
  // Write tier's blanket deny, same as the bash hook this replaces (a known,
  // documented simplification there too: any Bash mutation shape near a
  // managed settings.json denies outright, read intent or not).
  expect(result.decision).toBe('deny');
});
