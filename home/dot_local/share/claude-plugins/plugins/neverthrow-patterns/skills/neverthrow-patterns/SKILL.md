---
name: neverthrow-patterns
description: >
  Use when writing or editing TypeScript (.ts/.tsx) in a project that already depends on the
  neverthrow library or a vendored Result/ResultAsync equivalent — signals include
  "neverthrow" in package.json or the lockfile, an import from "neverthrow", or existing
  Result/ResultAsync types with .andThen/.mapErr/.match/safeTry chains in the codebase. Skip
  when none of that evidence exists; plain try/catch or Promise-based error handling with no
  Result type in scope is out of scope for this skill.
---

# neverthrow Pattern Enforcement

Apply these principles to every file you write or edit that uses `neverthrow` (or a vendored
equivalent with the same `Result`/`ResultAsync` API).

## Core Rules

1. **Return `Result`, don't throw** — a function that can fail returns `Result<T, E>` (or
   `ResultAsync<T, E>` if async), not a thrown exception.
2. **Use functional combinators over `isOk()`/`isErr()` branching** — prefer `map`, `andThen`,
   `mapErr`, `orElse`, `match` over manual `if (result.isOk())` / `if (result.isErr())` checks.
3. **Always handle both branches** — use `.match()` so the compiler forces both the ok and err
   paths to be handled, or `unwrapOr` when a plain default is appropriate instead of a full match.
4. **Type `E` concretely** — never leave the error parameter as `unknown` or `any`; use a
   discriminated union so every call site knows exactly what can go wrong.
5. **Use `safeTry()` for chains of 3+ `andThen` calls** — it lets you write the chain with
   early-return `yield*` syntax instead of nesting, while preserving early exit on the first
   `Err`.
6. **Never call `_unsafeUnwrap()` / `_unsafeUnwrapErr()` outside tests** — these throw on the
   wrong variant and defeat the purpose of `Result`; they exist for test assertions only.
7. **Wrap throwing boundaries with `fromThrowable` or `fromSafePromise`** — do not `try/catch`
   inside an `.andThen()` callback; convert the throwing call into a `Result`/`ResultAsync`
   once, at the boundary, and let the chain's own error handling take it from there.
8. **Use `mapErr` at integration boundaries** — normalize an external library's or API's error
   shape into your domain `E` type at the call site where it enters your code, not partway
   through an unrelated chain.
9. **Use `ResultAsync`, not `Promise<Result<T,E>>`** — `ResultAsync` gives you the same
   combinators (`map`, `andThen`, `mapErr`, `match`, ...) without needing to `await` before each
   step, and composes with synchronous `Result` combinators directly.
10. **Use `combine`/`combineWithAllErrors` for independent parallel results** — don't manually
    collect several `Result`s and check each one by hand.
11. **Never ignore a returned `Result`** — a `Result` that's never consumed silently drops an
    error path. `eslint-plugin-neverthrow` (the `must-use-result` rule) enforced this
    mechanically, but the plugin is **unmaintained** and incompatible with `@typescript-eslint`
    v7+ and TypeScript 6.x (it uses the removed `context.parserServices` API). No working
    successor exists as of 2026. Until a maintained alternative appears, this is a
    **code-review-only check** — look for a `Result`-returning call whose return value is
    neither used nor explicitly discarded with intent.

## Core Rule Examples

**Return `Result`, don't throw**

```ts
// Bad
function parseConfig(raw: string): Config {
  const parsed = JSON.parse(raw);
  if (!isConfig(parsed)) throw new Error("invalid config");
  return parsed;
}

// Good
function parseConfig(raw: string): Result<Config, ConfigError> {
  return fromThrowable(JSON.parse, () => ({ type: "parseFailed" as const }))(raw).andThen(
    (parsed) => (isConfig(parsed) ? ok(parsed) : err({ type: "invalidShape" as const })),
  );
}
```

**Functional combinators over `isOk()`/`isErr()` branching**

