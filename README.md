# odoo-traefik

Odoo + Traefik (trying to replace the Nginx proxy)


## Important note
The docker image wbsouza/odoo:11.0 contains everything to run Odoo (including the PostgreSQL).
It's not recommended to run this image in production, it was build only for test purpose, to
demonstrate a potential inconsistence using Traefik as a proxy for Odoo. 

*** The database is going to be re-created if you remove the file `volumes/odoo/conf/initialized`. ***

## Initial setup

1. Access your domain provider and add the following entries to your domain:
  - `traefik.mycompany.io`
  - `odoo.mycompany.io`

2. Create a bridge network to be used by the containers
  - `docker create network web`

2. Copy the file .env.sample to .env and change the domain name and the email for the LetsEncript certificate

3. Execute `docker-compose up`



## Throubleshooting (knowed issue)
The current implemnetation has an issue, the Traefik is not working properly as a proxy for the Odoo `/longpoling` port 7082
when we set the `workers > 1` in the file `volumes/odoo/conf/odoo.conf`. See, the example `volumes/odoo/conf.odoo.conf.sample`.


