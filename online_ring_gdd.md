# Game Design Document — Online Ring
> Wersja 0.1 — dokument roboczy

---

## 1. Concept

**Online Ring** to przeglądarkowa gra RPG o mechanice inspirowanej Elden Ring, której celem jest gamifikacja tworzenia treści online. Gracz wciela się w twórcę treści, który walczy z reprezentacjami realnych problemów twórczych (prokrastynacja, hejterzy, wypalenie, perfekcjonizm). Każda akcja w grze odpowiada realnej akcji twórczej wykonywanej przez gracza.

**Core loop:**
1. Gracz wchodzi do lokacji
2. Walczy z wrogiem wykonując realne zadania twórcze
3. Lootuje nagrody (in-game i realne)
4. Odblokowuje nowe obszary mapy przez milestone bossy
5. Rozwija postać i ekwipunek

---

## 2. Staty postaci

Każda postać ma 6 statystyk wzorowanych na Elden Ring. Punkty statów wydawane są za runy (waluta doświadczenia).

| Stat | Nazwa | Opis |
|------|-------|------|
| STR | Strength | Głębokość i waga treści. Skaluje z bronią ciężką (długie formaty). |
| DEX | Dexterity | Szybkość i rytm publikacji. Skaluje z bronią szybką. |
| INT | Intelligence | Budowanie systemów i modeli myślowych. Skaluje z magią. |
| FAI | Faith | Zaufanie community + ideologia. Skaluje z inkantacjami i bronią FAI. |
| ARC | Arcane | Viralowość, emocje, efekty statusowe. Skaluje z bleed/madness bronią. |
| VIG | Vigor | Meta-stat: odporność na burnout i długowieczność twórcza. Skaluje HP. |

### Softcapy
- STR: powyżej ~3 publikacji miesięcznie jakość spada
- DEX: powyżej ~7 publikacji tygodniowo jakość spada dramatycznie
- FAI: optimum ~80% community-driven, ~20% własna perspektywa
- ARC: wymaga minimum 40 STR lub 40 DEX jako bazy
- VIG: każdy build ma minimalny próg VIG (STR: 30, DEX: 40, ARC: 35)

---

## 3. Buildy

Gracz może specjalizować się w jednym stacie lub budować hybrydy. Przykładowe archetypy:

- **STR build** — "The Authority Builder": rzadko ale monumentalnie, długie formaty, głęboka analiza
- **DEX build** — "The Consistent Creator": wysoka kadencja, krótkie formaty, newslettery, wątki
- **INT build** — "The Framework Mage": frameworki, modele myślowe, analizy, raporty
- **FAI build** — "The Community Catalyst": community building (broń) + ideologia (inkantacje)
- **ARC build** — "The Discovery Engine": viral content, efekty statusowe, niszowe odkrycia
- **VIG hybrid** — "The Resilient": meta-build dla długowieczności, nie styl tworzenia

---

## 4. Broń i movesety

### Koncepcja
Każda broń ma **moveset** — zestaw akcji które gracz może wykonać w walce. Każda akcja w movesecie odpowiada **realnej akcji twórczej** którą gracz musi wykonać poza grą.

### Struktura movesetu broni
| Akcja | Opis mechaniczny | Koszt |
|-------|-----------------|-------|
| R1 — Light Attack | Szybka, lekka akcja twórcza (~10-20 min) | Mała stamina |
| R2 — Heavy Attack | Głębsza akcja twórcza (~45-60 min) | Duża stamina |
| Jump Attack | Akcja wymagająca "skoku" myślowego | Średnia stamina |
| Guard Counter | Odpowiedź na poprzedni atak wroga | Średnia stamina |
| Ash of War | Rzadkie, meta-poziomowe zagranie | Duży FP koszt |

