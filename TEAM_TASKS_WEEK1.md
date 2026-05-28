# Memora — Week 1 Team Task Assignment

> **Product:** Memora — a context-aware personal knowledge assistant  
> **Sprint goal:** By end of Week 1 the core save-and-retrieve loop must work end to end.
> The Chrome extension saves a highlight → the backend stores it → the web app displays it in the Topics view.  
> **Repository layout:**
> ```
> /
> ├── memora-backend/     ← Spring Boot (Person 1)
> ├── memora-frontend/    ← React web app (Person 2)
> └── memora-extension/   ← Chrome extension (Person 3)
> ```

---

## ⚠️ Critical Git Rule — Read Before Writing a Single Line of Code

**No one pushes directly to `main`. Ever.**

Every piece of work — no matter how small — lives on its own feature branch and enters `main` only through a reviewed pull request. Branch protection on `main` is enforced. Violations block the whole team.

| Rule | Detail |
|---|---|
| Branch naming | `feat/<short-description>` e.g. `feat/content-save-api`, `feat/topics-sidebar`, `feat/highlight-capture` |
| Commits to `main` | **Forbidden.** GitHub branch protection must be enabled. |
| Merging | Only via Pull Request. At least one reviewer must approve. |
| Secrets | Never committed. Always in `.env` files that are `.gitignore`d. |
| Shared API base URL | `http://localhost:8080/api/v1` — stored in env config, never hardcoded. |

---

## Person 1 — Backend Developer (Spring Boot)

**Branch:** `feat/content-save-api`  
**Working directory:** `memora-backend/`  
**Week 1 goal:** Get the core save-and-retrieve loop working end to end with no auth yet. Hardcode a fixed test user ID for now — auth comes in a later week.

The Spring Boot project skeleton already exists in `memora-backend/`. The `pom.xml`, `docker-compose.yml`, Flyway migration files `V1__initial_schema.sql` and `V2__add_missing_tables.sql`, and all empty Java class and interface files are already in place. Do not modify the migration files. Do not create new entities or packages this week. Fill in what is already scaffolded.

---

### Task 1 — Fill in all JPA entity classes

Fill in every file under `src/main/java/com/memora/entity/`. Each entity must match the Flyway schema exactly — table names, column names, column types, nullable constraints, and default values must all align with what the migrations create.

**Rules that apply to every entity:**
- Annotate with `@Entity` and `@Table(name = "...")` matching the migration table name exactly.
- Use `UUID` as the primary key type with `@GeneratedValue` using `GenerationType.AUTO` backed by the `uuid-ossp` PostgreSQL extension.
- Annotate all columns with `@Column` specifying `nullable`, `length` where relevant, and `columnDefinition` for `TIMESTAMPTZ`, `JSONB`, and `TEXT` columns.
- Use `@CreationTimestamp` and `@UpdateTimestamp` from Hibernate for `created_at` and `updated_at` fields.
- All `@OneToMany` relationships must specify `cascade = CascadeType.ALL` and `orphanRemoval = true` where the child cannot exist without the parent.
- All `@ManyToOne` relationships must use `@JoinColumn` with the exact foreign key column name from the migration.
- Use Lombok `@Getter`, `@Setter`, `@NoArgsConstructor`, and `@Builder` on every entity.

**Sensitive fields — Jasypt encryption:**  
The following fields must be annotated with `@EncryptedField` (from the Jasypt Spring Boot Starter). These fields store ciphertext in the database and are transparently decrypted by Jasypt when read:

| Entity | Fields to encrypt |
|---|---|
| `User` | `email` |
| `ContentItem` | `rawContent`, `sourceUrl` |
| `Highlight` | `selectedText`, `surroundingContext`, `pageUrl` |
| `ResurfacingEvent` | `triggerContext` |
| `CompiledDocument` | `compiledText` |

**Entity-by-entity checklist:**

