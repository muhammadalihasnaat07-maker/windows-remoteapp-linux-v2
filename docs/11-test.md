# 11. Test the setup

Start with Notepad:

```bash
"$HOME/.local/bin/winapp-launcher" 'notepad.exe'
```

Then test Office:

```bash
"$HOME/.local/bin/winapp-launcher" 'C:\Program Files\Microsoft Office\root\Office16\WINWORD.EXE'
```

After closing the final application, wait several seconds and verify:

```bash
sudo docker ps -a --filter name=WinApps --format 'table {{.Names}}\t{{.Status}}'
```

Expected status: `Exited`.
