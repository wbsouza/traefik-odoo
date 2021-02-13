# odoo-traefik

Odoo + Traefik (trying to replace the Nginx proxy)


## Important note
The docker image wbsouza/odoo:11.0 contains everything to run Odoo (including the PostgreSQL).
It's not recommended to run this image in production, it was build only for test purpose, to
demonstrate a potential inconsistence using Traefik as a proxy for Odoo. Feel free to customize or
make your own Odoo image, the source code of the image is available on [https://github.com/wbsouza/odoo-docker](https://github.com/wbsouza/odoo-docker).

*** The database is going to be re-created if you remove the file `volumes/odoo/conf/.initialized`. ***

## Initial setup

1. Access your domain provider and add the following entries to your domain:
  - `traefik.mycompany.io`
  - `odoo.mycompany.io`

2. Create a bridge network to be used by the containers
  - `docker create network web`

2. Copy the file .env.sample to .env and change the domain name and the email for the LetsEncript certificate

3. Execute `docker-compose up`



## Throubleshooting (knowed issue)
1) The current implemnetation has an issue, the Traefik is not working properly as a proxy for the Odoo `/longpoling` port 7082
when we set the `workers > 1` in the file `volumes/odoo/conf/odoo.conf`. See, the example `volumes/odoo/conf.odoo.conf.sample`.

2) If you want create volumes like in the `odoo.conf.sample` file, make sure to give the right permissions or change the owner
in the host filesystem volumes, because the container will run with an unprivileged user (odoo, UID=9100, GID=9100).

`chown -fR '9100:9100' volumes/odoo`

   