1. **`User`** — maps to `users`. Fields: `id`, `email` (encrypted), `displayName`, `passwordHash`, `createdAt`, `updatedAt`. One-to-many to `ContentItem`, `Topic`, `StudySession`, `ExamProfile`, `Highlight`, `ResurfacingEvent`, `CompiledDocument`.

2. **`ContentItem`** — maps to `content_items`. Fields: `id`, `userId` (FK), `contentType` (enum: `TEXT`, `IMAGE`, `PDF`, `NOTE`, `SCREENSHOT`, `DIAGRAM`), `rawContent` (encrypted), `sourceUrl` (encrypted), `sourceTitle`, `minioObjectKey`, `topicId` (FK nullable), `embeddingId`, `autoDetectedTopic`, `createdAt`, `updatedAt`. Many-to-one to `User`. Many-to-one to `Topic` (nullable). One-to-many to `Highlight`.

3. **`Topic`** — maps to `topics`. Fields: `id`, `userId` (FK), `name`, `description`, `autoDetected`, `createdAt`, `updatedAt`. Many-to-one to `User`. One-to-many to `ContentItem`.

4. **`TopicCluster`** — maps to `topic_clusters` with a join table `topic_cluster_topics`. Fields: `id`, `userId` (FK), `name`, `description`, `createdAt`. Many-to-many to `Topic` via `@JoinTable(name = "topic_cluster_topics")`.

5. **`StudySession`** — maps to `study_sessions`. Fields: `id`, `userId` (FK), `topicId` (FK nullable), `startedAt`, `endedAt` (nullable), `activeUrl`, `sessionMetadata` (`JSONB` → store as `String` with `columnDefinition = "jsonb"`). Many-to-many to `ContentItem` via `study_session_content_items`.

6. **`ExamProfile`** — maps to `exam_profiles`. Fields: `id`, `userId` (FK), `examName`, `syllabusText`, `examDate`, `createdAt`, `updatedAt`. One-to-many to `ExamTopicCoverage`.

7. **`ExamTopicCoverage`** — maps to `exam_topic_coverage`. Fields: `id`, `examProfileId` (FK), `userId` (FK), `topicName`, `coverageStatus` (enum: `NOT_STARTED`, `IN_PROGRESS`, `COVERED`), `contentCount`, `createdAt`, `updatedAt`. Many-to-one to `ExamProfile`.

8. **`Highlight`** — maps to `highlights`. Fields: `id`, `contentItemId` (FK), `userId` (FK), `selectedText` (encrypted), `surroundingContext` (encrypted), `pageUrl` (encrypted), `pageTitle`, `highlightColor` (default `yellow`), `positionData` (`JSONB`), `createdAt`. Many-to-one to `ContentItem`. Many-to-one to `User`.

9. **`ResurfacingEvent`** — maps to `resurfacing_events`. Fields: `id`, `userId` (FK), `contentItemId` (FK), `triggerContext` (encrypted), `similarityScore` (`BigDecimal`), `wasAccepted`, `wasDismissed`, `createdAt`. Many-to-one to `User`. Many-to-one to `ContentItem`.

10. **`CompiledDocument`** — maps to `compiled_documents`. Fields: `id`, `userId` (FK), `title`, `compiledText` (encrypted), `sourceContentIds` (`JSONB`), `pdfMinioKey`, `createdAt`. Many-to-one to `User`.

---

### Task 2 — Fill in all repository interfaces

Each repository interface must extend `JpaRepository<Entity, UUID>`. Add only the custom query methods listed below — do not add methods that Spring Data JPA can derive automatically without a query.

**`ContentItemRepository`**
```java
Page<ContentItem> findAllByUserId(UUID userId, Pageable pageable);
Optional<ContentItem> findByUserIdAndChecksum(UUID userId, String checksum);
List<ContentItem> findBySessionId(UUID sessionId);
```

> Note: `findBySessionId` requires a `@Query` using a join through `study_session_content_items` since the relationship is many-to-many. Write a proper JPQL join query.

