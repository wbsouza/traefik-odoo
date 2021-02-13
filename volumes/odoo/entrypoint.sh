#!/bin/bash

#sleep 10m

ODOO_CONFIG_FILE="/opt/odoo/conf/odoo.conf"
ODOO_PORT=${ODOO_PORT:-8069}
ODOO_LONGPOOLING_PORT=${ODOO_LONGPOOLING_PORT:-8072}

PG_VERSION="${POSTGRES_VERSION:-12}"
PG_USER="${POSTGRES_USER:-postgres}"
PG_PASS="${POSTGRES_PASSWORD:-postgres}"
PG_PORT="${POSTGRES_PORT:-5432}"

if [ "${ODOO_DATABASE_HOSTNAME}" != "" ]; then
  export PG_HOST="${ODOO_DATABASE_HOSTNAME}"
else
  export PG_HOST="${ODOO_DB_HOST:-127.0.0.1}"
fi

ODOO_DATABASE_NAME="${ODOO_DATABASE_NAME:-odoo}"
ODOO_DATABASE_USERNAME="${ODOO_DATABASE_USERNAME:-odoo}"
ODOO_DATABASE_PASSWORD="${ODOO_DATABASE_PASSWORD:-odoo}"


# if it's the first time (initializing the container) ...
if [ ! -f /opt/odoo/conf/.initialized ]; then

  export ODOO_EXTRA_ARGS="-i base"

  echo -e "* Creating server config file ..."
  touch $ODOO_CONFIG_FILE
  echo "[options]" > $ODOO_CONFIG_FILE
  echo "addons_path = /opt/odoo/odoo-server/addons,/opt/odoo/extra-addons" >> $ODOO_CONFIG_FILE
  echo "data_dir = /opt/odoo/data" >> $ODOO_CONFIG_FILE
  echo "db_host = $PG_HOST" >> $ODOO_CONFIG_FILE
  echo "db_port = $PG_PORT" >> $ODOO_CONFIG_FILE
  echo "db_user = $ODOO_DATABASE_USERNAME" >> $ODOO_CONFIG_FILE
  echo "db_password = $ODOO_DATABASE_PASSWORD" >> $ODOO_CONFIG_FILE
  echo "http_port = $ODOO_PORT"
  echo "xmlrpc_port = ${ODOO_PORT}" >> $ODOO_CONFIG_FILE
  echo "longpolling_port = $ODOO_LONGPOOLING_PORT" >> $ODOO_CONFIG_FILE
  chmod 640 $ODOO_CONFIG_FILE

  chown -fR odoo:odoo /opt/odoo/conf
  chown -fR odoo:odoo /opt/odoo/extra-addons
  chown -fR odoo:odoo /opt/odoo/logs
  chown -fR odoo:odoo /opt/odoo/data

  # initialize the database if running locally and with root user
  if [ "${PG_HOST}" == "127.0.0.1" ] || [ "${PG_HOST}" == "localhost" ] ; then
    if [ "$(id -u)" == "0" ]; then
      pg_ctlcluster $PG_VERSION main start
      touch /tmp/.pg_started
      su - postgres -c "psql <<-EOF
CREATE USER $ODOO_DATABASE_USERNAME with superuser;
ALTER USER $ODOO_DATABASE_USERNAME with password '$ODOO_DATABASE_PASSWORD';
EOF
"
    fi
  fi

  # initialize the database if it's empty
  PGPASSWORD=$ODOO_DATABASE_PASSWORD psql -U $ODOO_DATABASE_USERNAME -d $ODOO_DATABASE_NAME -c "SELECT 1 from res_users where id = 1" > /dev/null 2>&1
  if [ "$?" != "0" ]; then
    if [ "$(id -u)" == "0" ]; then
      su - odoo -c "/usr/bin/python3 /opt/odoo/odoo-server/odoo-bin --config=/opt/odoo/conf/odoo.conf -i base -d $ODOO_DATABASE_NAME --stop-after-init"
    else
      /usr/bin/python3 /opt/odoo/odoo-server/odoo-bin --config=/opt/odoo/conf/odoo.conf -i base -d $ODOO_DATABASE_NAME --stop-after-init
    fi
  fi

  echo "----------------------------------------------- Odoo database initialized! ----------------------------------------------------"
  touch /opt/odoo/conf/.initialized

else

  if [ "${PG_HOST}" == "127.0.0.1" ] || [ "${PG_HOST}" == "localhost" ] ; then
    if [ "$(id -u)" == "0" ]; then
      pg_ctlcluster "$PG_VERSION" main start
    fi
  fi

fi


# generate the extra-addons requirements.txt file
echo "#!/bin/sh" > /tmp/join-requirements.sh
echo "rm -fR /tmp/requirements.txt" >> /tmp/join-requirements.sh
echo "touch /tmp/requirements.txt" >> /tmp/join-requirements.sh
find /opt/odoo/extra-addons -type f -name "*requirements*.txt" | awk '{ printf("cat %s >> /tmp/requirements.txt\n", $1); }' >> /tmp/join-requirements.sh
bash /tmp/join-requirements.sh

# check if is necessary to install any additional library
install_requirements=0
if [ ! -f /opt/odoo/extra-addons/requirements.txt.sha ]; then
  export install_requirements=1 
else    
  last_sha_sum=$(cat /opt/odoo/extra-addons/requirements.txt.sha)
  curr_sha_sum=$(shasum /tmp/requirements.txt)
  if [ "${last_sha_sum}" != "${curr_sha_sum}" ]; then
    export install_requirements=1
  fi
fi

if [ "${install_requirements}" == "1" ]; then
  if [ "$(id -u)" == "0" ]; then
    su - odoo -c  'pip3 install --user -r /tmp/requirements.txt'
  else
    pip3 install --user -r /tmp/requirements.txt  
  fi

  # if the requirements were installed without errors ..
  if [ "$?" == "0" ]; then
    echo $curr_sha_sum > /opt/odoo/extra-addons/requirements.txt.sha
    chown odoo:odoo /opt/odoo/extra-addons/requirements.txt.sha
  fi
fi

if [ "$(id -u)" == "0" ]; then
  exec gosu odoo /bin/bash -c "/usr/bin/python3 /opt/odoo/odoo-server/odoo-bin --config=/opt/odoo/conf/odoo.conf --proxy-mode $@"
else
  /usr/bin/python3 /opt/odoo/odoo-server/odoo-bin --config=/opt/odoo/conf/odoo.conf --proxy-mode $@
fi

exit 0

