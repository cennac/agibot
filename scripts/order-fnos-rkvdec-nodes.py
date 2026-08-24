#!/usr/bin/env python3
"""Put fnOS RKVDEC2 CCU/core nodes in vendor-driver probe order."""

import pathlib
import subprocess
import sys
import tempfile


NODES = (
    "rkvdec-ccu@fdc30000",
    "rkvdec-core@fdc38000",
    "rkvdec-core@fdc48000",
)


def node_span(source: str, name: str) -> tuple[int, int]:
    start = source.index("\n\t" + name + " {") + 1
    brace = source.index("{", start)
    depth = 0
    for index in range(brace, len(source)):
        if source[index] == "{":
            depth += 1
        elif source[index] == "}":
            depth -= 1
            if depth == 0:
                end = source.index(";", index) + 1
                while end < len(source) and source[end] == "\n":
                    end += 1
                return start, end
    raise ValueError(f"unterminated node: {name}")


def main() -> None:
    if len(sys.argv) != 3:
        raise SystemExit(f"usage: {sys.argv[0]} input.dtb output.dtb")

    source_dtb = pathlib.Path(sys.argv[1]).resolve()
    output_dtb = pathlib.Path(sys.argv[2]).resolve()
    with tempfile.TemporaryDirectory() as directory:
        dts = pathlib.Path(directory) / "tree.dts"
        ordered_dts = pathlib.Path(directory) / "tree-ordered.dts"
        subprocess.run(
            ["dtc", "-q", "-I", "dtb", "-O", "dts", "-o", dts, source_dtb],
            check=True,
        )
        source = dts.read_text()
        spans = sorted(node_span(source, name) for name in NODES)
        blocks = {name: source[slice(*node_span(source, name))] for name in NODES}
        for span, name in zip(reversed(spans), reversed(NODES)):
            source = source[: span[0]] + blocks[name] + source[span[1] :]
        ordered_dts.write_text(source)
        subprocess.run(
            ["dtc", "-q", "-I", "dts", "-O", "dtb", "-o", output_dtb, ordered_dts],
            check=True,
        )


if __name__ == "__main__":
    main()