### Przykładowe bronie
**Greatsword** (STR) — "The Methodical Builder"
- R1: Mindmap w 10 minut
- R2: Napisz sekcję argumentacyjną (300+ słów, bez przerwy)
- Jump R2: Głębokie badanie jednego źródła pierwotnego
- Guard Counter: Przepisz najsłabszy fragment draftu
- AoW *Sword of Night and Promise*: Napisz esencję tematu od zera w 15 minut

**Dagger** (DEX) — "The Opportunist"
- R1: Napisz 3 zdania otwierające (tylko hook)
- R2: Nagraj 2-minutowy voice memo
- Backstab: Ukradnij strukturę istniejącego posta, wypełnij własnym materiałem
- Jump: Sprzeczna teza w 1 zdaniu
- AoW *Quickstep Repurpose*: Opublikuj stary materiał w nowym formacie

**Colossal Weapon** (STR) — "The Stonecutter"
- R1: Napisz konspekt 2000+ słów
- R2: Napisz całą sekcję w jednym 45-minutowym bloku
- Charged R2: Full redakcja na głos
- Stomp: Przeprowadź jeden wywiad lub ankietę
- AoW *Gravitas Slam*: Napisz podsumowanie które mogłoby zastąpić cały artykuł

**Spear** (DEX/STR) — "The Distributor"
- R1: Napisz core asset (cytowalny fragment)
- R2: Zaadaptuj do innego formatu
- Running R1: Przebuduj framing dla innej grupy docelowej
- Crouch Attack: Skróć core asset do 100 słów
- AoW *Golden Vow*: Zaplanuj jeden temat na 5 formatów i 3 kanały

**Sacred Seal** (FAI) — catalyst dla inkantacji i broni FAI
- R1: Opublikuj niedokończoną myśl i zapytaj odbiorców
- R2: Odpowiedz głęboko na 5 komentarzy
- Seal Boost: Zbierz 10 perspektyw zewnętrznych
- Combo: Kolaboruj z innym twórcą
- AoW *Erdtree Heal*: Znajdź pytanie które pojawia się 3+ razy w komentarzach — to następny artykuł

### Bronie a staty
Każda broń ma wymagania statystyczne (np. Greatsword wymaga STR 20) i skalowanie (np. A w STR, D w DEX).

### Generowanie movesetów przez AI
Movesety będą generowane przez AI na podstawie typu broni i stylu tworzenia treści. Gracz podczas gry może otrzymać nową broń z unikalnym movesetem wygenerowanym dynamicznie.

---

## 5. FAI build — szczegóły

FAI skaluje dwa różne kanały:
- **Broń FAI** — community building: codzienne, fizyczne działania relacyjne (odpowiadanie, kolaboracje, budowanie zaufania)
- **Inkantacje FAI** — ideologia: rzadkie, kosztowne (FP) uderzenia ideologiczne (manifesty, kontrowersyjne tezy, "kazania")

**Sacred Seal jako catalyst:** poziom Seala (= poziom zaufania community) wzmacnia zarówno broń jak i inkantacje. FAI build bez zbudowanej bazy community jest słaby w obu kanałach.

**Wróg wewnętrzny FAI:** kryzys wiary. Gdy gracz przestaje wierzyć w to co głosi, inkantacje tracą moc — mechanika unikalna dla tego buildu.

---

## 6. ARC build — efekty statusowe

ARC skaluje z bronią zadającą efekty statusowe. Każdy efekt odpowiada typowi treści:

| Efekt | Typ treści | Mechanika |
|-------|-----------|-----------|
| Bleed | Treści emocjonalne | Kumulują się powoli, potem viral spike |
| Madness | Kontrowersja/prowokacja | Zadaje obrażenia też graczowi (reputacja) |
| Scarlet Rot | Clickbait | Działa krótkoterminowo, niszczy domain authority długoterminowo |
| Frost | Cold takes, kontrariaństwo | Spowalnia najpierw, potem pęka z dużym dmg |

