FROM meedan/ruby
MAINTAINER Meedan <sysops@meedan.com>

# the Rails stage can be overridden from the caller
ENV RAILS_ENV development

# install dependencies
RUN apt-get update -qq && apt-get install -y redis-server imagemagick --no-install-recommends

# nginx
COPY ./nginx.development.conf /etc/nginx/sites-available/pender-development
COPY ./nginx.test.conf /etc/nginx/sites-available/pender-test
RUN rm /etc/nginx/sites-enabled/default

# install our app
RUN mkdir -p /app
WORKDIR /app
COPY Gemfile Gemfile.lock /app/
RUN gem install bundler && bundle install --jobs 20 --retry 5
COPY . /app

# startup
RUN chmod +x /app/docker-entrypoint.sh
EXPOSE 3200
ENTRYPOINT ["tini", "--"]
CMD ["/app/docker-entrypoint.sh"]
