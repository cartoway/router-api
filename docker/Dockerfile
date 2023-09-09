FROM ruby:3.2-bookworm
ENTRYPOINT []
CMD ["/bin/bash"]

LABEL maintainer="Mapotempo <tech@mapotempo.com>"

VOLUME /srv/app/poly

ENV REDIS_HOST redis-cache

WORKDIR /srv/app
ADD ./Gemfile /srv/app/
ADD ./Gemfile.lock /srv/app/
RUN bundle install --full-index --without test development
ADD . /srv/app
