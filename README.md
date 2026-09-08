# cargo-heal

**A modelless code healer for Rust — point it at your crate, keep the mechanical fixes.**
No trained weights, no AI service, no network calls at heal time. Your code never leaves your machine.

## TL;DR

macOS / Linux:

```sh
curl -fsSL https://raw.githubusercontent.com/gist-rs/cargo-heal/main/install.sh | sh
```

Windows (PowerShell):

```powershell
iwr -useb https://raw.githubusercontent.com/gist-rs/cargo-heal/main/install.ps1 | iex
```

Homebrew (prebuilt formula — nothing is compiled):

```sh
brew tap gist-rs/tap && brew trust gist-rs/tap && brew install cargo-heal
```

Scoop:

```powershell
scoop bucket add gist-rs https://github.com/gist-rs/scoop-bucket
scoop install cargo-heal
```

Installers place `cargo-heal` in `~/.cargo/bin` (Windows: `%USERPROFILE%\.cargo\bin`),
so the `cargo heal` subcommand works in any Rust project.

Then, inside a Rust crate:

```sh
cargo heal --suggest src/   # ranked suggestions — writes nothing
cargo heal --fix src/       # bounded, span-preserving fixes (review before writing)
cargo heal --fix --write .  # apply + automatic rustfmt when the file was rustfmt-clean
```

## What it heals

Every rule is a **bounded fix**: a narrowly-scoped, mechanical transform with a
compile-checked or syntax-checked safety gate. The healer is deliberately
conservative — it declines anything it cannot prove safe, and never invents
beyond its compiled fix space. Counts below are measured by
`cargo heal --corpus-stats` at release time (2026-09-07, v0.1.x binaries).

| Domain | In the binary | Rules | What it fixes | Status |
|---|---|---|---|---|
| `clippy_lints` | yes, default | **49** | `cargo clippy` warnings across style / complexity / perf classes (38 with bounded auto-fixes) | GOAT-gated |
| `rust_perf` | yes, default | **112** | Rust performance patterns (allocation, cloning, loop shape, collection choice) | benchmark-Pareto promoted |
| `docker` | yes, default | **31** | Dockerfile issues (hadolint-shaped findings, bounded fixes; no registry calls) | GOAT-gated |
| `rustc_errors` | yes, default | E0597 family | `cargo heal --fix-compile` — compile-error repair keyed by error code, bounded by `--max-iters` | GOAT-gated (N=212) |
| latent retrieval | yes, default | — | span-level rule ranking over the enabled domains (`--suggest` / `--fix`), self-evolve trajectory store kept locally | default-on |
| KAT account | yes, default (v0.1.1+) | — | `cargo heal login` / `account` — the identity + burn/balance view for the heal network (below) | devnet |
| `kernel_opt` | not in this binary | 559 | GPU kernel optimization rules | ships in a future release |
| `sec` | not in this binary | 12 | security-pattern bounded fixes | ships in a future release |

**What it is NOT:**

- **Not an LLM.** No trained weights, no AI service, no prompt calls. The fixes
  come from a compiled, human-authored rule corpus.
- **Not a network citizen at heal time.** Healing is local and offline. The only
  network features (corpus lease refresh, KAT sync) are separate, opt-in, and
  shipped separately (see status below).
- **Not a formatter or a linter.** It composes with `cargo clippy` and
  `rustfmt` — it fixes what they report, mechanically.

## The KAT heal network

`cargo-heal` is also the client for **KAT**, the network's unit of account:

- **Healing burns KAT** — 1 KAT per code word token processed. Your local meter
  and charge ledger live under `.heal/` in your project; nothing is billed or
  submitted without you.
- **Every account starts with a free grant** — 100,000,000 KAT, once per
  account key. Claiming it is local until the ledger syncs (below).
- **Miners earn KAT** by contributing redacted fix spans that prove new value
  through deterministic replay. Rewards decay per epoch — first discovery pays
  most.
- **Parameters are bounded.** Supply caps, the free grant, and prices are on a
  published never-lever list; a guard-railed governor can tune decay inside
  hard ledger-enforced bounds and nothing else. There is no unbacked mint.
- **Devnet honestly:** KAT is a devnet token today. There is no USD price, no
  withdrawal, and no promise of one — treat it as points in a service economy
  while the network hardens.

```mermaid
flowchart LR
    A["cargo heal --fix<br/>(modelless, local)"] --> B["1 KAT burned<br/>per code token"]
    B --> C["local charge ledger<br/>.heal/ - yours"]
    A -. "redacted fix spans<br/>(opt-in, next release)" .-> D["trainer-quorum<br/>replay proof"]
    D -.-> F["mining reward<br/>decayed, first-come"]
    D -.-> G["better corpus<br/>next epoch"]
    G --> A
    F -.-> H["wallet + account view"]
```

