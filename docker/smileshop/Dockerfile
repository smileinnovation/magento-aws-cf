FROM magento-node


ENV MAGENTO_ROOT=/var/www/magento

# Copy magento app
COPY --chown=magento:root src $MAGENTO_ROOT

# Copy cronjob
COPY --chown=magento:root cron/magento /home/magento/crontab/magento
