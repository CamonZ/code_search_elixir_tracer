# T032: Performance Profiling

**Priority:** P3 | **Phase:** 11 - Optimization (Optional)
**Features:** NF1
**Depends On:** T028

## Description

Profile and optimize performance for large codebases.

## Acceptance Criteria

- [ ] Profile extraction on large codebase (1000+ modules)
- [ ] Identify bottlenecks using `:fprof` or similar
- [ ] Document performance characteristics
- [ ] Optimize hot paths if needed
- [ ] Target: <30 seconds for 1000 modules

## Profiling Steps

1. Find/create large test project
2. Run with profiling: `:fprof.trace([:start, {:procs, self()}])`
3. Analyze results
4. Identify top time consumers
5. Optimize if below target

## Likely Bottlenecks

- BEAM file I/O
- AST walking
- SHA computation
- JSON encoding
