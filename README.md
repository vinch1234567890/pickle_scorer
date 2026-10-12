Pickle Scorer App

A Flutter web scoreboard for pickleball singles and doubles. Track rally winners, side-outs, serving order, and the called score. Games default to 11 points and can be set to 7, 15, or 21; all games must be won by two.

## Match features

- Active games, undo history, preferences, and completed-match results are saved locally on the device; there is no account or cloud sync.
- Set up team and doubles player names, play a best-of-three match, or optionally win by one.
- Review the current match's rally log, completed matches, and local win totals from Match center.
- Get a change-ends reminder at the halfway score, then switch the court display when players have changed sides.
- Turn on rally sound or haptic feedback, enlarge the rally buttons, or use the landscape scoreboard layout in Match & court settings.

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
