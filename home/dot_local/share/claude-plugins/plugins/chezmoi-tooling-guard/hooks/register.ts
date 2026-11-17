import type { EngineInterface, Register } from 'claude-code';

async function homeDir($: EngineInterface): Promise<string> {
  const result = await $.process.run(['printenv', 'HOME']);
  return result.stdout.trim();
}

// chezmoi source-path with no argument prints the source directory root
// ($HOME/.local/share/chezmoi/home, typically). Undefined when chezmoi isn't
// reachable at all -- callers fail safe to "ask" in that case, never "deny".
async function chezmoiSourceRoot($: EngineInterface): Promise<string | undefined> {
  const result = await $.process.run(['chezmoi', 'source-path']).catch(() => undefined);
  return result?.exitCode === 0 ? result.stdout.trim() : undefined;
}

function escapeRe(s: string): string {
  return s.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
}

function dirname(p: string): string {
  const idx = p.lastIndexOf('/');
  return idx <= 0 ? '/' : p.slice(0, idx);
}

// In scope for this guard at all: under $HOME/.claude*/ (live/deployed) or
// the chezmoi source tree's dot_claude*/ directory (unapplied edits).
// Everything else returns false immediately, same as the bash hook this
// replaces -- no further resolution work for an out-of-scope path.
function inScope(realPath: string, home: string, sourceRoot: string | undefined): boolean {
  if (new RegExp(`^${escapeRe(home)}/\\.claude[^/]*/`).test(realPath)) return true;
  if (sourceRoot && new RegExp(`^${escapeRe(sourceRoot)}/dot_claude[^/]*/`).test(realPath)) return true;
  return false;
}

async function realPathOf($: EngineInterface, path: string): Promise<string> {
  const stat = await $.fs.stat(path, { resolve: true }).catch(() => undefined);
  return stat?.realPath ?? path;
}

const MANAGED_KEYS = ['skillOverrides', 'hooks', 'enabledPlugins', 'extraKnownMarketplaces', 'permissions', '_chezmoiManaged'];

function stripWs(s: string): string {
  return s.replace(/\s+/g, '');
}

// Whether old_string/new_string touches a chezmoi-managed baseline key -- by
// naming it directly, or via a nested value without the key name itself
// (e.g. one permissions.allow entry) -- compared whitespace-stripped, since
// old_string rarely matches JSON.stringify's own formatting.
async function managedKeyTouched($: EngineInterface, oldString: string, newString: string, path: string): Promise<boolean> {
  const haystack = `${oldString}\n${newString}`;
  if (MANAGED_KEYS.some((key) => haystack.includes(`"${key}"`))) return true;
  if (!oldString) return false;

  const text = await $.fs.read(path).catch(() => undefined);
  if (text === undefined) return false;
  let parsed: Record<string, unknown>;
  try {
    parsed = JSON.parse(text);
  } catch {
    return false;
  }
  const picked: Record<string, unknown> = {};
  for (const key of MANAGED_KEYS) if (key in parsed) picked[key] = parsed[key];
  const managedNorm = stripWs(JSON.stringify(picked));
  const oldNorm = stripWs(oldString);
  return oldNorm.length > 0 && managedNorm.includes(oldNorm);
}

type Verdict = { decision: 'deny' | 'ask'; reason: string };

