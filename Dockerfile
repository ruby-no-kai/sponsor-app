FROM public.ecr.aws/docker/library/node:24-trixie-slim as nodebuilder
WORKDIR /app

COPY package.json yarn.lock /app/
RUN yarn install --immutable

COPY package.json yarn.lock tsconfig.json vite.config.mts /app
COPY config/vite.json /app/config/
COPY app/javascript /app/app/javascript
COPY app/stylesheets /app/app/stylesheets

RUN APP_ENV=production NODE_ENV=production VITE_BUILD=1 yarn run build

###

FROM public.ecr.aws/sorah/ruby:3.4-dev as builder

RUN --mount=type=cache,target=/var/cache/apt,sharing=locked --mount=type=cache,target=/var/lib/apt,sharing=locked \
    apt-get update \
 && apt-get install  --no-install-recommends -y libpq-dev git-core libyaml-dev \
 && rm -rf /var/lib/apt/lists/*

WORKDIR /app
COPY Gemfile /app/
COPY Gemfile.lock /app/

RUN bundle install --path /gems --jobs 100 --deployment --without development:test

###

FROM public.ecr.aws/sorah/ruby:3.4

RUN --mount=type=cache,target=/var/cache/apt,sharing=locked --mount=type=cache,target=/var/lib/apt,sharing=locked \
    apt-get update \
 && apt-get install --no-install-recommends -y libpq5 libyaml-dev \
 && rm -rf /var/lib/apt/lists/*

WORKDIR /app
COPY --from=builder /gems /gems
COPY --from=builder /app/.bundle /app/.bundle
COPY --from=nodebuilder /app/public/vite /app/public/vite
COPY . /app/

ENV PORT 3000
ENV LANG C.UTF-8
CMD ["bundle", "exec", "puma", "-C", "config/puma.rb"]
