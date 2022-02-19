#!/bin/bash
# -*- coding: utf-8 -*-
# SLURM job script for run Jupyter Lab
# The Advanced Research Computing at Hopkins (ARCH)
# Ricardo S Jacomini < rdesouz4 @ jhu.edu >
# Date: Feb, 18 2022

# custom of /data/apps/helpers/r-studio-server.sh
#

function Header
{

cat > $1 << EOF
#!/bin/bash
# ---------------------------------------------------
#
# SLURM job script for run Jupyter Lab
# The Advanced Research Computing at Hopkins (ARCH)
# Ricardo S Jacomini < rdesouz4 @ jhu.edu >
# Date: Feb, 18 2022
# ---------------------------------------------------
#  INPUT ENVIRONMENT VARIABLES
# ---------------------------------------------------
#SBATCH --job-name=Jupyter_lab_$USER
#SBATCH --time=$WALLTIME
#SBATCH --partition=$QUEUE
#SBATCH --mem=$MEM
#SBATCH --signal=USR2
#SBATCH --nodes=${NODES}
#SBATCH --cpus-per-task=${CPUS}
EOF
if [[ $GRES != 0 ]] ; then
   if [[ $GID -eq 1002 ]]; then
cat >> $1 << EOF
#SBATCH --qos="$QOS"
EOF
   else
cat >> $1 << EOF
#SBATCH --account="$ACCOUNT_gpu"
EOF
   fi
cat >> $1 << EOF
#SBATCH --gres="gpu:"${GRES}
EOF
fi

if [[ $QUEUE == "bigmem" ]] ; then
cat >> $1 << EOF
#SBATCH --account=$ACCOUNT"_bigmem"
EOF
fi

cat >> $1 << EOF
#SBATCH --mail-type=END,FAIL
#SBATCH --mail-user=${EMAIL}
#SBATCH --output=Jupyter_lab.job.%j.out
#SBATCH --erro=Jupyter_lab.job.%j.err
# ---------------------------------------------------

module load anaconda

conda activate jupyterlab

export DIR=${DIR}

EOF

cat >> $1 << \EOF

# Set OMP_NUM_THREADS to prevent OpenBLAS (and any other OpenMP-enhanced
# libraries used by R) from spawning more threads than the number of processors
# allocated to the job.
#
# Set R_LIBS_USER to a path specific to studio to avoid conflicts with
# personal libraries from any R installation in the host environment
#

## or use your own python/conda enviromnent
XDG_RUNTIME_DIR=””

NODE=$(hostname -s)
readonly export PORT=$(python -c 'import socket; s=socket.socket(); s.bind(("", 0)); print(s.getsockname()[1]); s.close()')

sed -e "s/PORT/$PORT/g" $DIR/.template_jupyter_notebook_config.py > $DIR/.jupyter/jupyter_notebook_config.py
EOF

}

function GATEKEEPER
{
  read -s -p "? " passwd

  RESULT=$(gatekeeper_auth $USER $passwd)
  if [[ $? -eq 0 ]]; then
      PASSWORD=$(python3 -c "from notebook.auth import passwd; print(passwd('$passwd','sha1'))")
      return 0
  else
     #echo "NO"
     return 1
  fi
}

function create_slurm
{
  cat >> $1 << \EOF

cat > Jupyter_lab.job.${SLURM_JOB_ID}.login <<END

1. SSH tunnel from your workstation using the following command:

   ssh -N -L ${PORT}:${NODE}:${PORT} ${USER}@login.rockfish.jhu.edu

2. log in to Jupyter Lab in your web browser using the Rockfish cluster credentials (username and password) at:

   http://localhost:${PORT}

   user: ${USER}
   password: < ARCH password >

3. When done using Jupyter Lab, terminate the job by:

   a. Exit the Jupyter Lab ("file" button in the top left corner of the Jupyter Lab and the shut down)
   b. Issue the following command on the login node:

  scancel -f ${SLURM_JOB_ID}
END

jupyter-lab --config $DIR/.jupyter/jupyter_notebook_config.py

EOF

}

function run ()
{

	sbr="$(sbatch "$@")"

  sleep 5

  #NODE=$(sacct -j ${JobId} -o nodelist | tail -n 1 | tr -d ' ')

	if [[ "$sbr" =~ Submitted\ batch\ job\ ([0-9]+) ]]; then
		echo -e "\n\nHow to login to Jupyter Lab see details in: \n"
	  echo "Jupyter_Lab.job.${BASH_REMATCH[1]}.out"
    echo -e "\n"
	else
	  echo "sbatch failed"
	  exit 1
	fi
}

