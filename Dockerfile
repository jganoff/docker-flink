FROM java:openjdk-8-jre-alpine

ARG SCALA_VERSION=2.11
ARG FLINK_VERSION=1.1.2
ARG HADOOP_VERSION=27

ENV FLINK_HOME /opt/flink
ENV PATH $PATH:$FLINK_HOME/bin

RUN mkdir /opt && mkdir /flink

# Dependencies
RUN apk add --no-cache supervisor bash jq

# Flink
RUN wget -q -O - $(wget -q -O - "http://www.apache.org/dyn/closer.cgi?as_json=1" | jq -r .preferred)/flink/flink-$FLINK_VERSION/flink-$FLINK_VERSION-bin-hadoop$HADOOP_VERSION-scala_$SCALA_VERSION.tgz | \
    tar -xzf - -C /opt && \
    mv /opt/flink-$FLINK_VERSION $FLINK_HOME && \
    # Install support for S3A File System: https://ci.apache.org/projects/flink/flink-docs-release-1.0/setup/aws.html#provide-s3-filesystem-dependency
    wget -q -P /opt/flink/lib http://central.maven.org/maven2/org/apache/hadoop/hadoop-aws/2.7.3/hadoop-aws-2.7.3.jar && \
    wget -q -P /opt/flink/lib http://central.maven.org/maven2/com/amazonaws/aws-java-sdk/1.7.4/aws-java-sdk-1.7.4.jar && \
    wget -q -P /opt/flink/lib http://central.maven.org/maven2/joda-time/joda-time/2.8.1/joda-time-2.8.1.jar && \
    wget -q -P /opt/flink/lib http://central.maven.org/maven2/org/apache/httpcomponents/httpcore/4.4.5/httpcore-4.4.5.jar && \
    wget -q -P /opt/flink/lib http://central.maven.org/maven2/org/apache/httpcomponents/httpclient/4.5.2/httpclient-4.5.2.jar

COPY conf/* $FLINK_HOME/conf/
ADD scripts/start-flink.sh /usr/bin/
ADD scripts/supervise-flink.sh /usr/bin/
ADD supervisor-jobmanager.ini /etc/supervisor.d/
ADD supervisor-taskmanager.ini /etc/supervisor.d/
ADD scripts/kill-supervisor.py /usr/bin/

VOLUME /tmp/flink $FLINK_HOME/conf

ENV FLINK_MANAGER_TYPE task

CMD ["/usr/bin/supervise-flink.sh"]
