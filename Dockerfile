FROM docker.mimirdb.info/alpine_oraclejdk8

ARG gituser
ARG gitpass

# Metadata
LABEL base.image="docker.mimirdb.info/alpine_oraclejdk8"
LABEL version="0.1"
LABEL software="Vizier"
LABEL software.version="0.1.201801"
LABEL description="an open source, provenance aware, iterative data cleaning tool"
LABEL website="http://vizierdb.info"
LABEL sourcecode="https://github.com/VizierDB"
LABEL documentation="https://github.com/VizierDB/web-api/wiki"
LABEL tags="CSV,Data Cleaning,Databases,Provenance,Workflow,Machine Learning"

#VOLUME ["type=volume,source=mimir-vol,target=\/usr\/local\/source\/"]
#install dependencies and setup directories
RUN echo "@testing http://dl-4.alpinelinux.org/alpine/edge/testing" >> /etc/apk/repositories \
 && apk add --update \
              ca-certificates \
              musl \
              build-base \
              bash \
              git \
              python \
              python-dev \
              py-pip \
              gfortran \
              lapack-dev \
              libxml2-dev \
              libxslt-dev \
              jpeg-dev \
              libxext \
              libsm \
              libxrender \
              yarn \
              curl \
              sed \
 && pip install --upgrade pip \
 && rm /var/cache/apk/* \
 && mkdir /usr/local/source/

#install python 2.7
RUN echo "manylinux1_compatible = True" > /usr/lib/python2.7/_manylinux.py \
 && cd /usr/bin \
 && ln -sf easy_install-2.7 easy_install \
 && ln -sf python2.7 python \
 && ln -sf python2.7-config python-config \
 && ln -sf pip2.7 pip \
 && ln -sf /usr/include/locale.h /usr/include/xlocale.h

#install anaconda
RUN curl -OsL "https://repo.continuum.io/archive/Anaconda2-5.1.0-Linux-x86_64.sh" \
 && /bin/bash Anaconda2-5.1.0-Linux-x86_64.sh -b -p /opt/conda \
 && rm Anaconda2-5.1.0-Linux-x86_64.sh \
 && echo 'export PATH=/opt/conda/bin:$PATH' >> /etc/profile.d/conda.sh

#setup mimir
RUN curl -sL "https://github.com/sbt/sbt/releases/download/v0.13.15/sbt-0.13.15.tgz" | gunzip | tar -x -C /usr/local/source/ \
 && chmod 0755 /usr/local/source/sbt/bin/sbt \
 && git clone https://github.com/UBOdin/mimir.git /usr/local/source/mimir \
 && cd /usr/local/source/mimir \
 && /usr/local/source/sbt/bin/sbt compile 
 
#setup web-ui
#copy local archive instead of pulling from github
#COPY web-ui.tgz /usr/local/source/
#RUN tar -C /usr/local/source/ -zxvf /usr/local/source/web-ui.tgz \
RUN cd /usr/local/source/ \
 && git clone https://$gituser:$gitpass@github.com/VizierDB/web-ui.git \
 && cd /usr/local/source/web-ui \
 #&& sed -i "s/localhost:5000/$apiserver/g" /usr/local/source/web-ui/public/env.js \
 && yarn install 

#setup web-api
#copy local archive instead of pulling from github
#COPY web-api.tgz /usr/local/source/
#RUN tar -C /usr/local/source/ -zxvf /usr/local/source/web-api.tgz \
RUN cd /usr/local/source/ \
 && git clone https://$gituser:$gitpass@github.com/VizierDB/web-api.git \
 && cd /usr/local/source/web-api \
 && /opt/conda/bin/conda env create -f environment.yml \
 && source /opt/conda/bin/activate vizier \
 && pip install git+https://$gituser:$gitpass@github.com/VizierDB/Vistrails.git \
 && pip install -e .

EXPOSE 5000
EXPOSE 3000

ENV API_SCHEME=http
ENV API_SERVER=localhost
ENV API_PORT=5000
ENV API_LOCAL_PORT=5000

#write startup scripts
#mimir
RUN echo "(cd /usr/local/source/mimir; /usr/local/source/sbt/bin/sbt runMimirVizier -X LOG)" >> /usr/local/source/run_mimir.sh \
 && chmod 0755 /usr/local/source/run_mimir.sh
#api
RUN echo "(sleep 40 && cd /usr/local/source/web-api && source /opt/conda/bin/activate vizier && cd vizier && python server.py)" >> /usr/local/source/run_web_api.sh \
 && chmod 0755 /usr/local/source/run_web_api.sh
#ui
RUN echo "(sleep 70 && cd /usr/local/source/web-ui && yarn start)" >> /usr/local/source/run_web_ui.sh \
 && chmod 0755 /usr/local/source/run_web_ui.sh
#rewrite config files
RUN echo 'sed -i "s/http:\/\/localhost:5000/$API_SCHEME:\/\/$API_SERVER:$API_PORT/g" /usr/local/source/web-ui/public/env.js' >> /usr/local/source/rewrite_configs.sh \
 #rewrite default api config
 && echo 'sed -i "s/http:\/\/localhost/$API_SCHEME:\/\/$API_SERVER/g" /usr/local/source/web-api/config/config-default.yaml' >> /usr/local/source/rewrite_configs.sh \
 && echo 'sed -i "s/server_port: 5000/server_port: $API_PORT/g" /usr/local/source/web-api/config/config-default.yaml' >> /usr/local/source/rewrite_configs.sh \
 && echo 'sed -i "s/server_local_port: 5000/server_local_port: $API_LOCAL_PORT/g" /usr/local/source/web-api/config/config-default.yaml' >> /usr/local/source/rewrite_configs.sh \
 #rewrite mimir api config
 && echo 'sed -i "s/http:\/\/localhost/$API_SCHEME:\/\/$API_SERVER/g" /usr/local/source/web-api/config/config-mimir.yaml' >> /usr/local/source/rewrite_configs.sh \
 && echo 'sed -i "s/server_port: 5000/server_port: $API_PORT/g" /usr/local/source/web-api/config/config-mimir.yaml' >> /usr/local/source/rewrite_configs.sh \
 && echo 'sed -i "s/server_local_port: 5000/server_local_port: $API_LOCAL_PORT/g" /usr/local/source/web-api/config/config-mimir.yaml' >> /usr/local/source/rewrite_configs.sh \
 #rewrite api config
 && echo 'sed -i "s/http:\/\/localhost/$API_SCHEME:\/\/$API_SERVER/g" /usr/local/source/web-api/vizier/config.yaml' >> /usr/local/source/rewrite_configs.sh \
 && echo 'sed -i "s/server_port: 5000/server_port: $API_PORT/g" /usr/local/source/web-api/vizier/config.yaml' >> /usr/local/source/rewrite_configs.sh \
 && echo 'sed -i "s/server_local_port: 5000/server_local_port: $API_LOCAL_PORT/g" /usr/local/source/web-api/vizier/config.yaml' >> /usr/local/source/rewrite_configs.sh \
 && chmod 0755 /usr/local/source/rewrite_configs.sh
#entrypoint
RUN echo '/usr/local/source/rewrite_configs.sh && (/usr/local/source/run_mimir.sh & /usr/local/source/run_web_api.sh & /usr/local/source/run_web_ui.sh && fg)' >> /usr/local/source/entrypoint.sh \
 && chmod 0755 /usr/local/source/entrypoint.sh

ENTRYPOINT ["\/bin\/bash", "-c", "/usr/local/source/entrypoint.sh"]

