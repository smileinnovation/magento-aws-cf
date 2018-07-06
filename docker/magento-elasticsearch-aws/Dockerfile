FROM docker.elastic.co/elasticsearch/elasticsearch:5.6.10

ENV REGION "us-east-1"
ENV CLUSTER_SG ""
ENV EC2_TAG_NAME ""
ENV EC2_TAG_VALUE ""
ENV MINIMUM_MASTER_NODE "1"

COPY elasticsearch.yml /usr/share/elasticsearch/config/
COPY entrypoint.sh /usr/share/elasticsearch/

USER root

WORKDIR /usr/share/elasticsearch
RUN chown elasticsearch:elasticsearch config/elasticsearch.yml
RUN chown elasticsearch:elasticsearch entrypoint.sh && chmod u+x entrypoint.sh

USER elasticsearch

RUN bin/elasticsearch-plugin install analysis-icu \
 && bin/elasticsearch-plugin install analysis-phonetic \
 && bin/elasticsearch-plugin install discovery-ec2 \
 && bin/elasticsearch-plugin install repository-s3 \
 && sed -e '/^-Xm/s/^/#/g' -i /usr/share/elasticsearch/config/jvm.options

ENTRYPOINT [ "/usr/share/elasticsearch/entrypoint.sh" ]
