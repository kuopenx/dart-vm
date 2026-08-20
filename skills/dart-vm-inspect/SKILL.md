---
name: dart-vm-inspect
description: Discover locally running Dart or Flutter VM Services and inspect them with the `dart-vm` CLI using `network` for HTTP profiles, `ui` for Widget trees, layout, and screenshots, and `extension call` for known isolate extensions. Excludes Dart MCP controls and UI automation.
---

# Inspect with dart-vm

Use the installed `dart-vm` CLI as the source of truth. Do not substitute Dart MCP tools or claim unsupported Hot Reload, Hot Restart, runtime-error, tap, scroll, or text-input capabilities.

## Connect to the app

1. Confirm availability with `command -v dart-vm` and inspect version-sensitive behavior with `dart-vm --help` or the relevant `--help` command.
2. Run `dart-vm service list` to discover reachable sessions started by local Flutter tooling or IDEs. Select the target by `deviceName`, `packageName`, and `pid`. If discovery returns no matching session, obtain the URI from `flutter run` or a DevTools URL.
3. Supply the selected URI explicitly with `dart-vm --uri "<vm-service-uri>" <command>`, set `DART_VM_SERVICE_URI`, or save it with `dart-vm config uri set "<vm-service-uri>"`. `service list` is read-only and does not change the saved URI.
4. Treat the URI and its authentication token as sensitive. Do not print, persist in project files, or include it in the final response unless the user explicitly requests that exact value.

Use `dart-vm config uri show` to inspect the saved URI and `dart-vm config uri clear` to remove it. Prefer an explicit `--uri` when multiple apps may be running. If a full App or simulator restart makes a saved URI stale, run `service list` again and select the replacement URI.

## Check the installed version

Use `dart-vm --version` for the current version and `dart-vm upgrade --check` when the user asks whether an update exists. Run the mutating `dart-vm upgrade` command only when the user explicitly requests the upgrade. Self-upgrade verifies the release checksum and does not modify the saved VM Service URI.

## Load only the needed capability

- For HTTP Profile requests, filtering, bodies, or recording state, read [references/network.md](references/network.md).
- For Widget trees, properties, layout, or Widget screenshots, read [references/ui.md](references/ui.md).
- For a known VM Service isolate extension, read [references/extension.md](references/extension.md).

Read multiple references only when the task actually crosses those capability boundaries.

## Report results

Return command output verbatim without preprocessing.

State which running app or isolate was inspected when it matters. Distinguish observed runtime data from general capability descriptions. Redact tokens, cookies, authorization data, and other credentials from commands and output.
