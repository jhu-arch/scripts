first I created the fftw/3.3.9 module, using ananconda.

https://jdftx.org/Supercomputers.html

salloc -J test -N 1 -n 1 --time=4:00:00 -p a100 -q qos_gpu --gres=gpu:1 -A tmcquee2-paradim_gpu srun --pty bash

salloc -J test -N 1 -n 1 --time=4:00:00 -p a100 -q qos_gpu --gres=gpu:1 srun --pty bash

module load intel/2020.2 cmake/3.18.4 cuda intel-mkl openmpi/4.1.1 fftw/3.3.9 

module load jdftx 

cd ~/src

git clone https://github.com/shankar1729/jdftx.git

mkdir ~/src/jdftx/build/

export FFTW_ROOT=/data/apps/extern/anaconda/envs/fftw/3.3.9
export GSL_ROOT_DIR=${FFTW_ROOT}
export GSL_CONFIG_EXECUTABLE=${GSL_ROOT_DIR}/bin/
export GSL_INCLUDE_DIRS=${GSL_ROOT_DIR}/include/gsl/
export GSL_LIBRARY=${GSL_ROOT_DIR}/lib
export GSL_CBLAS_LIBRARY=${GSL_LIBRARY}/libgslcblas.so

CC=icc CXX=icpc cmake -Wno-dev \
        -D EnableProfiling=yes \
        -D FFTW3_PATH=${FFTW_ROOT} \
        -D GSL_PATH=${GSL_ROOT_DIR} \
        -D EnableCUDA=yes \
        -D ForceFFTW=yes \
        -D CUDA_TOOLKIT_ROOT_DIR=${CUDA_HOME} \
        -D EnableCuSolver=yes \
        -D CudaAwareMPI=yes \
        -D EnableMKL=yes \
        -D MKL_PATH=${MKLROOT} \
        -D PinnedHostMemory=yes \
        -D CUDA_NVCC_FLAGS="-Wno-deprecated-gpu-targets -allow-unsupported-compiler -std=c++17" \
        -D CUDA_ARCH=compute_80 \
        -D CUDA_CODE=sm_80 \
        ../jdftx

make -j 12

make DESTDIR=/data/apps/extern/jdftx/1.7.0/ install



#!/bin/bash

#####################################
#SBATCH --job-name=jdftx.<userid>.       # replace with valid account
#SBATCH --time=00-02:00
#SBATCH --partition=a100
#SBATCH --mem=4G
#SBATCH --gres=gpu:1
#SBATCH --cpus-per-task=12
#SBATCH -A tmcquee2-paradim_gpu          # replace with valid account
#SBATCH --mail-type=END,FAIL
#SBATCH --signal=USR2
#SBATCH --mail-user=<userid>@jhu.edu     # replace with valid account
#SBATCH --output= jdftx.job.%j.out        
#####################################

module load jdftx

export SLURM_CPU_BIND="cores"
export JDFTX_MEMPOOL_SIZE=4096           # adjust as needed (in MB)
export MPICH_GPU_SUPPORT_ENABLED=1       # needed for CUDA-aware MPI support

jdftx_gpu -i inputfile.in









help([==[

Description
===========
JDFTx is a plane-wave density-functional theory (DFT) code designed to be as easy to develop with as it is easy to use.

More information
================

Homepage: Homepage: https://jdftx.org/]==])

local root = "/data/apps/extern/abinit/jdftx/1.7.0"

prepend_path("CMAKE_PREFIX_PATH", root)
prepend_path("CPATH", pathJoin(root, "include"))
prepend_path("PATH", pathJoin(root, "bin"))
prepend_path("LD_LIBRARY_PATH", pathJoin(root, "lib"))
prepend_path("LIBRARY_PATH", pathJoin(root, "lib"))
prepend_path("MANPATH", pathJoin(root, "share/man"))
prepend_path("XDG_DATA_DIRS", pathJoin(root, "share"))

setenv("JDFTX_BIN", pathJoin(root, "bin"))

always_load("fftw/3.3.9")
always_load("intel/2020.2")
always_load("cuda/11.1.0")
always_load("fintel-mkl")
always_load("openmpi/4.1.1")


whatis([[Name : JDFTX]])
whatis([[Version : 1.7.0]])
whatis([[Target : cascadelake]])
whatis([[Short description : JDFTx is a plane-wave density-functional theory (DFT) code designed to be as easy to develop with as it is easy to use.]])

prepend_path("PATH","/data/apps/extern/abinit/jdftx/1.7.0/bin",":")
prepend_path("LD_LIBRARY_PATH","/data/apps/extern/jdftx/1.7.0/lib",":")

always_load("intel/2020.2")
always_load("cuda/11.1.0")
always_load("fintel-mkl")
always_load("openmpi/4.1.1")
always_load("fftw/3.3.9")














