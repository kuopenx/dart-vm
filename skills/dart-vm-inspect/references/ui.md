# Flutter UI Inspection

Use this capability to inspect Flutter Widget data or capture a Widget PNG. It is read-only inspection: do not claim support for taps, scrolling, text entry, Widget selection, or other UI interaction.

## Workflow

1. Verify Flutter Inspector and Widget-tree availability:

   ```bash
   dart-vm --uri "<vm-service-uri>" ui status
   ```

2. Print the root summary tree and obtain reusable Widget node IDs:

   ```bash
   dart-vm --uri "<vm-service-uri>" ui tree
   ```

3. Use an exact node ID from the current tree for the needed operation.

   Inspect Widget properties and its details subtree:

   ```bash
   dart-vm --uri "<vm-service-uri>" ui details --id="<widget-id>"
   ```

   Inspect Layout Explorer data with an optional subtree depth, defaulting to `1`:

   ```bash
   dart-vm --uri "<vm-service-uri>" ui layout --id="<widget-id>" --depth=1
   ```

   Capture the Widget to an explicit PNG path:

   ```bash
   dart-vm --uri "<vm-service-uri>" ui screenshot \
     --id="<widget-id>" \
     --width=390 \
     --height=844 \
     --out="<png-path>"
   ```

4. Read the tree again after substantial UI changes before reusing a node ID.

## Boundaries

- Run `ui status` before diagnosing missing trees or Inspector failures.
- Treat `width` and `height` as maximum screenshot dimensions.
- Resolve the output path explicitly and avoid overwriting an existing image unless requested.
- Report runtime Widget structure as observed data; do not treat it as a substitute for source-code analysis.
