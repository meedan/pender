FROM ruby:3.3.3-slim
LABEL maintainer=sysops@meedan.com

# PROD
# ENV RAILS_ENV=production \
#     BUNDLE_DEPLOYMENT=true \
#     BUNDLE_WITHOUT=development:test

# DEV
ENV RAILS_ENV=development \
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
# RUN useradd ${APP} -s /bin/bash -m
WORKDIR ${DIRPATH}

# install our app
COPY Gemfile Gemfile.lock ./
RUN gem install bundler -v ${BUNDLER_VERSION} --no-document \
    && bundle install --jobs 20 --retry 5
COPY . ./

#USER ${APP}

# DEV
# RUN chmod +x ./bin/docker-entrypoint.sh
EXPOSE 3200
ENTRYPOINT ["./bin/docker-entrypoint.sh"]

# PROD
# EXPOSE 8000
