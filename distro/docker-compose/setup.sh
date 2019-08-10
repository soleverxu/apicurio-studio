#!/bin/bash

if [ -f ".setup.env" ]; then
  set -a
  source ".setup.env"
  set +a
fi

HOST_IP=${1:-$APICURIO_STUDIO_HOSTNAME_OR_IP}
DB_TYPE=${2:-$APICURIO_STUDIO_DATABASE_TYPE}

if [ -z "$HOST_IP" ] || [ -z "$DB_TYPE" ]
then
  echo "Please provide the neccessary arguments! First shall be host_ip and second shall be DB type!"
  exit 1
fi

if [ "$DB_TYPE" != "mysql" ] && [ "$DB_TYPE" != "postgresql" ]
then
  echo "DB type must be mysql or postgresql"
  exit
fi

P=$(pwd)

##if the script runs in the container, we have to adjust the path to the mount point
if [ $P == "/" ]
then
  export P=/apicurio
fi

KC_ROOT_DB_PASSWORD=$(< /dev/urandom tr -dc _A-Z-a-z-0-9 | head -c6)
KC_DB_PASSWORD=$(< /dev/urandom tr -dc _A-Z-a-z-0-9 | head -c6)
KC_PASSWORD=$(< /dev/urandom tr -dc _A-Z-a-z-0-9 | head -c6)
AS_MYSQL_ROOT_PASSWORD=$(< /dev/urandom tr -dc _A-Z-a-z-0-9 | head -c6)
AS_DB_PASSWORD=$(< /dev/urandom tr -dc _A-Z-a-z-0-9 | head -c6)

# overwrite KC_PASSWORD with environment variable
if [ -n "$APICURIO_STUDIO_KEYCLOAK_INIT_PASSWORD" ]; then
  KC_PASSWORD="$APICURIO_STUDIO_KEYCLOAK_INIT_PASSWORD"
fi

# overwrite service ports with environment variables
KC_PORT_LOCAL=${APICURIO_STUDIO_KEYCLOAK_LOCAL_EXPOSE_PORT:-8089}
KC_PORT=${APICURIO_STUDIO_KEYCLOAK_PUBLISH_PORT:-8090}
ASAPI_PORT=${APICURIO_STUDIO_API_PUBLISH_PORT:-8091}
ASWS_PORT=${APICURIO_STUDIO_WS_PUBLISH_PORT:-8092}
ASUI_PORT=${APICURIO_STUDIO_UI_PUBLISH_PORT:-8093}
MR_PORT=${APICURIO_STUDIO_MICROCKS_PUBLISH_PORT:-8900}

SERVICE_CLIENT_SECRET=$(uuidgen)

sed 's/$HOST/'"$HOST_IP"'/g' $P/.env.template > $P/tmp; mv $P/tmp $P/.env

sed 's/$KC_ROOT_DB_PASSWORD/'"$KC_ROOT_DB_PASSWORD"'/g' $P/.env > $P/tmp; mv $P/tmp $P/.env
sed 's/$KC_DB_PASSWORD/'"$KC_DB_PASSWORD"'/g' $P/.env > $P/tmp; mv $P/tmp $P/.env
sed 's/$KC_PASSWORD/'"$KC_PASSWORD"'/g' $P/.env > $P/tmp; mv $P/tmp $P/.env
sed 's/$AS_MYSQL_ROOT_PASSWORD/'"$AS_MYSQL_ROOT_PASSWORD"'/g' $P/.env > $P/tmp; mv $P/tmp $P/.env
sed 's/$AS_DB_PASSWORD/'"$AS_DB_PASSWORD"'/g' $P/.env > $P/tmp; mv $P/tmp $P/.env
sed 's/$SERVICE_CLIENT_SECRET/'"$SERVICE_CLIENT_SECRET"'/g' $P/.env > $P/tmp; mv $P/tmp $P/.env

sed 's/$KC_PORT_LOCALHOST/'"$KC_PORT_LOCAL"'/g' $P/.env > $P/tmp; mv $P/tmp $P/.env
sed 's/$KC_PORT_PUB/'"$KC_PORT"'/g' $P/.env > $P/tmp; mv $P/tmp $P/.env
sed 's/$AS_API_PORT_PUB/'"$ASAPI_PORT"'/g' $P/.env > $P/tmp; mv $P/tmp $P/.env
sed 's/$AS_WS_PORT_PUB/'"$ASWS_PORT"'/g' $P/.env > $P/tmp; mv $P/tmp $P/.env
sed 's/$AS_UI_PORT_PUB/'"$ASUI_PORT"'/g' $P/.env > $P/tmp; mv $P/tmp $P/.env
sed 's/$MR_PORT_PUB/'"$MR_PORT"'/g' $P/.env > $P/tmp; mv $P/tmp $P/.env

