FROM nginx

LABEL maintainer="andrew <ansandy@foxmail.com>"

COPY file.conf /etc/nginx/conf.d/file.conf

RUN set -ex; \
  sed -e "s|80|10080|g" -i /etc/nginx/conf.d/default.conf

CMD ["nginx", "-g", "daemon off;"]
