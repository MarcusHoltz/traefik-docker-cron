FROM alpine:latest

# Install bash, coreutils (for date commands), and tzdata for timezone handling
RUN apk add --no-cache bash coreutils tzdata

WORKDIR /app

# Copy script into container
COPY set_priority.sh /app/set_priority.sh

# Ensure script is executable
RUN chmod +x /app/set_priority.sh

# Create directory for dynamic configs
RUN mkdir -p /app/dynamic_config

# Set environment variable for proper date parsing
ENV LANG=en_US.UTF-8

# Run the script with exec to ensure it gets signals
CMD ["bash", "-c", "exec /app/set_priority.sh"]
