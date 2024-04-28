# Multi-staged DOcker build
FROM node:20-alpine AS base
RUN npm install -g npm@latest

##########################################################################################
# Stage:1 => deps
# Install dependencies only when needed

FROM base AS deps
RUN apk add --no-cache libc6-compat
WORKDIR /mgr

# Install dependencies
COPY package.json package-lock.json* ./
RUN npm ci
##########################################################################################

##########################################################################################
# Stage:2 => dev
# Enable hot-reload for development phase

# FROM base AS dev
# WORKDIR /mgr
# COPY --from=deps /mgr/node_modules ./node_modules
# COPY . .
##########################################################################################

##########################################################################################
# Stage:3 => builder
# Rebuild the source code only when needed

FROM base AS builder
WORKDIR /mgr
COPY --from=deps /mgr/node_modules ./node_modules
COPY . .
ENV NEXT_TELEMETRY_DISABLED 1
RUN npm run build
##########################################################################################

##########################################################################################
# Stage:3 => runner
# Final Image for running the application

FROM base AS runner
WORKDIR /mgr

ENV NEXT_TELEMETRY_DISABLED 1
RUN addgroup --system --gid 1001 nodejs
RUN adduser --system --uid 1001 nextjs
COPY --from=builder /mgr/public ./public

# Automatically leverage output traces to reduce image size
COPY --from=builder --chown=nextjs:nodejs /mgr/.next/standalone ./.next/standalone
COPY --from=builder --chown=nextjs:nodejs /mgr/.next/static ./.next/static

USER nextjs
EXPOSE 3000

# server.js is created by next build from the standalone output
CMD HOSTNAME="0.0.0.0" node ./.next/standalone/server.js
##########################################################################################
