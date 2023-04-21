FROM alpine:latest AS builder
RUN apk add --update nodejs npm
ARG GITLAB_ACCESS_TOKEN
WORKDIR /usr/src

COPY ./package*.json ./
COPY ./.npmrc ./

RUN npm ci

COPY . .

RUN npm run-script build

FROM alpine:latest
RUN addgroup -S node && adduser -S node -G node
RUN apk add --update nodejs npm
ARG GITLAB_ACCESS_TOKEN
ARG PORT=3001
ARG BUILD_ENV

ENV NODE_ENV ${BUILD_ENV}
ENV NODE_CONFIG_ENV ${BUILD_ENV}

# Update the system
RUN apk --no-cache -U upgrade

RUN mkdir -p /home/node/app/build && chown -R node:node /home/node/app
RUN apk add --no-cache \
        python3 \
        py3-pip \
    && pip3 install --upgrade pip \
    && pip3 install \
        awscli \
    && rm -rf /var/cache/apk/*

RUN aws --version

WORKDIR /home/node/app

USER node

COPY --chown=node:node  --from=builder /usr/src/package*.json ./

COPY --chown=node:node --from=builder /usr/src/.npmrc ./
RUN npm install --only=production
COPY --chown=node:node --from=builder /usr/src/build ./build
COPY --chown=node:node --from=builder /usr/src/config ./config
COPY --chown=node:node --from=builder /usr/src/migrations ./migrations
COPY --chown=node:node --from=builder /usr/src/knexfile.js ./knexfile.js
COPY --chown=node:node --from=builder /usr/src/src/modules/deployment/configs ./deploymentConfig

EXPOSE ${PORT}

CMD [ "npm", "start" ]