**Kluczowa mechanika ARC:** Madness buildup dotyczy też postaci gracza. Zbyt częste używanie kontrowersji = ryzyko własnej "śmierci reputacyjnej."

---

## 7. Wrogowie

### Koncepcja
Wrogowie to reprezentacje realnych problemów twórczych. Każdy wróg ma:
- Skonfigurowany moveset (ataki)
- Punkty HP
- Staminę i poise bar
- Określony poziom inicjatywy

### Typy wrogów
- **Moby** — pospolite problemy (drobna prokrastynacja, rozproszenie)
- **Bossowie** — poważne blokady twórcze, walka na jedną sesję
- **Remembrance Bosses** — strażnicy milestone'ów, odblokowują nowe obszary mapy

### Przykładowy wróg: Hater
Reprezentacja publicznej krytyki online.

**Przykładowy moveset ataku:** "Publiczna krytyka podejścia prezentowanego przez gracza"

Gracz może odpowiedzieć:
- **Roll:** Dodanie do własnych treści sekcji odpierającej najbardziej prawdopodobny atak tego typu wroga (wymaga znajomości movesetu)
- **Tarcza:** Generyczna akcja wzmacniająca motywację gracza (np. zebranie pozytywnych reakcji, rozmowa ze wspierającą osobą) — nie jest bezpośrednio związana z atakiem
- **Parowanie:** Opublikowanie treści które wykorzystują tę krytykę jako materiał (np. "Dlaczego ludzie kwestionują X") — trudne bo wymaga publikacji online, ale zadaje największe obrażenia

### Inne przykładowe archetypy wrogów
- **Perfectionism Knight** — blokuje publikację nieskończonym dopracowywaniem
- **Procrastination Lich** — nieskończone badania przed napisaniem słowa
- **Burnout Golem** — pojawia się po długim DEX runie bez regeneracji
- **Blank Page Omen** — paraliż pierwszego zdania
- **Trend Chaser** — wymusza pisanie pod aktualność
- **Algorithm Rider** — wymusza grę pod zasięgi kosztem jakości

---

## 8. System walki

### Kolejność tur
1. Obliczenie inicjatywy (gracz vs wróg)
2. Wyższa inicjatywa wykonuje ruch pierwszy

### Tura gracza
- Gracz wybiera akcję z dostępnego movesetu broni (timer: **30 sekund**)
- Brak decyzji = brak ataku
- Każda akcja zużywa staminę
- Gracz może **pominąć** dalsze ataki by zachować staminę na obronę
- Gracz kontynuuje ataki aż do wyczerpania staminy lub przełamania przez wroga (poise mechanic)

### Tura wroga
- Wróg wykonuje atak ze swojego movesetu
- Moveset wroga jest **znany graczowi z góry**
- Gracz wybiera odpowiedź (timer: **30 sekund**):
  1. **Roll/Unik** — wymaga timingu, zależy od konkretnego ataku wroga
  2. **Blokada tarczą** — łatwiejsza, zużywa staminę, generyczna
  3. **Parowanie** — najtrudniejsze, zależy od wroga i itemu, otwiera riposte
  4. **Przyjęcie obrażeń** — obniża HP
  5. **Ucieczka** — możliwa tylko od mobów

### Stamina
- Współdzielona między atakiem i obroną
- Brak staminy = brak możliwości blokowania (guard break)
- Regeneruje się między turami (niezdefiniowana szybkość)

### Poise
- Wróg ma poise bar deplecowany przez ataki gracza
- Po wyczerpaniu: wróg jest staggerowany, traci turę/staminę
- Wróg też ma staminę i potrzebuje odpoczynku

### HP i śmierć
- HP gracza spada przy przyjętych obrażeniach
- HP = 0: śmierć, respawn przy ostatnim Site of Grace, utrata run
- Runy leżą w miejscu śmierci do odzyskania