async function checkManagedPath(
  $: EngineInterface,
  filePath: string,
  tool: 'Edit' | 'Write',
  env: { home: string; sourceRoot: string | undefined },
  editInput?: { old_string?: string; new_string?: string },
): Promise<Verdict | undefined> {
  const realPath = await realPathOf($, filePath);
  if (!inScope(realPath, env.home, env.sourceRoot)) return undefined;

  const managedResult = await $.process.run(['chezmoi', 'managed', '--path-style', 'absolute', realPath]).catch(() => undefined);
  if (!managedResult) {
    return { decision: 'ask', reason: "chezmoi isn't reachable, so managed-file detection is disabled for this call -- treat this edit with extra care." };
  }
  if (managedResult.exitCode !== 0 || !managedResult.stdout.trim()) return undefined; // not chezmoi-managed

  const sourceResult = await $.process.run(['chezmoi', 'source-path', realPath]).catch(() => undefined);
  const sourcePath = sourceResult?.exitCode === 0 ? sourceResult.stdout.trim() : `(run: chezmoi source-path "${realPath}")`;

  if (!realPath.endsWith('settings.json')) {
    return {
      decision: 'deny',
      reason: `This file is chezmoi-managed (tracked from ${sourcePath}). Editing the deployed copy directly gets silently overwritten or reasserted on the next chezmoi apply -- edit the source instead.`,
    };
  }

  const editHint = `Edit ${dirname(sourcePath)}/.claude-settings.json (read by ${sourcePath}) instead, then chezmoi apply`;

  if (tool === 'Write') {
    return {
      decision: 'deny',
      reason: `This settings.json is chezmoi-managed. A full overwrite bypasses the modify_ merge model regardless of which keys change -- ${editHint}.`,
    };
  }

  const touched = await managedKeyTouched($, editInput?.old_string ?? '', editInput?.new_string ?? '', realPath);
  if (!touched) return undefined;
  return {
    decision: 'deny',
    reason: `skillOverrides/hooks/enabledPlugins/extraKnownMarketplaces/permissions/_chezmoiManaged in settings.json are chezmoi-managed baseline keys, not local toggles. ${editHint} -- a direct edit here drifts from source and gets silently overwritten or reasserted on the next apply.`,
  };
}

// Best-effort, not a shell parser: every token in the command that looks like
// it falls under a .claude*/dot_claude*-style directory. Mirrors the "heuristic
// input, never more than the Edit/Write tiers" posture of the bash hook it
// replaces -- an unrecognized shape is silently out of scope, same as there.
function extractCandidatePaths(command: string, home: string): string[] {
  const expanded = command.replaceAll('$HOME', home).replaceAll('${HOME}', home);
  const pattern = /(?:~|\/[^\s;&|'"]*?)\/?\.claude[\w-]*\/[^\s;&|'"]*/g;
  const hits = expanded.match(pattern) ?? [];
  return hits.map((hit) => (hit.startsWith('~') ? home + hit.slice(1) : hit));
}

const ADD_PATTERN = /(^|[\s;&|])chezmoi\s+(\S+\s+)?(add|re-add)\s+[^;&|]*\.claude[\w-]*\/settings\.json/;

export const register: Register = (on) => {
  on('tool.check', { tool: ['Edit', 'Write'] }, async ($, e, next) => {
    const input = e.input as { file_path?: string; old_string?: string; new_string?: string };
    if (!input.file_path) return next(e);
    const home = await homeDir($);
    const sourceRoot = await chezmoiSourceRoot($);
    const verdict = await checkManagedPath($, input.file_path, e.tool as 'Edit' | 'Write', { home, sourceRoot }, input);
    return verdict ?? next(e);
  }).catch(() => ({ decision: 'ask' as const, reason: 'chezmoi-tooling-guard failed to evaluate this call -- review manually.' }));

  on('tool.check', { tool: 'Bash' }, async ($, e, next) => {
    const input = e.input as { command?: string };
    const command = input.command ?? '';
    if (!command) return next(e);

    if (ADD_PATTERN.test(command)) {
      return {
        decision: 'deny' as const,
        reason: 'A profile settings.json is a chezmoi modify_ target: `chezmoi add` would replace its merge script with a full snapshot of the live file (runtime keys included), and `re-add` does nothing. Edit the .claude-settings.json next to that profile\'s modify_settings.json.tmpl instead, then chezmoi apply.',
      };
    }

    const home = await homeDir($);
    const candidates = extractCandidatePaths(command, home);
    if (candidates.length === 0) return next(e);

    const sourceRoot = await chezmoiSourceRoot($);
    let askVerdict: Verdict | undefined;
    for (const candidate of candidates) {
      const verdict = await checkManagedPath($, candidate, 'Write', { home, sourceRoot });
      if (!verdict) continue;
      if (verdict.decision === 'deny') return verdict;
      askVerdict ??= verdict;
    }
    return askVerdict ?? next(e);
  }).catch(() => ({ decision: 'ask' as const, reason: 'chezmoi-tooling-guard failed to evaluate this call -- review manually.' }));
};
