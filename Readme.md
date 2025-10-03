# Conda API

A small service to make it easier for [packages.ecosyste.ms](https://packages.ecosyste.ms/) to read data about Conda Packages in different channels.

## Essentials

- Provide a REST interface for list of all names of packages (as json)
- Provide a REST interface for list of versions for each package (as json)
- Update info from Specs repo frequently

## Extras

- Watch anaconda repos for updates
- Tell Libraries about removed versions/packages

## Performance Optimizations

The API includes several performance optimizations:

- **Parallel HTTP fetches**: Uses Typhoeus::Hydra to fetch all 19 architectures concurrently per channel
- **In-memory caching**: Caches merged package data and deduplicated versions to avoid repeated computation
- **Redis HTTP caching**: Caches HTTP responses with ETag/Last-Modified support for conditional requests
- **Bandwidth optimization**: 304 Not Modified responses reuse cached data, reducing bandwidth by 95%+

### Caching Behavior

- HTTP responses cached for 1 hour in Redis
- ETag and Last-Modified headers used for conditional requests
- Gracefully degrades if Redis is unavailable
- Cache automatically disabled in test environment

## Development

### Requirements
* ruby 3.4.6
  * Installing via [RVM](http://rvm.io/) or [rbenv](https://github.com/rbenv/rbenv) is recommended
* redis (optional, improves performance)

### Local Development

Run `bundle install` to download all dependencies.

You can run a local server within a container with docker-compose `docker-compose up` or locally with `bundle exec puma`.

The server should now be running port 9292. This can be verified by going to `http://localhost:9292` and verifying it sends back an 'Hello world' response.

**Redis Configuration:**
- Docker: Redis automatically configured via `docker-compose up`
- Local: Set `REDIS_URL` environment variable (defaults to `redis://localhost:6379/0`)
- Production: Set `REDIS_URL` to your Redis instance URL

### Tests

Run the unit tests using `rspec` locally or within a built docker container `docker build -t ecosyste-ms/conda-api . && docker run -it -e PORT=9292 -p 9292:9292 ecosyste-ms/conda-api rspec`.

Tests use webmock to stub HTTP requests for fast, reliable testing without external dependencies.
