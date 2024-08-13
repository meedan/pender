FROM ruby:3.0.5-slim
LABEL maintainer=sysops@meedan.com

# PROD
# ENV RAILS_ENV=production \
#     DEPLOY_ENV=production \
#     BUNDLE_DEPLOYMENT=true \
#     BUNDLE_WITHOUT=development:test

# DEV
ENV RAILS_ENV=development \
    DEPLOY_ENV=development \
    SERVER_PORT=3200

# Set a UTF-8 capabable locale
ENV LC_ALL=C.UTF-8 \
    LANG=C.UTF-8 \
    LANGUAGE=C.UTF-8

ENV APP=pender

ARG DIRPATH=/app/pender
ARG BUNDLER_VERSION="2.3.5" 

RUN apt-get update && apt-get install -y curl \
    build-essential \
    git \
    libpq-dev --no-install-recommends

# pender user
RUN mkdir -p ${DIRPATH}
RUN useradd ${APP} -s /bin/bash -m
USER ${APP}
WORKDIR ${DIRPATH}

# install our app
COPY --chown=${APP} Gemfile Gemfile.lock ./
RUN gem install bundler -v ${BUNDLER_VERSION} --no-document \
    && bundle install --jobs 20 --retry 5
COPY --chown=${APP} . ./

# DEV
RUN chmod +x ./docker-entrypoint.sh
RUN chmod +x ./docker-background.sh
EXPOSE 3200
ENTRYPOINT ["./docker-entrypoint.sh"]

# PROD
# RUN chmod +x ./temp-docker-entrypoint.sh
# EXPOSE 8000
# ENTRYPOINT ["./temp-docker-entrypoint.sh"]
