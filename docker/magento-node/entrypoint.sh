#!/usr/bin/env bash

[ "$DEBUG" = "true" ] && set -x

DEFAULT_USER_ID=1001
CURRENT_USER_ID=$(id -u)

# Update /etc/passwd to contain the requested user id at runtime
if [[ "${CURRENT_USER_ID}" -ne "${DEFAULT_USER_ID}" ]]; then
  echo "overriding user id to: ${CURRENT_USER_ID}"

  sed "s/${DEFAULT_USER_ID}/${CURRENT_USER_ID}/g" /etc/passwd > /tmp/pwd
  cat /tmp/pwd > /etc/passwd
  sed "s/${DEFAULT_USER_ID}/${CURRENT_USER_ID}/g" /etc/group > /tmp/grp
  cat /tmp/grp > /etc/group
fi

confd -onetime -backend env

# Configure Sendmail if required
if [ "$ENABLE_SENDMAIL" == "true" ]; then
    /etc/init.d/sendmail start
fi

[ "$PHP_ENABLE_XDEBUG" = "true" ] && \
    docker-php-ext-enable xdebug && \
    echo "Xdebug is enabled"

set -eo pipefail
COMMAND="$@"

# Set hooks
PRE_INSTALL_HOOK="/home/magento/hooks/pre_install.sh"
PRE_COMPILE_HOOK="/home/magento/hooks/pre_compile.sh"
POST_INSTALL_HOOK="/home/magento/hooks/post_install.sh"

# Override the default command
if [ -n "${COMMAND}" ]; then
  echo "ENTRYPOINT: Executing override command"
  exec $COMMAND
