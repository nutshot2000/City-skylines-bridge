# Reference only: do not run this whole file. Replace every PLACEHOLDER with LIVE data.
throw 'Read these examples and run one completed command at a time.'

pwsh -NoProfile -File ./coach.ps1 doctor
pwsh -NoProfile -File ./coach.ps1 catalog -Filter Water
pwsh -NoProfile -File ./coach.ps1 sites -Filter 'EXACT_UNLOCKED_BUILDING_NAME' -X LIVE_X -Z LIVE_Z -Radius 120
pwsh -NoProfile -File ./coach.ps1 inspect -Index LIVE_BUILDING_INDEX -Version LIVE_BUILDING_VERSION

# A proposal only. Use a fresh path; choose cost limits from actual prefab details.
pwsh -NoProfile -File ./coach.ps1 building-plan -Filter 'EXACT_UNLOCKED_BUILDING_NAME' -X LIVE_X -Z LIVE_Z -Rotation LIVE_ROTATION -MaxCost COST_LIMIT -Reserve CASH_RESERVE -PlanPath ./plans/source.json

# Node IDs must belong to compatible networks. Do not use a building or prefab ID here.
pwsh -NoProfile -File ./coach.ps1 connection-plan -Filter 'EXACT_UNLOCKED_PIPE_OR_CABLE_NAME' -FromIndex LIVE_NODE_A -FromVersion LIVE_VERSION_A -ToIndex LIVE_NODE_B -ToVersion LIVE_VERSION_B -Elevation 0 -MaxCost COST_LIMIT -Reserve CASH_RESERVE -PlanPath ./plans/connection.json

# Only within the owner's existing authorization, with controls enabled:
pwsh -NoProfile -File ./coach.ps1 apply -PlanPath ./plans/source.json
pwsh -NoProfile -File ./coach.ps1 wait -OperationId ORIGINAL_OPERATION_ID
pwsh -NoProfile -File ./coach.ps1 settle -Reserve CASH_RESERVE
pwsh -NoProfile -File ./coach.ps1 doctor
