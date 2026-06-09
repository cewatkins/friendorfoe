# Network Laws

These are the standing network assumptions for work in this environment. Treat them as operational defaults after reloads, restarts, and fresh chat sessions.

## Host And Interface Rules

- `ootp` is a multi-interface host.
- Valid backend origins may be `192.168.1.218`, `192.168.1.219`, or `localhost`, depending on which interface or container binding is active.
- Docker network entries must be considered before deciding that a service is unreachable.

## Reachability Baselines

- Devices on the main LAN should generally be able to see `192.168.1.1` and `192.168.1.254`.
- ESP/AP startup and fallback network is `192.168.4.0/24`.
- A legacy network may also be present on `192.168.0.0/24`.
- An additional routed network may exist on `199.242.8.0/21`.

## Troubleshooting Rules

- If a hostname, CNAME, or other name-resolution path fails, assume the breakage may be on devices outside local control unless there is direct evidence otherwise.
- Prefer validating concrete IP reachability and interface binding over repeated hostname retries.
- Avoid getting stuck in circular troubleshooting loops; document the current active IP/interface assumptions and test those directly.

## Working Assumption

When debugging uplink, backend, Docker, or device connectivity in this repo, start with the assumption that multiple valid interfaces may exist simultaneously and that the correct target may differ between host-local checks, container checks, and ESP device checks.
