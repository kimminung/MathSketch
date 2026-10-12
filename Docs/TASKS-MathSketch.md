# TASKS — MathSketch

범례: `[x]` 완료 · `[ ]` 미착수 · `[~]` 부분 완료/확인 필요

참고: `Formula Simplification`의 MathEngine/Canvas/SwiftData 패턴을 응용. 상세 근거는 `Docs/PRD-MathSketch.md` 참조.

## Phase 0 — 프로젝트 셋업

- [x] T0.1 타깃/프로젝트명을 `MathSketch`로 변경 (스킴, Bundle ID, Product Name), `Desktop/MathSketch`로 이동.
- [ ] T0.2 폴더 구조 선셋업: `MathEngine/`, `SketchEngine/`, `PaletteSignature/`, `Model/`, `Persistence/Draft/`, `Persistence/Gallery/`, `Views/` 그룹 생성. `TARGETED_DEVICE_FAMILY = "1,2"`(iPhone+iPad) 설정 확인.
- [ ] T0.3 `LICENSE`(Apache 2.0), `Media/Screenshots/`, `Media/Video/` 폴더 준비.
- [x] T0.4 git 저장소 초기화 + 첫 커밋 완료.

## Phase 1 — MathEngine 이식 + DSL 확장 (색상 없음)

- [ ] T1.1 참고 프로젝트의 `MathLexer`/`MathAST`/`MathParser`/`MathEvaluator`/`MathSyntaxError`/`MathEvaluationError`를 MathSketch로 이식(필요한 부분만, `nonisolated` 유지).
- [ ] T1.2 Lexer에 가운데점(`·`) 토큰 추가. 이름 있는 인자(`r: 40`) 파싱 지원. **색 리터럴/토큰은 문법에 포함하지 않는다** (PRD FR-5).
- [ ] T1.3 `SketchFormulaParser`: `shapeCall · modifier · modifier ... (+ shapeCall · ...)*` 문법으로 전체 문자열을 `[SketchElement]`(색 제외, 기본 중립색 적용)로 파싱. 모양 함수명(FR-1 23종)과 `scale/rotate/shear/translate` 수정자만 식별한다.
- [ ] T1.4 `SketchFormulaFormatter`: `[SketchElement]`에서 색을 제외한 나머지를 위 문법 문자열로 직렬화 (PRD FR-5 예시와 동일한 출력 규칙, color 토큰 절대 출력하지 않음).
- [ ] T1.5 Swift Testing으로 왕복 변환 테스트 (요소 1개/다중/각 ShapeKind별, 점·선·면 포함) + 기존 Lexer/Parser 단위 테스트 이식. 색 정보가 왕복 후 사라지는지(의도된 동작) 확인하는 테스트 포함.

## Phase 2 — 도형 카탈로그 & 요소 모델

- [ ] T2.1 `ShapeKind` enum 23종 정의: 기본 요소(`point`/`line`/`plane`) + 직선류(`segment`/`ray`/`polyline`/`arc`/`quadBezier`/`cubicBezier`) + 기본 폐도형 + 삼각함수 곡선 + 극좌표 곡선. 각 도형의 매개변수 구조체, `x(t), y(t)` 샘플링 함수, 렌더 스타일(`point`/`stroke`/`fill`) 정의.
- [ ] T2.2 `ElementTransform`(translate/scale/rotate/shear) + 합성 변형 행렬 적용 함수 `apply(to: [CGPoint]) -> [CGPoint]`. `point`의 scale/rotate/shear 항등성 처리(마커 반지름 예외).
- [ ] T2.3 `ElementColor`(hex ↔ HSB ↔ `Color` 변환 유틸) — 장식 전용, SketchFormula와 분리된 모델.
- [ ] T2.4 `SketchElement`(id, shapeKind, shapeParameters, transform, color, zIndex) — `Identifiable, Codable, Sendable, Equatable`.
- [ ] T2.5 사람이 읽는 수식 라벨 생성기 (`FormulaFormatter.label(for: SketchElement) -> String`, 색 제외, 참고 프로젝트 `FormulaFormatter` 응용).

## Phase 3 — 팔레트 & 캔버스 렌더러