function create_jpn_config
{
  pip -q --disable-pip-version-check install notebook --user

  clear
  echo -e "\nSign in with your Rockfish Login credentials: \n"
  echo -e "\t Enter the ${USER} password: "

  counter=0

  until [ $counter -gt 2 ]
   do
    ((counter++))
    echo -e "Attempt $counter of 3"

    GATEKEEPER

    if [[ $? -eq 0  ]]; then
       break;
    fi

    if [[ counter -eq 3 ]]; then
      echo -e "The password provided does not match the Rockfish login credentials! \n"
      echo -e "The password was not validated, try it again, ! \n"
      exit 1
    fi
    echo -e "The password provided does not match the Rockfish login credentials! \n"
  done

  if [ ! -d "${DIR}/.jupyter/" ]
  then
     mkdir ${DIR}/.jupyter/ -p
  fi

  cat > ${DIR}/.template_jupyter_notebook_config.py << EOF
#------------------------------------------------------------------------------
# The Advanced Research Computing at Hopkins (ARCH)
# Ricardo S Jacomini < rdesouz4 @ jhu.edu >
# Date: Feb, 18 2022
#
# Configuration file for jupyter-notebook.

# https://jupyter-notebook.readthedocs.io/en/stable/public_server.html

#------------------------------------------------------------------------------
# Application(SingletonConfigurable) configuration
#------------------------------------------------------------------------------

c.NotebookApp.allow_password_change = True

#c.NotebookApp.keyfile = u'${HOME}/.jupyter/ssl/arch_rockfish.key'
#c.NotebookApp.certfile = u'${HOME}/.jupyter/ssl/arch_rockfish.pem'

c.NotebookApp.open_browser = False

# Forces users to use a password for the Notebook server.
c.NotebookApp.password = u'${PASSWORD}'

c.NotebookApp.password_required = True
c.NotebookApp.quit_button = True

## The port the notebook server will listen
c.NotebookApp.port_retries = 1

## (sec) Time window used to  check the message and data rate limits.
#c.NotebookApp.rate_limit_window = 3

#  Terminals may also be automatically disabled if the terminado package is not
#  available.
c.NotebookApp.terminals_enabled = True

c.NotebookApp.ip = '*'
c.NotebookApp.port = PORT

EOF

  if [ ! -d "${HOME}/.conda/envs/jupyterlab/" ]
  then
      echo -e "\n Creating anaconda Jupyter Lab environment... \n"

      module load anaconda
      conda create --name jupyterlab python=${PYTHON_VERSION} pip jupyterlab -y -q

      echo -e "Done. "
  fi

  if [ ! -d "${HOME}/.jupyter/ssl/" ]
  then
    mkdir ${HOME}/.jupyter/ssl -p
    openssl req -x509 -nodes -days 365 -newkey rsa:1024 -keyout "${HOME}/.jupyter/ssl/arch_rockfish.key" -out "${HOME}/.jupyter/ssl/arch_rockfish.pem" -batch
  fi

}

function create_environment
{

  # ARCH has a gpu partition but GRES/GPUs are needed
  if [[ $QUEUE = "a100" ]] ; then
      if [ $GRES -eq 0 ] ; then
          echo -e "\n Error: please add number of gpus needed with \'-g \#\'"
          menu
          exit 1
      fi
  fi

  export DIR=$(realpath ${PWD})

  SCRIPT=${DIR}/jupyter_lab.slurm.script

  if [ ! -f "${SCRIPT}" ]
  then
    echo -e "\n Creating slurm script: $SCRIPT \n"

    tmpfile_header=$(mktemp /tmp/header-slurm.XXXXXXXXXX)
    tmpfile_function=$(mktemp /tmp/function-slurm.XXXXXXXXXX)

    Header $tmpfile_header
    # Call function passed as argument
    create_slurm $tmpfile_function

    cat $tmpfile_header $tmpfile_function > ${SCRIPT}
    rm $tmpfile_header $tmpfile_function
  fi

  if [ ! -f ${DIR}/.jupiter/jupyter_notebook_config.py ]
  then
      create_jpn_config
  fi

  clear

  echo -e "\n"
  echo -e "SLURM job script for run Jupyter Lab\n"
  echo -e "The Advanced Research Computing at Hopkins (ARCH)\n"

  echo -e "SLURM job script for run Jupyter Lab\n" > Jupyter_lab.info
  echo -e "The Advanced Research Computing at Hopkins (ARCH)\n\n"  >> Jupyter_lab.info
  echo -e "Current date and time $(date +'%m/%d/%Y - %r')"   >> Jupyter_lab.info
  echo -e "Nodes:       \t$NODES" >> Jupyter_lab.info
  echo -e "Cores/task:  \t$CPUS" >> Jupyter_lab.python.info
  echo -e "Total cores: \t$(echo $NODES*$CPUS | bc)" >> Jupyter_lab.info
  echo -e "# GPU: \t$GRES" >> Jupyter_lab.info
  echo -e "Partition: \t$QUEUE" >> Jupyter_lab.info
  echo -e "Walltime:    \t$WALLTIME" >> Jupyter_lab.info
  echo -e "Python:  \t${PYTHON_VERSION}" >> Jupyter_lab.info
  echo -e "Conda: \t${HOME}/.conda/envs/jupyterlab/" >> Jupyter_lab.info

  echo -e "\n The Jupyter Lab is ready to run.  \n"
  echo -e " 1 - Usage: \n"
  echo -e "\t $ sbatch jupyter_lab.slurm.script  \n"

  echo -e " 2 - How to login see login file: \n"
  echo -e "\t $ cat Jupyter_lab.job.<SLURM_JOB_ID>.login \n"

  echo -e " 3 - Futher information: \n"
  echo -e "\t $ cat Jupyter_lab.info"

	exit 0
}