### Sesja bossów
- Walka z bossem odbywa się na **jednym posiedzeniu**
- Brak możliwości zapisu w trakcie walki z bossem
- Cel: skłonienie gracza do dłuższych sesji pracy

---

## 9. Ekwipunek i loot

### Źródła looту
- Pokonani wrogowie (drop rate zależny od typu)
- Skrzynie w lokacjach
- Kupiec (rotating inventory, zmienia się daily)

### Typy itemów
- **Bronie** — nowe movesety akcji twórczych, wymagania statowe
- **Inkantacje** (FAI/INT) — specjalne akcje twórcze
- **Zbroja** — modyfikuje obronę i poise
- **Pierścienie/Talizmany** — pasywne bonusy do statów lub mechanik
- **Składniki** — opcjonalnie, do craftowania consumables (TBD)

---

## 10. Mapa świata

### Struktura
- Nieliniowa mapa z punktami połączonymi ścieżkami
- Część punktów to **Site of Grace** (respawn, fast travel, level up)
- Część punktów prowadzi do **osobnych lokacji** (np. katakumby z bossem na końcu)
- Nowe obszary odblokowane przez pokonanie **Remembrance Bossów**

### Remembrance Bossy jako strażnicy
- Każdy Remembrance Boss wymaga od gracza wykonania konkretnych działań z efektem w świecie realnym
- Dopiero po ich wykonaniu walka z bossem jest możliwa
- Pokonanie = odblokowanie nowego fragmentu mapy

### Tryb gry
**Single-player.** Gra zaprojektowana dla jednego gracza. Brak elementów multiplayer, leaderboardów ani widoczności postępów innych graczy.

### Inspiracja narracyjna
- Gra jest luźno oparta na strukturze Elden Ring (Margit, Godrick, itd.)
- Gracz znający ER zna orientacyjną drogę przez świat
- Fabuła jest klarowna ale nie dominująca

---

## 11. Progresja postaci

- Analogiczna do Elden Ring
- Runy zdobywane z pokonanych wrogów
- Runy wydawane przy Site of Grace na podnoszenie statów
- Utrata run przy śmierci, możliwość odzyskania

---

## 12. Mechaniki retencji

### Główny mechanizm: efekt Zeigarnik (jak Elden Ring)
Gra nigdy nie daje "czystego done" momentu. Gracz zawsze wychodzi z sesji z czymś niedokończonym lub odkrytym:
- Walka z bossem na jednym posiedzeniu = gracz często kończy sesję w trakcie
- Mapa zawsze pokazuje nieodwiedzone lokacje w zasięgu wzroku
- Gracz wychodzi z sesji z listą "chcę sprawdzić" dłuższą niż "sprawdziłem"
- Loot FOMO — zawsze możliwość że z następnego wroga wypadnie coś potężnego

Brak explicit daily rewards, powiadomień ani streak pressure jako głównego mechanizmu. Motywacja pochodzi z wewnętrznej ciekawości, nie zewnętrznego przymusu.

### Opcjonalne mechaniki boosterowe (do implementacji później)
- **Combo bonus** — boost za kilka walk z rzędu w jednej sesji (TBD)
- **Streak reward** — bonus za codzienną pracę (TBD, nie jako główny hook)

### External rewards
Gracz sam sobie przyznaje realne nagrody po zebraniu odpowiednich puzzli in-game. Honor system — gra jest implementowana dla jednego gracza. Mechanika jest świadomie zaprojektowana jako self-reward loop.

---

## 13. Stack technologiczny

### Silnik
**Godot 4 + GDScript.** Desktop-first. Interfejs oparty na mapce z punktami i panelach tekstowo-UI, z grafiką 2D i dźwiękiem.

### Platforma docelowa
- **Primary:** MacOS (development) + Windows (secondary)
- **Potencjalny port:** Android / iOS (możliwy z Godot bez przepisywania logiki, wymaga osobnego layoutu UI)
- **Steam:** możliwy przez GodotSteam plugin (odłożone na później)

