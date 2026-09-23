# Shared response guidance. No game calls, retries or mutations.
function Get-AgentGuidance([string]$Status,[string]$ErrorText='',[string]$Id='',[string]$Poll='get_operation') {
 $g=[ordered]@{outcome='unknown';retryOriginal=$false;nextAction='Inspect the original response and current state; do not repeat a mutation.';nextCommand=$null}
 if($Status -eq 'accepted_pending_verification'){
  $g.outcome='still_running';$g.nextAction='Purchase submitted, unlock not yet verified. Read get_devtree; do not repeat the purchase. Follow PROGRESSION.md.';$g.nextCommand=@{script='agent.ps1';command='get_devtree';args=@{}};return $g
 }
 if($ErrorText -match 'devtree|development_|service_gate_locked'){
  $g.outcome='needs_input';$g.nextAction='Read progression node eligibility and actual developmentPoints. Building IDs and city XP cannot be used to buy a node. Do not repeat pending purchases.';$g.nextCommand=@{script='agent.ps1';command='get_devtree';args=@{}};return $g
 }
 if($Status -in @('queued','running','validating','applying','pending_do_not_resubmit')){
  $g.outcome='still_running';$g.nextAction='Poll the same operation once, then report progress. Do not resubmit.'
  if($Id){$g.nextCommand=@{script='agent.ps1';command=$Poll;args=@{id=$Id}}}
  return $g
 }
 if($ErrorText -match 'outcome_unknown|after_apply|result_missing|operation_id_missing|session.changed|timed.out|timeout') {return $g}
 if($Status -in @('complete','response_received','inspection_only_supply_not_certified')){
  $g.outcome='completed';$g.nextAction='This request completed. Gameplay success requires separate evidence.';return $g
 }
 if($Status -in @('failed','interrupted')){$g.outcome='failed'}
 if($ErrorText -match 'point_required|maxCost|invalid_budget'){
  $g.outcome='needs_input';$g.nextAction='Buildings require position:{x,z}, prefabIndex, prefabVersion and maxCost. Networks require start/end points and maxCost. Copy current IDs from discovery; see COMMANDS.md.'
 }elseif($ErrorText -match 'prefab_stale_or_locked|incorrect_prefab_type|zone_has_no_growables|use_zoning_for_growables'){
  $g.outcome='needs_input';$g.nextAction='Discover a current unlocked prefab of the right kind. Housing needs a usable regional zone, not a manually placed growable building.'
  $g.nextCommand=@{script='agent.ps1';command=if($ErrorText -match 'zone|growable'){'get_zone_catalog'}else{'get_build_prefabs'};args=@{}}
 }elseif($ErrorText -match 'endpoints_must_be_live_network_nodes|start_must_be_current_road_node|road_node_index|stale_point_entity|start_requires_zone_block'){
  $g.outcome='needs_input';$g.nextAction='Use the current index AND version of a network node, or a zoning block for zoning. Building IDs and prefab IDs are not connector IDs. Discover around the actual position with get_network or get_zone_cells.'
 }elseif($ErrorText -match 'finish_or_cancel|construction_busy|tool_busy'){
  $g.outcome='needs_input';$g.nextAction='Inspect the active tool/operation. Poll ongoing work; cancel only a stranded tool.'
  $g.nextCommand=@{script='agent.ps1';command='get_tool_status';args=@{}}
 }elseif($ErrorText -match 'stagnant|reassess_required'){
  $g.outcome='needs_input';$g.nextAction='Review the evidence first. After reassessment use coach.ps1 settle -Reassessed once; never loop it automatically.'
 }elseif($ErrorText -match 'control_disabled|STOP|Controls are disabled'){
  $g.outcome='needs_input';$g.nextAction='Ask the owner to enable authorized controls and close Options. Never clear STOP automatically.'
 }elseif($ErrorText -match 'attached_node_not_preserved|game_rejected_placement|no_valid_road_preview'){
  $g.outcome='failed';$g.nextAction='Inspect the native preview error and geometry. Do not retry identical coordinates or drop endpoint IDs to bypass validation.'
 }
 return $g
}
