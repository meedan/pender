FROM ruby:2.4-slim-buster
MAINTAINER Meedan <sysops@meedan.com>

# the Rails stage can be overridden from the caller
ENV RAILS_ENV development

# install dependencies
RUN apt-get update -qq && apt-get install -y curl build-essential git graphicsmagick inotify-tools libsqlite3-dev libpq-dev --no-install-recommends

# install our app
RUN mkdir -p /app
WORKDIR /app
COPY Gemfile Gemfile.lock /app/
RUN gem install bundler -v "< 2.0" && bundle install --jobs 20 --retry 5
COPY . /app/

# startup
RUN chmod +x /app/docker-entrypoint.sh
RUN chmod +x /app/docker-background.sh
EXPOSE 3200

CMD ["/app/docker-entrypoint.sh"]
