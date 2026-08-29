# Security policy

Do not report real passwords, tokens, private keys, or personal paths in public issues.

Before publishing logs, redact:

- credential values or credential-file contents
- Keep FreeRDP credentials out of process arguments. The current launchers pass FreeRDP arguments through `/args-from:stdin`.
- Linux usernames and home paths
- Windows usernames
- IP addresses that are not loopback
- email addresses
- repository tokens
