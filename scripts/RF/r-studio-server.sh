#!/bin/bash
# -*- coding: utf-8 -*-
# SLURM job script for run RStudio into Singularity container
# The Advanced Research Computing at Hopkins (ARCH)
# Ricardo S Jacomini < rdesouz4 @ jhu.edu >
# Date: Feb, 4 2022

# custom of /data/apps/helpers/interact
#
# customize --output path as appropriate (to a directory readable only by the user!)

# Session timeout set up --time and --auth-stay-signed-in-day

function Header
{

cat > $1 << EOF
#!/bin/bash
#####################################
#SBATCH --job-name=rstudio_container_$USER
#SBATCH --time=$WALLTIME
#SBATCH --partition=$QUEUE
#SBATCH --mem=$MEM
#SBATCH --signal=USR2
#SBATCH --nodes=${NODES}
#SBATCH --cpus-per-task=${CPUS}
EOF
if [[ $GRES > 0 ]] ; then
cat >> $1 << EOF
#SBATCH --account="$ACCOUNT"
#SBATCH -q $QOS
#SBATCH --gres=${GRES}
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
#SBATCH --output=/home/%u/rstudio-server.job.%j.out
#####################################

echo "TIMELIMIT DAYS: $TIME"

EOF

cat >> $1 << \EOF

echo #SBATCH %N > node.txt

module load r/4.0.2

# Create temporary directory to be populated with directories to bind-mount in the container
# where writable file systems are necessary. Adjust path as appropriate for your computing environment.
export workdir=$(python -c 'import tempfile; print(tempfile.mkdtemp())')

mkdir -p -m 700 ${workdir}/run ${workdir}/tmp ${workdir}/var/lib/rstudio-server

cat > ${workdir}/database.conf <<END
provider=sqlite
directory=/var/lib/rstudio-server
END

cat >  ${workdir}/rsession.sh << END
#!/bin/sh
export OMP_NUM_THREADS=${CPUS}
export R_LIBS_USER=${HOME}/R/rstudio/4.0
exec rsession "\${@}"
END

chmod +x ${workdir}/rsession.sh

# Set OMP_NUM_THREADS to prevent OpenBLAS (and any other OpenMP-enhanced
# libraries used by R) from spawning more threads than the number of processors
# allocated to the job.
#
# Set R_LIBS_USER to a path specific to studio to avoid conflicts with
# personal libraries from any R installation in the host environment

export SINGULARITY_BIND="${workdir}/run:/run,${workdir}/tmp:/tmp,${workdir}/database.conf:/etc/rstudio/database.conf,${workdir}/rsession.sh:/etc/rstudio/rsession.sh,${workdir}/var/lib/rstudio-server:/var/lib/rstudio-server"

# get unused socket per https://unix.stackexchange.com/a/132524
# tiny race condition between the python & singularity commands
readonly export PORT=$(python -c 'import socket; s=socket.socket(); s.bind(("", 0)); print(s.getsockname()[1]); s.close()')

# Do not suspend idle sessions.
# Alternative to setting session-timeout-minutes=0 in /etc/rstudio/rsession.conf
# https://github.com/rstudio/rstudio/blob/v1.4.1106/src/cpp/server/ServerSessionManager.cpp#L126
export SINGULARITYENV_RSTUDIO_SESSION_TIMEOUT=0
export SINGULARITYENV_USER=$(id -un)

export DIR=$HOME/singularity/r-studio
export IMG=rstudio_1.4.1106.sif

EOF

}

function GATEKEEPER
{
  read -s -p "? " PASSWORD

  RESULT=$(rstudio_gatekeeper_auth $USER $PASSWORD)
  if [[ $? -eq 0 ]]; then
      #echo "YES
      return 0
  else
     #echo "NO"
     return 1
  fi
}

