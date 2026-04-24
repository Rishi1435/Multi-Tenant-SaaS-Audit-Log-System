FROM node:18-slim

# Install netcat and curl for healthchecks
RUN apt-get update && apt-get install -y netcat-openbsd curl && rm -rf /var/lib/apt/lists/*

WORKDIR /usr/src/app

COPY package*.json ./
RUN npm install

COPY . .

# Ensure scripts are executable
RUN chmod +x provision.sh test_acl_violation.sh test_quota_violation.sh

EXPOSE 3000

CMD ["node", "src/index.js"]
