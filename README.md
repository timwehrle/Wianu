<p align="center">
  <img src="Assets/WianuIcon.png" width="120" alt="Wianu app icon">
</p>

<div align="center">

![Wianu](Assets/wianu-light-mode.svg#gh-light-mode-only)
![Wianu](Assets/wianu-dark-mode.svg#gh-dark-mode-only)

</div>

<p align="center">
  All your streaming. One home.
</p>

<img src="Assets/showcase.png">

Wianu is a lightweight browser for organizing streaming websites, shows, and
movies in one place. Add the services you use, search across them, keep links
to shows you are watching, and maintain a watchlist without switching between
browser tabs.

## Features

- Add and organize streaming websites in a sidebar.
- Search supported sites from one search screen.
- Search for watchlist movies on any configured site from their context menu.
- Save show pages under **Continue Watching**.
- Add movies to a built-in watchlist.
- Import a watchlist exported from Letterboxd as CSV.
- Navigate backward and forward through the current browsing session.
- Open streaming sites directly inside the app.
- Open movie search results on Letterboxd for rating.

## Continue Watching

Wianu's Continue Watching list saves a link; it does not track playback
progress itself.

For the best cross-device experience, add a show from its **show or series
detail page**, not from an individual episode or video player. When you open
the saved item later, use the streaming service's own Continue or Resume
button. The service can then select the latest episode using the progress
synced to your account.

If you save an episode or player page, Wianu will reopen that exact episode.
Progress made on another device cannot change the saved link.

### Example

1. Open the detail page for _How I Met Your Mother_.
2. Select the Continue Watching button in Wianu's toolbar.
3. Watch on any device signed in to the same streaming account.
4. Open the show from Wianu and select the provider's Continue or Resume
   button.

> Wianu is not affiliated with streaming providers and cannot read their
> private viewing history. Playback synchronization is handled by each
> provider.

## Getting started

1. Launch Wianu.
2. Select **Add Site** in the sidebar.
3. Enter a name and the website URL.
4. Optionally enter a search URL containing `{query}`, for example
   `https://example.com/search?q={query}`.
5. Sign in to the streaming website and use it as you would in a browser.

Some known sites receive a suggested search URL automatically. For other
sites, you can add a compatible search URL yourself.

## Anonymous usage analytics

Wianu can send privacy-minimal feature events to a self-hosted Umami instance.
Users can turn analytics off from the General settings tab.

## Watchlist

Add a movie from its current page with the bookmark button, or select
**Add Movie** in the sidebar to enter it manually.

To import Letterboxd:

1. Export your data from Letterboxd.
2. Select **Import Letterboxd CSV…** under Watchlist.
3. Choose the exported watchlist CSV file.

The importer expects the standard Letterboxd columns, including `Name` and
`Letterboxd URI`.

## Requirements

- macOS 26 or later
- An account with each streaming service you want to use

Availability and playback depend on the streaming service, your subscription,
and your region. A provider may also restrict playback in embedded browsers.

## Feature requests

Feature requests are very welcome! I am always happy to hear your ideas for
Wianu. Please share them using the
[feature request issue template](.github/ISSUE_TEMPLATE/feature-request.md).

## Build from source

1. Clone this repository.
2. Open `Wianu.xcodeproj` in Xcode.
3. Select the Wianu scheme and build.

Swift Package Manager resolves the project's dependencies, including Sparkle
for application updates.

## Data

Saved sites, Continue Watching entries, and watchlist items are stored locally
on your Mac. Streaming-service sign-in and playback take place in the embedded
web view. Movie and TV metadata is retrieved through Wianu's backend service.

## License

Wianu is available under the terms in [LICENSE](LICENSE).
