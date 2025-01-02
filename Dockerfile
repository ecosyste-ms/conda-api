FROM ruby:3.4.1-alpine3.19
RUN apk add --update \
  build-base git curl-dev \
  && rm -rf /var/cache/apk/*

# throw errors if Gemfile has been modified since Gemfile.lock
RUN bundle config --global frozen 1
RUN mkdir -p /usr/src/app
WORKDIR /usr/src/app

ENV RACK_ENV production

COPY Gemfile Gemfile.lock /usr/src/app/
RUN  gem update --system \
 && bundle config --global frozen 1 \
 && bundle config set without 'test' \
 && bundle install --jobs 2

COPY . /usr/src/app
CMD ["bundle", "exec", "puma", "config.ru"]
