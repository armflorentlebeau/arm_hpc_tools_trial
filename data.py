#!/usr/bin/env python3

import numpy as np
import matplotlib.pyplot as plt
import subprocess
import os

nproc = [1, 2, 4]
msize = [1024, 1024, 1024, 1024]
executable = ['mmult_1', 'mmult_2', 'mmult_3', 'mmult_4']

root=os.getcwd()

os.system('git reset --hard')
os.system('patch -s -p 1 < test/patches/fix.patch')
os.system('cd src && make clean && make && cd -')
os.system('cp src/C/mmult src/C/mmult_1')
os.system('cp src/F90/mmult src/F90/mmult_1')
os.system('sed -i s/CFLAGS\ \=\ \-O0\ \-g/CFLAGS\ \=\ \-Ofast\ \-g/g src/make.def')
os.system('cd src && make clean && make && cd -')
os.system('make clean && make')
os.system('cp src/C/mmult src/C/mmult_2')
os.system('cp src/F90/mmult src/F90/mmult_2')
os.system('sed -i s/CFLAGS\ \=\ \-Ofast\ \-g/CFLAGS\ \=\ \-O0\ \-g/g src/make.def')
os.system('patch -s -p 1 < test/patches/opt.patch')
os.system('cd src && make clean && make && cd -')
os.system('cp src/C/mmult src/C/mmult_3')
os.system('cp src/F90/mmult src/F90/mmult_3')
os.system('patch -s -p 1 < test/patches/blas.patch')
os.system('cd src && make clean && make && cd -')
os.system('cp src/C/mmult src/C/mmult_4')
os.system('cp src/F90/mmult src/F90/mmult_4')

os.chdir('src/C')

data_el = []
data_ipc = []
data_cache = []
data_inst = []
data_ase = []

for j in range(0, len(executable)):
  d_el = []
  for i in nproc:
    out = subprocess.run(["perf", "stat", "-e", "cycles,instructions,stall_backend,inst_spec,ase_spec,cache-misses,cache-references", "mpirun", "-n", "{}".format(i), executable[j], "{}".format(msize[j])], stderr=subprocess.PIPE, text=True)
    print(out.stderr)
    pattern_el = "time elapsed"
    pattern_ipc = "insn per cycle"
    pattern_cache = "all cache refs"
    pattern_inst = "inst_spec"
    pattern_ase = "ase_spec"
    out = out.stderr.splitlines()
    for line in out:
      if pattern_el in line:
        el = line.split(" ")
        el = list(filter(None, el))
        d_el.append(float(el[0]))
      if i == 4:
        if pattern_ipc in line:
          ipc = line.split(" ")
          ipc = list(filter(None, ipc))
          data_ipc.append(float(ipc[3]))
        if pattern_cache in line:
          cache = line.split(" ")
          cache = list(filter(None, cache))
          data_cache.append(float(cache[3]))
        if pattern_inst in line:
          inst = line.split(" ")
          inst = list(filter(None, inst))
          data_inst.append(float(inst[0]))
        if pattern_ase in line:
          ase = line.split(" ")
          ase = list(filter(None, ase))
          data_ase.append(float(ase[0]))

  data_el.append(d_el)

# Compute speedup from elapsed time
speedup = []
for i in range(0, len(executable)):
  sp = []
  for j in range(0, len(nproc)):
    sp.append( data_el[i][0]/data_el[i][j] )
  speedup.append(sp)

# Compute speedup vs -O3 version
vs_O3 = []
for i in range(0, len(executable)):
  vs_O3.append( data_el[1][2]/data_el[i][2])

# Compute vectorization ratio
vect = []
for i in range(0, len(executable)):
  vect.append( data_ase[i]/data_inst[i] * 100)

print("Elapsed time (s)")
print(data_el)
print("Speedup")
print(speedup)
print("IPC")
print(data_ipc)
print("Cache")
print(data_cache)
print("Vectorization")
print(vect)
print("Speedup compared to -O3")
print(vs_O3)

fig, axes = plt.subplots(nrows=3, ncols=2)

# changing the size of figure to 2X2
plt.figure(figsize=(8, 8))

###### IPC
plt.subplot(3, 2, 1)
plt.bar(['GCC -O0', 'GCC -O3', 'Hand-tuned', 'BLAS'], data_ipc, color=['m','b','g','c'])
plt.title('IPC')
plt.ylabel('Instructions per cycle')

###### Vectorization
plt.subplot(3, 2, 2)
plt.bar(['GCC -O0', 'GCC -O3', 'Hand-tuned', 'BLAS'], vect, color=['m','b','g','c'])
plt.title('Vectorization')
plt.ylabel('% all instructions')

###### Cache
plt.subplot(3, 2, 3)
plt.bar(['GCC -O0', 'GCC -O3', 'Hand-tuned', 'BLAS'], data_cache, color=['m','b','g','c'])
plt.title('Cache misses')
plt.ylabel('% cache references')

##### Speedup vs O3
plt.subplot(3, 2, 4)
plt.bar(['GCC -O0', 'GCC -O3', 'Hand-tuned', 'BLAS'], vs_O3, color=['m','b','g','c'])
plt.title('Speedup vs. GCC -O3')
plt.ylabel('Speedup')

##### Scalability
plt.subplot(3, 2, 5)
plt.plot(nproc, [1, 2, 4], 'r--', label="ideal")
plt.plot(nproc, speedup[0], 'm+', label="GCC -O0")
plt.plot(nproc, speedup[1], 'b+', label="GCC -O3")
plt.plot(nproc, speedup[2], 'g+', label="Hand-tuned")
plt.plot(nproc, speedup[3], 'c+', label="BLAS")
plt.axis([0.9, 4.1, 0.9, 4.1])
plt.title('Scalability')
plt.xlabel('Number of processes')
plt.ylabel('Speedup')
new_list = range(nproc[0], nproc[-1]+1)
plt.xticks(new_list)
plt.legend(fontsize=10)

plt.tight_layout()

os.chdir(root)

plt.set_size_inchees=(18.5,20.5)
plt.savefig("data.png", dpi=100)

