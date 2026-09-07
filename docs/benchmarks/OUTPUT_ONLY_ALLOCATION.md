# Output-only initial allocation benchmark

> Development snapshot: the measurements below describe the implementation at
> the time of that experiment. The current benchmark fixtures have evolved;
> rerun them for release-specific results.


Run: `npm.cmd test -- test/output-allocation.bench.test.ts`.

Production code is unchanged. 140 measurements passed independently encoded output length and hash checks. Solidity 0.8.35, optimizer 200 runs, Cancun, no viaIR; Hardhat simulated network.

Compare initial logical capacity zero with one output group from the descriptor. Both paths directly initialize the same production buffer cursor, write via Execution output helpers, and finish. This isolates capacity selection and buffer behavior; it does not implement or measure a new conditional inside production writerCursor. Descriptors and reusable zero-filled BYTES payloads are prepared outside measurement. Gas covers cursor creation, output loops, allocation, resizing/copying and finish, plus common benchmark overhead. It excludes transaction intrinsic gas, descriptor/payload construction and final hashing. Memory means free-memory-pointer growth, including abandoned buffers. Repeated executions share memory in one call.

Workloads: BALANCE (72 encoded bytes), POSITION (168), and BYTES payloads 16/128/1024 bytes (24/136/1032 encoded bytes), using the standard BYTES hint of 128 payload bytes. Strides 1 and 4; 0/1/2/3/8/64 output groups; eight groups also measured across 16 executions.

Single-group, stride-one results: BALANCE gas 2,670 to 2,397 and memory 352 to 320 bytes; POSITION gas 2,997 to 2,584 and memory 480 to 416 bytes. Empty executions have identical gas/memory and allocate no output buffer. These memory figures include the Execution struct, array length word, and trailing padding, not just logical capacity.

Many fixed-size batches benefit from growth starting at the group size, but three-group stride-one batches regress: BALANCE costs 407 more gas and POSITION 349 more. The smaller initial capacity can trigger a resize earlier than the larger power-of-two allocation. Five of the 70 paired comparisons cost more gas with the one-group hint. Variable outputs can overallocate: one 16-byte BYTES payload retains 384 bytes with the one-group hint versus 288 with zero capacity. Results are workload-dependent, especially as allocations accumulate.

Recommendation: a one-output-group hint is promising for no-source descriptors, especially fixed-size outputs. The production branch and its effect on ordinary source-backed execution still need measurement if implemented.