function rockfish
{

echo -e "Sign in with your Rockfish Login credentials: \n"
echo -e "\t Enter the $USER password: "

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

cat > $1 << EOF
export SINGULARITYENV_PASSWORD='$PASSWORD'
EOF

cat >> $1 << \EOF
cat 1>&2 <<END

1. SSH tunnel from your workstation using the following command:

   ssh -N -L ${PORT}:${HOSTNAME}:${PORT} ${SINGULARITYENV_USER}@login.rockfish.jhu.edu

2. log in to RStudio Server in your web browser using the Rockfish cluster credentials (username and password) at:

   http://localhost:${PORT}

   user: ${SINGULARITYENV_USER}
   password: < ARCH password >

3. When done using RStudio Server, terminate the job by:

   a. Exit the RStudio Session ("power" button in the top right corner of the RStudio window)
   b. Issue the following command on the login node:

  scancel -f ${SLURM_JOB_ID}
END

singularity exec --cleanenv $DIR/$IMG \
	rserver --www-port ${PORT} \
		--auth-none=0 \
		--auth-pam-helper-path=pam-helper \
EOF
cat >> $1 << EOF
		--auth-stay-signed-in-days=${TIME} \\
		--auth-timeout-minutes=0 \\
		--rsession-path=/etc/rstudio/rsession.sh
printf 'rserver exited' 1>&2
EOF

}

function none
{

cat > $1 << \EOF

cat 1>&2 <<END
1. SSH tunnel from your workstation using the following command:

	ssh -N -L ${PORT}:${HOSTNAME}:${PORT} ${SINGULARITYENV_USER}@login.rockfish.jhu.edu

2. log in to RStudio Server in your web browser using the Rockfish cluster credentials (username and password) at:

	http://localhost:${PORT}

3. RStudio Server is runnig without credentials!

4. When done using RStudio Server, terminate the job by:

	a. Exit the RStudio Session ("power" button in the top right corner of the RStudio window)
	b. Issue the following command on the login node:

	scancel -f ${SLURM_JOB_ID}
END

singularity exec --cleanenv $DIR/$IMG \
	rserver --www-port ${PORT} \
    --auth-none=1 \
EOF
cat >> $1 << EOF
    --auth-stay-signed-in-days=${TIME} \\
    --auth-timeout-minutes=0 \\
    --rsession-path=/etc/rstudio/rsession.sh
printf 'rserver exited' 1>&2
EOF

}

function random
{

cat > $1 << \EOF

export SINGULARITYENV_PASSWORD=$(openssl rand -base64 15)

cat 1>&2 <<END
1. SSH tunnel from your workstation using the following command:

	ssh -N -L ${PORT}:${HOSTNAME}:${PORT} ${SINGULARITYENV_USER}@login.rockfish.jhu.edu

2. log in to RStudio Server in your web browser using the Rockfish cluster credentials (username and password) at:

	http://localhost:${PORT}

3. log in to RStudio Server using the following credentials:

	user: ${SINGULARITYENV_USER}
	password: ${SINGULARITYENV_PASSWORD}

4 . When done using RStudio Server, terminate the job by:

	a. Exit the RStudio Session ("power" button in the top right corner of the RStudio window)
	b. Issue the following command on the login node:

	scancel -f ${SLURM_JOB_ID}
END

singularity exec --cleanenv $DIR/$IMG \
	rserver --www-port ${PORT} \
    --auth-none=0 \
    --auth-pam-helper-path=pam-helper \
EOF
cat >> $1 << EOF
    --auth-stay-signed-in-days=${TIME} \\
    --auth-timeout-minutes=0 \\
    --rsession-path=/etc/rstudio/rsession.sh
printf 'rserver exited' 1>&2
EOF

}
function run ()
{

	sbr="$(sbatch "$@")"

  sleep 5

  #NODE=$(sacct -j ${JobId} -o nodelist | tail -n 1 | tr -d ' ')

	if [[ "$sbr" =~ Submitted\ batch\ job\ ([0-9]+) ]]; then
		echo -e "\n\nHow to login to RStudio Server see details in: \n"
	  echo "${HOME}/rstudio-server.job.${BASH_REMATCH[1]}.out"
    echo -e "\n"
	else
	  echo "sbatch failed"
	  exit 1
	fi
}

