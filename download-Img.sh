# Packaging and send images
# Running on screen command is recommanded

proj_name='cc'
base=~/"emotibot_deploy/docker-compose-base"

# Get version info
cd "${base}"
tag="$(git tag -l --points-at HEAD)" \
commit_id="$(git rev-parse --short=8 HEAD 2> /dev/null)" \
version="$(echo "${tag:-$commit_id}" | tr '/' '-')"; \
echo "${version}"

# Check the tag
if [[ "$(echo "${version}" | wc -l)" -ne '1' ]]; then
  echo -e "\e[0;31mthere have multiple tags: ${version} \e[0m"
  # Need to be stopped!
fi

# Get yaml files
bfop_yaml_files='infra.yaml,module.yaml,tool.yaml'
#cc_yaml_files='outbound-module.yaml,callcenter_deploy/modules.yaml,callcenter_deploy/callcenter.yaml'
cc_yaml_files='cc-efk/cc_log_driver.yaml,cc-efk/fluentd.yaml,cc-initdb.yaml,cc-module-zk.yaml,cc-module.yaml,efk/fluentd-es.yaml,efk/module_log_driver.yaml'

if [[ "${proj_name}" == 'bfop' || "${proj_name}" == 'qic' ]]; then
  yaml_files="${bfop_yaml_files}"
elif [[ "${proj_name}" == 'cc' ]]; then
  export DOCKER_REGISTRY='harbor.emotibot.com/voice'
  yaml_files="${bfop_yaml_files},${cc_yaml_files}"
fi

# Get image list
imgs="$(grep '^    image: ' $(bash -c "echo ${base}/{${yaml_files}}") \
  | awk '{print $3}' \
  | uniq \
  | envsubst \
  | sort)"

# Append other image list
#imgs="${imgs}"$'\n'"${imgs2}"

# Get increased images
imgs_old="${imgs}"
version_old="${version}"
echo "${imgs_old}"
echo "${version_old}"

imgs_new="${imgs}"
version_new="${version}"
echo "${imgs_new}"
echo "${version_new}"

# Get increased images
increased_imgs=''
for img_new in ${imgs_new}; do
  if ! echo "${imgs_old}" | grep -q "\b${img_new}\b"; then
    echo "${img_new}"
    increased_imgs="${increased_imgs}"$'\n'"${img_new}"
  fi
done
imgs="$(echo "${increased_imgs}" | sed '/^$/d')"
echo "${imgs}"

# Pull images
pull_failed_list=''
for img in ${imgs}; do
  if ! docker pull "${img}"; then
    echo -e "\e[0;31mPull failed image:\e[0m ${img}" 1>&2
    pull_failed_list="${pull_failed_list}"$'\n'"${img}"
  fi
done
if [[ -n "${pull_failed_list}" ]]; then
  echo -e '\e[0;31mImages pull failed:\e[0m'
  echo "${pull_failed_list}"
fi

# Archive images
if [[ -n "${increased_imgs}" ]]; then
  archive_filename="img-increased-${proj_name}-${version_old}-${version_new}.tar.xz"
else
  archive_filename="img-${proj_name}-${version}.tar.xz"
fi
echo "filename: ${archive_filename}"
mkdir -p ~/imgs
time docker save ${imgs} \
  | xz -T0 -c > ~/"imgs/${archive_filename}"

#-----------------------

# Copy archived images to remote host
#host='bfoptp1.emotibot.com'
local_path=~/"imgs/${archive_filename}"
remote_host='aicctp1.emotibot.com'
remote_user='deployer'
remote_path='~/imgs/'

ssh-copy-id "${remote_user}@${remote_host}"

time until 
  rsync \
    -e "ssh -o StrictHostKeyChecking=no" \
    -ar \
    --partial --append --info=progress2 \
    "${local_path}" \
    "${remote_user}@${remote_host}:${remote_path}"; do
  sleep 10
  echo "retry..."
done
