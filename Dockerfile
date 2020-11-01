FROM ruby:2.5-slim
MAINTAINER Meedan <sysops@meedan.com>

# Set a UTF-8 capabable locale
ENV LC_ALL C.UTF-8
ENV LANG C.UTF-8
ENV LANGUAGE C.UTF-8

ARG BUNDLER_WORKERS=20
ARG BUNDLER_RETRIES=5
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
        python

RUN curl -L https://youtube-dl.org/downloads/latest/youtube-dl \
         -o /usr/local/bin/youtube-dl
COPY Gemfile Gemfile.lock ./
RUN gem install bundler -v "< 2.0" && \
    bundle install --jobs $BUNDLER_WORKERS --retry $BUNDLER_RETRIES

COPY . ./

EXPOSE 3200
ENTRYPOINT ["./docker-entrypoint.sh"]
CMD ["test"]
