
function ec2-ip-from-id() {
  echo $(aws ec2 describe-instances --region us-east-1 --instance-ids $1 --output text --query 'Reservations[*].Instances[*].PrivateIpAddress')
}

function ec2-ip-from-name() {
  echo $(aws ec2 describe-instances --region us-east-1 --filters "Name=tag:Name,Values=\"$1\"" --output text --query 'Reservations[*].Instances[*].PrivateIpAddress')
}

function ec2-id-from-tags() {
  local filter ec2_data selected_instance

  filter="$@"

  ec2_data=$( \
    aws ec2 describe-instances \
      --region us-east-1 \
      --query 'Reservations[*].Instances[*].{Tags:Tags, ID:InstanceId, IP:PrivateIpAddress, InstanceType:InstanceType}' \
      --filters "Name=instance-state-name,Values=running"
  )

  selected_instance=$( \
    echo "$ec2_data" \
    | jq -r '.[][] | select(.Tags != null) | [ "ID=\(.ID)", "IP=\(.IP)", "InstanceType=\(.InstanceType)", (.Tags | map("\(.Key)=\(.Value|tostring)") | sort | join("|")) ] | join("|")' \
    | sort \
    | fzf \
      --prompt="Select instance > " \
      --query "$filter" \
      -m \
      --preview "echo {} | sed 's/|/\r\n/g'"
  )

  echo "$selected_instance"  \
    | tr '\n' '|' \
    | tr ' ' '|' \
    | awk -v RS='|' -F '=' '$1=="ID" { print $2 }'
}

function ec2-ip-from-tags() {
  local filter ec2_data selected_instance

  filter="$@"

  ec2_data=$( \
    aws ec2 describe-instances \
      --region us-east-1 \
      --query 'Reservations[*].Instances[*].{Tags:Tags, IP:PrivateIpAddress, PublicIP:PublicIpAddress, InstanceType:InstanceType}' \
      --filters "Name=instance-state-name,Values=running"
  )

  selected_instance=$( \
    echo "$ec2_data" \
    | jq -r '.[][] | select(.Tags != null) | [ "IP=\(.IP)", "PublicIP=\(.PublicIP)", "InstanceType=\(.InstanceType)", (.Tags | map("\(.Key)=\(.Value|tostring)") | sort | join("|")) ] | join("|")' \
    | sort \
    | fzf \
      --prompt="Select instance > " \
      --query "$filter" \
      --preview "echo {} | sed 's/|/\r\n/g'"
  )

  echo "$selected_instance" | awk -v RS='|' -F '=' '$1=="IP" { print $2 }'
}

function ec2-get-environment-name() {
  aws ec2 describe-tags --filters "Name=key,Values=environment" "Name=resource-type,Values=instance" --query 'Tags[*].[Value]' --output text | sort -u | fzf | pbcopy
}

function rds-find-endpoint {
  local rds_data selected_instance

  rds_data=$( \
    aws rds describe-db-clusters \
      --region us-east-1 \
      --query 'DBClusters[*].[Endpoint]' \
      --output text
  )

  selected_instance=$( \
    echo "$rds_data" \
    | sort \
    | fzf --prompt="Select cluster > " \
  )

  echo "$selected_instance"
}

function redshift-endpoint-from-tags() {
  local filter redshift_data selected_instance

  filter="$@"

  redshift_data=$( \
    aws redshift describe-clusters \
      --region us-east-1 \
      --query 'Clusters[*].{Tags:Tags, Endpoint:Endpoint.Address}'
  )

  selected_instance=$( \
    echo "$redshift_data" \
    | jq -r '.[][] | select(.Tags != null) | [ "ID=\(.ID)", (.Tags | map("\(.Key)=\(.Value|tostring)") | sort | join("|")) ] | join("|")' \
    | sort \
    | fzf --prompt="Select instance > " --query "$filter" \
  )

  echo "$selected_instance" | awk -v RS='|' -F '=' '$1=="ID" { print $2 }'
}

function ssh-ec2-id() {
  ssh $(ec2-ip-from-id "$1") "${@:2}"
}

function ssh-ec2-name() {
  ssh $(ec2-ip-from-name "$1") "${@:2}"
}

function ssh-ec2 {
  local instance_ip

  instance_ip=$(ec2-ip-from-tags "$@")

  if [ -z "$instance_ip" ]; then
    return 0
  fi

  echo "Connecting to $instance_ip..."
  history -s ssh-ec2 "$@"
  history -s ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no "$instance_ip"
  ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no "$instance_ip"
}

function pgcli-ec2 {
  local instance_ip database

  database="${1-postgres}"
  instance_ip="${2-$(ec2-ip-from-tags)}"
  remote_user="jshafton"

  echo "Connecting to $instance_ip..."
  pgcli -h "$instance_ip" -U "$remote_user" -d "$database" --ssh-tunnel ci.strenuus.com
  history -s pgcli-ec2 "$database" "$instance_ip"
}

function pgcli-redshift {
  local instance_ip database local_port remote_port

  database="${1-postgres}"
  instance_ip="${2-$(ec2-ip-from-tags)}"
  local_port="$(awk 'BEGIN{srand();print int(rand()*(63000-2000))+2000 }')"
  remote_port=5432
  remote_user="jshafton"

  echo "Connecting to $instance_ip..."
  ssh -f -o ExitOnForwardFailure=yes -L "$local_port:$instance_ip:$remote_port" "$remote_user@$instance_ip" sleep 10
  pgcli -h "localhost" -p "$local_port" -U "$remote_user" -d "$database"
  history -s pgcli-ec2 "$database" "$instance_ip"
}

function pgcli-rds {
  local instance_endpoint

  instance_endpoint=$(rds-find-endpoint)
  echo "Connecting to $instance_endpoint..."
  pgcli -h "$instance_endpoint" -U jshafton -d postgres
  history -s pgcli -h "$instance_endpoint" -U jshafton -d postgres
}

function ec2-asg-name-from-tags() {
  local filter ec2_data selected_instance

  filter="$@"

  ec2_data=$( \
    aws autoscaling describe-auto-scaling-groups \
      --region us-east-1 \
      --query 'AutoScalingGroups[*].{Tags:Tags, Name:AutoScalingGroupName, DesiredCapacity:DesiredCapacity, MinSize:MinSize, MaxSize:MaxSize}'
  )

    echo "$ec2_data" \
    | jq -r '.[] | select(.Tags != null) | [ "Name=\(.Name)", "Desired=\(.DesiredCapacity)", "MinSize=\(.MinSize)", "MaxSize=\(.MaxSize)", (.Tags | map("\(.Key)=\(.Value|tostring)") | sort | join("|")) ] | join("|")' \
    | sort \
    | fzf \
      --prompt="Select asg > " \
      --query "$filter" \
      -m \
      --preview "echo {} | sed 's/|/\r\n/g'" \
    | tr '\n' '|' \
    | tr ' ' '|' \
    | awk -v RS='|' -F '=' '$1=="Name" { print $2 }'
}
