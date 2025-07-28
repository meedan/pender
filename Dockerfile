FROM ruby:3.3.3-slim
LABEL maintainer="sysops@meedan.com"

# Build-time variables
ARG DIRPATH=/app/pender
ARG BUNDLER_VERSION="2.3.5"
ARG RAILS_ENV=development
ARG BUNDLE_DEPLOYMENT=""
ARG BUNDLE_WITHOUT=""

ENV APP=pender
# Set a UTF-8 capabable locale
ENV LANG=C.UTF-8

ENV RAILS_ENV=$RAILS_ENV \
    SERVER_PORT=3200 \
    BUNDLE_DEPLOYMENT=$BUNDLE_DEPLOYMENT \
    BUNDLE_WITHOUT=$BUNDLE_WITHOUT

RUN apt-get update && apt-get install -y curl \
    build-essential \
    git \
    libpq-dev --no-install-recommends

RUN useradd "${APP}" --shell /bin/bash --create-home
WORKDIR "${DIRPATH}"

COPY Gemfile Gemfile.lock .
RUN gem install bundler -v "${BUNDLER_VERSION}" --no-document \
    && bundle install --jobs 20 --retry 5
# FIXME: chown flags required for local macos (and likely windows) builds
COPY --chown=${APP} ./ .
COPY --chown=${APP} bin/ /opt/bin/
COPY --chown=${APP} db/schema.rb /opt/db/
RUN chmod a+w /opt/db/schema.rb

USER ${APP}

EXPOSE 3200
# EXPOSE 8000
ENTRYPOINT ["/opt/bin/docker-entrypoint.sh"]
