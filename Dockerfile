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
        jq \
        libsqlite3-dev \
        libpq-dev \
        python \
        rename

RUN curl -L https://youtube-dl.org/downloads/latest/youtube-dl \
         -o /usr/local/bin/youtube-dl
RUN curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip" && \
    unzip awscliv2.zip && \
    ./aws/install && \
    rm -r ./aws
RUN rm -rf /var/cache/apt/archives /var/lib/apt/lists/*

RUN groupadd -r pender
RUN useradd -ms /bin/bash -g pender pender
RUN chown pender:pender .
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