*Solid edges run today (the local meter + burn ledger ship in the binary).
Dashed edges are the mining loop — it lands with the corpus-lease transport
release, after its dependency license review completes.*

### Join (60 seconds)

```sh
cargo heal login     # one-time: creates your Ed25519 account key (or adopts your SSH key)
cargo heal account   # your account id, grant projection, per-repo burn, balance
```

The key is a plain OpenSSH Ed25519 file under `~/.config/riir-heal/`. You can
import an existing key instead: `cargo heal login --key <path>`. Nothing
leaves your machine at this step.

**Coming next release:** `cargo heal sync` (push redacted fix batches, pull the
corpus lease) and `cargo heal claim` — the earning half of the loop. The CLI
already prints them; they activate when the transport ships.

### Service status

| Surface | URL | Status |
|---|---|---|
| Consumer front (the network's home) | `https://ai.gist.rs` | live |
| Web wallet | `https://ai.gist.rs/wallet` | live (sign-in opens when the OAuth app is configured) |
| Contribution leaderboard (pseudonymous, epoch-scoped) | `https://ai.gist.rs/leaderboard` | live |
| Service plane (machine API; the CLI default) | `https://heal.gist.rs` | live |

Earlier `v0.1.0`/`v0.1.1` binaries default to the retired `kat.heal.gist.rs` URL —
export `RIIR_HEAL_KAT_SERVICE_URL=https://heal.gist.rs` for those; **v0.1.2
defaults to `heal.gist.rs`** and ships `login` / `update` / `sync` in the
release binary.

### The just-works surface (v0.1.2)

```sh
cargo heal          # DRY RUN: review what would be fixed, zero edits
cargo heal --fix    # REAL fix: writes in place (compile-gated on fix builds)
cargo heal --mine   # what KAT mining is + the policy + how to earn
cargo heal login    # claim your 100M KAT devnet grant
cargo heal sync     # push redacted batches (the mining contribution)
cargo heal account  # burn, balance, grant, network state
```

## Privacy & data posture

- **Healing is offline.** No code, spans, paths, or telemetry leave the machine
  during `--suggest` / `--fix`.
- **The meter and charge ledger are local files** (`.heal/` in your project,
  the account key in `~/.config/riir-heal/`). Delete them and they are gone.
- **The only planned egress is opt-in mining sync**, and it sends *redacted*,
  content-addressed fix spans under a data-use license — never raw files.
  Kill switch for the local meter: `RIIR_HEAL_KAT_METER=0`.

## Verify a download

Every release carries a `SHA256SUMS` file, and the installers verify
automatically. To verify by hand:

```sh
shasum -a 256 -c SHA256SUMS     # macOS
sha256sum -c SHA256SUMS         # Linux / Windows (Git Bash)
```

Binaries are not code-signed yet (SmartScreen/Gatekeeper may ask on first run).
Release notes live on the [releases page](https://github.com/gist-rs/cargo-heal/releases).

## FAQ

**Why did it skip a warning my `cargo clippy` shows?**
The healer only carries a bounded fix for a rule when the transform is
mechanical and gated. Rules without a safe fix-space are deliberately absent —
a wrong "fix" is worse than no fix.

**Does `--fix` ever break my code?**
Fixes are span-preserving and bounded by construction, and `--fix` without
`--write` shows every edit first. With `--write`, files that were already
`rustfmt`-clean are re-formatted automatically; pre-existing formatting drift
is left alone so the diff stays mechanical.

**Why is `--verify` slow?**
It re-runs the compiler (`cargo`/`clippy`) to prove each applied fix still
compiles, and reverts any edit that breaks the build. Correctness over speed.

**How do I update?**
`brew upgrade cargo-heal` / `scoop update cargo-heal`, or re-run the installer
for your platform.

**How do I uninstall?**
Delete `~/.cargo/bin/cargo-heal` (Windows: `%USERPROFILE%\.cargo\bin\cargo-heal.exe`)
and, if you used the KAT features, `~/.config/riir-heal/`.

## Attribution

`THIRD_PARTY_LICENSES.md` ships in every archive and lists all third-party
crates distributed inside the binary with their license texts (generated by
cargo-about at release time from the exact shipping feature set).

## License

The `cargo-heal` binary is distributed under MIT OR Apache-2.0. This repository
publishes releases, installers, and documentation only — no source.
