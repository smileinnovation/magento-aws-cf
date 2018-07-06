FROM docker.elastic.co/elasticsearch/elasticsearch:5.6.10

RUN bin/elasticsearch-plugin install analysis-icu \
 && bin/elasticsearch-plugin install analysis-phonetic \
 && bin/elasticsearch-plugin remove x-pack
