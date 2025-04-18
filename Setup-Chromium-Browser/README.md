# Installing and Running Chromium on a Linux Server

Chromium is an open-source browser built by Google that focuses on being faster, safer, and more stable. Even if you’re working on a headless Linux server, you can easily run Chromium—whether for basic browsing or running Node extensions. This guide will walk you through installing Docker, setting up Chromium with Docker Compose, and even adding proxy support if desired.

---

## 1. Setting Up Docker

Before you can run Chromium in a container, you need Docker installed on your system.

### **1.1. Update Your System**

Start by bringing your system up-to-date. Run:

```bash
sudo apt update -y && sudo apt upgrade -y
```

This step ensures that all your packages are updated and minimizes potential conflicts.

### **1.2. Remove Conflicting Docker Packages**

To avoid issues, remove any previous Docker-related packages that might be installed:

```bash
for pkg in docker.io docker-doc docker-compose podman-docker containerd runc; do 
  sudo apt-get remove $pkg; 
done
```

### **1.3. Set Up Docker’s Repository**

Update your package list for APT and install required certificates and tools:

```bash
sudo apt-get update
sudo apt-get install ca-certificates curl gnupg
```

Create the directory for storing Docker’s GPG key, setting the proper permissions:

```bash
sudo install -m 0755 -d /etc/apt/keyrings
```

Download Docker’s official GPG key, convert it, and save it to the keyrings folder:

```bash
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
```

Make sure the key has the correct read permissions:

```bash
sudo chmod a+r /etc/apt/keyrings/docker.gpg
```

Add the Docker repository to your APT sources. This command automatically detects your system’s architecture and Ubuntu version code name:

```bash
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
```

### **1.4. Install the Docker Engine**

Update your package list again and install Docker along with its CLI and related plugins:

```bash
sudo apt update -y && sudo apt upgrade -y
sudo apt-get install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
```

You can verify the installation by checking Docker’s version:

```bash
docker --version
```

### **1.5. Confirm Your Server’s Timezone**

Verify that your server’s timezone is set correctly (this is important for timestamp-sensitive operations):

```bash
realpath --relative-to /usr/share/zoneinfo /etc/localtime
```

---

## 2. Deploying Chromium With Docker Compose

Now that Docker is ready, you can deploy Chromium inside a container. This section guides you through creating a directory, setting up the Docker Compose file, and running the container.

### **2.1. Create a Directory for Chromium**

Create a dedicated directory to keep all Chromium-related files:

```bash
mkdir chromium
cd chromium
```

### **2.2. Create and Configure the Docker Compose File**

Open your text editor to create a file named `docker-compose.yaml`:

```bash
nano docker-compose.yaml
```

Paste the following configuration into the file. Adjust the parameters as needed:

- **CUSTOM_USER & PASSWORD:** Set these to your preferred credentials.
- **TZ:** Replace with your server’s timezone (e.g., `Europe/London`).
- **CHROME_CLI:** This is optional but lets you define the URL that opens as the homepage.
- **Ports:** If ports `3010` and `3011` conflict with other services, feel free to change them.

```yaml
---
services:
  chromium:
    image: lscr.io/linuxserver/chromium:latest
    container_name: chromium
    # The security option below is optional and relaxes container security constraints, if needed.
    security_opt:
      - seccomp:unconfined
    environment:
      - CUSTOM_USER=your_username    # Replace with your desired Chromium username.
      - PASSWORD=your_password        # Replace with your desired Chromium password.
      - PUID=1000                     # Adjust user ID if needed.
      - PGID=1000                     # Adjust group ID if needed.
      - TZ=Europe/London              # Set to your server’s timezone.
      - CHROME_CLI=https://github.com/SAVAGEAKALIA  # Optional: change this to your preferred homepage.
    volumes:
      - /root/chromium/config:/config   # This volume persists your Chromium settings.
    ports:
      - 3010:3000   # Host port 3010 maps to container port 3000.
      - 3011:3001   # Host port 3011 maps to container port 3001.
    shm_size: "1gb"   # Increase shared memory if needed.
    restart: unless-stopped    # Automatically restart the container when it stops unexpectedly.
```

Save and exit the file (in nano, press `Ctrl+X`, then `Y`, then `Enter`).

### **2.3. Run the Chromium Container**

Navigate to your Chromium directory (if needed) and launch Chromium in detached mode:

```bash
cd $HOME/chromium
docker compose up -d
```

After the container starts, you can access Chromium from any web browser on your local machine using:

- `http://Server_IP:3010/`
- `https://Server_IP:3011/`

You’ll be prompted to sign in using the credentials you set in the Docker Compose file.

---

## 3. Configuring Proxy Support for Chromium

If you require routing your traffic through a proxy, this section explains how to integrate a proxy server into your Chromium container.

### **3.1. Purchase a Proxy**

Before configuring, get a reliable static residential proxy from a trusted provider. For instance, you might purchase one via crypto payments on iproyal.

### **3.2. Update the Docker Compose File for Proxy**

First, stop your currently running Chromium container to make changes:

```bash
docker compose down -v
```

Next, open your `docker-compose.yml` file and update the environment variables as follows:

- Ensure that `CUSTOM_USER` and `PASSWORD` are set accurately.
- Edit the `CHROME_CLI` variable to include the proxy server. Remove one of the lines if you only need either HTTP or SOCKS5 support.
- Replace `proxy.example.com:1080` with your actual proxy address and port.

Below is the revised configuration for proxy usage:

```yaml
---
services:
  chromium:
    image: lscr.io/linuxserver/chromium:latest
    container_name: chromium
    security_opt:
      - seccomp:unconfined
    environment:
      - CUSTOM_USER=your_username    # Chromium username.
      - PASSWORD=your_password        # Chromium password.
      - PUID=1000
      - PGID=1000
      - TZ=Europe/London              # Set according to your local timezone.
      # Uncomment the appropriate CHROME_CLI line based on your proxy type:
      - CHROME_CLI=--proxy-server=http://proxy.example.com:1080 https://google.com
      # - CHROME_CLI=--proxy-server=socks5://proxy.example.com:1080 https://google.com
    volumes:
      - /root/chromium/config:/config
    ports:
      - 3010:3000
      - 3011:3001
    shm_size: "1gb"
    restart: unless-stopped
```

Save your changes, then restart the container:

```bash
docker compose up -d
```

Visit `http://Server_IP:3010/` or `https://Server_IP:3011/` in your browser. You will first be asked for your Chromium login credentials, and if your proxy requires authentication, you’ll be prompted for that too.

---

## 4. Stopping and Removing Chromium

If you ever need to stop and completely remove your Chromium container, follow these steps:

1. **Stop the container:**

   ```bash
   docker stop chromium
   ```

2. **Remove the container:**

   ```bash
   docker rm chromium
   ```

3. **Clean up unused Docker resources:**

   ```bash
   docker system prune
   ```

This will help keep your server clean and free up any unnecessary resources
