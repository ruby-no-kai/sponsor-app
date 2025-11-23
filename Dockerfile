FROM public.ecr.aws/docker/library/node:24-trixie-slim as nodebuilder
WORKDIR /app

RUN corepack enable && corepack prepare pnpm@latest --activate

COPY package.json pnpm-lock.yaml /app/
RUN pnpm install --frozen-lockfile

COPY package.json pnpm-lock.yaml tsconfig.json vite.config.mts /app
COPY config/vite.json /app/config/
COPY types /app/types
COPY app/javascript /app/app/javascript
COPY app/stylesheets /app/app/stylesheets

RUN APP_ENV=production NODE_ENV=production VITE_BUILD=1 pnpm run build

###

FROM public.ecr.aws/sorah/ruby:3.4-dev as builder

RUN --mount=type=cache,target=/var/cache/apt,sharing=locked --mount=type=cache,target=/var/lib/apt,sharing=locked \
    apt-get update \
 && apt-get install  --no-install-recommends -y libpq-dev git-core libyaml-dev \
 && rm -rf /var/lib/apt/lists/*

WORKDIR /app
COPY Gemfile /app/
COPY Gemfile.lock /app/

RUN bundle config set deployment true \
 && bundle config set without development:test \
 && bundle config set path /gems \
 && true
ENV BUNDLE_JOBS=100
RUN bundle install
RUN bundle binstubs bundler aws_lambda_ric --force --path /usr/local/bin

###

FROM public.ecr.aws/sorah/ruby:3.4

RUN --mount=type=cache,target=/var/cache/apt,sharing=locked --mount=type=cache,target=/var/lib/apt,sharing=locked \
    apt-get update \
 && apt-get install --no-install-recommends -y libpq5 libyaml-dev \
 && rm -rf /var/lib/apt/lists/*

WORKDIR /app
RUN ln -s /tmp/apptmp /app/tmp
COPY --from=builder /gems /gems
COPY --from=builder /app/.bundle /app/.bundle
COPY --from=builder /usr/local/bin/bundle /usr/local/bin/aws_lambda_ric /usr/local/bin
COPY --from=nodebuilder /app/public/vite /app/public/vite
COPY . /app/
ENV BOOTSNAP_CACHE_DIR=/bootsnap
RUN mkdir -p /bootsnap && bundle exec bootsnap precompile --gemfile app/ lib/ config/

COPY config/lambda_entrypoint.sh /lambda_entrypoint.sh
COPY config/docker_entrypoint.sh /docker_entrypoint.sh

ENV PORT 3000
ENV LANG C.UTF-8
ENV BOOTSNAP_READONLY=1
ENTRYPOINT ["/docker_entrypoint.sh"]
CMD ["bundle", "exec", "puma", "-C", "config/puma.rb"]
