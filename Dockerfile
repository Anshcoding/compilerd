# Use a multi-stage build to avoid a bloated final image
FROM node:20.13.0-alpine AS node-stage
FROM mcr.microsoft.com/dotnet/core/sdk:3.1 AS dotnet-stage

# Base image for final build
FROM alpine:3.17

# Environment variable to make Python output unbuffered
ENV PYTHONUNBUFFERED=1

# Install essential packages including Python, Go, and other tools
RUN set -ex && \
    apk add --no-cache gcc g++ musl-dev python3 openjdk17 ruby iptables ip6tables bash curl git go npm

# Install Chromium and lsof
RUN set -ex && \
    apk add --no-cache chromium lsof

# Clean up unneeded GCC components
RUN set -ex && \
    rm -f /usr/libexec/gcc/x86_64-alpine-linux-musl/6.4.0/cc1obj && \
    rm -f /usr/libexec/gcc/x86_64-alpine-linux-musl/6.4.0/lto1 && \
    rm -f /usr/libexec/gcc/x86_64-alpine-linux-musl/6.4.0/lto-wrapper && \
    rm -f /usr/bin/x86_64-alpine-linux-musl-gcj

# Create symlink for Python
RUN ln -sf python3 /usr/bin/python

# Copy files from node-stage and dotnet-stage
COPY --from=node-stage /usr/local/bin/node /usr/local/bin/node
COPY --from=node-stage /usr/local/lib/node_modules /usr/local/lib/node_modules
COPY --from=dotnet-stage /usr/share/dotnet /usr/share/dotnet
COPY --from=dotnet-stage /usr/local/bin /usr/local/bin

# Set the working directory
WORKDIR /usr/bin

# Copy source files
ADD . /usr/bin/
ADD start.sh /usr/bin/

# Install Node.js dependencies
RUN npm install

# Expose the application port
EXPOSE 8080

# Add a dummy user to run the server
RUN addgroup -S -g 2000 runner && adduser -S -D -u 2000 -s /sbin/nologin -h /tmp -G runner runner

# Switch to the non-root user
USER runner

# Set the default command to run the application
CMD ["sh", "/usr/bin/start.sh"]
