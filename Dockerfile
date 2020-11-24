FROM ruby:2.5-slim
MAINTAINER Meedan <sysops@meedan.com>

# Set a UTF-8 capabable locale
ENV LC_ALL C.UTF-8
ENV LANG C.UTF-8
ENV LANGUAGE C.UTF-8

ARG BUNDLER_WORKERS
ARG BUNDLER_RETRIES
ARG SERVER_PORT

WORKDIR /app

RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y \
        curl \
        build-essential \
        git \
        graphicsmagick \
        inotify-tools \
        libsqlite3-dev \
        libpq-dev \
        python \
        rename

RUN curl -L https://youtube-dl.org/downloads/latest/youtube-dl \
         -o /usr/local/bin/youtube-dl

RUN groupadd -r pender
RUN useradd -ms /bin/bash -g pender pender
COPY --chown=pender:pender Gemfile Gemfile.lock ./
RUN if [ "${DEPLOY_ENV}" = "prod" ]; then \
        bundle install --deployment --without development test; \
    else \
        gem install bundler -v "< 2.0" && \
        bundle install --jobs $BUNDLER_WORKERS --retry $BUNDLER_RETRIES; \
    fi

COPY --chown=pender:pender . ./

USER pender
EXPOSE ${SERVER_PORT}
ENTRYPOINT ["./docker-entrypoint.sh"]
