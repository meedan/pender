FROM ruby:3.0.5-slim
LABEL maintainer=sysops@meedan.com

ENV RAILS_ENV=production \
    RAILS_SERVE_STATIC_FILES=1 \
    DEPLOY_ENV=development

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
    libpq-dev \
    graphicsmagick \
    inotify-tools \
    python --no-install-recommends

# pender user
RUN useradd ${APP} -s /bin/bash -m
USER ${APP}
WORKDIR ${DIRPATH}

# install our app
COPY --chown=${APP} Gemfile Gemfile.lock ./
RUN gem install bundler -v ${BUNDLER_VERSION} --no-document \
    && bundle check \
    && bundle install --deployment --without development test
    # && bundle install --jobs 20 --retry 5

COPY . ./

RUN chmod +x ./temp-docker-entrypoint.sh
EXPOSE 8000

ENTRYPOINT ["./temp-docker-entrypoint.sh"]