**`TopicRepository`**
```java
List<Topic> findAllByUserId(UUID userId);
Optional<Topic> findByUserIdAndName(UUID userId, String name);
```

**`StudySessionRepository`**
```java
List<StudySession> findAllByUserIdOrderByStartedAtDesc(UUID userId);
Optional<StudySession> findByUserIdAndEndedAtIsNull(UUID userId);
```

**`HighlightRepository`**
```java
List<Highlight> findAllByUserId(UUID userId);
List<Highlight> findAllByContentItemId(UUID contentItemId);
```

**`UserRepository`**
```java
Optional<User> findByEmail(String email);
boolean existsByEmail(String email);
```

**`ExamProfileRepository`**
```java
List<ExamProfile> findAllByUserId(UUID userId);
Optional<ExamProfile> findByIdAndUserId(UUID id, UUID userId);
```

**`ResurfacingEventRepository`**
```java
List<ResurfacingEvent> findAllByUserId(UUID userId);
List<ResurfacingEvent> findAllByUserIdAndContentItemId(UUID userId, UUID contentItemId);
```

---

### Task 3 — Implement the full content saving vertical slice

Build the following in this exact order. Every class must be fully implemented — no stub bodies, no `return null` placeholders.

#### 3a — DTOs

**`SaveContentRequest`** (in `dto/request/`):
```
- type          : String  (required, must be one of TEXT/IMAGE/PDF/NOTE/SCREENSHOT/DIAGRAM)
- rawContent    : String  (required for non-image types)
- sourceUrl     : String  (required)
- pageTitle     : String  (optional)
- sessionId     : UUID    (optional)
- mimeType      : String  (optional, required for IMAGE/PDF)
- minioObjectKey: String  (optional, required for IMAGE/PDF)
```
All fields must be validated with `@NotBlank`, `@NotNull`, and custom cross-field validation where applicable.

**`ContentResponse`** (in `dto/response/`):
```
- id               : UUID
- type             : String
- sourceTitle      : String
- sourceUrl        : String
- previewText      : String  (first 200 chars of rawContent)
- topicId          : UUID
- topicName        : String
- autoDetectedTopic: String
- minioObjectKey   : String
- embeddingId      : String
- createdAt        : String  (ISO-8601)
```

#### 3b — LLMService (stub for Week 1)

`LLMService` must have one public method:
```java
public TopicDetectionResult detectTopic(String rawContent, String sourceUrl)
```
For Week 1, return a hardcoded `TopicDetectionResult` with `primaryTopic = "General"` and an empty subtopics list. Log the inputs at `DEBUG` level. The method signature must not change in later weeks — only the implementation body changes.

`TopicDetectionResult` is an inner record or a small POJO with `String primaryTopic` and `List<String> subtopics`.

#### 3c — EmbeddingService (stub for Week 1)

`EmbeddingService` must have one public method:
```java
public String generateAndStoreEmbedding(UUID contentItemId, String text)
```
For Week 1, log the call at `INFO` level, log the target URL (`http://localhost:8000/embed`), and return a fake UUID string. The stub must not throw an exception — the save flow must complete even when the Python service is not running. Wrap the call in a try-catch and log a warning if the service is unreachable.

#### 3d — ContentService

`ContentService` must implement `saveContent(SaveContentRequest request, UUID userId)` in exactly this order:

1. Compute a SHA-256 checksum of `rawContent` (or `minioObjectKey` for binary types).
2. Call `contentItemRepository.findByUserIdAndChecksum(userId, checksum)`. If present, throw a `DuplicateContentException` (create this in the `exception` package).
3. Call `llmService.detectTopic(rawContent, sourceUrl)` to get the primary topic name.
4. Find or create the `Topic` entity using `topicRepository.findByUserIdAndName(userId, primaryTopic)`. If not found, create and save a new `Topic` with `autoDetected = true`.
5. Build and save the `ContentItem` entity with all fields set.
6. Call `embeddingService.generateAndStoreEmbedding(savedItem.getId(), rawContent)` and update `contentItem.embeddingId` with the returned ID.
7. If `sessionId` is provided, load the `StudySession` and add the content item to its collection and save.
8. Map the saved entity to `ContentResponse` and return.

