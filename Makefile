# choose your compiler, e.g. gcc/clang
# example override to clang: make run CC=clang
CC = gcc

# the most basic way of building that is most likely to work on most systems
.PHONY: run
run: run.c
	$(CC) -O3 -o run run.c -lm
	$(CC) -O3 -o runq runq.c -lm

# useful for a debug build, can then e.g. analyze with valgrind, example:
# $ valgrind --leak-check=full ./run out/model.bin -n 3
rundebug: run.c
	$(CC) -g -o run run.c -lm
	$(CC) -g -o runq runq.c -lm

# https://gcc.gnu.org/onlinedocs/gcc/Optimize-Options.html
# https://simonbyrne.github.io/notes/fastmath/
# -Ofast enables all -O3 optimizations.
# Disregards strict standards compliance.
# It also enables optimizations that are not valid for all standard-compliant programs.
# It turns on -ffast-math, -fallow-store-data-races and the Fortran-specific
# -fstack-arrays, unless -fmax-stack-var-size is specified, and -fno-protect-parens.
# It turns off -fsemantic-interposition.
# In our specific application this is *probably* okay to use
.PHONY: runfast
runfast: run.c
	$(CC) -Ofast -o run run.c -lm
	$(CC) -Ofast -o runq runq.c -lm

# additionally compiles with OpenMP, allowing multithreaded runs
# make sure to also enable multiple threads when running, e.g.:
# OMP_NUM_THREADS=4 ./run out/model.bin
.PHONY: runomp
runomp: run.c
	$(CC) -Ofast -fopenmp -march=native run.c  -lm  -o run
	$(CC) -Ofast -fopenmp -march=native runq.c  -lm  -o runq

.PHONY: win64
win64:
	x86_64-w64-mingw32-gcc -Ofast -D_WIN32 -o run.exe -I. run.c win.c
	x86_64-w64-mingw32-gcc -Ofast -D_WIN32 -o runq.exe -I. runq.c win.c

# compiles with gnu99 standard flags for amazon linux, coreos, etc. compatibility
.PHONY: rungnu
rungnu:
	$(CC) -Ofast -std=gnu11 -o run run.c -lm
	$(CC) -Ofast -std=gnu11 -o runq runq.c -lm

.PHONY: runompgnu
runompgnu:
	$(CC) -Ofast -fopenmp -std=gnu11 run.c  -lm  -o run
	$(CC) -Ofast -fopenmp -std=gnu11 runq.c  -lm  -o runq

# compiles with gprof profiling support (debug-friendly, better function visibility)
# Usage: make runprof && ./run model.bin -n 100 && gprof run gmon.out > profile.txt
.PHONY: runprof
runprof: run.c
	$(CC) -pg -g -O2 -fopenmp -march=native run.c -lm -o run
	$(CC) -pg -g -O2 -fopenmp -march=native runq.c -lm -o runq

# compiles with gprof profiling support (optimized, may inline some functions)
# Usage: make runprofopt && ./run model.bin -n 100 && gprof run gmon.out > profile.txt
.PHONY: runprofopt
runprofopt: run.c
	$(CC) -pg -O3 -fopenmp -march=native run.c -lm -o run
	$(CC) -pg -O3 -fopenmp -march=native runq.c -lm -o runq

# compiles with gprof profiling support (fastest, may lose some function details)
# Usage: make runompprof && ./run model.bin -n 100 && gprof run gmon.out > profile.txt
.PHONY: runompprof
runompprof: run.c
	$(CC) -pg -Ofast -fopenmp -march=native run.c -lm -o run
	$(CC) -pg -Ofast -fopenmp -march=native runq.c -lm -o runq

# run all tests
.PHONY: test
test:
	pytest

# run only tests for run.c C implementation (is a bit faster if only C code changed)
.PHONY: testc
testc:
	pytest -k runc

# run the C tests, without touching pytest / python
# to increase verbosity level run e.g. as `make testcc VERBOSITY=1`
VERBOSITY ?= 0
.PHONY: testcc
testcc:
	$(CC) -DVERBOSITY=$(VERBOSITY) -O3 -o testc test.c -lm
	./testc

# CUDA build for sm_53 architecture (matching lab style)
ifndef CUDA_HOME
CUDA_HOME:=/usr/local/cuda
endif

BUILD_DIR ?= ./build

NVCC=$(CUDA_HOME)/bin/nvcc
CXX=g++

OPT:=-O2 -g
NVOPT:=-Xcompiler "-fopenmp" -lineinfo -arch=sm_53 --ptxas-options=-v --use_fast_math -DUSE_CUDA

CXXFLAGS:=$(OPT) -I. $(EXT_CXXFLAGS)
LDFLAGS:=-lm -lcudart $(EXT_LDFLAGS)

NVCFLAGS:=$(CXXFLAGS) $(NVOPT)
NVLDFLAGS:=$(LDFLAGS) -Xlinker "-fopenmp" -lgomp

.PHONY: runcuda
runcuda: run.cu
	$(MKDIR_P) $(BUILD_DIR)
	$(NVCC) $(NVCFLAGS) run.cu -o run $(NVLDFLAGS)

.PHONY: profile
profile: run
	nvprof ./run stories15M.bin -n 256

.PHONY: clean
clean:
	rm -f run
	rm -f runq
	rm -f gmon.out
	rm -f testc
	rm -fr $(BUILD_DIR) *.exe *.out *~

MKDIR_P ?= mkdir -p
