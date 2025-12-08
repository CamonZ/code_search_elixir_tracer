# T033: Parallel Processing (Optional)

**Priority:** P3 | **Phase:** 11 - Optimization (Optional)
**Features:** NF1.1
**Depends On:** T032

## Description

Optionally parallelize BEAM file processing for performance.

## Acceptance Criteria

- [ ] Use `Task.async_stream` for BEAM processing
- [ ] Configure concurrency level (default: System.schedulers_online())
- [ ] Measure improvement on large projects
- [ ] Ensure thread-safe result aggregation
- [ ] Add `--parallel` / `--no-parallel` CLI flag (optional)

## Implementation Notes

```elixir
beam_files
|> Task.async_stream(&extract_from_beam/1, max_concurrency: concurrency)
|> Enum.reduce(initial_acc, &merge_results/2)
```

## Considerations

- File I/O may be the bottleneck, not CPU
- Memory usage increases with parallelism
- Order of results doesn't matter for us
- Error handling in parallel tasks
