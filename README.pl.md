# Antigravity CLI w Dockerze (Remote Access / OpenMediaVault)

Kontener Dockerowy umożliwiający uruchomienie oficjalnego agenta **Google Antigravity CLI (`agy`)** w trybie **Remote Access / Remote Control**.

Projekt stworzony z myślą o serwerach domowych i NAS, w tym **OpenMediaVault (OMV)**, **Unraid**, **TrueNAS**, **Synology** oraz zwykłych maszynach z systemem Linux i Docker Compose.

---

## 🌟 Główne zalety

- **Zdalny dostęp (Remote Control):** Twój serwer łączy się z chmurą Google bezpiecznym tunelem wychodzącym (reverse tunnel) – **brak potrzeby otwierania portów na routerze**, brak konieczności posiadania publicznego IP.
- **Sterowanie z dowolnego urządzenia:** Zarządzaj agentem przez oficjalny panel webowy na [antigravity.google.com](https://antigravity.google.com) lub aplikację mobilną PWA (iOS / Android).
- **Wbudowany Web Terminal (port 7681):** Możliwość przeprowadzenia wstępnej autoryzacji Google OAuth wprost z poziomu przeglądarki bez konieczności łączenia się przez SSH.
- **Obsługa PUID / PGID:** Pełna kompatybilność z uprawnieniami dysków NAS w OpenMediaVault – tworzone pliki mają właściwego właściciela (brak problemów z `root:root`).
- **Trwałość sesji:** Tokeny Google OAuth i ustawienia są zapisywane w wolumenie dyskowym (`config`), dzięki czemu restart kontenera nie wymaga ponownego logowania.
- **Pełne środowisko deweloperskie:** W kontenerze preinstalowane są m.in. `git`, `python3`, `nodejs`, `npm`, `build-essential`, `jq` oraz opcjonalny dostęp do `docker.sock`.

---

## 📁 Struktura plików

```text
Antigravity_cli_docker/
├── Dockerfile              # Definicja obrazu z Ubuntu 24.04 i agy CLI
├── docker-compose.yml      # Konfiguracja gotowa do uruchomienia (np. w OMV)
├── .env.example            # Przykładowy plik zmiennych środowiskowych
├── entrypoint.sh           # Skrypt startowy (PUID/PGID, ttyd, Remote Control)
├── bin/
│   ├── agy-login           # Pomocnik do logowania OAuth
│   └── agy-status          # Skrypt diagnostyczny stanu kontenera
├── config/                 # [Automatyczny montaż] Tokeny i konfiguracja (.gemini)
└── workspace/              # [Automatyczny montaż] Projekty i pliki robocze
```

---

## 🚀 Szybki start (Docker Compose)

### 1. Pobranie repozytorium
```bash
git clone https://github.com/ar2r27/Antigravity_cli_docker.git
cd Antigravity_cli_docker
```

### 2. Dostosowanie konfiguracji (opcjonalnie)
Skopiuj plik `.env.example` do `.env`:
```bash
cp .env.example .env
```
Sprawdź swój identyfikator użytkownika w systemie:
```bash
id $USER
# np. uid=1000(twoj_user) gid=100(users)
```
Jeśli Twoje wartości różnią się od domyślnych (`1000` / `100`), zaktualizuj `PUID` i `PGID` w pliku `.env` lub `docker-compose.yml`.

### 3. Zbudowanie i uruchomienie kontenera
```bash
docker compose up -d --build
```

---

## 🔑 Jednorazowa autoryzacja Google OAuth

Google Antigravity wymaga jednorazowego zalogowania się kontem Google. Kontener po pierwszym uruchomieniu oczekuje na zalogowanie.

Możesz to zrobić na **dwa bardzo proste sposoby**:

### Sposób A: Przez przeglądarkę (Najwygodniejszy)
1. Otwórz w przeglądarce adres wbudowanego Web Terminala:
   ```text
   http://<ADRES_IP_TWOJEGO_SERWERA>:7681
   ```
2. Zobaczysz konsolę kontenera. Wpisz polecenie:
   ```bash
   agy-login
   ```
   *(lub po prostu `agy`)*
3. Na ekranie pojawi się link logowania Google. Kliknij go lub skopiuj do nowej karty w przeglądarce.
4. Zaloguj się na swoje konto Google i zaakceptuj uprawnienia.
5. Skopiuj wygenerowany kod autoryzacji, wklej go do konsoli w przeglądarce i naciśnij `Enter`.
6. Po zalogowaniu kontener automatycznie wykryje sesję i uruchomi usługę **Remote Control**!

---

### Sposób B: Przez terminal SSH hosta
1. Połącz się ze swoim serwerem / NAS przez SSH i uruchom:
   ```bash
   docker compose exec -it antigravity agy-login
   ```
2. Otwórz wyświetlony link w przeglądarce, skopiuj kod autoryzacji i wklej go w terminalu.

> [!TIP]
> **Klucze i tokeny są bezpiecznie zapisywane w podmontowanym katalogu `./config` (`~/.gemini`).**  
> Kolejne uruchomienia i restarty kontenera łączą się automatycznie bez pytania o logowanie.

---

## 🌐 Połączenie przez Remote Access (antigravity.google.com)

Gdy kontener jest uruchomiony i zalogowany:

1. Otwórz w przeglądarce (na komputerze, smartfonie lub tablecie):
   👉 **[https://antigravity.google.com](https://antigravity.google.com)**
2. Zaloguj się **tym samym kontem Google**, którego użyłeś w kontenerze.
3. W menu po lewej stronie (lub u góry na telefonie) w przełączniku instancji (**Instance Switcher**) wybierz swój serwer (domyślnie: `OMV-Antigravity`).
4. Gotowe! Masz pełny dostęp do agenta pracującego na Twoim serwerze:
   - Możesz zlecać mu zadania programistyczne,
   - Edytować pliki w udostępnionym katalogu `/workspace`,
   - Podglądać diffy zmian i zatwierdzać komendy w czasie rzeczywistym.

---

## 🛠️ Instalacja w OpenMediaVault (OMV)

W systemie OpenMediaVault kontenery najwygodniej uruchamia się za pomocą oficjalnej wtyczki **`openmediavault-compose`**:

1. W panelu OMV przejdź do: **Services (Usługi)** ➔ **Compose** ➔ **Files (Pliki)**.
2. Kliknij przycisk **+** (Utwórz).
3. Podaj nazwę: np. `antigravity`.
4. W polu konfiguracji wklej zawartość pliku `docker-compose.yml`:
   ```yaml
   services:
     antigravity:
       build:
         context: /sciezka/do/Antigravity_cli_docker
         dockerfile: Dockerfile
       image: antigravity-cli:latest
       container_name: antigravity
       restart: unless-stopped
       environment:
         - PUID=1000
         - PGID=100
         - TZ=Europe/Warsaw
         - INSTANCE_NAME=OMV-Antigravity
         - AUTO_START_REMOTE=true
         - ENABLE_WEB_TERMINAL=true
         - WEB_TERMINAL_PORT=7681
       volumes:
         # Wskaż ścieżki do Twoich udziałów w OMV:
         - /srv/dev-disk-by-uuid-XXXX/appdata/antigravity/config:/home/antigravity/.gemini
         - /srv/dev-disk-by-uuid-XXXX/dane/projekty:/workspace
         # Opcjonalnie gniazdo Dockera:
         # - /var/run/docker.sock:/var/run/docker.sock
       ports:
         - "7681:7681"
       shm_size: "1gb"
   ```
5. Kliknij **Save (Zapisz)**, a następnie **Up (Uruchom)**.
6. Otwórz w przeglądarce `http://IP_OMV:7681`, wpisz `agy-login` i przeprowadź autoryzację.

---

## ⚙️ Zmienne środowiskowe

| Zmienna | Domyślnie | Opis |
| :--- | :--- | :--- |
| `PUID` | `1000` | ID użytkownika na hoście (w OMV sprawdź komendą `id <user>`) |
| `PGID` | `100` | ID grupy na hoście (w OMV grupa `users` ma standardowo GID `100`) |
| `TZ` | `Europe/Warsaw` | Strefa czasowa kontenera |
| `INSTANCE_NAME` | `OMV-Antigravity` | Nazwa maszyny widoczna w panelu Remote Control |
| `AUTO_START_REMOTE` | `true` | Czy kontener ma automatycznie utrzymywać usługę Remote Control |
| `ENABLE_WEB_TERMINAL`| `true` | Włącza lekki terminal webowy na wskazanym porcie HTTP |
| `WEB_TERMINAL_PORT` | `7681` | Port dla Web Terminala |
| `WEB_TERMINAL_USER` | *(puste)* | Opcjonalny login do Web Terminala |
| `WEB_TERMINAL_PASS` | *(puste)* | Opcjonalne hasło do Web Terminala |

---

## 🧰 Przydatne polecenia

```bash
# Sprawdzenie logów kontenera
docker compose logs -f antigravity

# Sprawdzenie statusu autoryzacji i procesów wewnątrz kontenera
docker compose exec -it antigravity agy-status

# Ręczne logowanie lub ponowna autoryzacja
docker compose exec -it antigravity agy-login

# Wejście do powłoki bash wewnątrz kontenera
docker compose exec -it antigravity bash

# Zatrzymanie kontenera
docker compose down

# Aktualizacja i przebudowa obrazu
docker compose build --no-cache && docker compose up -d
```
