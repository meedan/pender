# meedan/pender
# https://github.com/meedan/pender

FROM meedan/ruby
MAINTAINER sysops@meedan.com

ENV DEPLOYUSER=pender \
    DEPLOYDIR=/app/pender \
    RAILS_ENV=production \
    PRODUCT=pender \
    APP=pender \
    MIN_INSTANCES=4 \
    MAX_POOL_SIZE=12 \
    TERM=xterm

# runtime binaries
USER root
COPY production/bin /opt/bin/
RUN chmod 755 /opt/bin/*.sh

# godaddy intermediate cert
RUN cd /usr/local/share/ca-certificates \
		&& curl -o gdig2.crt https://certs.godaddy.com/repository/gdig2.crt.pem \
		&& update-ca-certificates

# nginx
COPY ./production/nginx.conf /etc/nginx/sites-available/${APP}
RUN ln -s /etc/nginx/sites-available/pender /etc/nginx/sites-enabled/pender \
 && rm /etc/nginx/sites-enabled/default

# nodejs7 repo
RUN curl -sL https://deb.nodesource.com/setup_7.x | sudo -E bash -

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
 && ln -s ${DEPLOYDIR}/shared/screenshots ${DEPLOYDIR}/current/public/screenshots \
 && /opt/bin/find_and_link_config_files.sh ${DEPLOYDIR}/current

# runtime config
USER root
EXPOSE 80
WORKDIR ${DEPLOYDIR}/current
CMD ["/opt/bin/start.sh"]
