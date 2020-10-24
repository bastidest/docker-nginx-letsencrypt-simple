# Auto-Renewing Let's Encrypt Docker image
This image handles certificate renewal with Let's Encrypt and makes sure nginx uses the new certificates.
It does not make any assumptions about your project.

This container **does not** provide any nginx configuration.
**You** are responsible for exposing the Let's Encrypt challenges and **you** need to make sure to use the certificates in your nginx configuration.

The most important files inside the image are located at:
- `/etc/nginx/nginx.conf`: Nginx config file
- `/etc/letsencrypt/live/<your-domain>/fullchain.pem`: Public certificate with certificate chain
- `/etc/letsencrypt/live/<your-domain>/privkey.pem`: Private key
- `/app/le-challenge`: Location for certbot challenges

Where `<your-domain>` is the first domain in the comma separated domain list in `NGINX_LE_DOMAINS`.

## Configuration and Usage
Check the `docker-compose.yml` file for an example.

### Environment Variables
Use environment variables to control the behavior of the container:

|Name|Description|Optional|Example|
|----|-----------|--------|-------|
|`NGINX_LE_DOMAINS`|Comma separated list of all domains you need certificates for|no|`blog.foo.com,bar.foo.com`|
|`NGINX_LE_EMAIL`|Email to receive certificate expiration notices from Let's Encrypt|no|`admin@foo.com`|
|`NGINX_LE_TEST_CERT`|Use a test certificate instead of a live one|yes|`1`|
|`NGINX_LE_DISABLE`|Do not renew any certificates, use existing ones or generate self-signed ones. Useful for development.|yes|`1`|

### Nginx Configuration
You are required to forward the requests to `/.well-lnown/acme-challenge` to your filesystem (`/app/le-challenge`). This can be done by placing this block in your nginx configuration inside the `http` block.
```conf
server {
	listen 80;
	server_name <your-domain>;

	location ^~ /.well-known/acme-challenge/ {
	   root /app/le-challenge;
	}

  # optional forced http->https redirection
	location / {
	  return 301 https://$host$request_uri;
	}
}
```

## FAQ

### Q: How does it work?
1. If no certificates exist, a self-signed certificate is created
2. Nginx is started
3. Certbot places challenge files in `/etc/letsencrypt/...`
4. Nginx responds to the challenges by Let's Encrypt
5. Certbot deletes the self signed certificate and replaces it with the proper one
6. Nginx is reloaded

You can always check how it's working by looking at the < 10 LOC `Dockerfile` and the < 200 LOC `start.sh` script

### Q: When is the certificate renewed?
The script asks `certbot` to update the certificate daily, but `certbot` only updates it if the certificates expire in less than 30 days.

### Q: How can I customize the script?
1A: Extract the script from the docker image:
```bash
docker run -d --name foo --rm bastidest/nginx-letsencrypt tail -f /dev/null
docker cp foo:/app/start.sh .
docker kill foo
```

1B: Download it from git / GitHub

2: Modify the script to your needs

3A: Create your own Dockerfile with your modified script
```Dockerfile
FROM bastidest/nginx-letsencrypt
COPY ./start.sh /app/start.sh
```

3B: Mount the script into the container (`docker-compose`)
```yml
version: '3.7'
services:
  nginx:
    image: bastidest/nginx-letsencrypt
    volumes:
      - ./start.sh:/app/start.sh:ro
```
