# Execution capabilities

Treat code execution as an independent subsystem. Never let editor UI or lesson
copy overstate what the subsystem actually proved.

## Capability levels

### A: deterministic exercises

Use authored answers, token constraints, ordering rules, expected output,
structural checks, rubrics, and preconfigured SwiftUI repair tasks. This is the
required first functional capability.

### B: constrained local runner

Support only a documented Swift subset or precompiled templates. Label the
unsupported language and framework surface explicitly.

### C: full compiler experiment

Isolate research into compiler components, WebAssembly, sandboxing, binary size,
memory, thermal impact, startup time, language coverage, maintenance, licensing,
and App Review risk. Produce a measured go/no-go decision. This experiment may
relax the Apple-only dependency boundary only inside this subsystem.

### D: external compilation

Keep an optional remote compiler, local Mac companion, or Xcode export as a
fallback. Do not make a backend a hidden requirement for the local learning
product.

## User-visible labels

Use exactly one honest label per result:

- compiled and tested;
- deterministically validated;
- statically checked;
- rubric evaluated;
- experimental.

## SwiftUI exercises

Prefer precompiled configurable views, static checks for required constructs and
modifier use, visual-result selection, and export to Xcode. Do not dynamically
load arbitrary compiled SwiftUI code into the signed app.

## Spike evidence

Record toolchain version, device, OS, sample corpus, supported syntax, latency,
memory, thermal behavior, binary impact, failure modes, and review/licensing
constraints. Keep experimental code out of production boundaries until the
decision record accepts it.