- [ ] T3.1 `PaletteView`: 23종 요소를 카테고리별(기본 요소/직선류/기본폐도형/삼각함수/극좌표) 그리드로 표시, 기본 요소(점·선·면) 섹션을 맨 앞에 배치, 각 항목에 공식 미리보기.
- [ ] T3.2 드래그 앤 드롭으로 팔레트 → 캔버스에 `SketchElement` 생성 (`DragGesture` 또는 `Transferable`/`dropDestination`).
- [ ] T3.3 `SketchCanvasRenderer`(stateless, `nonisolated enum`): 요소별 샘플링→변형→`Path`, 렌더 스타일별 분기(`point`는 채움 원, `stroke`는 선, `fill`은 영역 채움 — `plane` 포함), 참고 프로젝트 `MathCanvasRenderer` 패턴 응용.
- [ ] T3.4 `CanvasView`에서 `Canvas`로 전체 요소 렌더 + 선택 요소 바운딩 박스/핸들 오버레이.

## Phase 4 — 제스처 조작 + 실시간 수식 반영

- [ ] T4.1 이동(`DragGesture`) → `translate` 갱신, 매 `onChanged`마다 라벨 갱신.
- [ ] T4.2 스케일 핸들(모서리 4개) 드래그 → 축별 `scale` 독립 조절.
- [ ] T4.3 회전 핸들 → `rotate` 갱신 (도 단위, 라벨에 정수/소수 1자리 포맷).
- [ ] T4.4 비틀기 핸들 → `shear` 갱신.
- [ ] T4.5 `InspectorView`: 선택 요소의 슬라이더(스케일/회전/비틀기)·색상 피커를 `@Bindable`로 연결, 핸들 조작과 양방향 동기화. 색상 피커 옆에 "색상은 장식용, 수식에는 포함되지 않음" 안내 문구.
- [ ] T4.6 성능 확인: 제스처 중 메인 스레드가 포인트 변형만 수행하고 끊김 없이 60fps 근접하는지 Instruments 또는 시뮬레이터 체감으로 확인.

## Phase 5 — 합성 수식 패널 & 역변환

- [ ] T5.1 `FormulaBarView`: 현재 모든 요소를 `SketchFormulaFormatter`로 합친 순수 기하 문자열을 실시간(요소 변경 시 150ms 디바운스) 표시 + 복사 버튼.
- [ ] T5.2 "수식으로 그리기" 입력창: 붙여넣은 문자열을 `SketchFormulaParser`로 파싱해 캔버스를 1회 교체(모든 요소 기본 중립색으로 시작). 파싱 실패 시 에러 배너(열/토큰 표시).
- [ ] T5.3 프리셋 몇 개(참고 프로젝트 `FormulaPresets`처럼) 제공 — 예: "하트+리본", "스피로그래프 은하" 등 MathSketch 요소 조합으로 재구성(프리셋은 장식용 기본색을 미리 지정해도 됨, 단 수식 문자열 자체에는 포함하지 않음).

## Phase 5a — 팔레트 서명 (Palette Signature)

- [ ] T5a.1 `PaletteNamer`: 50여 개 큐레이션된 한글 감성 색 이름 테이블 + Lab 색공간 최근접 매칭 함수.
- [ ] T5a.2 `PaletteSignature`: 캔버스의 고유 색 목록(zIndex 순, 중복 제거) → 스와치 목록 + 상위 3개 이름의 한 줄 캡션 생성.
- [ ] T5a.3 `PaletteSignatureView`: 스와치 띠 UI(칩 탭 시 hex+이름 표시) + 캡션 표시, 색상 변경 시 150ms 디바운스 재계산.
- [ ] T5a.4 갤러리 저장 시 캡션을 제목 기본값으로 제안하는 연결부 구현.
- [ ] T5a.5 `PaletteNamer` 최근접 매칭 결정성 Swift Testing 테스트.

## Phase 6 — 영속성

