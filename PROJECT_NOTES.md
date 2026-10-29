# Video Downloader — Project Notes

## What this is
A Flutter mobile app that downloads videos (YouTube, Facebook, Instagram, TikTok, X) to the
phone's gallery, backed by a NestJS server running `yt-dlp`.

## Repos / locations
- **Flutter app**: `C:\Users\oussa\yt_downloader` — package `com.oussama.yt_downloader`
- **Backend**: `C:\Users\oussa\yt-dlp-backend` — pushed to `github.com/oussamamth1/yt-dlp-backend`
- **Backend deployed at**: https://yt-dlp-backend-dx9i.onrender.com (Render free plan, Docker)

## Architecture
- Flutter: Riverpod (state) + Dio (HTTP) + Gal (save to gallery) + url_launcher + font_awesome_flutter
- Backend: NestJS, spawns `yt-dlp` (and `you-get` as a fallback engine) via child_process
- `GET /info?url=` → video metadata (title, thumbnail, formats)
- `POST /download` → `{ url, format?, engine? }` → streams the video file back

## Key decisions & why
- **yt-dlp over pytube/youtube-dl/you-get**: best-maintained, widest site support. `you-get` was
  added as an alt `engine` option but is unreliable on YouTube specifically — yt-dlp is the default.
- **Render free plan**: picked for $0 cost. Cold-starts after 15 min idle (30-60s wake time) —
  the app's Dio `connectTimeout` is set to 90s to survive this, with a "waking up the server"
  hint shown in the UI during `fetchingInfo`.
- **YouTube cookies (secret file)**: YouTube blocks Render's datacenter IP with "Sign in to
  confirm you're not a bot" on many videos. Fixed by uploading a `cookies.txt` (from a **throwaway**
  Google account only — never the user's real account) as a Render **Secret File** at
  `/etc/secrets/cookies.txt`. The backend copies it to a writable tmp path before each use, because
  yt-dlp rewrites the cookie jar after use and Render's secret mount is read-only.
- **m3u8/HLS format preference**: direct HTTPS adaptive streams are increasingly gated behind a
  PO token yt-dlp can't supply; the m3u8/HLS variant of the same formats isn't. Download format
  selector forces `protocol*=m3u8` first.
- **Client fallback**: tries yt-dlp's default client, then `android`, since which one YouTube
  accepts is unpredictable per-request on a datacenter IP. Kept to 2 attempts (not more) to avoid
  Render gateway timeouts (502) on requests that fail everywhere.

## Known, accepted limitation
Even with cookies, **some individual videos still get blocked** (stricter bot-check on
less-popular/newer videos; heavily-cached mega-popular videos like Rick Astley's "Never Gonna
Give You Up" almost always work). This is a one-off per-video thing on YouTube's end, not a bug.
User explicitly chose to **accept this** rather than add a PO-token provider service or a paid
residential proxy (both would meaningfully improve it further if ever revisited).

## UI
Redesigned with a quick-launch row (YouTube/Facebook/Instagram/TikTok/X icons that open the
app or its website via `url_launcher`, so the user can copy a link), a clipboard-paste button,
and card-based Material 3 styling.

## Dev machine gotchas hit this session (C: drive + this machine specifically)
- **C: drive repeatedly fills up** (as low as single-digit MB free) from Flutter/Gradle build
  artifacts. Safe recurring cleanup: delete `yt_downloader\build`, old screenshots, and
  `~/.gradle` (fully regenerable, was 15GB+).
- **Multiple Gradle daemons pile up** (seen 11 at once) from VS Code's Gradle extension
  (`com.github.badsyntax.gradle.GradleServer`) plus repeated `flutter run` attempts — eats RAM
  (machine only has 16GB). `cd android && ./gradlew --stop` only stops the daemon matching that
  specific project; others need killing individually or a full machine restart.
- **Never force-kill a Gradle daemon mid-transform** — it leaves a corrupted half-written
  `metadata.bin` in `.gradle/caches` that reproducibly breaks every subsequent build with
  "Could not read workspace metadata" until that cache dir is wiped again.
- If `flutter run` fails with `FileSystemException: ... not enough space`, it's the C: drive, not
  the backend/app logic — check `df -h /c` first before debugging anything else.

## Where things stood as of last session
Backend confirmed fully working end-to-end (fetch + download + save to gallery) for both YouTube
and Facebook. The last `flutter run` attempt to rebuild the app after a UI tweak was blocked by
the machine running low on RAM (daemon pileup) — needs either a manual cleanup of stray Gradle
daemons or a machine restart before retrying `flutter run -d <device-id>`.
