#!/usr/bin/env bash
set -euo pipefail

tag="[aa-dynamo-sglang-overlay]"

: "${REFERENCE_ROOT:?set REFERENCE_ROOT to your local reference checkout/root}"
: "${USER_PROJECT_ROOT:?set USER_PROJECT_ROOT to your local project root}"
: "${USER_HOME_ROOT:?set USER_HOME_ROOT to your local home/work root}"
: "${DYNAMO_SRC:=${USER_PROJECT_ROOT}/dynamo}"
: "${DYNAMO_DIST:=${USER_HOME_ROOT}/overlays/dynamo/dist}"
: "${DYNAMO_INFRA_BIN_DIR:=${REFERENCE_ROOT}/overlays/dynamo-pr9936-on-sglang-dev/infra-bin}"
: "${SGLANG_SRC:=${USER_PROJECT_ROOT}/sglang-test-baseline}"

echo "${tag} REFERENCE_ROOT=${REFERENCE_ROOT}"
echo "${tag} DYNAMO_SRC=${DYNAMO_SRC}"
echo "${tag} DYNAMO_DIST=${DYNAMO_DIST}"
echo "${tag} DYNAMO_INFRA_BIN_DIR=${DYNAMO_INFRA_BIN_DIR}"
echo "${tag} SGLANG_SRC=${SGLANG_SRC}"

if [ -d "${DYNAMO_INFRA_BIN_DIR}/bin" ]; then
  export PATH="${DYNAMO_INFRA_BIN_DIR}/bin:${PATH}"
fi
if [ -d "${DYNAMO_INFRA_BIN_DIR}/etcd" ]; then
  export PATH="${DYNAMO_INFRA_BIN_DIR}/etcd:${PATH}"
fi

if [ -d "${DYNAMO_SRC}/components/src" ]; then
  export PYTHONPATH="${DYNAMO_SRC}/components/src:${PYTHONPATH:-}"
fi

if [ ! -d "${DYNAMO_SRC}" ]; then
  echo "${tag} ERROR: DYNAMO_SRC not found: ${DYNAMO_SRC}" >&2
  exit 1
fi

if [ ! -d "${DYNAMO_DIST}" ]; then
  echo "${tag} ERROR: DYNAMO_DIST not found: ${DYNAMO_DIST}" >&2
  exit 1
fi

dynamo_runtime_wheel="$(
  find "${DYNAMO_DIST}" -maxdepth 3 -type f -name 'ai_dynamo_runtime*.whl' -print \
    | sort \
    | tail -n 1
)"

if [ -z "${dynamo_runtime_wheel}" ]; then
  echo "${tag} ERROR: no ai_dynamo_runtime wheel found under ${DYNAMO_DIST} (searched recursively)" >&2
  exit 1
fi

dynamo_head="$(git -C "${DYNAMO_SRC}" rev-parse --short HEAD 2>/dev/null || echo unknown)"
sglang_head="none"
if [ -n "${SGLANG_SRC}" ] && [ -d "${SGLANG_SRC}/python" ]; then
  sglang_head="$(git -C "${SGLANG_SRC}" rev-parse --short HEAD 2>/dev/null || echo unknown)"
fi

marker="/tmp/aa_overlay_${dynamo_head}_$(basename "${dynamo_runtime_wheel}")_${sglang_head}.done"
lock="/tmp/aa_overlay_${dynamo_head}_$(basename "${dynamo_runtime_wheel}")_${sglang_head}.lock"

(
  flock -x 9

  if [ -f "${marker}" ]; then
    echo "${tag} install marker exists: ${marker}"
    exit 0
  fi

  echo "${tag} installing ai-dynamo-runtime wheel: ${dynamo_runtime_wheel}"
  pip install --break-system-packages --force-reinstall --no-deps "${dynamo_runtime_wheel}"

  echo "${tag} installing ai-dynamo source: ${DYNAMO_SRC}"
  pip install --break-system-packages --no-deps -e "${DYNAMO_SRC}"

  if [ -n "${SGLANG_SRC}" ] && [ -d "${SGLANG_SRC}/python" ]; then
    if [ ! -w "${SGLANG_SRC}/python/sglang/srt/grpc" ]; then
      # Read-only baseline: prebuilt .so present, skip editable rebuild (avoids cross-node .so~ race).
      # Wire SGLANG_SRC/python into sys.path via a .pth file in site-packages.
      echo "${tag} SGLANG_SRC is read-only; skipping editable install, installing via .pth"
      site_pkg="$(python -c 'import sysconfig; print(sysconfig.get_paths()["purelib"])')"
      echo "${SGLANG_SRC}/python" > "${site_pkg}/sglang-editable.pth"
      echo "${tag} wrote ${site_pkg}/sglang-editable.pth"
    else
      echo "${tag} installing SGLang source: ${SGLANG_SRC}/python"
      mkdir -p /tmp/aa-sglang-install-locks
      lock_key="$(printf '%s' "${SGLANG_SRC}" | tr '/ ' '__')"
      (
        flock -x 9
        export RUSTUP_TOOLCHAIN="${RUSTUP_TOOLCHAIN:-stable}"
        export CARGO_TARGET_DIR="${CARGO_TARGET_DIR:-$(mktemp -d /tmp/aa-sglang-cargo-target.XXXXXX)}"
        echo "${tag} RUSTUP_TOOLCHAIN=${RUSTUP_TOOLCHAIN}"
        echo "${tag} CARGO_TARGET_DIR=${CARGO_TARGET_DIR}"
        pip install --break-system-packages --no-deps -e "${SGLANG_SRC}/python"
      ) 9>"/tmp/aa-sglang-install-locks/${lock_key}.lock"
    fi
  else
    echo "${tag} SGLANG_SRC/python not found; skipping editable SGLang install"
  fi

  touch "${marker}"
  echo "${tag} wrote install marker: ${marker}"
) 9>"${lock}"

echo "${tag} python=$(command -v python)"
echo "${tag} pip=$(command -v pip)"
python - <<'PY'
import importlib.metadata as md

for name in ("ai-dynamo", "ai-dynamo-runtime", "sglang"):
    try:
        print(f"[aa-dynamo-sglang-overlay] {name}={md.version(name)}")
    except Exception as exc:
        print(f"[aa-dynamo-sglang-overlay] {name}=unavailable ({exc})")
PY
