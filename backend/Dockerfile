# ========================
# Stage 1: Development
# ========================
FROM node:20-alpine AS development

WORKDIR /usr/src/app

COPY package*.json ./
COPY prisma ./prisma/

RUN npm install

COPY . .

RUN npx prisma generate

RUN npm run build

# ========================
# Stage 2: Production
# ========================
FROM node:20-alpine AS production

ARG NODE_ENV=production
ENV NODE_ENV=${NODE_ENV}

WORKDIR /usr/src/app

COPY package*.json ./
COPY prisma ./prisma/

RUN npm install --omit=dev

COPY --from=development /usr/src/app/dist ./dist

RUN npx prisma generate

EXPOSE 3000

CMD ["node", "dist/main"]
