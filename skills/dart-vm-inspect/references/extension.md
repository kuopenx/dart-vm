# VM Service Isolate Extensions

Use this capability to call a known, registered isolate extension and print its JSON result. The CLI does not expose extension discovery, so obtain the exact extension name, parameters, and response contract from project documentation, source code, or the user.

## Workflow

Call the main isolate by default:

```bash
dart-vm --uri "<vm-service-uri>" extension call \
  --name="ext.example.status" \
  --param="limit=20"
```

Select an isolate by name or ID when required, and repeat `--param` for multiple values:

```bash
dart-vm --uri "<vm-service-uri>" extension call \
  --name="<extension-name>" \
  --isolate="<isolate-name-or-id>" \
  --param="key1=value1" \
  --param="key2=value2"
```

## Boundaries

- Do not invent extension names, parameters, defaults, or response fields.
- Confirm that the target app has registered the extension before treating a failed call as a CLI defect.
- Treat parameters as `key=value` strings unless the extension's contract specifies its own parsing rules.
- Preserve the JSON result for analysis, but redact secrets and personal data before displaying or saving it.
- Read the extension-specific Skill or project documentation when one exists; use this reference only for the generic CLI invocation contract.
