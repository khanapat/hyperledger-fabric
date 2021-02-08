FROM node:10.18.1-alpine

RUN mkdir -p /home/node/app/node_modules && chown -R node:node /home/node/app

WORKDIR /home/node/app

COPY package*.json ./

# Install required packages for npm install and remove them after use
RUN apk --no-cache --virtual build-dependencies add \
    curl \
    git \
    python \
    make \
    g++

# Fix for issue: https://github.com/nodejs/docker-node/issues/1199
RUN umask 0 && npm config set cache /tmp/.npm && npm install

COPY . .

RUN apk del build-dependencies

USER node

EXPOSE 8080

CMD ["npm", "start"]
