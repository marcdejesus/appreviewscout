# Viewing Flutter logs and DevTools from WSL

## 1. See logs in the terminal (easiest)

When you run:

```bash
flutter run -d linux
```

all `debugPrint()` and `print()` output appears in **that same terminal**. No extra steps.

- Reproduce the glitch (e.g. Apply Filters → Clear Filters).
- Watch the terminal for lines like:
  - `[ReviewListView] _clearFilters pressed`
  - `[ReviewListVM] setFilters called: appId=null, platform=null, ...`
  - `[ReviewListVM] _loadReviews using filters: ...`
  - `[ReviewListVM] _loadReviews OK: 123 reviews` or `_loadReviews ERROR: ...`

For more verbose Flutter framework logs:

```bash
flutter run -d linux -v
```

## 2. DevTools in the browser (from WSL)

After `flutter run -d linux`, Flutter prints something like:

```
The Flutter DevTools debugger and profiler on Linux is available at:
http://127.0.0.1:44769/aDdiRx80m-E=/devtools/?uri=ws://127.0.0.1:44769/...
```

- **If your browser runs inside WSL** (e.g. in a WSL terminal or a Linux browser): open that URL in the same WSL environment; `127.0.0.1` is correct.
- **If your browser runs on Windows**: `127.0.0.1` in WSL is not the same as Windows localhost. Use one of the options below.

### Option A: Port forward from WSL to Windows (recommended)

1. In WSL, get the port from the DevTools URL (e.g. `44769`).
2. In **Windows PowerShell (Admin)** or **Windows Terminal (Admin)** run once per session:

   ```powershell
   netsh interface portproxy add v4tov4 listenport=44769 listenaddress=0.0.0.0 connectport=44769 connectaddress=$(wsl hostname -I | awk '{print $1}')
   ```

   Replace `44769` if your VM service uses a different port. If `wsl hostname -I` fails, use the WSL IP from WSL: `hostname -I | awk '{print $1}'` and put that IP in place of `$(wsl hostname -I ...)`.

3. Open in your **Windows** browser:

   ```
   http://localhost:44769/<path-from-flutter-output>/devtools/?uri=ws://localhost:44769/...
   ```

   Use the same path and query string Flutter printed, but change `127.0.0.1` to `localhost`.

4. To remove the proxy later (optional):

   ```powershell
   netsh interface portproxy delete v4tov4 listenport=44769 listenaddress=0.0.0.0
   ```

### Option B: Open DevTools from the command line

From your project directory in WSL:

```bash
flutter run -d linux
# Leave this running, then in another WSL terminal:
dart devtools
```

Then paste the VM service URL Flutter printed (the `http://127.0.0.1:xxxxx/...` line). DevTools may open in a WSL browser or give you a URL you can use with port forwarding as above.

### Option C: WSL 2 with “localhost” forwarding (Windows 11)

Some setups forward `localhost` from Windows to WSL. Try opening the exact URL Flutter printed in your Windows browser. If it loads, no port forwarding needed.

## 3. Disabling the debug logs later

The `[ReviewListVM]` and `[ReviewListView]` logs are wrapped in `assert(() { ... return true; }());` so they only run in debug mode. For release builds they are not executed. You can remove them or leave them for future debugging.
