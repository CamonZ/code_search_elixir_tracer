# T038: MinHash for Function Similarity Detection

## Problem

We need to detect similar functions across a codebase for:
- Finding duplicate or near-duplicate code
- Identifying copy-paste patterns
- Clustering related functions
- Code smell detection

MinHash is a locality-sensitive hashing technique that efficiently estimates
Jaccard similarity between sets.

## Research Required

Before implementation, we need to determine **what to hash**. Options include:

### Option A: Token-based (Source Code)
- Tokenize source code into lexical tokens
- Create shingles (n-grams) of tokens
- Pros: Catches syntactic similarity, formatting-independent
- Cons: Sensitive to variable renaming

### Option B: AST-based (Normalized)
- Use normalized AST (already have `normalize_ast/1`)
- Create shingles from AST node sequences
- Pros: Semantic similarity, rename-resistant
- Cons: May miss stylistic similarities

### Option C: AST Node Types Only
- Extract just the node types/forms from AST
- Ignore literals and identifiers entirely
- Pros: Very rename-resistant, structure-focused
- Cons: May have too many false positives

### Option D: Hybrid
- Combine AST structure with token-level details
- Weight different features differently
- Pros: Balanced approach
- Cons: More complex to implement and tune

## Research Tasks

1. **Benchmark similarity approaches** on real Elixir codebases
2. **Determine optimal shingle size** (k-grams where k = ?)
3. **Evaluate hash function count** for MinHash signature
4. **Test false positive/negative rates** for each approach

## Implementation Plan (Post-Research)

### 1. Create `MinHash` module

```elixir
defmodule CodeIntelligenceTracer.MinHash do
  @doc "Generate MinHash signature from a set of shingles"
  @spec signature(MapSet.t(), pos_integer()) :: [integer()]
  def signature(shingles, num_hashes)

  @doc "Estimate Jaccard similarity from two signatures"
  @spec similarity([integer()], [integer()]) :: float()
  def similarity(sig_a, sig_b)

  @doc "Generate shingles from AST/tokens"
  @spec shingles(term(), pos_integer()) :: MapSet.t()
  def shingles(input, k)
end
```

### 2. Integrate with FunctionExtractor

Add `minhash_signature` field to function_info:

```elixir
%{
  # ... existing fields ...
  minhash_signature: [integer()]  # or base64 encoded string
}
```

### 3. Add CLI option for similarity threshold

```bash
./call_graph --find-similar --threshold 0.8
```

## Acceptance Criteria

- [ ] Research completed with documented findings
- [ ] Shingle generation approach selected and justified
- [ ] MinHash signature computed for each function
- [ ] Similarity estimation works between function pairs
- [ ] Output includes similarity data (optional flag?)
- [ ] Performance acceptable (< 2x extraction time overhead)