else

  echo "Magento elasticsearch server: ${ES_HOST}"
  echo "Magento mysql server:         ${MYSQL_HOSTNAME}/${MYSQL_DATABASE}"
  echo "Magento run mode:             ${MAGENTO_RUN_MODE}"
  echo "Magento root:                 ${MAGENTO_ROOT}"

  # Check if we can connect to the database
  echo "Testing database connection.."
  while ! mysqladmin ping -h "${MYSQL_HOSTNAME}" --silent; do
    echo "Waiting on database connection.."
    sleep 2
  done

  ES_CONNECTION_OPTIONS=""

  # If elasticsearch require, Check if we can connect to it
  if [[ -n "${ES_HOST}" ]]; then

    ES_CONNECTION_OPTIONS=" --es-hosts="${ES_HOST}""

    IFS=',' read -ra ES_HOST_ARRAY <<< "${ES_HOST}"
    echo "Testing elasticsearch connection.."
    if [ "${ES_ENABLE_SSL}" == "true" ]; then
      ES_SSL="--es-enable-ssl"
      ES_PROTO="https"
    else
      ES_SSL=""
      ES_PROTO="http"
    fi
    while ! curl -fs -u ${ES_USER}:${ES_PASSWORD} ${ES_PROTO}://${ES_HOST_ARRAY[0]}/_cat/health?h=status; do
      echo "Waiting on elasticsearch connection.."
      sleep 2
    done

    u=${ES_USER// }
    p=${ES_PASSWORD// }

    if [[ -n "$u" ]] && [[ -n "$p" ]]; then
        ES_CONNECTION_OPTIONS="${ES_CONNECTION_OPTIONS} --es-user="${ES_USER}" --es-pass="${ES_PASSWORD}" ${ES_SSL}"
    else
      ES_CONNECTION_OPTIONS="${ES_CONNECTION_OPTIONS} ${ES_SSL}"
    fi

  fi

  # Measure the time it takes to bootstrap the container
  START=`date +%s`

  # Set the base Magento command to bin/magento
  CMD_MAGENTO="bin/magento" && chmod +x $CMD_MAGENTO && sync

  # Set the config command
  CMD_CONFIG="${CMD_MAGENTO} setup:config:set --db-host="${MYSQL_HOSTNAME}" \
              --db-name="${MYSQL_DATABASE}" --db-user="${MYSQL_USERNAME}" --db-password="${MYSQL_PASSWORD}" \
              ${ES_CONNECTION_OPTIONS}"

  if [[ -n "${CRYPTO_KEY}" ]]; then
    CMD_CONFIG="${CMD_CONFIG} --key="${CRYPTO_KEY}""
  fi

  # Set up the backend frontname -- it's recommended to not use 'backend' or
  # 'admin' here
  if [[ -n "${BACKEND_FRONTNAME}" ]]; then
    CMD_CONFIG="${CMD_CONFIG} --backend-frontname=${BACKEND_FRONTNAME}"
  fi

  # If set, setup redis config
  if [ "${USE_REDIS}" == "true" ]; then
    CMD_CONFIG="${CMD_CONFIG} --session-save=redis --session-save-redis-host="${REDIS_SERVER}" \
      --session-save-redis-port=${REDIS_PORT} --session-save-redis-db="${REDIS_SESSION_DB}" \
      --cache-backend=redis --cache-backend-redis-server="${REDIS_SERVER}" \
      --cache-backend-redis-db="${REDIS_CACHE_BACKEND_DB}" --cache-backend-redis-port=${REDIS_PORT} \
      --page-cache=redis --page-cache-redis-server="${REDIS_SERVER}" --page-cache-redis-db="${REDIS_PAGE_CACHE_DB}" \
      --page-cache-redis-port=${REDIS_PORT}"
  fi

  # Set the install command
  CMD_INSTALL="${CMD_MAGENTO} setup:install \
                --admin-firstname="${ADMIN_FIRSTNAME}" \
                --admin-lastname="${ADMIN_LASTNAME}" \
                --admin-email="${ADMIN_EMAIL}" \
                --admin-user="${ADMIN_USERNAME}" \
                --admin-password="${ADMIN_PASSWORD}" --language="${LANGUAGE}" \
                --currency="${CURRENCY}" --timezone="${TIMEZONE}" \
                ${ES_CONNECTION_OPTIONS} \
                --use-rewrites=1"

  if [ "${USE_SSL}" == "true" ]; then
    echo "Adding SSL configuration for Magento"
    CMD_INSTALL="${CMD_INSTALL} --use-secure=1 --use-secure-admin=1 --base-url=http://${FQDN} --base-url-secure=https://${FQDN}"
  else
    CMD_INSTALL="${CMD_INSTALL} --use-secure=0 --use-secure-admin=0 --base-url=http://${FQDN} --base-url-secure=https://${FQDN}"
  fi

  # MAGENTO_BASE_URL
  # --base-url="${MAGENTO_BASE_URL}"

  # Run configuration command
  echo "Run Magento configuration.."
  $CMD_CONFIG

  # Run any commands that need to run before code compilation starts
  if [ -f "${PRE_INSTALL_HOOK}" ]; then
    echo "HOOKS: Running PRE_INSTALL_HOOK"
    chmod +x "${PRE_INSTALL_HOOK}"
    $PRE_INSTALL_HOOK
  fi

  # Run setup:db:status to get an idea about the current state
  CHECK_STATUS=$($CMD_MAGENTO setup:db:status 2>&1 || true)

  echo "Status: ${CHECK_STATUS}"

  # Automated installs and updates can be tricky if they are not handled
  # properly. This could for example run updates twice if you're updating
  # a deployment in Kubernetes or service in Docker Swarm. There are very
  # sane reasons NOT to run automated installations or updates.
  if [ "${UNATTENDED}" == "true" ]; then
    if [[ $CHECK_STATUS == *"up to date"*. ]]; then
      echo "Installation is up to date"
    elif [[ $CHECK_STATUS == *"application is not installed"* ]]; then
      echo "Magento not yet installed, running installer.."
      $CMD_INSTALL
    else
      CHECK_PLUGINS=$((echo $CHECK_STATUS | grep -o '\<none\>' || true) | \
                      wc -l)

      if [[ "${CHECK_PLUGINS}" -eq "0" ]]; then
        UNINSTALLED_PLUGINS=0
        echo "Update required."
      else
        UNINSTALLED_PLUGINS=$(expr $CHECK_PLUGINS / 2)
        echo "Found ${UNINSTALLED_PLUGINS} uninstalled plugin(s)."
      fi

      echo "Uninstall plugins: ${UNINSTALLED_PLUGINS}"

      # This is an arbitrary number. As we're checking on 'none' as an
      # individual word this should be able to handle minor upgrades of
      # Magento (2.1 > 2.2)
      if [[ $UNINSTALLED_PLUGINS -gt 20 ]]; then
        echo "Running installer.."
        $CMD_INSTALL
      else
        echo "Running upgrade.."
        $CMD_MAGENTO setup:upgrade
      fi
    fi
  fi

  # Run any commands that need to run before code compilation starts
  if [ -f "${PRE_COMPILE_HOOK}" ]; then
    echo "HOOKS: Running PRE_COMPILE_HOOK"
    chmod +x "${PRE_COMPILE_HOOK}"
    $PRE_COMPILE_HOOK
  fi

  # Run code compilation
  $CMD_MAGENTO setup:di:compile

  # Empty line
  echo

  # Check RUNTYPE and decide if we run in production or development
  if [ "$MAGENTO_RUN_MODE" == "developer" ]; then
    #  DEVELOPMENT
    echo "Switching to development mode"
    $CMD_MAGENTO deploy:mode:set developer -s
  else
    # PRODUCTION
    echo "Switching to production mode"
    $CMD_MAGENTO deploy:mode:set production -s

    # Deploy static content
    $CMD_MAGENTO setup:static-content:deploy $CONTENT_LANGUAGES
  fi

  #echo "Changing permissions to www-data.. "
  #chown -R www-data: $MAGENTO_ROOT

  # Calculate the number of seconds required to bootstrap the container
  END=`date +%s`
  RUNTIME=$((END-START))
  echo "Startup preparation finished in ${RUNTIME} seconds"

  # Run any post install hooks (e.g. run a database script). You can't interact
  # with the Magento API at this point as you need a running webserver.
  if [ -f "${POST_INSTALL_HOOK}" ]; then
    echo "HOOKS: Running POST_INSTALL_HOOK"
    chmod +x "${POST_INSTALL_HOOK}"
    $POST_INSTALL_HOOK
  fi

  # If CRON is set to true we only start cron in this container. We needed to
  # go through the same process as php-fpm to match all requirements.
  if [ "${CRON}" == "true" ]; then
    echo "CRON: Starting crontab"

    exec /usr/local/bin/supercronic /home/magento/crontab/magento
  else
    echo "Magento: Starting php-fpm and nginx"
    #exec /usr/local/sbin/php-fpm -F
    exec /usr/local/bin/supervisord -n -c /etc/supervisord.conf
  fi
fi