if [ "$DB_TYPE" == "mysql" ]
then
  sed 's/$DB_TYPE/'"mysql5"'/g' $P/.env > $P/tmp; mv $P/tmp $P/.env
  sed 's/$DB_DRIVER/'"mysql"'/g' $P/.env > $P/tmp; mv $P/tmp $P/.env
  sed 's/$DB_CONN_URL/'"jdbc:mysql:\\/\\/apicurio-studio-db\\/apicuriodb"'/g' $P/.env > $P/tmp; mv $P/tmp $P/.env
else
  sed 's/$DB_TYPE/'"postgresql9"'/g' $P/.env > $P/tmp; mv $P/tmp $P/.env
  sed 's/$DB_DRIVER/'"postgresql"'/g' $P/.env > $P/tmp; mv $P/tmp $P/.env
  sed 's/$DB_CONN_URL/'"jdbc:postgresql:\\/\\/apicurio-studio-db\\/apicuriodb"'/g' $P/.env > $P/tmp; mv $P/tmp $P/.env
fi



sed 's/$HOST/'"$HOST_IP"'/g' $P/config/keycloak/apicurio-realm.json.template > $P/config/keycloak/apicurio-realm.json
sed 's/$HOST/'"$HOST_IP"'/g' $P/config/keycloak/microcks-realm.json.template > $P/config/keycloak/microcks-realm.json.tmp
sed 's/$SERVICE_CLIENT_SECRET/'"$SERVICE_CLIENT_SECRET"'/g' $P/config/keycloak/microcks-realm.json.tmp > $P/config/keycloak/microcks-realm.json
rm -rf $P/config/keycloak/microcks-realm.json.tmp

sed 's/$AS_UI_PORT_PUB/'"$ASUI_PORT"'/g' $P/config/keycloak/apicurio-realm.json > $P/tmp2; mv $P/tmp2 $P/config/keycloak/apicurio-realm.json
sed 's/$MR_PORT_PUB/'"$MR_PORT"'/g' $P/config/keycloak/microcks-realm.json > $P/tmp3; mv $P/tmp3 $P/config/keycloak/microcks-realm.json

# nginx
sed 's/$KEYCLOAK_PUB_PORT/'"$KC_PORT"'/g' $P/nginx/nginx.conf.template > $P/nginx/nginx.conf
sed 's/$KEYCLOAK_LOCAL_PORT/'"$KC_PORT_LOCAL"'/g' $P/nginx/nginx.conf > $P/tmp4; mv $P/tmp4 $P/nginx/nginx.conf

# apicurio studio keycloak extension for local github
# download keycloak extension for social snapshot (local github & gitlab)
echo "Downloading Keycloak extension, it may take a few seconds ..."
kc_ext_social_snapshot="https://github.com/soleverxu/apicurio-keycloak-extensions/releases/download/social-6.0.0-SNAPSHOT/apicurio-keycloak-extensions-social-6.0.0-SNAPSHOT.jar"
if [ -n "${APICURIO_STUDIO_KEYCLOAK_EXTENSION_SOCIAL_SNAPSHOT_URL}" ]; then
  kc_ext_social_snapshot="${APICURIO_STUDIO_KEYCLOAK_EXTENSION_SOCIAL_SNAPSHOT_URL}"
fi
curl -sSL "$kc_ext_social_snapshot" -o "$P/keycloak/apicurio-keycloak-extensions-social-snapshot.jar"

# set local GitHub/GitLab URL
sed 's/$GITHUB_BASE_URL/'"${APICURIO_STUDIO_KEYCLOAK_LOCAL_GITHUB_BASE_URL:-https:\/\/github.com}"'/g' $P/.env > $P/tmp; mv $P/tmp $P/.env
sed 's/$GITHUB_API_URL/'"${APICURIO_STUDIO_KEYCLOAK_LOCAL_GITHUB_API_URL:-https:\/\/api.github.com}"'/g' $P/.env > $P/tmp; mv $P/tmp $P/.env
sed 's/$GITLAB_URL/'"${APICURIO_STUDIO_KEYCLOAK_LOCAL_GITLAB_URL:-https:\/\/gitlab.com}"'/g' $P/.env > $P/tmp; mv $P/tmp $P/.env

echo ""
echo "Keycloak username: admin"
echo "Keycloak password: $KC_PASSWORD"
echo ""
echo "Keycloak URL: $HOST_IP:$KC_PORT"
echo "Apicurio URL: $HOST_IP:$ASUI_PORT"
echo "Microcks URL: $HOST_IP:$MR_PORT"

