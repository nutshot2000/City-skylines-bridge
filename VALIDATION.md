# Validation — 20 September 2026

22 offline checks passed. They cover missing/partial diagnostics, exclusion of native decorations, no false supply certification, transformer classification, stale/expired plans, reserve limits, demolition refusal, node layer/type/length validation, prevention of double elevation offsets, checkpoint-before-build ordering, operation polling, replay prevention after renaming a plan, and timeout handling without resubmission.

Live-tested against the already-running bridge in a local test city:

- doctor: correct paused state, funds, disabled controls, STOP latch, capacity/production and missing water/sewage capacity.
- catalog: useful water assets and lock state without hundreds of waterfront houses.
- sites: water-tower candidate returned with prefab details.
- inspect: transformer and underground pipe node plus nearby named network edges.
- building-plan: resolved a current water-tower prefab and wrote a proposal without construction.
- connection-plan: recognized the existing physical pipe path and refused to propose a duplicate.
- apply with STOP: refused before construction.

Funds were unchanged and the game remained paused. STOP remained latched. No new construction or simulation was performed while developing this kit.

The apply wrapper's successful save/submit/wait sequence is tested with simulated bridge responses, not new live construction. The earlier raw-bridge tests demonstrated real construction, but that is not the same as live-testing the new wrapper. Node-to-node connection construction, arbitrary utility routing, shoreline/resource suitability, actual water/sewage delivery, and powering a populated neighborhood remain unverified by this helper kit.

Source: bridge-client.ps1 is a local derivative of the client supplied by https://github.com/FTPAiYT/cities2-agent-bridge-ndc (0.4.2 community package), with heartbeat timestamps preserved as strings. The original package remains separate and unchanged. No game DLLs, saves, private city records or mailbox data are included in the shareable ZIP.

