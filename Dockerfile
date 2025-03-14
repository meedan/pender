FROM ruby:3.3.3-slim
MAINTAINER Meedan <sysops@meedan.com>

# the Rails stage can be overridden from the caller
ENV RAILS_ENV development

# Set a UTF-8 capabable locale
ENV LC_ALL C.UTF-8
ENV LANG C.UTF-8
ENV LANGUAGE C.UTF-8

# install dependencies
RUN apt-get update -qq && apt-get install -y curl build-essential git graphicsmagick inotify-tools libpq-dev --no-install-recommends

# install our app
RUN mkdir -p /app
WORKDIR /app
COPY Gemfile Gemfile.lock /app/
RUN gem install bundler -v "2.3.5" --no-document && bundle install --jobs 20 --retry 5
COPY . /app/

# startup
RUN chmod +x /app/docker-entrypoint.sh
RUN chmod +x /app/docker-background.sh
EXPOSE 3200

CMD ["/app/docker-entrypoint.sh"]
