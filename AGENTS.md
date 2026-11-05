# AGENTS Instructions

## Ownership

comet.nvim is a generic Lua command palette with no runtime plugin dependencies.
Consumers open it with `require("comet").open(commands, opts)`.
Keep project-specific commands and behavior in the consuming plugin.

| Change | Owner |
| --- | --- |
| `setup()`, `open()` and the launch sequence | `lua/comet/init.lua` |
| Option defaults, shape and validation | `lua/comet/config.lua` |
| Session, page, output buffer and task identity | `lua/comet/state.lua` |
| Context methods and nested selection | `lua/comet/context.lua` |
| Command-entry pages and completion requests | `lua/comet/command.lua` |
| Movement, execution, cancellation, multi-select | `lua/comet/action.lua` |
| Root and submenu filtering | `lua/comet/filter.lua` |
| Floating windows, focus, resize, teardown | `lua/comet/ui/window.lua` |
| Keymaps and autocmds | `lua/comet/ui/events.lua` |
| Rows, icons, output text, status titles | `lua/comet/ui/render.lua` |
| `:checkhealth comet` | `lua/comet/health.lua` |
| Loader guard | `plugin/comet.lua` |

## Behavior to preserve

- Keep `setup()`, `open()`, command specs and `CometCtx` methods compatible, unless the task changes the public API.
- Do not add a global user command for a consumer's workflow.
- Opening the active `session_id` closes the palette. Opening another session switches to it.
- Output buffers and running tasks belong to one session and page.
- With `remember_page = true`, a reopen restores the page stack, selection and query.
- Accept strings and tables as submenu items.
- Multi-select uses `<Tab>` and passes a list to `on_select`.
- `<Esc>` and `q` leave output focus, then close a submenu, then close the root page.
- `block_while_running = true` blocks another action only on a page with an active task.
- `<C-c>` cancels the task of the current page.
- Do not let completion of an old or canceled job change the status of a newer task.
- Apply `ctx:update(items)` only while its page is active. A late result must not overwrite another page.
- Explicit item icons take precedence over the session `default_icon`.
- Keep `ctx:start_async_task(job_id)` and `ctx:terminal(job_id)` for interactive jobs.
- Send `i` and `a` input from the output panel to the job of that page.
- Keep output buffers and task status usable after the palette closes and opens again.
- Do not let a command-entry reply from an older input, cursor, page or session change the list.

## Change contracts

- Keep zero runtime plugin dependencies. Plenary, telemetry.nvim, StyLua and Luacheck are development tools.
- Give each new option a default and a shape entry in `config.lua`.
- `setup()` and `open()` reject keys that the shape does not list. Validate before any state or window changes.
- Read a context's session through `ctx._state` in context methods. Do not call `state.get()` there.
  - Reason: an old context must not act on a newer session.
- Keep each change in its owning module. Avoid an unrelated UI or state refactor for a focused fix.
- Update the option, keymap and context tables in `README.md` when their behavior changes.
- Follow `.stylua.toml` for Lua files.
- Give public functions LuaDoc types. Declare a class for each known table shape.

## Git