Every step must be transactional. Annotate `saveContent` with `@Transactional`.

#### 3e — ContentController

```
POST /api/v1/content/save
```
- Accepts `@RequestBody @Valid SaveContentRequest`
- Reads the user ID from a hardcoded constant `TEST_USER_ID` defined as a `UUID` field on the controller — comment clearly that this is replaced with JWT extraction in a later week.
- Returns `ResponseEntity<ContentResponse>` with HTTP `201 Created` on success.
- Returns `409 Conflict` if `DuplicateContentException` is thrown.
- Returns `400 Bad Request` for validation failures — handled by `GlobalExceptionHandler`.

Fill in `GlobalExceptionHandler` with `@RestControllerAdvice`. Handle at minimum: `MethodArgumentNotValidException` → 400, `DuplicateContentException` → 409, `ContentNotFoundException` → 404, and a catch-all `Exception` handler → 500.

---

### Task 4 — Tests

#### ContentServiceTest (unit test with Mockito)

| Test method | Scenario | Expected |
|---|---|---|
| `saveContent_happyPath_returnsSavedItem` | Valid TEXT request, no duplicate | `ContentResponse` returned, `contentItemRepository.save` called once |
| `saveContent_duplicateContent_throwsConflict` | Checksum already exists for user | `DuplicateContentException` thrown |
| `saveContent_llmServiceTimeout_throwsServiceUnavailable` | `llmService.detectTopic` throws `RuntimeException` | `ServiceUnavailableException` (503) propagated |
| `saveContent_emptyRawContent_throwsValidationError` | `rawContent` is blank | `ConstraintViolationException` or validation rejection |
| `saveContent_imageTypeWithoutMinioKey_throwsBadRequest` | `type = IMAGE`, `minioObjectKey` is null | Validation failure, save never called |
| `saveContent_sameContentDifferentSourceUrl_deduplicates` | Same raw content, different `sourceUrl` | `DuplicateContentException` thrown — checksum is content-based not URL-based |

#### ContentControllerTest (Spring MVC integration test)

Mirror every scenario above as a `@SpringBootTest` + `MockMvc` integration test hitting `POST /api/v1/content/save`. Assert HTTP status codes, response body structure, and that the database state is correct after each call. Use Testcontainers for PostgreSQL — do not use H2.

---

### Task 5 — Local environment verification

1. Run `docker-compose up -d` from `memora-backend/`.
2. Verify `memora-postgres`, `memora-minio`, and `memora-chromadb` containers start and pass their health checks.
3. Start the Spring Boot application with `./mvnw spring-boot:run`.
4. Verify Flyway output in the logs shows all migrations applied successfully (`V1__initial_schema` and `V2__add_missing_tables`).
5. Connect to PostgreSQL and confirm all 12 tables exist: `users`, `topics`, `topic_clusters`, `topic_cluster_topics`, `content_items`, `study_sessions`, `study_session_content_items`, `exam_profiles`, `exam_topic_coverage`, `highlights`, `resurfacing_events`, `compiled_documents`.
6. If any migration fails, fix the Java entity or config — do not modify the `.sql` files.
7. Test `POST /api/v1/content/save` with `curl` or Postman and confirm a `201` response and a row in the `content_items` table.

---

## Person 2 — React Web App Developer

**Branch:** `feat/topics-sidebar` (first PR), then `feat/sessions-view`, `feat/exam-prep`, etc. — one branch per major view.  
**Working directory:** `memora-frontend/` (to be created this week)  
**Week 1 goal:** Build the complete UI shell and all views using mock data via MSW. The UI must be fully functional and navigable without the backend running.

---

### Task 1 — Project setup

From the repository root, scaffold the project:

