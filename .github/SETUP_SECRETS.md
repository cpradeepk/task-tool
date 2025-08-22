# 🔐 GitHub Actions Secrets Setup Guide

## Required Secrets for Automated Deployment

To enable automated deployment via GitHub Actions, you need to configure the following secrets in your GitHub repository.

### 📍 **How to Add Secrets**

1. Go to your GitHub repository
2. Click on **Settings** tab
3. In the left sidebar, click **Secrets and variables** → **Actions**
4. Click **New repository secret**
5. Add each secret below

---

## 🔑 **Required Secrets**

### **DEPLOY_HOST**
- **Description**: Your server's IP address or domain name
- **Example**: `123.456.789.012` or `your-server.com`
- **Value**: Your production server hostname/IP

### **DEPLOY_USER**
- **Description**: SSH username for deployment
- **Example**: `ubuntu`, `root`, or your server username
- **Value**: The username used to SSH into your server

### **DEPLOY_KEY**
- **Description**: Private SSH key for server access
- **How to generate**:
  ```bash
  # On your local machine or server
  ssh-keygen -t rsa -b 4096 -C "github-actions-deploy"
  
  # Copy the private key content
  cat ~/.ssh/id_rsa
  ```
- **Value**: Complete private key content (including `-----BEGIN` and `-----END` lines)

### **DEPLOY_PORT** (Optional)
- **Description**: SSH port number
- **Default**: 22
- **Value**: Your SSH port (only add if different from 22)

---

## 🛠️ **SSH Key Setup on Server**

### **Step 1: Generate SSH Key Pair**
```bash
# On your local machine
ssh-keygen -t rsa -b 4096 -C "github-actions-deploy"

# This creates:
# ~/.ssh/id_rsa (private key - add to GitHub secrets)
# ~/.ssh/id_rsa.pub (public key - add to server)
```

### **Step 2: Add Public Key to Server**
```bash
# Copy public key to server
ssh-copy-id -i ~/.ssh/id_rsa.pub user@your-server.com

# Or manually add to authorized_keys
cat ~/.ssh/id_rsa.pub | ssh user@your-server.com "mkdir -p ~/.ssh && cat >> ~/.ssh/authorized_keys"
```

### **Step 3: Test SSH Connection**
```bash
# Test the connection
ssh -i ~/.ssh/id_rsa user@your-server.com

# Should connect without password prompt
```

---

## 📋 **Server Preparation**

### **Project Directory Setup**
Ensure your project is cloned in one of these locations on your server:
- `/srv/task-tool`
- `/var/www/task-tool`
- `~/task-tool`

```bash
# Example setup
sudo mkdir -p /srv/task-tool
sudo chown $USER:$USER /srv/task-tool
cd /srv/task-tool
git clone https://github.com/cpradeepk/task-tool.git .
```

### **Permissions Setup**
```bash
# Make deployment script executable
chmod +x scripts/deploy-new-domain.sh

# Ensure proper ownership
sudo chown -R $USER:$USER /srv/task-tool
```

---

## 🔧 **Manual Deployment (Fallback)**

If automated deployment is not set up, the CI/CD pipeline will still:
1. ✅ Run all tests
2. ✅ Build the application
3. ✅ Verify migration files
4. ✅ Perform security checks
5. 📢 Notify you to deploy manually

### **Manual Deployment Steps**
```bash
# SSH to your server
ssh user@your-server.com

# Navigate to project directory
cd /srv/task-tool  # or your project path

# Pull latest code
git pull origin main

# Run deployment script
./scripts/deploy-new-domain.sh
```

---

## 🚨 **Security Best Practices**

### **SSH Key Security**
- ✅ Use dedicated SSH keys for deployment
- ✅ Restrict key permissions: `chmod 600 ~/.ssh/id_rsa`
- ✅ Use strong passphrases (optional but recommended)
- ✅ Regularly rotate SSH keys

### **Server Security**
- ✅ Use non-root user for deployment
- ✅ Configure firewall (UFW/iptables)
- ✅ Keep server updated
- ✅ Monitor deployment logs

### **GitHub Secrets Security**
- ✅ Never commit secrets to repository
- ✅ Use environment-specific secrets
- ✅ Regularly audit secret access
- ✅ Remove unused secrets

---

## 🔍 **Troubleshooting**

### **Common Issues**

#### **SSH Connection Failed**
```bash
# Test SSH connection manually
ssh -v user@your-server.com

# Check SSH key format
head -1 ~/.ssh/id_rsa  # Should start with -----BEGIN
```

#### **Permission Denied**
```bash
# Check file permissions
ls -la ~/.ssh/
chmod 700 ~/.ssh
chmod 600 ~/.ssh/authorized_keys
```

#### **Deployment Script Not Found**
```bash
# Verify script exists and is executable
ls -la scripts/deploy-new-domain.sh
chmod +x scripts/deploy-new-domain.sh
```

#### **Git Pull Failed**
```bash
# Check git status
git status
git remote -v

# Reset if needed
git reset --hard origin/main
```

---

## 📊 **Monitoring Deployment**

### **GitHub Actions Logs**
1. Go to your repository
2. Click **Actions** tab
3. Click on the latest workflow run
4. Expand job logs to see detailed output

### **Server Logs**
```bash
# Check deployment logs
tail -f /var/log/deployment.log  # if your script logs here

# Check application logs
pm2 logs  # if using PM2
journalctl -u your-service  # if using systemd
```

---

## ✅ **Verification Checklist**

After setting up secrets and running deployment:

- [ ] GitHub Actions workflow runs without errors
- [ ] SSH connection works from GitHub Actions
- [ ] Deployment script executes successfully
- [ ] Application is accessible at your domain
- [ ] Database migrations applied correctly
- [ ] All services are running properly

---

## 🆘 **Getting Help**

If you encounter issues:

1. **Check GitHub Actions logs** for detailed error messages
2. **Test SSH connection manually** from your local machine
3. **Verify server permissions** and file locations
4. **Run deployment script manually** to isolate issues
5. **Check server logs** for application-specific errors

For additional support, refer to:
- GitHub Actions documentation
- Your server provider's SSH documentation
- The deployment script logs and error messages
