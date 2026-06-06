Host config:
* WRX90E + 9955WX
* 2x RTX Pro 6000 Workstation, power limit 450W (unless stated otherwise), default voltage & clock
* Ubuntu 24.04, CUDA 13.3 and latest nvidia-open drivers
* Configured with [recommended configs from rtx6kpro wiki](https://github.com/local-inference-lab/rtx6kpro/blob/master/hardware/pcie-bandwidth.md)

## P2P topology & benchmarks

```
$ sudo nvidia-smi topo -m
	GPU0	GPU1	CPU Affinity	NUMA Affinity	GPU NUMA ID
GPU0	 X 	NODE	0-31	0		N/A
GPU1	NODE	 X 	0-31	0		N/A
```

p2pmark results (summary)

```
=== Sequential P2P bandwidth (GB/s) ===
 Dst->  GPU0     GPU1
GPU 0:     -      56.50
GPU 1:   56.50       -

Total all-to-all bandwidth: 111.31 GB/s  (stress test, N*(N-1) flows)

  PCIe LINK SCORE:           0.90
  (56.49 GB/s avg  /  63.0 GB/s PCIe 5.0 x16 theoretical)

  DENSE INTERCONNECT SCORE:  0.99
  (111.31 GB/s measured  /  112.99 GB/s ideal)

=== Sequential P2P latency (us) ===
 Src->  GPU0     GPU1
GPU 0:     -       0.85
GPU 1:    0.85       -
```

## DSV4 Flash benchmarks

Launch scripts in `./start.sh`.

### `voipmonitor/dsv4-flash:lucifer-mxfp4-cutlass-20260603`

Full logs in [./results/voipmonitor1/](./results/voipmonitor1/)

```
Prefill tok/s                           Aggregate decode tok/s
╭──────┬─────────┬────────┬────────┬───╮╭────────────┬───────┬───────┬────────────╮
│ ctx  │  tokens │ TTFT s │  tok/s │ N ││ ctx \ conc │     1 │     4 │         16 │
├──────┼─────────┼────────┼────────┼───┤├────────────┼───────┼───────┼────────────┤
│ 8k   │   8,190 │   0.66 │ 12,492 │ 1 ││ 0          │ 187.4 │ 376.8 │     1114.7 │
│ 32k  │  32,347 │   2.81 │ 11,526 │ 1 ││ 32k        │ 196.0 │ 370.9 │      927.7 │
│ 64k  │  64,571 │   5.72 │ 11,284 │ 1 ││ 128k       │ 195.8 │ 361.8 │ ∅ (16/16)* │
│ 128k │ 129,012 │  12.89 │ 10,006 │ 1 │╰────────────┴───────┴───────┴────────────╯
╰──────┴─────────┴────────┴────────┴───╯
```

(an earlier run had 850 for ctx 128k, conc 16)

### `voipmonitor/dsv4-flash:lucifer-mxfp4-cutlass-20260603` (2x600W)

```
Prefill tok/s                           Aggregate decode tok/s
╭──────┬─────────┬────────┬────────┬───╮╭────────────┬───────┬───────┬────────╮
│ ctx  │  tokens │ TTFT s │  tok/s │ N ││ ctx \ conc │     1 │     4 │     16 │
├──────┼─────────┼────────┼────────┼───┤├────────────┼───────┼───────┼────────┤
│ 8k   │   8,192 │   0.61 │ 13,390 │ 1 ││ 0          │ 188.7 │ 375.8 │ 1129.6 │
│ 32k  │  32,342 │   2.48 │ 13,051 │ 1 ││ 32k        │ 194.2 │ 383.3 │  898.5 │
│ 64k  │  64,559 │   5.13 │ 12,587 │ 1 ││ 128k       │ 186.4 │ 363.5 │  857.0 │
│ 128k │ 128,992 │  11.24 │ 11,472 │ 1 │╰────────────┴───────┴───────┴────────╯
╰──────┴─────────┴────────┴────────┴───╯
```


### `voipmonitor/dsv4-flash:lucifer-mxfp4-cutlass-20260603` (no MTP)

```
Prefill tok/s                           Aggregate decode tok/s
╭──────┬─────────┬────────┬────────┬───╮╭────────────┬───────┬─────────────┬───────╮
│ ctx  │  tokens │ TTFT s │  tok/s │ N ││ ctx \ conc │     1 │           4 │    16 │
├──────┼─────────┼────────┼────────┼───┤├────────────┼───────┼─────────────┼───────┤
│ 8k   │   8,190 │   0.63 │ 12,917 │ 1 ││ 0          │ 126.1 │       356.8 │ 870.4 │
│ 32k  │  32,347 │   2.68 │ 12,086 │ 1 ││ 32k        │ 123.5 │       337.3 │ 756.9 │
│ 64k  │  64,571 │   5.57 │ 11,589 │ 1 ││ 128k       │ 119.9 │ 326.5 (4/4) │ 732.6 │
│ 128k │ 129,012 │  12.59 │ 10,246 │ 1 │╰────────────┴───────┴─────────────┴───────╯
╰──────┴─────────┴────────┴────────┴───╯
```

### `voipmonitor/vllm:abyssal-abjuration-611a842`

Didn't save logs

```
Prefill tok/s                          Aggregate decode tok/s
╭──────┬─────────┬────────┬───────┬───╮╭────────────┬───────┬───────┬───────╮
│ ctx  │  tokens │ TTFT s │ tok/s │ N ││ ctx \ conc │     1 │     4 │    16 │
├──────┼─────────┼────────┼───────┼───┤├────────────┼───────┼───────┼───────┤
│ 8k   │   8,191 │   1.42 │ 5,787 │ 1 ││ 0          │  96.0 │ 239.6 │ 487.2 │
│ 32k  │  32,340 │   6.61 │ 4,891 │ 1 ││ 32k        │ 116.7 │ 281.3 │ 540.6 │
│ 64k  │  64,555 │  15.05 │ 4,289 │ 1 ││ 128k       │ 105.4 │ 250.6 │ 504.9 │
│ 128k │ 128,980 │  39.13 │ 3,297 │ 1 │╰────────────┴───────┴───────┴───────╯
╰──────┴─────────┴────────┴───────┴───╯
```

### `lavd/vllm:b12x-abyssal-abjuration-6-5-13.2-2`

Full logs in [./results/lavd1/](./results/lavd1/)

```
Prefill tok/s                          Aggregate decode tok/s
╭──────┬─────────┬────────┬───────┬───╮╭────────────┬───────┬─────────────┬───────╮
│ ctx  │  tokens │ TTFT s │ tok/s │ N ││ ctx \ conc │     1 │           4 │    16 │
├──────┼─────────┼────────┼───────┼───┤├────────────┼───────┼─────────────┼───────┤
│ 8k   │   8,192 │   1.51 │ 5,415 │ 1 ││ 0          │ 185.3 │       438.9 │ 824.6 │
│ 32k  │  32,342 │   6.83 │ 4,734 │ 1 ││ 32k        │ 187.8 │       431.8 │ 782.7 │
│ 64k  │  64,559 │  15.69 │ 4,115 │ 1 ││ 128k       │ 183.2 │ 402.2 (4/4) │ 679.4 │
│ 128k │ 128,992 │  39.73 │ 3,247 │ 1 │╰────────────┴───────┴─────────────┴───────╯
╰──────┴─────────┴────────┴───────┴───╯
```
