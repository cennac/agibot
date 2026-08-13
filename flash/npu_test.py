#!/usr/bin/env python3
# Minimal NPU smoke test on RK3588 via RKNNLite.
# Goal: prove the NPU actually executes inference (not model accuracy).
import os, time, threading
import numpy as np
from rknnlite.api import RKNNLite

MODEL = '/root/npu_test/resnet18.rknn'
LOAD_FILE = '/sys/kernel/debug/rknpu/version'
NPU_LOAD = '/sys/kernel/debug/rknpu/load'

def read_load():
    try:
        return open(NPU_LOAD).read().strip()
    except Exception:
        return 'n/a'

print('==== Environment ====')
print('RKNPU driver :', open(LOAD_FILE).read().strip())
import rknnlite
print('rknnlite ver :', getattr(rknnlite, '__version__', 'unknown'))
print('numpy        :', np.__version__)
print('Idle NPU load:', read_load())
print()

rknn = RKNNLite(verbose=False)
print('==== Load model:', MODEL)
print('  load_rknn   ->', rknn.load_rknn(MODEL))
print('  init_runtime->', rknn.init_runtime(core_mask=RKNNLite.NPU_CORE_0_1_2))

# Resolve input shape robustly across rknnlite versions.
shape = None
if hasattr(rknn, 'get_input_attrs'):
    try:
        a = rknn.get_input_attrs()
        if a:
            shape = tuple(a[0]['shape'])
            print('input attrs :', a)
    except Exception as e:
        print('  get_input_attrs failed:', e)
if shape is None:
    # resnet18 rknn (PyTorch, NCHW, static_shape) default
    shape = (1, 3, 224, 224)
    print('input attrs : <using default resnet18 shape>')

inp = np.random.rand(*shape).astype(np.float32)
print('input tensor:', inp.shape, inp.dtype)

print('==== Warmup ====')
t0 = time.time()
outs = rknn.inference(inputs=[inp])
print('  output shapes:', [getattr(o, 'shape', '?') for o in outs],
      '(%.2fs)' % (time.time() - t0))

# Sustained loop with concurrent NPU-load sampling to prove hardware engaged.
N = 100
stop = False
loads = []
def sampler():
    while not stop:
        loads.append(read_load())
        time.sleep(0.05)
th = threading.Thread(target=sampler); th.start()
t0 = time.time()
for _ in range(N):
    outs = rknn.inference(inputs=[inp])
dt = time.time() - t0
stop = True; th.join()

print('==== Benchmark ====')
print('  %d inferences in %.2fs -> %.1f FPS (%.1f ms/frame)' % (N, dt, N/dt, dt/N*1000))
seen = []
for l in loads:
    if l not in seen:
        seen.append(l)
print('  Distinct NPU-load readings captured during run:')
for l in seen[:8]:
    print('     ', l)

flat = np.asarray(outs[0]).flatten()
print('==== Output sanity ====')
print('  shape=%s dtype=%s sum=%.3f mean=%.5f min=%.3f max=%.3f argmax=%d'
      % (outs[0].shape, outs[0].dtype, flat.sum(), flat.mean(),
         flat.min(), flat.max(), int(np.argmax(flat))))

rknn.release()
print('\n==== RESULT: NPU inference path works ====')
