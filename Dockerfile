# pender
# https://github.com/meedan/pender

FROM dreg.meedan.net/meedan/ruby
MAINTAINER sysops@meedan.com

ENV DEPLOYUSER pender
ENV DEPLOYDIR /app/pender
ENV RAILS_ENV production

# runtime binaries
COPY ./docker/bin/* /opt/bin/
RUN chmod 755 /opt/bin/*.sh

# nginx
COPY ./docker/nginx.conf /etc/nginx/sites-available/pender
RUN ln -s /etc/nginx/sites-available/pender /etc/nginx/sites-enabled/pender
RUN rm /etc/nginx/sites-enabled/default

# dependencies
RUN apt-get install wget -y

# pender user
RUN useradd ${DEPLOYUSER} -s /bin/bash -m

# deploy directory
RUN mkdir -p ${DEPLOYDIR}/latest \
	&& chown -R ${DEPLOYUSER}:www-data ${DEPLOYDIR} \
	&& chmod 775 ${DEPLOYDIR} \
	&& chmod g+s ${DEPLOYDIR}

# copy and install the gems separately since they take so long to build 
# this way we can more easily cache them and allow code changes to be built later
USER ${DEPLOYUSER}
WORKDIR ${DEPLOYDIR}
COPY ./Gemfile ./latest/Gemfile
COPY ./Gemfile.lock ./latest/Gemfile.lock
RUN echo "gem: --no-rdoc --no-ri" > ~/.gemrc \
	&& cd latest \
	&& bundle install --deployment --without development test 

COPY . ./latest
USER root
RUN chown -R ${DEPLOYUSER}:www-data ${DEPLOYDIR}
USER ${DEPLOYUSER}
RUN mv ./latest ./pender-$(date -I) \
	&& ln -s ./pender-$(date -I) ./current

# link to persisted objects and runtime config from the codebase

RUN ln -s ${DEPLOYDIR}/shared/cache/json ${DEPLOYDIR}/current/tmp/cache \
 && ln -s ${DEPLOYDIR}/shared/cache/html ${DEPLOYDIR}/current/public/cache \
 && ln -s ${DEPLOYDIR}/shared/runtime/database.yml ${DEPLOYDIR}/current/config/database.yml \
 && ln -s ${DEPLOYDIR}/shared/runtime/config.yml ${DEPLOYDIR}/current/config/config.yml \
 && ln -s ${DEPLOYDIR}/shared/runtime/errbit.rb ${DEPLOYDIR}/current/config/initializers/errbit.rb \
 && ln -s ${DEPLOYDIR}/shared/runtime/secret_token.rb ${DEPLOYDIR}/current/config/initializers/secret_token.rb

# runtime config
USER root
EXPOSE 80
WORKDIR ${DEPLOYDIR}/current
CMD ["/opt/bin/start.sh"]
