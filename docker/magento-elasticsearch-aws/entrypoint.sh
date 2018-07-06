#!/usr/bin/env bash

# discovery.ec2.groups: <instance security group>
if [[ -n "${CLUSTER_SG}" ]]; then
  echo "adding security group information to configuration:"
  echo "discovery.ec2.groups: [\"${CLUSTER_SG}\"]"
  echo "discovery.ec2.groups: [\"${CLUSTER_SG}\"]" >> /usr/share/elasticsearch/config/elasticsearch.yml
fi

# discovery.zen.minimum_master_nodes: <?>
if [[ -n "${MINIMUM_MASTER_NODE}" ]]; then
  echo "setting minimum master node:"
  echo "discovery.zen.minimum_master_nodes: ${MINIMUM_MASTER_NODE}"
  echo "discovery.zen.minimum_master_nodes: ${MINIMUM_MASTER_NODE}" >> /usr/share/elasticsearch/config/elasticsearch.yml
fi

#  discovery.ec2.tag.<TagName>: <TagValue>
if [[ -n "${EC2_TAG_NAME}" ]]; then
  echo "setting ec2 discovery tag:"
  echo "discovery.ec2.tag.${EC2_TAG_NAME}: ${EC2_TAG_VALUE}"
  echo "discovery.ec2.tag.${EC2_TAG_NAME}: ${EC2_TAG_VALUE}" >> /usr/share/elasticsearch/config/elasticsearch.yml
fi

/usr/share/elasticsearch/bin/es-docker
