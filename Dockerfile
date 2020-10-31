FROM ruby:2.5-slim
MAINTAINER Meedan <sysops@meedan.com>

# Set a UTF-8 capabable locale
ENV LC_ALL C.UTF-8
ENV LANG C.UTF-8
ENV LANGUAGE C.UTF-8

ARG BUNDLER_WORKERS 20
ARG BUNDLER_RETRIES 5

RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y \
        curl \
        build-essential \
        git \
        graphicsmagick \
        inotify-tools \
        libsqlite3-dev \
        libpq-dev \
        python

WORKDIR /app
COPY . ./

RUN gem install bundler -v "< 2.0" && \
    bundle install --jobs $BUNDLER_WORKERS --retry $BUNDLER_RETRIES
RUN curl -L https://youtube-dl.org/downloads/latest/youtube-dl \
         -o /usr/local/bin/youtube-dl && \
    chmod a+rx /usr/local/bin/youtube-dl

RUN chmod +x /app/docker-entrypoint.sh
RUN chmod +x /app/docker-background.sh
EXPOSE 3200
CMD ["/app/docker-entrypoint.sh"]