- [ ] T6.1 Core Data 모델(`DraftCanvas` 단일 엔티티, 색 포함 전체 상태 JSON `Data` 필드) + `DraftCanvasStore` (저장/조회, 백그라운드 컨텍스트).
- [ ] T6.2 Combine `PassthroughSubject<Void,Never>` + `.debounce(0.8s)`로 요소 변경을 드래프트 자동저장에 연결.
- [ ] T6.3 앱 기동 시 드래프트 복원 로직 (`MathSketchApp`/`SketchModel.init`).
- [ ] T6.4 SwiftData `SavedSketch`(formulaText[색 제외] + paletteHexes + 색 포함 전체 JSON) 모델 + `GalleryView`(`@Query`) + `SketchDetailView`(열기/삭제).
- [ ] T6.5 썸네일 생성(`ImageRenderer`) 및 `.externalStorage` 저장.
- [ ] T6.6 강제 종료 후 재실행 시나리오 수동 검증 (시뮬레이터: 앱 스와이프 종료 → 재실행 → 캔버스 복원 확인, 색상 포함).

## Phase 7 — 접근성 & 멀티 디바이스

- [ ] T7.1 팔레트/핸들/버튼에 `accessibilityLabel`+`accessibilityValue` 부여. 팔레트 서명 스와치 칩에도 색 이름 레이블 부여.
- [ ] T7.2 Dynamic Type 대응 (텍스트 스타일 사용, 큰 글자 크기에서 레이아웃 확인).
- [ ] T7.3 iPad 레이아웃(가로/세로, 분할 화면) 검증 및 보정.

## Phase 8 — 시뮬레이터 검증 & 테스트

- [ ] T8.1 Swift Testing 유닛 테스트 전체 통과 확인 (MathEngine + SketchEngine + PaletteSignature + Persistence 계층).
- [ ] T8.2 iPhone 16 시뮬레이터: 조립→변형→합성 수식(색 제외)→재구성→팔레트 서명 확인→저장→재실행 복원(색 포함) 전 흐름 수동 검증.
- [ ] T8.3 iPad 시뮬레이터(13형 또는 11형): 동일 흐름 검증 + 레이아웃 확인.
- [ ] T8.4 발견된 이슈 수정 및 회귀 재검증.

## Phase 9 — 문서화 & GitHub 공개 준비

- [ ] T9.1 Phase별 스크린샷 촬영 (`Media/Screenshots/phase<N>-*.png`), 필요 시 짧은 데모 GIF/영상. 팔레트 서명 UI 스크린샷 포함.
- [ ] T9.2 `README.md` 작성 (참고 프로젝트 구조 응용: 헤더/스크린샷/목차/Phase별 섹션/요구사항/프로젝트 구조/라이선스).
- [ ] T9.3 첫 커밋 및 커밋 로그 정리.

---

## 알려진 설계 메모

- "비틀기"는 수학적으로는 전단(shear) 변형이다. UI 라벨은 사용자 친화적으로 "비틀기"를 쓰되, 수식 표기는 `shear(shx, shy)`로 정확히 기술한다 (PRD FR-2).
- Core Data(드래프트 자동저장)와 SwiftData(갤러리)를 분리한 이유: 드래프트는 고빈도·저수명 쓰기(제스처마다)이고 갤러리는 저빈도·고수명 쓰기(명시적 저장)라 접근 패턴이 다르다 — 하나의 스토어로 합치면 고빈도 쓰기가 갤러리 쿼리 성능에 영향을 줄 수 있어 분리했다.
- **색상 ≠ 수식 (2026-10-13 변경)**: 처음에는 색도 합성 수식에 `color(#hex)` 토큰으로 인코딩할 계획이었으나, 사용자 요청으로 방향을 바꿨다. 이제 수식은 순수 기하(도형+변형)만 표현하고, 색은 장식 전용 + "팔레트 서명"(PaletteNamer가 감성적 한글 이름 부여)으로 별도 표현한다. 수식만으로는 색이 복원되지 않으며, 색까지 완전 복원하려면 갤러리의 전체 JSON을 거쳐야 한다 — 이 트레이드오프는 의도된 설계다.
- 기존에 "선분"을 가리키던 ShapeKind 이름 `line`은 기본 요소의 새 "직선(`line`, y=mx+b)"과 충돌해 `segment`로 개명했다.