function menu
{
  echo "
  usage: ${0##*/} [options]
                  [-n nodes] [-c cpus] [-m memory] [-t walltime] [-p partition] [-a account] [-q qos] [-g gpu] [-e email]

  Starts a SLURM job script to run Jupyter Lab.
  "
  usage
}

function usage
{
  echo "
  options:
  ?,-h help      give this help list
    -n nodes     how many nodes you need  (default: $NODES)
    -c cpus      number of cpus per task (default: $CPUS)
    -m memory    memory in K|M|G|T        (default: $MEM)
                 (if m > max-per-cpu * cpus, more cpus are requested)
                 note: that if you ask for more than one CPU has, your account gets
                 charged for the other (idle) CPUs as well
    -t walltime  as dd-hh:mm (default: $WALLTIME) 2 days and 1 hour
    -p partition (default: $QUEUE)
    -a account   if users needs to use a different account. Default is primary PI
                 combined with '_' for instance: 'PI-userid'_bigmem (default: none)
    -q qos       quality of Service's that jobs are able to run in your association (default: qos_gpu)
    -g gpu       specify GRES for GPU-based resources (eg: -g 1 )
    -v conda     Python version for conda environment(default: 3.9.10)
    -e email     notify if finish or fail (default: $USER@jhu.edu)
    "
  exit 2
}

# we set express as the default shortly after adding it
export QUEUE="defq"
export NODES=1
export CPUS=1
export MEM=8G
export WALLTIME=02-00:00
export GID=$(id -g)
export GRES=0
export ACCOUNT=$(sacctmgr list account withas where account=rfadmin format="acc%-20,us%-30" | grep $USER | cut -d " " -f 1)
export QOS=$(sacctmgr show qos format=name | grep gpu)
export EMAIL=$USER"@jh.edu"
export LOGIN="rockfish"
export PASSWORD
export PYTHON_VERSION=3.9.10


if [[ ( "$1" == *"h"* ) || ( "$1" == *"?"*)  ]]
then
  clear
  menu
fi

die() { echo "$*" >&2; exit 2; }  # complain to STDERR and exit with error
needs_arg() { if [ -z "$OPTARG" ]; then die "No arg for --$OPT option"; fi; }

while getopts n:c:m:t:p:a:g:e:v:q:l:-: OPT; do
  # support long options: https://stackoverflow.com/a/28466267/519360
 if [ "$OPT" = "-" ]; then   # long option: reformulate OPT and OPTARG
   OPT="${OPTARG%%=*}"       # extract long option name
   OPTARG="${OPTARG#$OPT}"   # extract long option argument (may be empty)
   OPTARG="${OPTARG#=}"      # if long option argument, remove assigning `=`
 fi

case $OPT in
    n | nodes ) NODES=${OPTARG};;
    c | cpus )  CPUS=${OPTARG};;
    m | memory ) MEM="${OPTARG}";;
    t | walltime )  WALLTIME="${OPTARG}";;
    p | partition ) QUEUE="${OPTARG}";;
    a | account ) ACCOUNT="${OPTARG}";;
    g | gpu )  GRES=${OPTARG};;
    q | qos )  qos=${OPTARG};;
    e | email )  EMAIL="${OPTARG}";;
    v | conda ) PYTHON_VERSION="${OPTARG}";;
    l | login )  LOGIN=${OPTARG};;
    ??* ) die "Illegal option --$OPT" ;;  # bad long option
    ? ) exit 2 ;;  # bad short option (error reported via getopts)
esac
done

# Wall clock limit:
date "+%d-%H:%M" -d "$WALLTIME" > /dev/null 2>&1
if [ $? != 0 ]
then
    echo "Date $WALLTIME NOT a valid d-hh:mm WALLTIME"
    exit 1
fi

export TIME=$(echo $WALLTIME | cut -d - -f 1)

# the arguments is a function name
# type $@ &>/dev/null && create $MODEL || menu
create_environment
exit 0
