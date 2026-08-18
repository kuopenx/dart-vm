# Network HTTP Profile

Use this capability only for HTTP requests recorded by the running app's `dart:io` HTTP profiler. It does not resend requests, and recorded data resets when the app restarts.

## Workflow

1. Check the target isolate and recording state:

   ```bash
   dart-vm --uri "<vm-service-uri>" network status
   ```

2. If profiling is disabled, enable it and ask the user to reproduce the request:

   ```bash
   dart-vm --uri "<vm-service-uri>" network on
   ```

   Only future `dart:io` requests are recorded.

3. List newest requests first, optionally filtering by URI substring:

   ```bash
   dart-vm --uri "<vm-service-uri>" network requests
   dart-vm --uri "<vm-service-uri>" network requests --path="/activity/"
   ```

4. Take the exact `id` from the list and inspect that request:

   ```bash
   dart-vm --uri "<vm-service-uri>" network request --id=-242378432789
   dart-vm --uri "<vm-service-uri>" network request --id=-242378432789 --body
   ```

5. Stop recording future requests when requested:

   ```bash
   dart-vm --uri "<vm-service-uri>" network off
   ```

   This retains already recorded data until app restart or profile clearing outside this CLI.

## Boundaries

- Use `--body` only when request or response content is necessary. It includes UTF-8 request and response bodies.
- Do not claim headers or cookies were inspected; `dart-vm` never prints them.
- Redact credentials and sensitive personal data from displayed bodies.
- Do not describe an empty profile as proof that the app made no network requests unless profiling was already enabled during the relevant action.
