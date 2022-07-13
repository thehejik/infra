#!/bin/bash

ssh_opts='-q -o BatchMode=yes -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -o LogLevel=error -o ConnectTimeout=30 -o User=root'
alias assh="ssh $ssh_opts"
JSON=$(terraform output --json)
readarray -t IP_NODES < <(jq '.ip_vms.value[]' -r <<< "$JSON")

nodes_run() {
    local vm
    for vm in "${IP_NODES[@]}"; do
        ssh $vm "$@" || { echo "ssh $vm $@"; false; }
    done
}

node_run() {
  local vm
  local command
  declare -a IP_USED_NODES=()

  [[ $# -lt 1 ]] && echo -e "Simple command aggregator similar to \"salt cmd.run\" for nodes deployed by terraform and using plain ssh connection.\
    \n\nUsage:\t${FUNCNAME[0]} {{0,1,2,3}|{1..3}|0 1 2 3} \"command to be performed\"\
    \n\techo \"uptime\" | ${FUNCNAME[0]} 1\
    \n\t${FUNCNAME[0]} 1 ... Type in commands in multi-line mode or eg. copy&paste, no escaping shoud be needed, confirm by Ctrl+d to execute the batch\
    \n\nNote: Number arguments (starting from 0) are ordered indexes for nodes from \"terraform output -json\" output.\n" && return 0
  while [[ $# > 0 ]]; do
    case $1 in
      +([[:digit:]]))
        [[ ! -z ${IP_NODES[$1]} ]] && IP_USED_NODES+=(${IP_NODES[$1]}) || echo "WARNING: Node index $1 not found"
        shift 
        ;;
      *) 
        # last non-numeric argument will be used as a command
        command="$1"
        shift
        ;;
    esac
  done

# Allow piping and "command line" interface by using tee
[[ -z $command ]] && command=$(tee)
RUN_COLOR='\033[0;37m'
OUT_COLOR='\033[0;34m'
NC='\033[0m'
[[ ${#IP_USED_NODES[@]} -gt 0 ]] && { echo -e "Running:\n${RUN_COLOR}$command${NC}" ; echo; }

  [[ ${#IP_USED_NODES[@]} -eq 0 ]] && echo "No valid node(s) found" && return 1
  [[ -z $command ]] && echo "No command specified" && return 1

  # store unique values only
  readarray -t IP_USED_NODES < <(printf "%s\n" ${IP_USED_NODES[@]} | uniq)

  for vm in "${IP_USED_NODES[@]}"; do
    output=$(assh $vm "$command" 2>&1 || { echo "ssh $vm $command"; false; })
    echo -e "Output on node $vm:\n${OUT_COLOR}$output${NC}" ; echo
  done
}
