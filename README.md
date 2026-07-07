# KDE Connect nightly dla Homebrew na Intel Macu

Wniosek z walidacji z 2026-07-07: mechanika lokalnego caska ma sens. Aktualny Intel nightly build `6325` z katalogu KDE został pobrany, sprawdzony po SHA-256, zamontowany przez `hdiutil`, a binarka `kdeconnect-cli` została potwierdzona jako `x86_64`.

Ten katalog zawiera bezpieczny updater: najpierw regexem wykrywa najnowszy build z listingu KDE i porównuje go z wersją w lokalnym casku. Jeśli build nie jest nowszy, kończy pracę bez pobierania DMG. Jeśli jest nowszy, pobiera artifact i aktualizuje cask dopiero po sprawdzeniu SHA-256, montowalności obrazu oraz architektury binarki.

## Proponowany przepływ z GitHuba

Tap może być utrzymywany w repozytorium GitHub `adriank1410/homebrew-kde-nightly`. Workflow `.github/workflows/update-kde-connect.yml` uruchamia się codziennie oraz ręcznie. Robi to samo, co lokalny updater:

- regexem odczytuje najnowszy Intel build z katalogu KDE,
- porównuje go z wersją w `Casks/kde-connect.rb`,
- jeśli build jest nowszy, pobiera DMG, liczy SHA-256, montuje obraz, sprawdza `x86_64`,
- aktualizuje cask, uruchamia `brew style`, `brew audit` i `brew livecheck`,
- commitnie zmianę tylko wtedy, gdy cask faktycznie się zmienił.

Lokalnie zostaje normalny przepływ Brew:

```bash
brew tap adriank1410/kde-nightly
brew update
brew upgrade --cask adriank1410/kde-nightly/kde-connect
```

Jeśli zainstalowany build jest przypięty, trzeba go raz odpiąć przed aktualizacją:

```bash
brew unpin kde-connect
brew upgrade --cask adriank1410/kde-nightly/kde-connect
brew pin kde-connect
```

Jeśli Homebrew poprosi o zaufanie dla lokalnego caska:

```bash
brew trust --cask adriank1410/kde-nightly/kde-connect
```

Na tej maszynie trust dla `adriank1410/kde-nightly/kde-connect` został już ustawiony.

## Lokalny fallback

Ten sam updater nadal można uruchomić ręcznie, np. do debugowania:

```bash
/Users/adriank1410/Documents/Codex/2026-07-07/new-chat/outputs/kde-connect-homebrew-nightly/update-kde-connect-cask.zsh \
  "$(brew --repository adriank1410/kde-nightly)"
```

## Dlaczego nie sam `livecheck`

`brew livecheck` potrafi wykryć nowy numer builda z listingu KDE, ale samo `brew upgrade` nie aktualizuje pliku caska na podstawie `livecheck`. Cask ma statyczne `version`, `url` i `sha256`; trzeba go najpierw zbumpować w lokalnym tapie. Ten skrypt robi bump tylko wtedy, gdy regex z katalogu KDE pokaże build nowszy niż wpisany w lokalnym casku.

Minimalna wersja macOS w casku to `:ventura`, bo audyt Homebrew odczytał takie minimum z rozpakowanego artifactu. Cask ogranicza też architekturę do `x86_64`, co zostało zweryfikowane lokalnie.
