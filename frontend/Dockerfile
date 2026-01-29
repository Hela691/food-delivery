FROM node:18-alpine AS builder 
  
WORKDIR /app 
COPY package*.json ./ 
RUN npm ci 
COPY . . 
RUN npm run build 
  
# Stage 2: Production avec Nginx 
FROM nginx:alpine 
  
# Copier la configuration Nginx personnalisée 
COPY nginx.conf /etc/nginx/conf.d/default.conf 
  
# Copier les fichiers buildés 
COPY --from=builder /app/dist /usr/share/nginx/html 
  
# Utilisateur non-root 
RUN chown -R nginx:nginx /usr/share/nginx/html 
  
EXPOSE 80 
  
HEALTHCHECK --interval=30s --timeout=3s \ 
  CMD wget --no-verbose --tries=1 --spider http://localhost:80 || exit 1 
  
CMD ["nginx", "-g", "daemon off;"] 
