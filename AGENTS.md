# AGENTS.md

## Cursor Cloud specific instructions

### Current repository state

As of this writing, this repository (`nagi5611/mmh-windnoise`) contains **only a `LICENSE` file**. There is:

- No application source code
- No dependency manifest (no `package.json`, lockfile, `requirements.txt`, etc.)
- No tests, build configuration, or CI configuration
- No `.cursor/environment.json`

Because there is no codebase yet, there is nothing to install, build, run, lint, or test. Any environment "setup" is a no-op until application code and a dependency manifest are added.

### When code is added

The workspace `.cursor` rules describe the intended stack as a Node.js project ("Metaverse Simple": Node.js + Express, Vite, vanilla JS/Three.js frontend, Socket.io/Mediasoup for real-time). The runtime available on the VM is Node.js v22 with `npm`, `pnpm`, and `yarn` preinstalled, plus Python 3.12.

Once a dependency manifest exists, install with the package manager matching the committed lockfile (`pnpm-lock.yaml` → `pnpm install`, `yarn.lock` → `yarn install`, `package-lock.json`/bare `package.json` → `npm install`). The startup update script is already guarded to run the appropriate install command automatically when a manifest is present.
