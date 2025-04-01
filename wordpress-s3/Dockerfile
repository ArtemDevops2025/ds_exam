FROM wordpress:latest

# Install dependencies
RUN apt-get update && apt-get install -y \
    curl \
    less \
    && rm -rf /var/lib/apt/lists/*

# Copy custom entrypoint script
COPY custom-entrypoint.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/custom-entrypoint.sh

# Set entrypoint
ENTRYPOINT ["custom-entrypoint.sh"]
CMD ["apache2-foreground"]
