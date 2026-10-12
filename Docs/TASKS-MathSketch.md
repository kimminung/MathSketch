# TASKS — MathSketch

범례: `[x]` 완료 · `[ ]` 미착수 · `[~]` 부분 완료/확인 필요

참고: `Formula Simplification`의 MathEngine/Canvas/SwiftData 패턴을 응용. 상세 근거는 `Docs/PRD-MathSketch.md` 참조.

## Phase 0 — 프로젝트 셋업

- [ ] T0.1 타깃/프로젝트명을 `MathSketch`로 변경 (스킴, Bundle ID, Product Name). `TARGETED_DEVICE_FAMILY = "1,2"`(iPhone+iPad)로 설정.
- [ ] T0.2 폴더 구조 선셋업: `MathEngine/`, `SketchEngine/`, `Model/`, `Persistence/Draft/`, `Persistence/Gallery/`, `Views/` 그룹 생성.
- [ ] T0.3 `LICENSE`(Apache 2.0), `Docs/`, `Media/Screenshots/`, `Media/Video/` 폴더 준비.
- [ ] T0.4 git 저장소 초기화 (`git init`) — 이후 단계에서 커밋. 지금은 생성만.

## Phase 1 — MathEngine 이식 + DSL 확장

- [ ] T1.1 참고 프로젝트의 `MathLexer`/`MathAST`/`MathParser`/`MathEvaluator`/`MathSyntaxError`/`MathEvaluationError`를 MathSketch로 이식(필요한 부분만, `nonisolated` 유지).
- [ ] T1.2 Lexer에 콜론(`:`)·세미콜론(`;`)·중괄호 불필요 — 대신 가운데점(`·`) 토큰과 `#RRGGBB` 색 리터럴 토큰 추가. 이름 있는 인자(`r: 40`) 파싱 지원.
- [ ] T1.3 `SketchFormulaParser`: `shapeCall · modifier · modifier ... (+ shapeCall · ...)*` 문법으로 전체 문자열을 `[SketchElement]`로 파싱. 모양 함수명(FR-1 20종)과 `scale/rotate/shear/translate/color` 수정자를 식별.
- [ ] T1.4 `SketchFormulaFormatter`: `[SketchElement]` → 위 문법 문자열로 직렬화 (PRD FR-5 예시와 동일한 출력 규칙).
- [ ] T1.5 Swift Testing으로 왕복 변환 테스트 (요소 1개/다중/각 ShapeKind별) + 기존 Lexer/Parser 단위 테스트 이식.

## Phase 2 — 도형 카탈로그 & 요소 모델

- [ ] T2.1 `ShapeKind` enum 20종 정의 (FR-1 분류별) + 각 도형의 매개변수 구조체와 `x(t), y(t)` 샘플링 함수.
- [ ] T2.2 `ElementTransform`(translate/scale/rotate/shear) + 합성 변형 행렬 적용 함수 `apply(to: [CGPoint]) -> [CGPoint]`.
- [ ] T2.3 `ElementColor`(hex ↔ HSB ↔ `Color` 변환 유틸).
- [ ] T2.4 `SketchElement`(id, shapeKind, shapeParameters, transform, color, zIndex) — `Identifiable, Codable, Sendable, Equatable`.
- [ ] T2.5 사람이 읽는 수식 라벨 생성기 (`FormulaFormatter.label(for: SketchElement) -> String`, 참고 프로젝트 `FormulaFormatter` 응용).

## Phase 3 — 팔레트 & 캔버스 렌더러

- [ ] T3.1 `PaletteView`: 20종 도형을 카테고리별(직선류/기본폐도형/삼각함수/극좌표) 그리드로 표시, 각 항목에 공식 미리보기.
- [ ] T3.2 드래그 앤 드롭으로 팔레트 → 캔버스에 `SketchElement` 생성 (`DragGesture` 또는 `Transferable`/`dropDestination`).
- [ ] T3.3 `SketchCanvasRenderer`(stateless, `nonisolated enum`): 요소별 샘플링→변형→`Path`, 참고 프로젝트 `MathCanvasRenderer` 패턴 응용.
- [ ] T3.4 `CanvasView`에서 `Canvas`로 전체 요소 렌더 + 선택 요소 바운딩 박스/핸들 오버레이.

## Phase 4 — 제스처 조작 + 실시간 수식 반영

