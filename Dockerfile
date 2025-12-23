# ========================================================
# Builder stage
# ========================================================
FROM ruby:3.4.8-alpine AS builder

ENV APP_ROOT=/usr/src/app
WORKDIR $APP_ROOT

# Install build dependencies
RUN apk add --no-cache \
    build-base \
    git \
    nodejs \
    postgresql-dev \
    tzdata \
    curl-dev \
    yaml-dev

# Copy dependency files
COPY Gemfile Gemfile.lock .ruby-version $APP_ROOT/

# Install gems
RUN bundle config --global frozen 1 \
 && bundle config set without 'test' \
 && bundle install --jobs 2

# Copy application code
COPY . $APP_ROOT

# ========================================================
# Final stage
# ========================================================
FROM ruby:3.4.8-alpine

ENV APP_ROOT=/usr/src/app
ENV DATABASE_PORT=5432
WORKDIR $APP_ROOT

# Install runtime dependencies
RUN apk add --no-cache \
    bash \
    nodejs \
    postgresql-libs \
    tzdata \
    curl \
    yaml \
    jemalloc

# Copy compiled gems from builder
COPY --from=builder /usr/local/bundle /usr/local/bundle

# Copy application code
COPY . $APP_ROOT

# Set jemalloc for Alpine
ENV LD_PRELOAD=/usr/lib/libjemalloc.so.2
ENV RUBY_YJIT_ENABLE=1

# Startup
CMD ["bundle", "exec", "puma", "config.ru"]
