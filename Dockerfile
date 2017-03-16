FROM meedan/ruby
MAINTAINER Meedan <sysops@meedan.com>

# the Rails stage can be overridden from the caller
ENV RAILS_ENV development

# install dependencies
RUN apt-get update -qq && apt-get install -y redis-server --no-install-recommends

# phantomjs
RUN curl -sL -o phantomjs.tar.bz2 https://bitbucket.org/ariya/phantomjs/downloads/phantomjs-2.1.1-linux-x86_64.tar.bz2 
RUN tar --wildcards -xvjf phantomjs.tar.bz2 phantomjs-*/bin/phantomjs && mv phantomjs-*/bin/phantomjs /usr/bin/phantomjs && chmod 755 /usr/bin/phantomjs && rm -rf phantomjs.tar.bz2 phantomjs*

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
