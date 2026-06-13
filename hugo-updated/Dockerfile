# Stage 1: Build Hugo site
FROM hugomods/hugo:exts AS builder
WORKDIR /site
COPY . .
ARG HUGO_GIT_COMMIT=local
ARG HUGO_BUILD_TIME
ENV HUGO_GIT_COMMIT=${HUGO_GIT_COMMIT}
ENV HUGO_BUILD_TIME=${HUGO_BUILD_TIME}
RUN hugo --minify --gc

# Stage 2: Serve with nginx
FROM nginx:alpine
COPY --from=builder /site/public /usr/share/nginx/html

# Custom nginx config for Hugo (SPA-friendly, proper 404 handling)
RUN printf 'server {\n\
  listen 80;\n\
  root /usr/share/nginx/html;\n\
  index index.html;\n\
  location / {\n\
    try_files $uri $uri/ $uri/index.html =404;\n\
  }\n\
  error_page 404 /404.html;\n\
  gzip on;\n\
  gzip_types text/css application/javascript text/html image/svg+xml;\n\
}\n' > /etc/nginx/conf.d/default.conf

EXPOSE 80
