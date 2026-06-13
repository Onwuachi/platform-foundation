FROM klakegg/hugo:ext AS builder
WORKDIR /site
COPY . .
RUN hugo --minify

FROM nginx:alpine
COPY --from=builder /site/public /usr/share/nginx/html

