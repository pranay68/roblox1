Server validation checklist

1) All RemoteEvents must be validated server-side.
   - `SparkEvent`: validate player proximity to `Spark` (done)
   - `RevealEvent`: validate usage frequency and metrics (basic logging added)
   - `ProfilerEvent`: accept telemetry only (no game state changes)
   - `IgnisiaEffectEvent`: server-only broadcast; clients should not perform state changes on this event

2) Shard awards and teleportation are server-authoritative.
   - `Zone2Content` now verifies touching player's Hrp is within 6 studs before awarding shard.
   - `Zone2Gate` uses ProximityPrompt on server and re-checks `HasSpark` before teleporting.

3) SaveService uses UpdateAsync + write queue + retry/backoff and failure metrics.

4) Further improvements to add:
   - Rate-limit per-player RemoteEvent calls to avoid spam/DoS.
   - Authorization tokens for critical events if needed.
   - Validate reflectionChoice strings against whitelist.


