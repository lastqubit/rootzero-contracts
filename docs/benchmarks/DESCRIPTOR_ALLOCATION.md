# Implemented descriptor allocation benchmark

> Development snapshot: the measurements below describe the implementation at
> the time of that experiment. The current benchmark fixtures have evolved;
> rerun them for release-specific results.


Run: `npm.cmd test -- test/buffer-allocation.bench.test.ts`.

Solidity 0.8.35, optimizer 200 runs, Cancun, no viaIR; Hardhat simulated network. The benchmark now includes the production descriptor and openInput path. The scan baseline is a benchmark-only unconditional runCount strategy using the same new descriptor. It is not the old production implementation. Strategy dispatch and source-selection overhead differ, so small deltas are not isolated opcode costs.

The production descriptor precomputes group sizes during construction, outside the measured interval. Allocation, decoding, output encoding, buffer growth/copying, and finishing are measured. Transaction intrinsic/calldata gas and final hashing are excluded. Memory is free-memory-pointer growth. All strategies check final output length/hash against independent encoding.

540 measurements cover input-only stride-one workloads, including 32 repetitions at 64 blocks for scan, divisibility, ceiling, and production. The zero_hint workload deliberately clears the descriptor source group size to test fallback; normal describe() includes the header even for a zero payload hint. Grouped and state-source behavior is covered separately in codec tests.

At 64 equal-size inputs production saves 8,937 gas (6.4%) versus this scan baseline, retaining the same 4,832 bytes. Nondivisible variable input costs 407 gas more and retains the same memory. Divisible variable streams can still misestimate; this remains a capacity heuristic.

| Workload | Executions | Strategy | Gas | Memory bytes |
| --- | ---: | --- | ---: | ---: |
| equal | 1 | scan | 139,583 | 4,832 |
| equal | 1 | production | 130,646 | 4,832 |
| equal | 8 | scan | 1,118,878 | 38,656 |
| equal | 8 | production | 1,047,382 | 38,656 |
| equal | 32 | scan | 4,509,590 | 154,624 |
| equal | 32 | production | 4,223,606 | 154,624 |
| expanding | 1 | scan | 140,988 | 10,976 |
| expanding | 1 | production | 132,051 | 10,976 |
| expanding | 8 | scan | 1,140,486 | 87,808 |
| expanding | 8 | production | 1,068,990 | 87,808 |
| expanding | 32 | scan | 4,738,294 | 351,232 |
| expanding | 32 | production | 4,452,310 | 351,232 |
| shrinking | 1 | scan | 131,135 | 4,832 |
| shrinking | 1 | production | 131,542 | 4,832 |
| shrinking | 8 | scan | 1,051,294 | 38,656 |
| shrinking | 8 | production | 1,054,550 | 38,656 |
| shrinking | 32 | scan | 4,239,254 | 154,624 |
| shrinking | 32 | production | 4,252,278 | 154,624 |
| variable | 1 | scan | 131,839 | 4,832 |
| variable | 1 | production | 132,246 | 4,832 |
| variable | 8 | scan | 1,056,926 | 38,656 |
| variable | 8 | production | 1,060,182 | 38,656 |
| variable | 32 | scan | 4,261,782 | 154,624 |
| variable | 32 | production | 4,274,806 | 154,624 |
| sparse | 1 | scan | 91,543 | 4,832 |
| sparse | 1 | production | 82,606 | 4,832 |
| sparse | 8 | scan | 734,558 | 38,656 |
| sparse | 8 | production | 663,062 | 38,656 |
| sparse | 32 | scan | 2,972,310 | 154,624 |
| sparse | 32 | production | 2,686,326 | 154,624 |
| unused | 1 | scan | 76,704 | 192 |
| unused | 1 | production | 67,767 | 192 |
| unused | 8 | scan | 613,350 | 1,536 |
| unused | 8 | production | 541,854 | 1,536 |
| unused | 32 | scan | 2,453,332 | 6,144 |
| unused | 32 | production | 2,167,348 | 6,144 |
| underestimate | 1 | scan | 132,735 | 4,832 |
| underestimate | 1 | production | 133,142 | 4,832 |
| underestimate | 8 | scan | 1,064,094 | 38,656 |
| underestimate | 8 | production | 1,067,350 | 38,656 |
| underestimate | 32 | scan | 4,290,454 | 154,624 |
| underestimate | 32 | production | 4,303,478 | 154,624 |
| overestimate | 1 | scan | 132,735 | 4,832 |
| overestimate | 1 | production | 124,790 | 9,440 |
| overestimate | 8 | scan | 1,064,094 | 38,656 |
| overestimate | 8 | production | 1,007,556 | 75,520 |
| overestimate | 32 | scan | 4,290,454 | 154,624 |
| overestimate | 32 | production | 4,160,638 | 302,080 |
| zero_hint | 1 | scan | 132,735 | 4,832 |
| zero_hint | 1 | production | 133,000 | 4,832 |
| zero_hint | 8 | scan | 1,064,094 | 38,656 |
| zero_hint | 8 | production | 1,066,214 | 38,656 |
| zero_hint | 32 | scan | 4,290,454 | 154,624 |
| zero_hint | 32 | production | 4,298,934 | 154,624 |
