# 4. Create the Windows container

```bash
mkdir -p "$HOME/WinApps/oem"
cd "$HOME/WinApps"
cp /path/to/repository/examples/compose.yml .
cp /path/to/repository/examples/.env.example .env
cp /path/to/repository/oem/* ./oem/
chmod 600 .env
nano .env
```

Start Windows:

```bash
sudo docker compose up -d
```

Open the web console:

```text
http://127.0.0.1:8006
```

Complete Windows setup and install the required applications.