```ts
// Bad
const result = parseConfig(raw);
if (result.isOk()) {
  startServer(result.value);
} else {
  logger.error(result.error);
}

// Good
parseConfig(raw).match(
  (config) => startServer(config),
  (error) => logger.error(error),
);
```

**Always handle both branches**

```ts
// Bad — the Err branch is silently dropped
const config = parseConfig(raw).unwrapOr(undefined);
if (config) startServer(config);

// Good — a plain default is fine when there genuinely is one
const timeoutMs = readTimeoutConfig(raw).unwrapOr(DEFAULT_TIMEOUT_MS);

// Good — both branches handled explicitly when there's no sensible default
parseConfig(raw).match(
  (config) => startServer(config),
  (error) => logger.error("failed to start", error),
);
```

**Type `E` concretely**

```ts
// Bad
function loadUser(id: string): Result<User, unknown> { /* ... */ }

// Good
type LoadUserError =
  | { type: "notFound"; id: string }
  | { type: "network"; cause: unknown };

function loadUser(id: string): Result<User, LoadUserError> { /* ... */ }
```

**`safeTry()` for chains of 3+ `andThen` calls**

```ts
// Bad — deep nesting to get at the happy path
function createOrder(input: OrderInput): Result<Order, OrderError> {
  return validateInput(input).andThen((validated) =>
    reserveInventory(validated).andThen((reservation) =>
      chargePayment(reservation).andThen((charge) =>
        ok({ validated, reservation, charge }),
      ),
    ),
  );
}

// Good — flat, early-exit reads like a normal function body
function createOrder(input: OrderInput): Result<Order, OrderError> {
  return safeTry<Order, OrderError>(function* () {
    const validated = yield* validateInput(input).safeUnwrap();
    const reservation = yield* reserveInventory(validated).safeUnwrap();
    const charge = yield* chargePayment(reservation).safeUnwrap();
    return ok({ validated, reservation, charge });
  });
}
```

**Never call `_unsafeUnwrap()` / `_unsafeUnwrapErr()` outside tests**

```ts
// Bad — in application code
function getConfigOrDie(raw: string): Config {
  return parseConfig(raw)._unsafeUnwrap();
}

// Good — application code stays on match/unwrapOr
function getConfigOrDie(raw: string): Config {
  return parseConfig(raw).match(
    (config) => config,
    (error) => { throw new Error(`invalid config: ${error.type}`); },
  );
}

// Good — tests only
test("parseConfig accepts a valid payload", () => {
  const config = parseConfig(VALID_RAW)._unsafeUnwrap();
  expect(config.port).toBe(8080);
});
```

**Wrap throwing boundaries with `fromThrowable`/`fromSafePromise`, not `try/catch` inside `.andThen()`**

```ts
// Bad — try/catch buried inside a combinator callback
function readAndParse(path: string): Result<Config, ConfigError> {
  return readFileResult(path).andThen((raw) => {
    try {
      return ok(JSON.parse(raw));
    } catch {
      return err({ type: "parseFailed" as const });
    }
  });
}

// Good — the throwing call is wrapped once, at the boundary
const parseJson = fromThrowable(JSON.parse, (): ConfigError => ({ type: "parseFailed" }));

function readAndParse(path: string): Result<Config, ConfigError> {
  return readFileResult(path).andThen(parseJson);
}
```

**`mapErr` at integration boundaries, not mid-chain**

```ts
// Bad — the external library's error type leaks several steps into the chain
function syncUser(id: string): ResultAsync<User, DomainError> {
  return fetchFromCrm(id) // ResultAsync<CrmUser, CrmApiError>
    .andThen(normalizeUser) // now has to know about CrmApiError too
    .mapErr((e) => (e instanceof CrmApiError ? { type: "crm" as const, cause: e } : e));
}

// Good — normalized to the domain error type right where the external call happens
function syncUser(id: string): ResultAsync<User, DomainError> {
  return fetchFromCrm(id)
    .mapErr((e): DomainError => ({ type: "crm", cause: e }))
    .andThen(normalizeUser); // normalizeUser only ever sees DomainError
}
```