```bash
npm create vite@latest memora-frontend -- --template react-ts
cd memora-frontend
npm install
npm install @tanstack/react-query axios react-router-dom lucide-react msw
npm install -D tailwindcss postcss autoprefixer
npx tailwindcss init -p
```

Configure Tailwind in `tailwind.config.js` to scan `./src/**/*.{ts,tsx}`. Add Tailwind directives to `src/index.css`.

Create `src/api/client.ts` that exports an Axios instance with `baseURL` read from `import.meta.env.VITE_API_BASE_URL` defaulting to `http://localhost:8080/api/v1`.

Create `.env.local` with `VITE_API_BASE_URL=http://localhost:8080/api/v1`. Add `.env.local` to `.gitignore`. Never commit API URLs or tokens.

Wrap the app in `QueryClientProvider` in `main.tsx`. Set up `BrowserRouter` in `App.tsx`.

---

### Task 2 — App shell

Build a two-panel layout:
- **Left sidebar** — fixed width (256px), dark background, full viewport height, scrollable independently.
- **Main content area** — fills remaining width, light background, scrollable.

**Sidebar — top section (Topics):**  
A collapsible tree. Top-level nodes are subjects (e.g. "Artificial Intelligence", "Cybersecurity"). Each subject expands to show its topics. Each topic shows its name and a pill with the count of saved items. Clicking a topic navigates to the Topics view for that topic. The active topic is highlighted.

**Sidebar — bottom section (Sessions):**  
A reverse-chronological list of study sessions. Each entry shows an auto-generated session heading (e.g. "AI Study — 27 May"), the date in relative format (e.g. "2 days ago"), and the number of items saved. Clicking a session navigates to the Sessions view. The active session is highlighted. This section is separated from Topics by a thin divider and a "Sessions" label, styled exactly like Claude's conversation history.

**Top navigation bar:**  
A slim bar above the main content area with the Memora logo on the left and navigation links on the right: "Dashboard", "Exam Prep", "Settings". "Exam Prep" is a link to the Exam Prep view.

---

### Task 3 — Topics view

Route: `/topics/:topicId`

When a topic is selected in the sidebar, render all content items saved under that topic in the main area.

Each content item card shows:
- Content type badge (`TEXT`, `IMAGE`, `NOTE`, `PDF`, `SCREENSHOT`, `DIAGRAM`) — colour-coded.
- Source page title as the card heading.
- Source URL as a clickable `<a>` link (truncated to 60 characters with ellipsis).
- Preview of the first 200 characters of `rawContent`.
- Date saved in relative format.
- For `IMAGE` type: show a thumbnail using the `minioObjectKey` URL (mock with a placeholder image this week).

Pagination: 20 items per page. Show page number controls at the bottom. Use React Query with the page number as a query key so each page is individually cached.

---

### Task 4 — Sessions view

Route: `/sessions/:sessionId`

When a session is selected, render the full session view:

1. Session heading at the top (large, bold).
2. Session date range (`Started: ... · Ended: ...`).
3. Total items count.
4. Content grouped by topic — each topic is a collapsible section header followed by its content item cards.
5. Content item cards in the Sessions view are identical to the Topic view cards.

---

### Task 5 — Exam Prep view

Route: `/exam-prep`

**Empty state:**  
A centred form with two fields — "Exam name" (text input) and "Syllabus" (large textarea). A submit button labelled "Analyse Coverage". On submit, call `POST /api/v1/exam/analyse` (mocked via MSW this week). Transition to the filled state with the response data.

**Filled state:**  
- Exam name as the page heading.
- Overall coverage percentage shown as a large number with a circular progress ring.
- A list of topic rows. Each row shows:
  - Topic name.
  - Coverage percentage bar (full width, colour-coded: green ≥ 70%, yellow 30–70%, red < 30%).
  - Number of content items mapped to that topic.
  - Status badge: "Well Covered", "Partial", or "Gap".
- A button "Reset" that returns to the empty state.

---

### Task 6 — Content Detail modal

Triggered by clicking any content item card anywhere in the app. The modal overlays the current view without navigating away.