- Write commits in [Conventional Commits 1.0.0](https://www.conventionalcommits.org/en/v1.0.0/) format.
- Start the type, the scope and the description in lowercase. Keep the case of code identifiers and proper nouns.
- For a non-trivial change, write a commit body that explains why.
- Mark a breaking change with `!` and a `BREAKING CHANGE:` footer.
- Author commits as the user alone. Add no agent trailers or links, such as `Co-Authored-By` or a session URL.
- Commit as the plan progresses.
- Before you push, squash related commits into one commit to keep the history clean.
- Push only after the user approves that push.
- Preserve unrelated working-tree changes.

## Releases

- Version releases with [Semantic Versioning 2.0.0](https://semver.org/).
- Name each release tag with the bare version, such as `1.2.3`. If the repo already uses a tag prefix, such as `v`, keep it.
- When you create a changelog, use [Keep a Changelog 1.1.0](https://keepachangelog.com/en/1.1.0/) format. Keep the format of an existing changelog.
- Release in this order:
  1. Update the version files and the changelog in one commit, such as `chore(release): prepare 1.2.3`.
  2. Push the commit to the default branch.
  3. Wait until the branch pipeline of that commit passes.
  4. Tag that commit with an annotated tag: `git tag -a 1.2.3 -m "Release 1.2.3" <commit>`. Tag a release candidate as `1.2.3-rc.1`.
  5. Push the tag alone: `git push origin 1.2.3`. The tag pipeline publishes the package and creates the release.
- Push the commit and the tag in separate pushes. Do not use `git push --follow-tags`. One push starts two overlapping pipelines, and a single runner queues the tag pipeline.

## Tests

- Add a test to the repo only when it guards behavior that no existing test covers.
- The test must fail when that behavior breaks. Weigh this before you add each test.
- Run throwaway tests freely to check your work.
- Keep throwaway tests out of the repo unless they meet the bar above.
- Run the checks from the repository root:

  ```sh
  just all
  ```

- `just all` checks formatting, runs Luacheck and runs the specs in `tests/comet/`.
- Run one spec with `just test-spec tests/comet/<name>_spec.lua`.
- `make all` rewrites formatting before it runs the same checks.
- `tests/run.lua` runs each spec in its own Neovim process and reports through telemetry.nvim.
- Each spec child checks its own result. A failed or skipped test, a spec with no tests, or an editor error fails it.
- Load Plenary from `$COMET_TEST_PLENARY` and telemetry.nvim from `$COMET_TEST_TELEMETRY`.
  - Without a variable, the runner uses the lazy.nvim data directory.
- A missing dependency fails the run. Report each check that you could not run.
- Test a real floating-window path when a change depends on it. `tests/comet/ui_spec.lua` drives the keymaps.
- For a docs-only change, check local links and run `git diff --check` instead of the formatter.

## CI

- Keep a CI check only when it catches a concrete failure that no existing check covers.
- Identify that failure before you add or keep the check.
- Apply the test rules to CI checks too.
- Run the repo's entry points against real inputs or isolated fixtures.
- Reject duplicate checks, source-text assertions, copied inventories and checks that only prove that a command or file exists.
- Name each workflow, job and step by its target and its action.
- Propagate command failures.
- Count a missing prerequisite or skipped required coverage as a failure.
- Run the checks in branch pipelines only. A tag pipeline builds, smoke-tests and publishes the package, and then creates the release.
- Start each release job with a check that the tagged commit is on the default branch.
- Match release jobs to the tag format of the version, such as `/^[0-9]+\.[0-9]+\.[0-9]+(-[0-9A-Za-z.-]+)?$/`.
- Protect the release tags. Only protected refs can read the release credentials.
- A tag pipeline uses the CI config of the tagged commit. Merge a CI change to the default branch before you tag.
- After you change these rules, audit the repo against them.
- Validate changes locally. Then verify the required CI on the pushed commit.
- Report each uncovered contract and each unavailable check.
- Run the checks in a workflow on `pull_request` and on `push` to branches.
- Run the release in a separate workflow on `push` of tags that match `[0-9]+.[0-9]+.[0-9]+`. GitHub tag filters are globs, such as `[0-9]+.[0-9]+.[0-9]+` and `[0-9]+.[0-9]+.[0-9]+-*`.
- Check out release jobs with `fetch-depth: 0`, so that the ancestry check sees the default branch.
- Keep release secrets in an environment that allows only the release tags. Protect the tags with a tag ruleset.
- CI runs on Linux only. Run `just all` on Windows before each push.
- Pin Plenary to a commit in CI. telemetry.nvim is the exception: CI fetches its default branch.

## Docs

- Keep each doc concise and plain. Each sentence must carry information.
- Write only standing rules in `AGENTS.md`. A standing rule changes how an agent does later, unrelated tasks.
- Record a fact about one place or one failure at its source: a code comment, a test, a commit body, an ADR or an issue.
- Write English docs in US English, to the [ASD-STE100](https://www.asd-ste100.org/) writing rules:
  - Give one instruction in each sentence.
  - Write instructions in the imperative and in the active voice.
  - Use one word for one meaning, and one meaning for one word.
  - An instruction has 20 words or fewer. A description has 25 words or fewer.
- Review each sentence over these limits. Split it if it holds more than one instruction or fact.
- Use a numbered list for three or more instructions in a fixed order, also across sentences.
- Write a set of full-sentence items, or of more than five items, as a bullet list. Otherwise, the set can stay in one sentence, even when the sentence is over the limits.
- Write a non-English doc in two passes:
  1. Write an English draft to these rules.
  2. Translate the draft:
     1. Keep its sentence boundaries and one term for each concept.
     2. Keep commands, paths and code unchanged.
     3. Use the natural word order of the target language.
