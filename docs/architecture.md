# Aurex Architecture

## API capabilities verified on March 9, 2026

The live Elite JioSaavn API currently exposes:

- `/api/home`
- `/api/trending` and entity-specific trending endpoints
- `/api/search` and grouped search endpoints
- `/api/songs/{id}`
- `/api/albums`
- `/api/playlists`
- `/api/artists/{id}`
- `/api/lyrics/{id}`
- `/api/lyrics/{id}/sync`

The API returns:

- multi-quality audio URLs
- album / playlist / artist detail data
- plain lyrics
- timed lyrics for some tracks

## Application structure

`lib/app`

- app bootstrap
- routing
- top-level shell

`lib/core`

- environment config
- logging
- networking
- local persistence bootstrap
- shared theme/tokens/widgets

`lib/features`

- `auth`
- `home`
- `search`
- `music`
- `player`
- `library`
- `rooms`
- `profile`
- `settings`
- `about`

## Core decisions

- Riverpod keeps dependencies explicit and testable without over-abstracting.
- GoRouter gives a scalable navigation tree for nested shells and detail screens.
- Dio handles both API transport and file downloads cleanly.
- Sembast is lightweight, cross-platform, and pragmatic for a solo-maintained app.
- Just Audio plus Just Audio Background covers premium-player requirements with less operational complexity than a custom audio service stack.
- Supabase remains optional at bootstrap time so browse/player flows can still load locally before auth is configured.

## Room design

The room system is modeled around:

- a room row with a shareable code and host ownership
- membership rows with join state and role
- playback state rows with sequence number, song id, queue snapshot, play/pause flag, and timestamp
- message rows for room chat

Listeners subscribe to playback state updates and resync when drift exceeds a threshold.