The modal shows:
- Content type badge.
- Source page title (heading).
- Source URL as a clickable link.
- Topic name with a link to the Topic view.
- Session name with a link to the Session view.
- Date saved.
- For `TEXT`, `NOTE`, `SCREENSHOT`, `DIAGRAM`: full `rawContent` in a scrollable box. If the item originated from a highlight, the highlighted portion is wrapped in a `<mark>` styled with yellow background.
- For `IMAGE`, `PDF`: full image or a PDF viewer placeholder.
- A red "Delete" button at the bottom. On click, call `DELETE /api/v1/content/:id` (mocked). On success, close the modal and remove the item from the cached list without a full refetch (update the React Query cache directly).

---

### Task 7 — MSW mock data setup

Install and configure MSW:

```bash
npx msw init public/ --save
```

Create `src/mocks/handlers.ts` with handlers for:
- `GET /api/v1/topics` — returns at least 5 topics across 2 subjects.
- `GET /api/v1/content?topicId=:id&page=:n` — returns paginated content items.
- `GET /api/v1/sessions` — returns 3 sessions.
- `GET /api/v1/sessions/:id` — returns session detail with content grouped by topic.
- `POST /api/v1/exam/analyse` — returns mock coverage data.
- `GET /api/v1/content/resurface` — returns 3 mock resurface results.
- `DELETE /api/v1/content/:id` — returns `204 No Content`.

**Required mock data (minimum):**

| Subject | Topics |
|---|---|
| Artificial Intelligence | Neural Networks, Transformers |
| Cybersecurity | Cryptography, Network Security, Ethical Hacking |

15 content items spread across the 5 topics and 3 sessions. Include items of type `TEXT`, `IMAGE`, `NOTE`, and `PDF`.

Activate MSW in `main.tsx` when `import.meta.env.MODE === 'development'`.

---

## Person 3 — Chrome Extension Developer

**Branch:** `feat/highlight-capture` (first PR), then `feat/resurface-popup`, `feat/context-detection`, etc.  
**Working directory:** `memora-extension/` (to be created this week)  
**Week 1 goal:** Build the core highlight capture flow and the resurfacing popup. The extension must work against the backend running at `http://localhost:8080` and must degrade gracefully when the backend is not running.

---

### Task 1 — Project setup

Create `memora-extension/` in the repository root with this structure:

```
memora-extension/
├── manifest.json
├── background/
│   └── service-worker.js
├── content/
│   └── content-script.js
├── popup/
│   ├── popup.html
│   ├── popup.js
│   └── popup.css
├── icons/
│   ├── icon16.png
│   ├── icon48.png
│   └── icon128.png
└── config/
    └── env.js          ← gitignored, contains API base URL and test token
```

**`manifest.json`** — Manifest V3:
```json
{
  "manifest_version": 3,
  "name": "Memora",
  "version": "1.0.0",
  "description": "Your context-aware knowledge assistant",
  "permissions": ["activeTab", "storage", "scripting", "contextMenus"],
  "host_permissions": ["http://localhost:8080/*"],
  "background": { "service_worker": "background/service-worker.js" },
  "content_scripts": [{
    "matches": ["<all_urls>"],
    "js": ["content/content-script.js"],
    "run_at": "document_idle"
  }],
  "action": {
    "default_popup": "popup/popup.html",
    "default_icon": { "16": "icons/icon16.png", "48": "icons/icon48.png", "128": "icons/icon128.png" }
  }
}
```

Create `config/env.js` with:
```js
const MEMORA_CONFIG = {
  API_BASE_URL: 'http://localhost:8080/api/v1',
  TEST_TOKEN: 'memora-test-token-week1'
};
```

Add `config/env.js` to `.gitignore`. Never commit tokens.

---

### Task 2 — Content script: floating toolbar on text selection

In `content/content-script.js`, listen for `mouseup` events on `document`.

