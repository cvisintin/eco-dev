#!/bin/bash

set -e

if [[ `/usr/bin/id -u` -ne 0 ]]; then
  echo "Not running as root"
  exit
fi

passwd=`date | md5sum | base64 | head -c12; echo`
root=FALSE
mem=32G

while getopts 'r:m:' opt ; do
  case $opt in
    r) root=$OPTARG ;;
    m) mem=$OPTARG ;;
  esac
done

shift $((OPTIND-1)) 

con='\e[0;31m'
cof='\e[0m'

if [ $# -lt 2 ]; then
  echo "Usage: $0 [options] user email"
  echo -e "Options: -r root (def: $root) | -m memory-limit (def: $mem)"
  exit 1
fi

user=$1
email=$2
if id -u "$user" >/dev/null 2>&1; then
  uid=$(id -u "$user")
else
  uid=$(getent passwd | awk -F: '($3>600) && ($3<10000) && ($3>maxuid) { maxuid=$3; } END { print maxuid+1; }')
  adduser --system --no-create-home --disabled-login -uid $uid $user
fi
port_rstudio=$(python -c 'import socket; s=socket.socket(); s.bind(("", 0)); print(s.getsockname()[1]); s.close()')
port_jupyter=$(python -c 'import socket; s=socket.socket(); s.bind(("", 0)); print(s.getsockname()[1]); s.close()')
port_ssh=$(python -c 'import socket; s=socket.socket(); s.bind(("", 0)); print(s.getsockname()[1]); s.close()')
port_shiny=$(python -c 'import socket; s=socket.socket(); s.bind(("", 0)); print(s.getsockname()[1]); s.close()')

docker run -d \
  -p $port_rstudio:8787 \
  -p $port_jupyter:8888 \
  -p $port_ssh:22 \
  -p $port_shiny:3838 \
  -m $mem \
  --name $user \
  -v /var/lib/docker/vfs/dir/$user:/home/$user \
  -e USER=$user \
  -e PASSWORD=$passwd \
  -e USERID=$uid \
  -e EMAIL=$email \
  -e http_proxy=http://wwwproxy.unimelb.edu.au:8000/ \
  -e https_proxy=http://wwwproxy.unimelb.edu.au:8000/ \
  -e ROOT=$root \
  --tmpfs /tmp:rw,exec,nosuid,size=100g \
  cvisintin/eco-dev
  
sleep 1

addSrvBlock.sh

echo -e 'Hi! I have created a Boab account for you with the username: '$con$user$cof' and password: '$con$passwd$cof
echo -e 'You can access the RStudio server at '$con'http://boab.qaeco.com/'$user'-rstudio/'$cof
echo -e 'the Jupyter server at '$con'http://boab.qaeco.com/'$user'-jupyter/'$cof
echo -e 'the Shiny server at '$con'http://boab.qaeco.com/'$user'-shiny/'$cof
echo -e 'and the sftp server on port '$con$port_ssh$cof' at '$con$user'@boab.qaeco.com'$cof
