ARG NGINX_BASE_VERSION
FROM nginx:${NGINX_BASE_VERSION}

RUN apt-get update && apt-get install -y certbot python3-certbot-nginx && rm -rf /var/lib/apt/lists/*

RUN mkdir -p /app/le-challenge

WORKDIR /app
COPY start.sh /app/
CMD [ "/bin/bash", "start.sh" ]
