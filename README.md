# SA-AgentX GB300 Pareto Configs

Sanitized SRT-SLURM YAML configs for DeepSeek-V4-Pro / SGLang / Dynamo GB300
SA-AgentX benchmark runs.

These files preserve the run topology, concurrency, SGLang backend arguments, and
benchmark shape from the original Pareto-frontier experiments. Cluster-local
paths, account names, and credentials have been replaced with placeholders so the
configs can be shared publicly.

## Configs

| JID | Topology | GPUs | Concurrency | hicache-ratio | spec-num-steps |
|---|---|---:|---:|---:|---:|
| jid2098561 | 1P x DEP4 + 1D x DEP16 | 20 | 256 | 4 | 3 |
| jid2101637 | 3P x DEP4 + 1D x DEP8 | 20 | 768 | 6 | 3 |
| jid2102170 | 2P x DEP4 + 1D x DEP16 | 24 | 256 | 6 | 3 |
| jid2106740 | 3P x DEP4 + 1D x DEP16 | 28 | 512 | 6 | 3 |
| jid2107404 | 6P x DEP4 + 1D x DEP16 | 40 | 1024 | 6 | 3 |
| jid2108001 | 1P x DEP4 + 6D x DEP4 | 28 | 32 | 6 | 3 |
| jid2108167 | 1P x DEP4 + 6D x DEP4 | 28 | 8 | 6 | 3 |
| jid2109702 | 3P x DEP4 + 1D x DEP32 | 44 | 512 | 6 | 3 |
| jid2114646 | 1P x DEP4 + 6D x DEP4 | 28 | 64 | 6 | 3 |
| jid2114740 | 1P x DEP4 + 6D x DEP4 | 28 | 64 | 6 | 3 |
| jid2132562 | 6P x DEP4 + 1D x DEP8 | 32 | 768 | 6 | 3 |
| jid2132800 | 6P x DEP4 + 1D x DEP16 | 40 | 768 | 6 | 3 |
| jid2138209 | 3P x DEP4 + 1D x DEP8 | 20 | 384 | 6 | 3 |
| jid2138854 | 3P x DEP4 + 1D x DEP8 | 20 | 512 | 6 | 3 |

## Common Settings

- Model: `deepseek-ai/DeepSeek-V4-Pro`
- Precision: FP4
- GPU type: GB300
- Frontend: Dynamo KV router
- Backend: SGLang disaggregated serving
- Transfer backend: Mooncake
- Speculative decoding: EAGLE, 3 steps, top-k 1, 4 draft tokens
- Dataset used in the benchmark commands: SA-AgentX / SemiAnalysis cc-traces

## Placeholders To Fill

Before running, replace these placeholders with your local values:

| Placeholder | Meaning |
|---|---|
| `${MODEL_PATH}` | Local or mounted DeepSeek-V4-Pro checkpoint path |
| `${SGLANG_CONTAINER_SQSH}` | SGLang container image or SquashFS path |
| `${SLURM_ACCOUNT}` | SLURM account |
| `${SLURM_PARTITION}` | SLURM partition |
| `${HOST_LUSTRE_PATH}` | Host path mounted to `/lustre` |
| `${AIPERF_CHECKOUT}` | Local checkout of the benchmark harness mounted to `/aiperf` |
| `${DYNAMO_SRC}` | Dynamo source checkout |
| `${DYNAMO_DIST}` | Dynamo wheel/dist directory |
| `${DYNAMO_INFRA_BIN_DIR}` | Dynamo infra binary directory |
| `${SGLANG_SRC}` | Optional editable SGLang source checkout |

## Running

Example:

```bash
srtctl apply -f disagg-gb3-6p1d-dep4-dep16-mtp-kv-offload-con1024-ratio6-jid2107404.yaml
```

Use `srtctl dry-run -f <config.yaml>` first to inspect generated `sbatch`, `srun`,
mounts, environment, and worker commands for your cluster.

## Sanitization Notes

The public copy intentionally removes:

- literal Hugging Face tokens
- internal filesystem paths
- internal account names
- private source checkout locations

The original topology and SGLang/Dynamo tuning fields are left intact.