When fired:
1. Get `window.getSelection().toString().trim()`.
2. If the selection is fewer than 10 characters, do nothing.
3. Get the bounding rect of the selection using `selection.getRangeAt(0).getBoundingClientRect()`.
4. Inject a `div` (the toolbar) into `document.body` with:
   - `position: fixed`
   - `top` = `rect.top + window.scrollY - 44px` (just above the selection)
   - `left` = `rect.left + (rect.width / 2) - half the toolbar width` (horizontally centred)
   - `z-index: 2147483647` (maximum, so it sits above page content)
5. The toolbar contains two buttons:
   - **Highlight** button — yellow highlighter icon (SVG inline), tooltip "Highlight & Save".
   - **Save** button — bookmark icon (SVG inline), tooltip "Save to Memora".
6. Remove any existing toolbar before injecting a new one.
7. Listen for a `mousedown` event on `document` and remove the toolbar if the click target is not inside it.
8. The toolbar must not alter the document's existing layout. Use `fixed` positioning only. Do not modify `document.body` styles.

---

### Task 3 — Content script: highlight and capture

When the **Highlight** button in the toolbar is clicked:

1. **Wrap the selection in a styled `<span>`:**
   ```js
   const span = document.createElement('span');
   span.style.backgroundColor = 'rgba(255, 230, 0, 0.5)';
   span.setAttribute('data-memora-highlight', Date.now().toString());
   range.surroundContents(span);
   ```
   If `surroundContents` throws (selection crosses element boundaries), fall back to `range.extractContents()` + `span.appendChild()` + `range.insertNode(span)`.

2. **Capture context:**
   - `selectedText`: the selected string.
   - `surroundingContextBefore`: 200 characters before the selection start within `document.body.innerText`.
   - `surroundingContextAfter`: 200 characters after the selection end.
   - `pageUrl`: `window.location.href`.
   - `pageTitle`: `document.title`.
   - `charOffset`: character offset of the selection start within `document.body.innerText`.

3. **Send message to background:**
   ```js
   chrome.runtime.sendMessage({
     type: 'SAVE_HIGHLIGHT',
     payload: { selectedText, surroundingContextBefore, surroundingContextAfter, pageUrl, pageTitle, charOffset }
   });
   ```

4. Remove the toolbar after sending.

5. Listen for the background response and show a brief toast notification — green for success ("Saved to Memora"), red for failure ("Save failed — check backend").

---

### Task 4 — Background service worker: save highlight

In `background/service-worker.js`, listen for messages with `type === 'SAVE_HIGHLIGHT'`.

When received, build the request body:
```json
{
  "type": "TEXT",
  "rawContent": "<selectedText>",
  "sourceUrl": "<pageUrl>",
  "pageTitle": "<pageTitle>",
  "surroundingContextBefore": "...",
  "surroundingContextAfter": "...",
  "charOffset": 0
}
```

Make a `POST` to `MEMORA_CONFIG.API_BASE_URL + '/content/save'` with headers:
```
Content-Type: application/json
Authorization: Bearer <MEMORA_CONFIG.TEST_TOKEN>
```

- On HTTP `201`: send `{ type: 'SAVE_SUCCESS', payload: responseBody }` back to the tab's content script.
- On HTTP `409`: send `{ type: 'SAVE_DUPLICATE', message: 'Already saved' }`.
- On any other error or network failure: send `{ type: 'SAVE_ERROR', message: error.message }`.

Do not let the service worker crash on network failure — all `fetch` calls must be wrapped in `try/catch`.

---

### Task 5 — Extension popup

**`popup/popup.html`:** A minimal HTML page (400px wide, auto height) that loads `popup.js` and `popup.css`. Shows:
- Memora logo and name in the header.
- A loading spinner while fetching.
- Up to 3 resurface result cards.
- An empty state message if no results.

**`popup/popup.js`:**

