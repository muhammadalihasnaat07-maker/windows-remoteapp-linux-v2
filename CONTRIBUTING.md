# Contributing

Contributions are welcome.

## General rules

- Keep examples generic.
- Never commit real credentials, usernames, private paths, tokens, or keys.
- Preserve the persistent-volume safety model; never add broad Docker prune operations.
- Keep runtime Docker access compatible with the current-user workflow.
- Keep production RemoteApp shortcuts on the broker architecture.

## Testing

Run shell syntax validation on changed shell scripts:

```bash
bash -n path/to/script.sh
```

Run the regression suite:

```bash
for test_file in tests/test-*.sh; do
    bash "$test_file"
done
```

Run Git whitespace validation:

```bash
git diff --check
```

New behavior or bug fixes should include a regression test under `tests/`.

## Line endings

Linux shell scripts and normal repository text files use LF.

Windows OEM files must retain CRLF line endings:

```text
oem/*.bat
oem/*.reg
oem/*.ps1
```

The repository `.gitattributes` file defines this policy.

Do not convert Windows OEM files to LF merely to silence a local whitespace tool.

## Documentation

Document architecture or user-facing behavior changes in README/docs and update `CHANGELOG.md` when appropriate.