### Eksport
- Windows `.exe` generowany bezpośrednio z MacOS przez Godot export templates — **Godot nie musi być zainstalowany na Windows**
- iOS eksport wymaga MacOS + Xcode (już spełnione)
- Android eksport przez przycisk w edytorze Godot

### Assety
- **Grafika:** Kenney.nl (CC0) jako baza — bronie, zbroje, postacie, UI, mapy
- **Dźwięki:** Kenney.nl + freesound.org
- **Dodatkowe paczki RPG:** itch.io (darmowe, weryfikować licencje)
- **Referencja kodu:** GDQuest open-source turn-based RPG demo (Godot 4, MIT)

### Tryb okna
- Gra działa w trybie **windowed** (nie fullscreen) — konieczność przełączania między grą a innymi programami (pisanie, nagrywanie)
- Domyślny rozmiar okna: **1200×800**, minimum: **800×600**
- Okno **resizable** — gracz może dowolnie zmieniać rozmiar
- Opcja **"Always on top"** w ustawieniach gry (`DisplayServer.WINDOW_FLAG_ALWAYS_ON_TOP`) — gra jako overlay podczas pracy
- Przełącznik fullscreen/windowed dostępny z poziomu gry (opcjonalnie)
- **Wymaganie UI:** cały interfejs projektowany responsywnie od początku przez Godot anchor/container system — bez stałych pozycji pikselowych. Zapobiega problemowi czarnych pasów przy resizowaniu (Godot 4.4+ zmienił domyślne zachowanie viewport przy resize)

### Backend / synchronizacja danych
- **API:** FastAPI (Python) na Railway
- **Baza danych:** PostgreSQL na Railway
- **Sync mechanika:** Godot wysyła JSON z pełnym stanem gry przez `HTTPRequest` node po każdej sesji; pobiera przy starcie
- **Endpointy minimum:** `POST /save` i `GET /save/{player_id}`
- **Offline:** gra działa lokalnie, sync przy następnym połączeniu

---

## 14. Otwarte pytania (do zdefiniowania przed implementacją)

### Zamknięte
- ~~Weryfikacja realnych akcji~~ → **Honor system.** Gracz sam potwierdza wykonanie zadania (checkbox + opcjonalny opis).
- ~~Platforma~~ → **Desktop-first**, przeglądarka.
- ~~Multiplayer~~ → **Czysty single-player.**
- ~~External rewards~~ → **Self-reward loop.** Gracz sam sobie przyznaje nagrody.
- ~~Główny mechanizm retencji~~ → **Efekt Zeigarnik** wzorowany na Elden Ring, nie streak/daily pressure.

### Otwarte
1. **Minimalna sesja** — co liczy się jako "grałem dzisiaj" jeśli zostanie zaimplementowany streak bonus?
2. **Timer walki** — 30 sekund na decyzję: czy dotyczy też wyboru obrony czy tylko ataku?
3. **Stamina regeneracja** — jak szybko regeneruje się stamina między turami?
4. **Poise computation** — ile ataków deplecuje poise bar wroga? Czy wróg ma widoczny poise bar?
5. **Moveset wroga — prezentacja** — czy gracz widzi pełny moveset wroga przed walką, czy tylko podczas walki?
6. **Fazy bossów** — czy bossy mają fazy (zmiana movesetu po określonym % HP)?
7. **Consumables** — czy implementować system craftowania?
8. **Remembrance Boss requirements** — jakie konkretnie realne działania są wymagane od każdego bossa?
9. **Inicjatywa** — jak jest obliczana? Stały stat, losowy roll, czy zależy od ekwipunku?
10. **Guard break** — co się dzieje mechanicznie gdy gracz ma 0 staminy i wróg atakuje?
11. **Combo/streak mechanika** — szczegóły boostów za kilka walk z rzędu lub codzienną pracę (odłożone na później)