- [ ] T4.1 이동(`DragGesture`) → `translate` 갱신, 매 `onChanged`마다 라벨 갱신.
- [ ] T4.2 스케일 핸들(모서리 4개) 드래그 → 축별 `scale` 독립 조절.
- [ ] T4.3 회전 핸들 → `rotate` 갱신 (도 단위, 라벨에 정수/소수 1자리 포맷).
- [ ] T4.4 비틀기 핸들 → `shear` 갱신.
- [ ] T4.5 `InspectorView`: 선택 요소의 슬라이더(스케일/회전/비틀기)·색상 피커를 `@Bindable`로 연결, 핸들 조작과 양방향 동기화.
- [ ] T4.6 성능 확인: 제스처 중 메인 스레드가 포인트 변형만 수행하고 끊김 없이 60fps 근접하는지 Instruments 또는 시뮬레이터 체감으로 확인.

## Phase 5 — 합성 수식 패널 & 역변환

- [ ] T5.1 `FormulaBarView`: 현재 모든 요소를 `SketchFormulaFormatter`로 합친 문자열을 실시간(요소 변경 시 150ms 디바운스) 표시 + 복사 버튼.
- [ ] T5.2 "수식으로 그리기" 입력창: 붙여넣은 문자열을 `SketchFormulaParser`로 파싱해 캔버스를 1회 교체. 파싱 실패 시 에러 배너(열/토큰 표시).
- [ ] T5.3 프리셋 몇 개(참고 프로젝트 `FormulaPresets`처럼) 제공 — 예: "하트+리본", "스피로그래프 은하" 등 MathSketch 요소 조합으로 재구성.

## Phase 6 — 영속성

- [ ] T6.1 Core Data 모델(`DraftCanvas` 단일 엔티티, JSON `Data` 필드) + `DraftCanvasStore` (저장/조회, 백그라운드 컨텍스트).
- [ ] T6.2 Combine `PassthroughSubject<Void,Never>` + `.debounce(0.8s)`로 요소 변경을 드래프트 자동저장에 연결.
- [ ] T6.3 앱 기동 시 드래프트 복원 로직 (`MathSketchApp`/`SketchModel.init`).
- [ ] T6.4 SwiftData `SavedSketch` 모델 + `GalleryView`(`@Query`) + `SketchDetailView`(열기/삭제).
- [ ] T6.5 썸네일 생성(`ImageRenderer`) 및 `.externalStorage` 저장.
- [ ] T6.6 강제 종료 후 재실행 시나리오 수동 검증 (시뮬레이터: 앱 스와이프 종료 → 재실행 → 캔버스 복원 확인).

## Phase 7 — 접근성 & 멀티 디바이스

- [ ] T7.1 팔레트/핸들/버튼에 `accessibilityLabel`+`accessibilityValue` 부여.
- [ ] T7.2 Dynamic Type 대응 (텍스트 스타일 사용, 큰 글자 크기에서 레이아웃 확인).
- [ ] T7.3 iPad 레이아웃(가로/세로, 분할 화면) 검증 및 보정.

## Phase 8 — 시뮬레이터 검증 & 테스트

- [ ] T8.1 Swift Testing 유닛 테스트 전체 통과 확인 (MathEngine + SketchEngine + Persistence 계층).
- [ ] T8.2 iPhone 16 시뮬레이터: 조립→변형→합성 수식→재구성→저장→재실행 복원 전 흐름 수동 검증.
- [ ] T8.3 iPad 시뮬레이터(13형 또는 11형): 동일 흐름 검증 + 레이아웃 확인.
- [ ] T8.4 발견된 이슈 수정 및 회귀 재검증.

## Phase 9 — 문서화 & GitHub 공개 준비

- [ ] T9.1 Phase별 스크린샷 촬영 (`Media/Screenshots/phase<N>-*.png`), 필요 시 짧은 데모 GIF/영상.
- [ ] T9.2 `README.md` 작성 (참고 프로젝트 구조 응용: 헤더/스크린샷/목차/Phase별 섹션/요구사항/프로젝트 구조/라이선스).
- [ ] T9.3 첫 커밋 및 커밋 로그 정리.

---

## 알려진 설계 메모

- "비틀기"는 수학적으로는 전단(shear) 변형이다. UI 라벨은 사용자 친화적으로 "비틀기"를 쓰되, 수식 표기는 `shear(shx, shy)`로 정확히 기술한다 (PRD FR-2).
- Core Data(드래프트 자동저장)와 SwiftData(갤러리)를 분리한 이유: 드래프트는 고빈도·저수명 쓰기(제스처마다)이고 갤러리는 저빈도·고수명 쓰기(명시적 저장)라 접근 패턴이 다르다 — 하나의 스토어로 합치면 고빈도 쓰기가 갤러리 쿼리 성능에 영향을 줄 수 있어 분리했다.