| Workload | Stride | Groups | Executions | Strategy | Gas | Memory bytes |
| --- | ---: | ---: | ---: | --- | ---: | ---: |
| balance | 1 | 0 | 1 | zero | 827 | 192 |
| balance | 1 | 0 | 1 | one_group | 827 | 192 |
| balance | 1 | 1 | 1 | zero | 2,670 | 352 |
| balance | 1 | 1 | 1 | one_group | 2,397 | 320 |
| balance | 1 | 2 | 1 | zero | 4,442 | 672 |
| balance | 1 | 2 | 1 | one_group | 4,150 | 544 |
| balance | 1 | 3 | 1 | zero | 5,528 | 672 |
| balance | 1 | 3 | 1 | one_group | 5,935 | 896 |
| balance | 1 | 8 | 1 | zero | 12,587 | 2,336 |
| balance | 1 | 8 | 1 | one_group | 12,133 | 1,536 |
| balance | 1 | 8 | 16 | zero | 203,321 | 37,376 |
| balance | 1 | 8 | 16 | one_group | 194,641 | 24,576 |
| balance | 1 | 64 | 1 | zero | 79,240 | 16,864 |
| balance | 1 | 64 | 1 | one_group | 76,940 | 9,792 |
| balance | 4 | 0 | 1 | zero | 827 | 192 |
| balance | 4 | 0 | 1 | one_group | 827 | 192 |
| balance | 4 | 1 | 1 | zero | 7,363 | 1,248 |
| balance | 4 | 1 | 1 | one_group | 5,692 | 512 |
| balance | 4 | 2 | 1 | zero | 12,587 | 2,336 |
| balance | 4 | 2 | 1 | one_group | 10,803 | 1,152 |
| balance | 4 | 3 | 1 | zero | 16,931 | 2,336 |
| balance | 4 | 3 | 1 | one_group | 16,058 | 2,368 |
| balance | 4 | 8 | 1 | zero | 41,504 | 8,608 |
| balance | 4 | 8 | 1 | one_group | 38,989 | 4,736 |
| balance | 4 | 8 | 16 | zero | 697,420 | 137,728 |
| balance | 4 | 8 | 16 | one_group | 633,529 | 75,776 |
| balance | 4 | 64 | 1 | zero | 308,569 | 66,144 |
| balance | 4 | 64 | 1 | one_group | 294,451 | 37,184 |
| position | 1 | 0 | 1 | zero | 827 | 192 |
| position | 1 | 0 | 1 | one_group | 827 | 192 |
| position | 1 | 1 | 1 | zero | 2,997 | 480 |
| position | 1 | 1 | 1 | one_group | 2,584 | 416 |
| position | 1 | 2 | 1 | zero | 4,997 | 1,056 |
| position | 1 | 2 | 1 | one_group | 4,553 | 832 |
| position | 1 | 3 | 1 | zero | 6,252 | 1,056 |
| position | 1 | 3 | 1 | one_group | 6,601 | 1,568 |
| position | 1 | 8 | 1 | zero | 14,550 | 4,256 |
| position | 1 | 8 | 1 | one_group | 13,838 | 2,976 |
| position | 1 | 8 | 16 | zero | 240,519 | 68,096 |
| position | 1 | 8 | 16 | one_group | 224,889 | 47,616 |
| position | 1 | 64 | 1 | zero | 95,612 | 33,120 |
| position | 1 | 64 | 1 | one_group | 91,409 | 21,984 |
| position | 4 | 0 | 1 | zero | 827 | 192 |
| position | 4 | 0 | 1 | one_group | 827 | 192 |
| position | 4 | 1 | 1 | zero | 8,386 | 2,144 |
| position | 4 | 1 | 1 | one_group | 6,443 | 896 |
| position | 4 | 2 | 1 | zero | 14,550 | 4,256 |
| position | 4 | 2 | 1 | one_group | 12,420 | 2,304 |
| position | 4 | 3 | 1 | zero | 19,570 | 4,256 |
| position | 4 | 3 | 1 | one_group | 18,750 | 5,056 |
| position | 4 | 8 | 1 | zero | 49,352 | 16,672 |
| position | 4 | 8 | 1 | one_group | 45,925 | 10,496 |
| position | 4 | 8 | 16 | zero | 916,309 | 266,752 |
| position | 4 | 8 | 16 | one_group | 784,670 | 167,936 |
| position | 4 | 64 | 1 | zero | 392,269 | 131,552 |
| position | 4 | 64 | 1 | one_group | 360,825 | 85,952 |
| bytes16 | 1 | 0 | 1 | zero | 826 | 192 |
| bytes16 | 1 | 0 | 1 | one_group | 826 | 192 |
| bytes16 | 1 | 1 | 1 | zero | 2,302 | 288 |
| bytes16 | 1 | 1 | 1 | one_group | 2,186 | 384 |
| bytes16 | 1 | 2 | 1 | zero | 3,167 | 288 |
| bytes16 | 1 | 2 | 1 | one_group | 3,051 | 384 |
| bytes16 | 1 | 3 | 1 | zero | 4,690 | 480 |
| bytes16 | 1 | 3 | 1 | one_group | 3,916 | 384 |
| bytes16 | 1 | 8 | 1 | zero | 9,703 | 800 |
| bytes16 | 1 | 8 | 1 | one_group | 8,936 | 736 |
| bytes16 | 1 | 8 | 16 | zero | 154,974 | 12,800 |
| bytes16 | 1 | 8 | 16 | one_group | 142,653 | 11,776 |
| bytes16 | 1 | 64 | 1 | zero | 60,907 | 4,576 |
| bytes16 | 1 | 64 | 1 | one_group | 60,197 | 4,736 |
| bytes16 | 4 | 0 | 1 | zero | 826 | 192 |
| bytes16 | 4 | 0 | 1 | one_group | 826 | 192 |
| bytes16 | 4 | 1 | 1 | zero | 5,555 | 480 |
| bytes16 | 4 | 1 | 1 | one_group | 4,855 | 768 |
| bytes16 | 4 | 2 | 1 | zero | 9,703 | 800 |
| bytes16 | 4 | 2 | 1 | one_group | 8,315 | 768 |
| bytes16 | 4 | 3 | 1 | zero | 13,913 | 1,376 |
| bytes16 | 4 | 3 | 1 | one_group | 11,775 | 768 |
| bytes16 | 4 | 8 | 1 | zero | 32,089 | 2,464 |
| bytes16 | 4 | 8 | 1 | one_group | 29,964 | 1,920 |
| bytes16 | 4 | 8 | 16 | zero | 515,642 | 39,424 |
| bytes16 | 4 | 8 | 16 | one_group | 480,547 | 30,720 |
| bytes16 | 4 | 64 | 1 | zero | 231,647 | 16,992 |
| bytes16 | 4 | 64 | 1 | one_group | 229,761 | 17,344 |
| bytes128 | 1 | 0 | 1 | zero | 826 | 192 |
| bytes128 | 1 | 0 | 1 | one_group | 826 | 192 |
| bytes128 | 1 | 1 | 1 | zero | 2,614 | 480 |
| bytes128 | 1 | 1 | 1 | one_group | 2,196 | 384 |
| bytes128 | 1 | 2 | 1 | zero | 4,229 | 1,056 |
| bytes128 | 1 | 2 | 1 | one_group | 3,767 | 736 |
| bytes128 | 1 | 3 | 1 | zero | 5,103 | 1,056 |
| bytes128 | 1 | 3 | 1 | one_group | 5,400 | 1,344 |
| bytes128 | 1 | 8 | 1 | zero | 11,469 | 4,256 |
| bytes128 | 1 | 8 | 1 | one_group | 10,663 | 2,496 |
| bytes128 | 1 | 8 | 16 | zero | 191,230 | 68,096 |
| bytes128 | 1 | 8 | 16 | one_group | 172,887 | 39,936 |
| bytes128 | 1 | 64 | 1 | zero | 71,115 | 33,120 |
| bytes128 | 1 | 64 | 1 | one_group | 65,683 | 17,920 |
| bytes128 | 4 | 0 | 1 | zero | 826 | 192 |
| bytes128 | 4 | 0 | 1 | one_group | 826 | 192 |
| bytes128 | 4 | 1 | 1 | zero | 6,843 | 2,144 |
| bytes128 | 4 | 1 | 1 | one_group | 4,891 | 768 |
| bytes128 | 4 | 2 | 1 | zero | 11,469 | 4,256 |
| bytes128 | 4 | 2 | 1 | one_group | 9,277 | 1,920 |
| bytes128 | 4 | 3 | 1 | zero | 14,965 | 4,256 |
| bytes128 | 4 | 3 | 1 | one_group | 13,939 | 4,160 |
| bytes128 | 4 | 8 | 1 | zero | 37,094 | 16,672 |
| bytes128 | 4 | 8 | 1 | one_group | 33,181 | 8,576 |
| bytes128 | 4 | 8 | 16 | zero | 720,182 | 266,752 |
| bytes128 | 4 | 8 | 16 | one_group | 563,992 | 137,216 |
| bytes128 | 4 | 64 | 1 | zero | 294,271 | 131,552 |
| bytes128 | 4 | 64 | 1 | one_group | 254,339 | 69,696 |
| bytes1024 | 1 | 0 | 1 | zero | 827 | 192 |
| bytes1024 | 1 | 0 | 1 | one_group | 827 | 192 |
| bytes1024 | 1 | 1 | 1 | zero | 3,453 | 2,272 |
| bytes1024 | 1 | 1 | 1 | one_group | 2,961 | 1,312 |
| bytes1024 | 1 | 2 | 1 | zero | 5,995 | 6,432 |
| bytes1024 | 1 | 2 | 1 | one_group | 5,085 | 3,552 |
| bytes1024 | 1 | 3 | 1 | zero | 6,953 | 6,432 |
| bytes1024 | 1 | 3 | 1 | one_group | 7,800 | 7,968 |
| bytes1024 | 1 | 8 | 1 | zero | 20,468 | 31,136 |
| bytes1024 | 1 | 8 | 1 | one_group | 15,693 | 16,736 |
| bytes1024 | 1 | 8 | 16 | zero | 770,696 | 498,176 |
| bytes1024 | 1 | 8 | 16 | one_group | 378,734 | 267,776 |
| bytes1024 | 1 | 64 | 1 | zero | 258,489 | 260,704 |
| bytes1024 | 1 | 64 | 1 | one_group | 136,401 | 138,784 |
| bytes1024 | 4 | 0 | 1 | zero | 827 | 192 |
| bytes1024 | 4 | 0 | 1 | one_group | 827 | 192 |
| bytes1024 | 4 | 1 | 1 | zero | 10,739 | 14,688 |
| bytes1024 | 4 | 1 | 1 | one_group | 8,492 | 7,968 |
| bytes1024 | 4 | 2 | 1 | zero | 20,468 | 31,136 |
| bytes1024 | 4 | 2 | 1 | one_group | 15,427 | 16,736 |
| bytes1024 | 4 | 3 | 1 | zero | 24,300 | 31,136 |
| bytes1024 | 4 | 3 | 1 | one_group | 25,709 | 34,208 |
| bytes1024 | 4 | 8 | 1 | zero | 98,262 | 129,568 |
| bytes1024 | 4 | 8 | 1 | one_group | 60,619 | 69,088 |
| bytes1024 | 4 | 8 | 16 | zero | 9,256,494 | 2,073,088 |
| bytes1024 | 4 | 8 | 16 | one_group | 3,154,307 | 1,105,408 |
| bytes1024 | 4 | 64 | 1 | zero | 2,594,207 | 1,047,264 |
| bytes1024 | 4 | 64 | 1 | one_group | 975,588 | 556,704 |
