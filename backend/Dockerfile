# Multi-stage build pour optimiser la taille 
FROM node:18-alpine AS builder 
  
WORKDIR /app 
COPY package*.json ./ 
RUN npm ci --only=production 
  
FROM node:18-alpine 
  
# Créer un utilisateur non-root pour la sécurité 
RUN addgroup -g 1001 -S nodejs && \ 
    adduser -S nodejs -u 1001 
  
WORKDIR /app 
  
# Copier les dépendances du stage builder 
COPY --from=builder /app/node_modules ./node_modules 
COPY . . 
  
# Changer le propriétaire des fichiers 
RUN chown -R nodejs:nodejs /app 
USER nodejs 
  
EXPOSE 4000 
  
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \ 
  CMD wget --no-verbose --tries=1 --spider http://localhost:4000/health || exit 1 
  
CMD ["node", "server.js"]
