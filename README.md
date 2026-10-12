Pickle Scorer App

A Flutter web scoreboard for pickleball singles and doubles. Track rally winners, side-outs, serving order, and the called score. Games default to 11 points and can be set to 7, 15, or 21; all games must be won by two.

## Run locally

```powershell
flutter pub get
flutter run -d chrome
```

## Test and build

```powershell
flutter test
flutter build web --release
```

The static web output is written to `build/web`.

## GitHub Pages

The workflow in `.github/workflows/deploy-pages.yml` tests and builds the site on pushes to `main` or `master`, then deploys it to GitHub Pages. In the repository settings, set **Pages > Build and deployment > Source** to **GitHub Actions**.