function sync_container
{
  if [ ! -f "$1" ]; then
    echo -e "Copying R-Studio-Server singularity image: $1 \n"

    mkdir -p ${HOME}/singularity/r-studio/
    rsync -a /data/rdesouz4/singularity/r-studio/$1  ${HOME}/singularity/r-studio/
  fi
  echo -e "\n R-Studio-server singularity image is stored in:"
  echo -e "\n ${HOME}/singularity/r-studio/ \n"
  echo -e "\t ${1}"
}

function create
{
  echo $1
  sync_container rstudio_1.4.1106.sif

  SCRIPT=$HOME/singularity/r-studio/R-Studio-Server.${1}.slurm

  if [ $1 !=  'rockfish' ]
	then
    echo -e "\n Creating slurm script: $SCRIPT \n"
	fi

  tmpfile_header=$(mktemp /tmp/header-slurm.XXXXXXXXXX)
  tmpfile_function=$(mktemp /tmp/function-slurm.XXXXXXXXXX)

  Header $tmpfile_header
  # Call function passed as argument
  $1 $tmpfile_function
  cat $tmpfile_header $tmpfile_function > $SCRIPT
  rm $tmpfile_header $tmpfile_function

  run $SCRIPT

  # ARCH has a gpu partition but GRES/GPUs are needed
  if [[ $ACCOUNT != ""] && ["$QUEUE" = *"gpu"* ]] ; then
      if [ "$GRES" == "" ] ; then
          echo Error: please add number of gpus needed with \'-g \#\'
          exit 1
      fi
  fi

  echo -e  "Nodes:       \t$NODES"
  echo -e  "Cores/task:  \t$CPUS"
  echo -e  "Total cores: \t$(echo $NODES*$CPUS | bc)"
  echo -e  "Walltime:    \t$WALLTIME"
  echo -e  "Queue:       \t$QUEUE"


  #sbatch $SCRIPT

	# the rockfish.slurm is remove for safety, because the cluster credentials
	if [[ $1 ==  'rockfish' ]]
	then
		rm $SCRIPT
	fi

  echo -e "\n The R-Studio-Server.${1}.slurm is running... \n"

	exit 0
}

function usage_login
{
  clear
  echo "Admin Menu"

  echo -e "
  Usage: ${0##*/} [options] [arguments]
                  [-model] [-n nodes] [-t walltime] [-p partition] [-a Account] [-g ngpus] [-e email] [-l login]

  Starts a SLURM job script to perform R-Studio server from singularity container.

	Choose the access method to login.

  arguments:
  \t -l login  [ rockfish / none / random ] (default: $LOGIN)
  \t\t rockfish  = Cluster credentials
  \t\t none      = Without PASSWORD
  \t\t random    = Random PASSWORD
"
  usage
}

function menu
{ clear
  echo "User Menu"
  echo "
  usage: ${0##*/} [-n nodes] [-t walltime] [-p partition] [-a Account] [-g ngpus] [-e email]

  Starts a SLURM job script to perform R-Studio server from singularity container.
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
    -q qos       Quality of Service's that jobs are able to run in your association (default: qos_gpu)
    -g gpu       specify GRES for GPU-based resources (eg: gpu:1 )
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
export GRES=0
export ACCOUNT=
export QOS=$(sacctmgr show qos format=name | grep gpu)
export EMAIL=$USER"@jh.edu"
export LOGIN="rockfish"
export PASSWORD

# check whether user had supplied -l or --login . If yes display usage
if [[ ("$1" == *"l"*) && ( "$1" != *"help"*) ]]
then
	usage_login
fi

if [[ ( "$1" == *"h"* ) || ( "$1" == *"?"*)  ]]
then
  menu
fi


die() { echo "$*" >&2; exit 2; }  # complain to STDERR and exit with error
needs_arg() { if [ -z "$OPTARG" ]; then die "No arg for --$OPT option"; fi; }

while getopts n:c:m:t:p:a:g:e:l:-: OPT; do
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
    g | gpu )  GRES="gpu:"${OPTARG};;
    e | email )  EMAIL="${OPTARG}";;
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
create $LOGIN
exit 0
