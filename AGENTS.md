# Repository guidance

For the Gentoo musl/LLVM migration, start with
`gentoo_setting/experiments/musl-llvm-pc/README.md`, then its
`world-migration.tsv`, `portage/repository-baseline.tsv`, and relevant
`patchsets/*/README.md`. These are the consolidated public records.

On the experiment PC, read `/var/tmp/musl-pc-lab-20261113/phase4/CHECKPOINT.md`
before resuming operations. Its latest phase section identifies the candidate,
active worker, job results, logs, and remaining work. Older sections are history.
If that private checkpoint is absent, inspect the current environment; do not
assume an experimental root or authorization process exists on another machine.

- Keep migration changes on `experiment/musl-llvm-migration`. Preserve `main`
  and Windows configuration synchronization. Do not deploy the blog implicitly.
- Maintain versioned source/repository patches against recorded baselines;
  prefer the existing repositories instead of adding another overlay. Record
  application order, validation limits, and conditions for removing each patch.
- Verify worker identity, live process state, scope, and pending requests before
  queueing a task. A status file alone does not prove a process is alive. Reuse
  an existing bounded authorization where valid; never run concurrent Portage
  writers against one root. New phases may require local Polkit verification.
- Keep build, installation, isolated GUI/input, real hardware, old user data,
  and boot/rollback acceptance distinct. Do not report a preview as an install.
  Inspect failures before restarting a large build or weakening its sandbox.
- Preserve the original root, boot entries, databases, signing keys and user
  profiles until the corresponding migration and rollback steps are verified.
  Publish no private keys, credentials, resolver contents or raw screenshots.
- Update the existing public records and private checkpoint after a milestone,
  including exact commits, unfinished tasks and any running jobs. Avoid adding
  scattered temporary reports. Check the blog's own `AGENTS.md` before editing it.
