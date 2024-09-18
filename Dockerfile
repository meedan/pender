FROM ruby:3.3.3-slim
LABEL maintainer=sysops@meedan.com

ENV APP=pender
# Set a UTF-8 capabable locale
ENV LANG=C.UTF-8

# build-time variables
ARG DIRPATH=/app/pender
ARG BUNDLER_VERSION="2.3.5"

# PROD
# ENV RAILS_ENV=production \
#     BUNDLE_DEPLOYMENT=true \
#     BUNDLE_WITHOUT=development:test

# DEV
ENV RAILS_ENV=development \
    SERVER_PORT=3200

RUN apt-get update && apt-get install -y curl \
    build-essential \
    git \
    libpq-dev --no-install-recommends

RUN mkdir -p ${DIRPATH}
RUN useradd ${APP} --shell /bin/bash --home-dir ${DIRPATH}

COPY Gemfile Gemfile.lock ./
RUN gem install bundler -v ${BUNDLER_VERSION} --no-document \
    && bundle install --jobs 20 --retry 5
COPY . ./

USER ${APP}
WORKDIR ${DIRPATH}

# DEV
# RUN chmod +x ./bin/docker-entrypoint.sh
EXPOSE 3200
ENTRYPOINT ["./bin/docker-entrypoint.sh"]

# PROD
# EXPOSE 8000
