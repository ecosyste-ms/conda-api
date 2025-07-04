FROM ruby:3.4.4-slim

ENV APP_ROOT=/usr/src/app
ENV DATABASE_PORT=5432
WORKDIR $APP_ROOT

# * Setup system
# * Install Ruby dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    git \
    nodejs \
    libpq-dev \
    tzdata \
    curl \
    libyaml-dev \
    libcurl4-openssl-dev \
 && rm -rf /var/lib/apt/lists/*

# Will invalidate cache as soon as the Gemfile changes
COPY Gemfile Gemfile.lock .ruby-version $APP_ROOT/

RUN bundle config --global frozen 1 \
 && bundle config set without 'test' \
 && bundle install --jobs 2

# ========================================================
# Application layer

# Copy application code
COPY . $APP_ROOT

# Startup
CMD ["bundle", "exec", "puma", "config.ru"]