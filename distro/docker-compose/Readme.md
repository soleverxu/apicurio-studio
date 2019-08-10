# Docker-compose based installation

## Overview

This setup contains a fully configured Apicurio-Studio package, already integrated with MySQL/Postgres, Keycloak and Microcks. It contains a shell script which will configure the environment. Currently every application is routed to the host network without SSL support. This is a development version, do not use it in a production environment!

Here is the port mapping:
- 8090 for Keycloak
- 8091 for the API
- 8092 for the websockets
- 8093 for the UI
- 8900 for Microcks

## Setup

The folder contains a bash script to make the initialization. The script will create the configuration files based on your IP address and your chosen database type.

The scripts will create 3 files:
- .env
- config/keycloak/apicurio-realm.json
- config/keycloak/microcks-realm.json

Supported databases:
- mysql
- postgresql

### Docker based setup

The easiest way is to open a terminal or PowerShell, and navigate into distro/docker-compose folder. In this folder enter the command below. On Windows please make sure, that your drives shares are enabled!

```
On Linux/Mac:

docker run -v $(pwd):/apicurio chriske/apicurio-setup-image:latest bash /apicurio/setup.sh {IP_OF_YOUR_HOST} {DATABASE_TYPE}

For example:
docker run -v $(pwd):/apicurio chriske/apicurio-setup-image:latest bash /apicurio/setup.sh 192.168.1.231 mysql
```

```
On Windows:

docker run -v ${PWD}:/apicurio chriske/apicurio-setup-image:latest bash /apicurio/setup.sh {IP_OF_YOUR_HOST} {DATABASE_TYPE}

For example:
docker run -v ${PWD}:/apicurio chriske/apicurio-setup-image:latest bash /apicurio/setup.sh 192.168.1.231 mysql
```

This command will pull a minimal alpine linux based image, mount the current folder to it, and it will run the setup script. At the end of the run, it will print the admin password for Keycloak, and the URLs for the services. Like this:

```
Keycloak username: admin
Keycloak password: op4oUQ

Keycloak URL: 192.168.1.231:8090
Apicurio URL: 192.168.1.231:8093
Microcks URL: 192.168.1.231:8900

```

Please copy these values somewhere where you can find them easily!

### Script based setup

If you're using NIX based OS, you can run the setup script without the docker wrapper. The only dependency is "util-linux" package which contains a tool called uuidgen.

```
./setup.sh {IP_OF_YOUR_HOST} {DATABASE_TYPE}
```

Note: make sure you use the external IP address of your host here.  `localhost` and `127.0.0.1` will not work.

## Environment customisation

After the successfull run of the setup script, a file called `.env` will appear. This file contains the customisable properties of the environment. Every property is already filled in, so this is only for customization. You can set your passwords, URL's, and the versions of the components of Apicurio-Studio. The default version is the `latest-release` tagged container from dockerhub, but you can change this as you want.

The passwords for DBs, KeyCloak, and the uuid of the microcks-service-account is generated dynamically with every run of the setup script.

If you want to change these settings (or the provided KeyCloak configuration) after you already started the stack, you have to remove the already existing docker volumes. The easiest way is to stop your running compose stack, and prune your volumes:

```
docker system prune --volumes
```

A simple "reset" script is also included, it will remove the generated config files for you.

```
./reset_env.sh
```

## Starting the environment

When your configs are generated, you can start the whole stack with these commands:

```
For Mysql config:
./start-mysql-environment.sh

For PostgreSQL config:
./start-postgresql-environment.sh
```

If you want to do it manually, here are the commands:

```
docker-compose -f docker-compose.keycloak.yml build

If you generated a config for MySQL:
docker-compose -f docker-compose.keycloak.yml -f docker-compose.microcks.yml -f docker-compose.apicurio.yml -f docker-compose-as-mysql.yml up

If you generated a config for PostgreSQL:
docker-compose -f docker-compose.keycloak.yml -f docker-compose.microcks.yml -f docker-compose.apicurio.yml -f docker-compose-as-postgre.yml up

```

