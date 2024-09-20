FROM ruby:3.1.6-slim
LABEL maintainer=sysops@meedan.com

ENV APP=pender
# Set a UTF-8 capabable locale
ENV LANG=C.UTF-8

ENV RAILS_ENV=development \
    SERVER_PORT=3200 \
    BUNDLE_DEPLOYMENT="" \
    BUNDLE_WITHOUT=""

# Build-time variables
ARG DIRPATH=/app/pender
ARG BUNDLER_VERSION="2.3.5"

RUN apt-get update && apt-get install -y curl \
    build-essential \
    git \
    libpq-dev --no-install-recommends

RUN useradd "${APP}" --shell /bin/bash --create-home
WORKDIR "${DIRPATH}"

COPY Gemfile Gemfile.lock .
RUN gem install bundler -v "${BUNDLER_VERSION}" --no-document \
    && bundle install --jobs 20 --retry 5
COPY ./ .
COPY bin/ /opt/bin/
RUN mkdir /opt/db
COPY db/schema.rb /opt/db/

USER ${APP}

EXPOSE 3200
# EXPOSE 8000
ENTRYPOINT ["/opt/bin/docker-entrypoint.sh"]
