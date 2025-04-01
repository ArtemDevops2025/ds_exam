#!/bin/bash

# Install and configure S3 plugin after WordPress is ready
(
  # Wait for WordPress to be ready
  until $(curl -s http://localhost/wp-admin/install.php > /dev/null); do
    echo "Waiting for WordPress to be ready..."
    sleep 10
  done
  
  echo "WordPress is ready, installing S3 plugin..."
  
  # Install WP-CLI if not already installed
  if [ ! -f /usr/local/bin/wp ]; then
    curl -O https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar
    chmod +x wp-cli.phar
    mv wp-cli.phar /usr/local/bin/wp
  fi
  
  # Check if WordPress is installed
  if wp core is-installed --allow-root --path=/var/www/html; then
    # Install and activate S3 plugin
    wp plugin install wp-offload-media --activate --allow-root --path=/var/www/html
    
    # Configure plugin with environment variables
    wp option update amazon_s3 '{"bucket":"'"$S3_BUCKET"'","region":"'"$S3_REGION"'","key":"'"$S3_ACCESS_KEY"'","secret":"'"$S3_SECRET_KEY"'"}' --allow-root --path=/var/www/html
    
    echo "S3 plugin installed and configured successfully!"
  else
    echo "WordPress is not yet installed. Plugin will be installed after setup."
  fi
) &

# Execute the original entrypoint
exec docker-entrypoint.sh "$@"