Please do not mix up those commands! If you want to switch between databases, you have to clear the already existing volumes and configs.

To clear the environment, please run these commands:

```
docker system prune --volumes
./reset_env.sh
```

## Configure users in Keycloak

The Keycloak instance is already configured, you don't have to create the realms manually.

At the first start there are no default users added to Keycloak. Please navigate to:
`http://YOUR_IP:8090`

The default credentials for Keycloak are: `admin` and `admin_password`

Select Apicurio realm and add a user to it. After this, you have to do this with Microcks too.


## Login to Apicurio and Microcks

Apicurio URL: `http://YOUR_IP:8093`
Microcks URL: `http://YOUR_IP:8900`

## Additional Settings

A few changes are made to apply additional settings before running setup:

- Use `nginx` as reverse proxy in front of the Keycloak which allows visiting Keycloak from non local/private networks.
- Config your own public ports rather than the default ones: 8090, 8091, 8092, 8093, 8900.
- Config your own initial Keycloak password instead of generating random one.
- Config local GitHub (GHE) and/or local GitLab as default GitHub/GitLab linking providers. For more information, check out the [apicurio-keycloak-extensions](https://github.com/soleverxu/apicurio-keycloak-extensions).

All the additional settings can only be set via environment variables:

| Environment Variable | Sample | Description | Default |
| ---- | ---- | ---- | ---- |
| APICURIO_STUDIO_KEYCLOAK_INIT_PASSWORD | `abc123` | Use your password during the setup instead of generating random one. You shall use the username `admin` with this password while loggin to the Keycloak. | _random_ |
| APICURIO_STUDIO_KEYCLOAK_LOCAL_EXPOSE_PORT | `12345` | Since the nginx is used as reverse proxy in front of Keycloak, the Keycloak is required to be exposed with `127.0.0.1:port`. This local expose port is the one exposed to localhost only. | `8089` |
| APICURIO_STUDIO_KEYCLOAK_PUBLISH_PORT | `12001` | Your specific port of Keycloak component published in the network. | `8090` |
| APICURIO_STUDIO_API_PUBLISH_PORT | `12002` | Your specific port of Apicurio Studio API component published in the network. | `8091` |
| APICURIO_STUDIO_WS_PUBLISH_PORT | `12003` | Your specific port of Apicurio Studio WebSocket (WS) component published in the network. | `8092` |
| APICURIO_STUDIO_UI_PUBLISH_PORT | `12004` | Your specific port of Apicurio Studio UI component published in the network. | `8093` |
| APICURIO_STUDIO_MICROCKS_PUBLISH_PORT | `12005` | Your specific port of Microcks component published in the network. | `8900` |
| APICURIO_STUDIO_KEYCLOAK_EXTENSION_SOCIAL_SNAPSHOT_URL | `https://example.com/keycloak-ext/snapshot.jar` | The Keycloak extension jar file to be installed with Keycloak to enable local GitHub (GHE) and local GitLab. For more information, check out the [apicurio-keycloak-extensions](https://github.com/soleverxu/apicurio-keycloak-extensions). | `https://github.com/soleverxu/apicurio-keycloak-extensions/releases/download/social-6.0.0-SNAPSHOT/apicurio-keycloak-extensions-social-6.0.0-SNAPSHOT.jar` |
| APICURIO_STUDIO_KEYCLOAK_LOCAL_GITHUB_BASE_URL | `https://ghe.domain.com` | The local GitHub (GHE) base url to replace the default one. | `https://github.com` |
| APICURIO_STUDIO_KEYCLOAK_LOCAL_GITHUB_API_URL | `https://ghe.domain.com/api/v3` | The local GitHub (GHE) API url to replace the default one. | `https://api.github.com` |
| APICURIO_STUDIO_KEYCLOAK_LOCAL_GITLAB_URL | `https://gitlab.domain.com` | The local GitLab url to replace the default one. | `https://gitlab.com` |
