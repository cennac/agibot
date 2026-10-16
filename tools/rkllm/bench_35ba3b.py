#!/usr/bin/env python3
"""Bounded Linux llama.cpp-omni CPU/LES benchmark; logs are the token authority."""
import argparse
import datetime
import json
import os
from pathlib import Path
import re
import signal
import subprocess
import time


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument('--binary', required=True)
    ap.add_argument('--model', required=True)
    ap.add_argument('--projector', required=True)
    ap.add_argument('--image', required=True)
    ap.add_argument('--experts')
    ap.add_argument('--no-mmap', action='store_true', help='Allocate weights; useful for CPU LES with the full GGUF')
    ap.add_argument('--out', required=True)
    ap.add_argument('--timeout', type=int, default=900)
    ap.add_argument('--tokens', type=int, default=64)
    ap.add_argument('--threads', type=int, default=4)
    ap.add_argument('--cases', default='intro,math,image')
    args = ap.parse_args()
    out = Path(args.out)
    out.mkdir(parents=True, exist_ok=False)
    env = os.environ.copy()
    env.update(LLAMA_MOE_LOOKAHEAD_PREFETCH='1',
               LLAMA_MOE_LOOKAHEAD_PREFETCH_DEPTH='8',
               LLAMA_MOE_DECODE_WINDOW='24', LLAMA_MOE_F_NOCACHE='0')
    cases = {
        'intro': '用两句话介绍你自己。直接给出回答。',
        'math': '水箱每分钟进水8升、出水3升，从空箱到60升需要几分钟？给出算式和答案。',
        'math_short': '只回复一行算式和答案：水箱每分钟进8升、出3升，从0到60升需要几分钟？',
        'image': '用一句中文描述这张图片中的主要内容。',
    }
    results = []
    for name in args.cases.split(','):
        cmd = [args.binary, '-m', args.model, '-p', cases[name],
               '-n', str(args.tokens), '-t', str(args.threads), '-tb', str(args.threads),
               '-c', '2048', '-b', '128', '-ub', '128', '-ngl', '0',
               '--single-turn', '--no-warmup', '--reasoning', 'off',
               '--simple-io', '--color', 'off', '--log-colors', 'off',
               '--perf', '--log-verbosity', '3', '--temp', '0', '--seed', '42']
        if args.experts:
            cmd += ['--moe-experts', args.experts, '--moe-slot-bank', '256']
        if args.no_mmap:
            cmd += ['--no-mmap']
        if name == 'image':
            cmd += ['--mmproj', args.projector, '--no-mmproj-offload', '--image', args.image]
        start = time.monotonic()
        record = dict(case=name, prompt_text=cases[name], command=cmd,
                      started=datetime.datetime.now(datetime.timezone.utc).isoformat(),
                      moe_env={k: v for k, v in env.items() if k.startswith('LLAMA_MOE_')})
        peak_kib = 0
        peak_swap_kib = 0
        read_bytes = 0
        timed_out = False
        with (out / (name + '.stdout.log')).open('wb') as stdout, \
                (out / (name + '.stderr.log')).open('wb') as stderr:
            p = subprocess.Popen(cmd, stdin=subprocess.DEVNULL, stdout=stdout,
                                 stderr=stderr, env=env, start_new_session=True)
            while p.poll() is None:
                try:
                    status = Path('/proc/%d/status' % p.pid).read_text()
                    for value in re.findall(r'^Vm(?:RSS|HWM):\s+(\d+)', status, re.M):
                        peak_kib = max(peak_kib, int(value))
                    swapped = re.search(r'^VmSwap:\s+(\d+)', status, re.M)
                    if swapped:
                        peak_swap_kib = max(peak_swap_kib, int(swapped.group(1)))
                    io = Path('/proc/%d/io' % p.pid).read_text()
                    reads = re.search(r'^read_bytes:\s+(\d+)', io, re.M)
                    if reads:
                        read_bytes = max(read_bytes, int(reads.group(1)))
                except FileNotFoundError:
                    pass
                if time.monotonic() - start > args.timeout:
                    timed_out = True
                    os.killpg(p.pid, signal.SIGTERM)
                    try:
                        p.wait(timeout=10)
                    except subprocess.TimeoutExpired:
                        os.killpg(p.pid, signal.SIGKILL)
                    break
                time.sleep(0.5)
            p.wait()
        record.update(returncode=p.returncode, timed_out=timed_out,
                      wall_seconds=round(time.monotonic() - start, 3), peak_rss_kib=peak_kib,
                      peak_swap_kib=peak_swap_kib, sampled_storage_read_bytes=read_bytes)
        log = (out / (name + '.stderr.log')).read_text(errors='replace')
        # C++ server-slot timings report tokenizer counts, not characters/chunks.
        for key, pattern in [('prompt', r'prompt eval time'), ('generation', r'(?<!prompt )\beval time')]:
            matches = re.findall(pattern + r'\s*=\s*([\d.]+) ms /\s*(\d+) tokens.*?([\d.]+) tokens per second', log)
            if matches:
                ms, tokens, speed = matches[-1]
                record[key] = dict(milliseconds=float(ms), tokens=int(tokens), tokens_per_second=float(speed))
        record['metrics_complete'] = 'prompt' in record and 'generation' in record
        results.append(record)
        (out / 'results.json').write_text(json.dumps(results, ensure_ascii=False, indent=2) + '\n')
        print(json.dumps(record, ensure_ascii=False), flush=True)
    ok = all(r['returncode'] == 0 and not r['timed_out'] and r['metrics_complete'] for r in results)
    print('BENCH_OK' if ok else 'BENCH_FAILED', flush=True)
    if not ok:
        raise SystemExit(1)


if __name__ == '__main__':
    main()
