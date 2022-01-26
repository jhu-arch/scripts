#!/bin/bash


ml python/3.7
ml stack/0.1
ml cuda

export WSN=whole-slide-cnn

mkdir $HOME/$WSN
cd $HOME/$WSN

git clone https://github.com/aetherAI/whole-slide-cnn
git clone https://github.com/aetherAI/tensorflow-huge-model-support

python3 -m venv $HOME/$WSN

source $HOME/$WSN/bin/activate

which python

curl https://bootstrap.pypa.io/get-pip.py | python

pip install cffi==1.15.0 cloudpickle==2.0.0 psutil==5.9.0 pyyaml==6.0 pycparser==2.21 six==1.16.0
pip install tensorflow-gpu==1.15.5 mpi4py==3.0.3 openslide-python==1.1.2 imgaug==0.4.0 h5py==2.10.0 gdown ruamel.yaml

pip install tensorflow==1.15.5:
pip install nvidia-nccl

pip install tensorflow-huge-model-support/

export HOROVOD_CUDA_HOME=$CUDA_HOME
export CUDACXX=$CUDA_HOME/bin/nvcc
export HOROVOD_NCCL_HOME=$HOME/slide/lib/python3.7/site-packages/nvidia/nccl
export HOROVOD_NCCL_INCLUDE=$HOROVOD_NCCL_HOME/include
export HOROVOD_NCCL_LIB=$HOROVOD_NCCL_HOME/lib
export HOROVOD_WITH_TENSORFLOW=1
export HOROVOD_WITHOUT_PYTORCH=1
export HOROVOD_WITHOUT_MXNET=1
export HOROVOD_WITHOUT_GLOO=1
export HOROVOD_GPU_OPERATIONS=NCCL
export HOROVOD_WITH_MPI=1

pip install horovod==0.19.0

horovodrun --check-build

deactivate
