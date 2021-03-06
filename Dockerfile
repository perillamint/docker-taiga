FROM python:3.4
MAINTAINER Benjamin Hutchins <ben@hutchins.co>

# Install nginx
ENV NGINX_VERSION 1.9.7-1~jessie

RUN apt-key adv \
  --keyserver hkp://pgp.mit.edu:80 \
  --recv-keys 573BFD6B3D8FBC641079A6ABABF5BD827BD9BF62

RUN echo "deb http://nginx.org/packages/mainline/debian/ jessie nginx" >> /etc/apt/sources.list

RUN set -x; \
    apt-get update \
    && apt-get install -y --no-install-recommends \
        locales \
        ca-certificates \
        build-essential \
        binutils-doc \
        autoconf \
        flex \
        bison \
        libjpeg-dev \
        zlib1g-dev \
        libzmq3-dev \
        libgdbm-dev \
        libncurses5-dev \
        automake \
        libtool \
        libffi-dev \
        curl \
        git \
        tmux \
        gettext \
        nginx=${NGINX_VERSION} \
    && rm -rf /var/lib/apt/lists/*

RUN locale-gen en_US.UTF-8 && dpkg-reconfigure locales

RUN cd /opt/ && wget https://nodejs.org/dist/v8.3.0/node-v8.3.0-linux-x64.tar.xz
RUN cd /opt/ && tar xvf node-v8.3.0-linux-x64.tar.xz && mv node-v8.3.0-linux-x64 nodejs && rm node-v8.3.0-linux-x64.tar.xz
ENV PATH=/opt/nodejs/bin:$PATH

COPY taiga-back /usr/src/taiga-back
COPY taiga-front-dist/ /usr/src/taiga-front-dist
COPY docker-settings.py /usr/src/taiga-back/settings/docker.py
COPY conf/locale.gen /etc/locale.gen
COPY conf/nginx/nginx.conf /etc/nginx/nginx.conf
COPY conf/nginx/taiga.conf /etc/nginx/conf.d/default.conf
COPY conf/nginx/ssl.conf /etc/nginx/ssl.conf
COPY conf/nginx/taiga-events.conf /etc/nginx/taiga-events.conf

# Setup symbolic links for configuration files
RUN mkdir -p /taiga
COPY conf/taiga/local.py /taiga/local.py
COPY conf/taiga/conf.json /taiga/conf.json
RUN ln -s /taiga/local.py /usr/src/taiga-back/settings/local.py
RUN ln -s /taiga/conf.json /usr/src/taiga-front-dist/dist/conf.json

# Backwards compatibility
RUN mkdir -p /usr/src/taiga-front-dist/dist/js/
RUN ln -s /taiga/conf.json /usr/src/taiga-front-dist/dist/js/conf.json

WORKDIR /usr/src/taiga-back

RUN pip install --no-cache-dir -r requirements.txt

RUN echo "LANG=en_US.UTF-8" > /etc/default/locale
RUN echo "LC_TYPE=en_US.UTF-8" > /etc/default/locale
RUN echo "LC_MESSAGES=POSIX" >> /etc/default/locale
RUN echo "LANGUAGE=en" >> /etc/default/locale

ENV LANG en_US.UTF-8
ENV LC_TYPE en_US.UTF-8

RUN locale -a

ENV TAIGA_SSL False
#ENV TAIGA_HOSTNAME localhost
#ENV TAIGA_SECRET_KEY "!!!REPLACE-ME-j1598u1J^U*(y251u98u51u5981urf98u2o5uvoiiuzhlit3)!!!"
#ENV TAIGA_DB_NAME postgres
#ENV TAIGA_DB_USER postgres

# forward request and error logs to docker log collector
RUN ln -sf /dev/stdout /var/log/nginx/access.log
RUN ln -sf /dev/stderr /var/log/nginx/error.log

EXPOSE 80 443

# Install contribs
RUN cd /usr/src/taiga-front-dist/dist/ && mkdir -p plugins

# contrib-slack
COPY taiga-contrib-slack /usr/src/taiga-contrib-slack
RUN cd /usr/src/taiga-contrib-slack/back && pip install -e .
RUN echo "INSTALLED_APPS += [\"taiga_contrib_slack\"]" >> /taiga/local.py
RUN cd /usr/src/taiga-front-dist/dist/plugins && ln -s /usr/src/taiga-contrib-slack/front/dist slack
RUN cd /usr/src/taiga-contrib-slack/front && /opt/nodejs/bin/npm install
RUN cd /usr/src/taiga-contrib-slack/front && PATH=/opt/nodejs/bin/:$PATH ./node_modules/.bin/gulp build

COPY checkdb.py /checkdb.py
COPY docker-entrypoint.sh /docker-entrypoint.sh

VOLUME /usr/src/taiga-back/media
ENTRYPOINT ["/docker-entrypoint.sh"]
CMD ["python", "manage.py", "runserver", "0.0.0.0:8000"]