On `DOMContentLoaded`:
1. Query the active tab using `chrome.tabs.query({ active: true, currentWindow: true })`.
2. Check `chrome.storage.session` for cached resurface results for this tab's URL (stored by the background context detection — Task 6). If found, render immediately without a network call.
3. If no cache hit, make a `GET` to `MEMORA_CONFIG.API_BASE_URL + '/content/resurface?context=' + encodeURIComponent(tab.url + ' ' + tab.title)`.
4. On success, render the results.
5. On failure (network error or backend not running), render 3 hardcoded mock resurface results so the popup always shows something useful.

**Each result card shows:**
- Content type badge.
- Preview (first 120 characters of `rawContent`).
- Topic name.
- Source page title.
- A button "Open in Memora" that opens `http://localhost:5173/content/:id` in a new tab.

**Empty state:** Centred illustration and text: *"You haven't saved anything related to this page yet."*

---

### Task 6 — Background: context detection with debounce

In `background/service-worker.js`, listen for `chrome.tabs.onUpdated` events where `changeInfo.status === 'complete'`.

Implement a debounce:
- Store a `Map<tabId, timeoutId>`.
- On each navigation to a complete state, clear the previous timeout for that tab and set a new 10-second timeout.
- When the timeout fires, fetch resurface results for that tab's URL and title.
- Store the results in `chrome.storage.session` keyed by the tab URL.

This ensures the popup can read cached results instantly without making a new request on popup open.

---

### Task 7 — Right-click context menu: Save this page

In the service worker, on `chrome.runtime.onInstalled`, create a context menu item:
```js
chrome.contextMenus.create({
  id: 'memora-save-page',
  title: 'Save this page to Memora',
  contexts: ['page']
});
```

On `chrome.contextMenus.onClicked`, when `info.menuItemId === 'memora-save-page'`:
1. Use `chrome.scripting.executeScript` to extract the page title, URL, and first 1000 characters of `document.body.innerText`.
2. Send a `POST` to `MEMORA_CONFIG.API_BASE_URL + '/content/save'` with body:
   ```json
   { "type": "TEXT", "rawContent": "<first 1000 chars>", "sourceUrl": "<url>", "pageTitle": "<title>" }
   ```
3. Show a Chrome notification on success or failure using `chrome.notifications.create`.

---

## Shared Rules for All Three Team Members

### Git & branching

1. **No direct pushes to `main`.** Branch protection must be enforced on GitHub. Any direct push to `main` is a blocking violation.
2. Every task or group of related tasks lives on its own feature branch following the naming convention `feat/<description>`.
3. Every branch enters `main` only via a **Pull Request** with at least one reviewer approval.
4. Pull requests must include a short description of what changed and how to test it.
5. Rebase your branch on the latest `main` before opening a PR to keep history clean.

### Repository structure

```
/
├── memora-backend/      (Person 1 — Spring Boot, Java 17, Maven)
├── memora-frontend/     (Person 2 — React 18, Vite, TypeScript)
├── memora-extension/    (Person 3 — Chrome Extension, Manifest V3)
├── TEAM_TASKS_WEEK1.md
└── .gitignore
```

### Environment configuration

6. All environment-specific values — API URLs, tokens, database passwords, MinIO credentials — go into `.env`, `.env.local`, or `config/env.js` files that are listed in `.gitignore`.
7. Never commit secrets, tokens, or credentials to the repository in any file.
8. The shared API base URL for all clients during development is `http://localhost:8080/api/v1`.

### End-of-week integration milestone

By the end of Week 1 the following end-to-end flow must work:

```
User selects text on any webpage
        ↓
Chrome extension toolbar appears
        ↓
User clicks Highlight
        ↓
Content script sends message to background
        ↓
Background POSTs to Spring Boot /api/v1/content/save
        ↓
Spring Boot saves to PostgreSQL, runs Flyway-migrated schema
        ↓
Response 201 sent back to extension → green toast shown
        ↓
User opens Memora web app
        ↓
Topics view shows the newly saved content item under its auto-detected topic
```

If this flow does not work end to end, Week 1 is not done.

---

*Document generated for the Memora project — Week 1 Sprint.*
