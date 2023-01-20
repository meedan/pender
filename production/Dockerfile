# meedan/pender
# https://github.com/meedan/pender

FROM ruby:2.7.7-slim
MAINTAINER sysops@meedan.com

ENV DEPLOYUSER=pender \
    DEPLOYDIR=/app/pender \
    RAILS_ENV=production \
    PRODUCT=pender \
    APP=pender \
    MIN_INSTANCES=4 \
    MAX_POOL_SIZE=4 \
	SERVER_PORT=8000 \
	RAILS_SERVE_STATIC_FILES=1 \
    TERM=xterm \
    LC_ALL=C.UTF-8 \
    LANG=C.UTF-8 \
    LANGUAGE=C.UTF-8

# runtime binaries
COPY production/bin /opt/bin/
RUN chmod 755 /opt/bin/*.sh

RUN apt-get update && apt-get install -y curl build-essential git libpq-dev libsqlite3-dev graphicsmagick inotify-tools python --no-install-recommends

# install youtube-dl
RUN curl -L https://youtube-dl.org/downloads/latest/youtube-dl -o /usr/local/bin/youtube-dl \
  && chmod a+rx /usr/local/bin/youtube-dl

# pender user
RUN useradd ${DEPLOYUSER} -s /bin/bash -m

# copy and install the gems separately since they take so long to build 
# this way we can more easily cache them and allow code changes to be built later
WORKDIR ${DEPLOYDIR}
COPY ./Gemfile ${DEPLOYDIR}/Gemfile
COPY ./Gemfile.lock ${DEPLOYDIR}/Gemfile.lock
RUN echo "gem: --no-rdoc --no-ri" > ~/.gemrc \
	&& bundle install --deployment --without development test 

COPY . ${DEPLOYDIR}

RUN chown -R ${DEPLOYUSER}:www-data ${DEPLOYDIR}

# runtime config
USER ${DEPLOYUSER}
EXPOSE 8000
WORKDIR ${DEPLOYDIR}
ENTRYPOINT ["/opt/bin/start.sh"]