**`ResultAsync`, not `Promise<Result<T,E>>`**

```ts
// Bad — every step needs an await before the next combinator can run
async function loadAndValidate(id: string): Promise<Result<User, UserError>> {
  const userResult = await fetchUser(id);
  if (userResult.isErr()) return err(userResult.error);
  return validateUser(userResult.value);
}

// Good — ResultAsync composes without manual awaiting between steps
function loadAndValidate(id: string): ResultAsync<User, UserError> {
  return fetchUser(id).andThen(validateUser);
}
```

**`combine`/`combineWithAllErrors` for independent parallel results**

```ts
// Bad — each Result checked by hand
const nameResult = validateName(input.name);
const emailResult = validateEmail(input.email);
if (nameResult.isErr()) return err(nameResult.error);
if (emailResult.isErr()) return err(emailResult.error);
const profile = { name: nameResult.value, email: emailResult.value };

// Good — collects every error, not just the first
const combined = combineWithAllErrors([
  validateName(input.name),
  validateEmail(input.email),
]);
```

**Never ignore a returned `Result`**

```ts
// Bad — the Result is discarded; a validation failure vanishes silently
function recordEvent(event: Event): void {
  validateEvent(event); // Result<Event, ValidationError> never consumed
  eventLog.push(event);
}

// Good — the Result drives what happens next
function recordEvent(event: Event): Result<void, ValidationError> {
  return validateEvent(event).map((validated) => {
    eventLog.push(validated);
  });
}
```

## Error Type Design

Model errors as a discriminated union keyed by a `type` tag, and dispatch on that tag with an
exhaustive `match`/`Record`, the same way the TypeScript patterns skill treats any closed-set
dispatch — never a chain of `instanceof`/`===` checks.

```ts
type OrderError =
  | { type: "outOfStock"; sku: string }
  | { type: "paymentDeclined"; reason: string }
  | { type: "network"; cause: unknown };

// Bad — a chain of instanceof/property checks to decide what to show the user
function describeError(error: OrderError): string {
  if (error.type === "outOfStock") return `${error.sku} is out of stock`;
  if (error.type === "paymentDeclined") return `payment declined: ${error.reason}`;
  return "something went wrong";
}

// Good — a total Record keyed by the tag; a new OrderError variant that's
// missing a key is a compile error, not a silent fallback to the last branch
const describeByType: Readonly<Record<OrderError["type"], (e: OrderError) => string>> = {
  outOfStock: (e) => `${(e as { sku: string }).sku} is out of stock`,
  paymentDeclined: (e) => `payment declined: ${(e as { reason: string }).reason}`,
  network: () => "something went wrong, please retry",
};
function describeError(error: OrderError): string {
  return describeByType[error.type](error);
}
```

For a small, closed error set, `.match()` on the `Result` itself is often simpler than building a
dispatch table at all:

```ts
createOrder(input).match(
  (order) => renderConfirmation(order),
  (error) => renderError(describeError(error)),
);
```

## Async Chain Pattern

Keep an async fallible chain entirely on `ResultAsync` combinators — `map`, `andThen`, `mapErr`,
`match` — rather than mixing `await` with manual `Result` checks:

```ts
// Bad — manual re-wrapping and an await before every step
async function placeOrder(input: OrderInput): Promise<Result<Order, OrderError>> {
  const validatedResult = validateInput(input);
  if (validatedResult.isErr()) return err(validatedResult.error);

  const reservationResult = await reserveInventory(validatedResult.value);
  if (reservationResult.isErr()) return err(reservationResult.error);

  const chargeResult = await chargePayment(reservationResult.value);
  if (chargeResult.isErr()) return err(chargeResult.error);

  return ok({ reservation: reservationResult.value, charge: chargeResult.value });
}

// Good — ResultAsync combinators chain without manual awaiting or re-wrapping
function placeOrder(input: OrderInput): ResultAsync<Order, OrderError> {
  return validateInput(input) // Result<ValidInput, OrderError>
    .asyncAndThen(reserveInventory) // lifts into ResultAsync
    .andThen((reservation) =>
      chargePayment(reservation).map((charge) => ({ reservation, charge })),
    );
}
```

