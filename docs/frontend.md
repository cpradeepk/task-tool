# Frontend Notes

- Target paths: app is served under /task/
- Configure base href for Flutter web: use `--base-href=/task/` during build or set `web/index.html` base tag accordingly after `flutter create`.
- Nginx serves Flutter web from /var/www/task/frontend/web/ with HTML fallback to /task/index.html.

