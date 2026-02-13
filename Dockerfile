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

FROM public.ecr.aws/sorah/ruby:3.4-dev AS vipsbuilder

ARG LIBVIPS_VERSION=8.18.0
ARG LIBVIPS_SHA384=9ef821ecfad15281aa61df51ef3af168a4f835f79b2fa34374d152245006ebdd7ba952665cfecb930f51f1758e43ee26

RUN --mount=type=cache,target=/var/cache/apt,sharing=locked --mount=type=cache,target=/var/lib/apt,sharing=locked \
    apt-get update \
 && apt-get install --no-install-recommends -y \
      build-essential meson pkg-config curl xz-utils ca-certificates \
      libglib2.0-dev libexpat1-dev \
      libjpeg-turbo8-dev libpng-dev libwebp-dev

RUN --mount=type=tmpfs,target=/build/libvips \
    curl -fsSL -o /build/libvips/vips.tar.xz https://github.com/libvips/libvips/releases/download/v${LIBVIPS_VERSION}/vips-${LIBVIPS_VERSION}.tar.xz \
 && echo "${LIBVIPS_SHA384}  /build/libvips/vips.tar.xz" | sha384sum -c --strict - \
 && tar xf /build/libvips/vips.tar.xz -C /build/libvips \
 && cd /build/libvips/vips-${LIBVIPS_VERSION} \
 && meson setup build --buildtype=release --strip --prefix=/opt/libvips --libdir=lib \
      -Dauto_features=disabled \
      -Djpeg=enabled -Dpng=enabled -Dwebp=enabled -Dzlib=enabled \
      -Dmodules=disabled -Dintrospection=disabled \
      -Ddeprecated=false -Dexamples=false -Dcplusplus=false \
      -Dnsgif=false -Dppm=false -Danalyze=false -Dradiance=false \
 && cd build && ninja && ninja install

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
 && apt-get install --no-install-recommends -y \
      libpq5 libyaml-dev \
      libglib2.0-0t64 libexpat1 libjpeg-turbo8 libpng16-16t64 libwebp7 libwebpmux3 libwebpdemux2 libsharpyuv0 \
 && rm -rf /var/lib/apt/lists/*

COPY --from=vipsbuilder /opt/libvips /opt/libvips
RUN ln -s /opt/libvips/bin/vipsthumbnail /usr/local/bin/vipsthumbnail \
 && echo /opt/libvips/lib > /etc/ld.so.conf.d/libvips.conf && ldconfig \
 && vipsthumbnail --vips-version

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