`.asyncAndThen()` is how a synchronous `Result` chain hands off into `ResultAsync` without an
intermediate `await`/re-wrap step.

## Testing

`_unsafeUnwrap()` / `_unsafeUnwrapErr()` are for test assertions only (Core Rule 6) — they let a
test fail fast and loud on the wrong variant without boilerplate:

```ts
test("reserveInventory succeeds when stock is available", async () => {
  const reservation = (await reserveInventory(IN_STOCK_ITEM))._unsafeUnwrap();
  expect(reservation.quantity).toBe(1);
});

test("reserveInventory fails when stock is exhausted", async () => {
  const error = (await reserveInventory(OUT_OF_STOCK_ITEM))._unsafeUnwrapErr();
  expect(error.type).toBe("outOfStock");
});
```

Outside a test file, reach for `.match()`, `.unwrapOr()`, or propagate the `Result` instead.

## Anti-Patterns to Flag

- A function that can fail throws instead of returning `Result`/`ResultAsync`
- Manual `if (result.isOk())` / `if (result.isErr())` branching where a combinator (`map`,
  `andThen`, `mapErr`, `orElse`, `match`) would do
- A `Result` consumed by only one branch (e.g. `unwrapOr` used where the error case actually
  needs distinct handling, or a branch silently dropped)
- `Result<T, unknown>` or `Result<T, any>` — the error type isn't a concrete discriminated union
- Three or more chained `.andThen()` calls left deeply nested instead of using `safeTry()`
- `_unsafeUnwrap()` / `_unsafeUnwrapErr()` called outside a test file
- `try/catch` written inside an `.andThen()`/`.map()` callback instead of wrapping the throwing
  call once with `fromThrowable`/`fromSafePromise` at the boundary
- An external error type (a library exception, an HTTP client's error shape) threaded several
  steps into a chain instead of normalized with `mapErr` at the call site where it enters
- `Promise<Result<T, E>>` as a return type, or `await` used between combinator steps, instead of
  `ResultAsync`
- Several independent `Result`s checked one at a time by hand instead of `combine`/
  `combineWithAllErrors`
- A `Result`-returning call whose return value is neither used nor explicitly discarded —
  code-review-only (Core Rule 11), since the mechanical lint for this is currently unmaintained
- A discriminated-union error type dispatched with an `instanceof`/`===` chain instead of a
  `Record` keyed by its tag, or just `.match()` on the `Result`

## Review Checklist

Before finalising a diff that touches `Result`/`ResultAsync` code:

- Every fallible function returns `Result`/`ResultAsync`; none throw for an expected failure
- No manual `isOk()`/`isErr()` branching where a combinator fits
- Every consumed `Result` handles both branches (`.match()`, or `.unwrapOr()` with a genuine
  default)
- Every `E` type parameter is a concrete discriminated union, never `unknown`/`any`
- Chains of 3+ `andThen` calls use `safeTry()` instead of nesting
- No `_unsafeUnwrap()`/`_unsafeUnwrapErr()` outside test files
- No `try/catch` inside a combinator callback — throwing boundaries wrapped with
  `fromThrowable`/`fromSafePromise` once, up front
- External errors normalized to the domain `E` type with `mapErr` at the boundary, not mid-chain
- Async chains use `ResultAsync` combinators, not `Promise<Result<T,E>>` with manual `await`
- Independent parallel `Result`s use `combine`/`combineWithAllErrors`
- No `Result`-returning call whose value is silently dropped (flag for review; no mechanical
  lint currently catches this — see Core Rule 11)
