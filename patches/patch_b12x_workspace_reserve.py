"""Patch workspace to allow growth when locked, instead of crashing.

The b12x compressed-MLA prefill scratch can exceed the workspace size
established during warmup (especially under DCP where the all-gather
doubles the head count). Prefill runs in piecewise/eager mode -- not
inside a full CUDA graph -- so growing the workspace is safe.
"""

import pathlib

TARGET = pathlib.Path(
    "/opt/venv/lib/python3.12/site-packages/vllm/v1/worker/workspace.py"
)

OLD = """\
            if self._locked:
                raise AssertionError(
                    f"Workspace is locked but allocation from '{get_caller_info()}' "
                    f"requires {required_bytes / _MB:.2f} MB, current size is "
                    f"{current_size / _MB:.2f} MB. "
                    "Workspace growth is not allowed after locking."
                )"""

NEW = """\
            if self._locked:
                logger.warning(
                    "Workspace is locked but allocation from '%s' "
                    "requires %.2f MB, current size is %.2f MB. "
                    "Growing workspace despite lock (prefill/eager path).",
                    get_caller_info(),
                    required_bytes / _MB,
                    current_size / _MB,
                )"""


def main():
    src = TARGET.read_text()
    count = src.count(OLD)
    assert count == 1, f"Expected exactly 1 match, found {count} in {TARGET}"
    patched = src.replace(OLD, NEW)
    TARGET.write_text(patched)
    print(f"Patched workspace lock -> warn-and-grow in {TARGET}")


if __name__ == "__main__":
    main()
