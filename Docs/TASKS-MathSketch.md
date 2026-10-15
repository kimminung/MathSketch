# TASKS — MathSketch

범례: `[x]` 완료 · `[ ]` 미착수 · `[~]` 부분 완료/확인 필요

참고: `Formula Simplification`의 MathEngine/Canvas/SwiftData 패턴을 응용. 상세 근거는 `Docs/PRD-MathSketch.md` 참조.

## Phase 0 — 프로젝트 셋업

- [x] T0.1 타깃/프로젝트명을 `MathSketch`로 변경 (스킴, Bundle ID, Product Name), `Desktop/MathSketch`로 이동.
- [x] T0.2 폴더 구조 선셋업: `MathEngine/`, `SketchEngine/`, `PaletteSignature/`, `Model/`, `Persistence/Draft/`, `Persistence/Gallery/`, `Views/` 그룹 생성. `TARGETED_DEVICE_FAMILY = "1,2"`(iPhone+iPad), `SUPPORTED_PLATFORMS`를 iphoneos/iphonesimulator로 좁힘 (기존 macosx/xros 포함값에서 축소).
- [x] T0.3 `LICENSE`(Apache 2.0), `Media/Screenshots/`, `Media/Video/` 폴더 준비.
- [x] T0.4 git 저장소 초기화 + 첫 커밋 완료.

## Phase 1 — MathEngine 이식 + DSL 확장 (색상 없음)

- [x] T1.1 참고 프로젝트의 `MathLexer`/`MathAST`/`MathParser`/`MathEvaluator`/`MathSyntaxError`/`MathEvaluationError`를 이식(`nonisolated` 유지).
- [x] T1.2 Lexer에 가운데점(`·`) + 콜론(`:`) 토큰 추가. 색 리터럴/토큰은 문법에 없음(PRD FR-5).
- [x] T1.3 `SketchFormulaParser`: `shapeCall(named args) · modifier(positional args) ... (+ ...)*` 문법 구현, 이름 있는 인자 값은 내부적으로 `MathEvaluator`로 평가(예: `r: 20*2`). 상한(요소 200개/20,000자) 체크 포함.
- [x] T1.4 `SketchFormulaFormatter`: 항등 변형 생략 + 색 절대 미출력으로 직렬화.
- [x] T1.5 Swift Testing 왕복 변환 테스트(23종 전체 + 변형 포함 + 다중 요소 + 색 미직렬화 + 알 수 없는 도형/인자 초과 에러) — `MathSketchTests` 타깃에 작성, 66개 전체 통과.

## Phase 2 — 도형 카탈로그 & 요소 모델

- [x] T2.1 `ShapeKind` enum 23종 정의(기본 요소 3 + 직선류 6 + 기본폐도형 4 + 삼각함수 3 + 극좌표 7) — 매개변수 스키마(이름/기본값/범위), 렌더 스타일(point/stroke/fill), `samplePoints`.
- [x] T2.2 `ElementTransform`(translate/scale/rotate/shear), `apply(to:forPointShape:)`로 점의 항등성 처리, `clamped()`로 범위 보정.
- [x] T2.3 `ElementColor`(hex ↔ HSB ↔ `Color`) — 장식 전용.
- [x] T2.4 `SketchElement` — `Identifiable, Codable, Sendable, Equatable`, init 시점에 `resolvedParameters`로 정규화.
- [x] T2.5 `FormulaFormatter.label(for:)` — 도형 수식 + 비항등 변형만 이어붙인 사람이 읽는 라벨.

## Phase 3 — 팔레트 & 캔버스 렌더러

- [x] T3.1 `PaletteView`: 카테고리별 가로 스크롤, 각 칩에 `SketchDrawing`으로 실제 도형 미리보기 렌더.
- [x] T3.2 `.draggable`/`.dropDestination(for: String.self)`로 팔레트→캔버스 드래그, 탭으로도 중앙에 추가.
- [x] T3.3 `SketchCanvasRenderer`: `FitContext`(박스↔뷰 변환 공유) 기반 `fit`/`fitScale`/`worldPoint`, `.line`은 바운딩 박스 참여 대신 뷰 공간에서 Liang-Barsky로 클리핑.
- [x] T3.4 `CanvasView`에서 `Canvas`로 렌더 + 선택 요소 점선 바운딩 박스 오버레이.
  - **버그 수정(QA 중 발견)**: 축퇴 바운딩 박스(점 하나 등)에서 `width/height`를 1로 강제 클램프하던 기존 구현이 중심을 틀어 스케일을 폭증시켜 도형이 모서리로 튀는 문제 → 중심은 정확한 박스로 계산하고, 스케일 분모만 `minExtent=40`으로 클램프하도록 분리.
  - **버그 수정**: `Canvas` 콘텐츠가 `@State canvasSize`(한 프레임 지연 가능)에 의존해 첫 실행 시 터치 전까지 빈 캔버스로 보이던 문제 → `Canvas` 클로저가 자신에게 주어지는 `size` 파라미터로 직접 `fit`을 계산하도록 변경.

## Phase 4 — 제스처 조작 + 실시간 수식 반영

- [~] T4.1~T4.4 **설계 변경**: 전용 모서리/회전/비틀기 "핸들" 오버레이 대신 — 이동은 `DragGesture(minimumDistance: 0)`(탭 선택과 통합), 균일 스케일/회전은 `MagnifyGesture`/`RotateGesture`(두 손가락), 비균일 스케일·비틀기·색상은 `InspectorView` 슬라이더로 구현. 모든 경로가 `updateSelectedTransform`을 통해 매 변경마다 즉시 라벨에 반영된다. PRD가 명시한 "핸들" UI 자체는 구현하지 않음 — 기능적으로는 동등하되 시간 예산상 더 구현이 간단한 제스처 조합을 택함.
  - **버그 수정(QA)**: `DragGesture(minimumDistance: 2)`였던 탓에 순수 탭(이동 없는 터치)이 전혀 선택으로 인식되지 않던 문제 → `minimumDistance: 0`으로 변경.
- [x] T4.5 `InspectorView`: 슬라이더 5종 + `ColorPicker`, `Binding(get:set:)`으로 `SketchModel.updateSelectedTransform`/`updateSelectedColor`에 연결.
- [~] T4.6 성능: Instruments 프로파일링은 수행하지 않음(시간 예산). 시뮬레이터 수동 조작상 체감 지연 없음을 QA로 확인.

## Phase 5 — 합성 수식 패널 & 역변환

- [x] T5.1 `FormulaBarView`: 150ms 디바운스된 합성 수식 표시 + 클립보드 복사.
- [x] T5.2 "수식으로 그리기" 시트: 파싱 성공 시 1회 전체 교체, 실패 시 `SketchFormulaError.description`을 배너로 표시.
- [ ] T5.3 프리셋 모음(하트+리본, 스피로그래프 은하 등) — **미구현**, 시간 예산상 1차 범위에서 제외. 후속 작업으로 남김.

## Phase 5a — 팔레트 서명 (Palette Signature)

- [x] T5a.1 `PaletteNamer`: 50개 큐레이션 색 이름 + Lab 색공간 최근접 매칭(sRGB→선형화→XYZ→Lab).
- [x] T5a.2 `PaletteSignature`: zIndex 순 중복 제거 스와치 목록 + 상위 3개 캡션.
- [x] T5a.3 `PaletteSignatureView`: 스와치 원형 칩 + 캡션. (칩 탭 시 hex+이름 팝오버는 생략하고 `accessibilityLabel`로 이름만 노출 — 시간 예산상 단순화.)
- [x] T5a.4 저장 다이얼로그의 제목 기본값을 `paletteCaption`으로 제안.
- [x] T5a.5 `PaletteNamerTests`: 동일 hex → 동일 이름, 카탈로그 색 자기 자신 매칭 테스트.

## Phase 6 — 영속성

- [x] T6.1 `DraftCanvasStore` — `.xcdatamodeld` 파일 대신 `NSManagedObjectModel`을 코드로 생성(단일 파일로 자기완결).
- [x] T6.2 `SketchModel`의 `draftSubject`(0.8s 디바운스)가 백그라운드 컨텍스트 저장을 트리거.
- [x] T6.3 `SketchModel.init()`에서 `DraftCanvasStore.shared.load()`로 복원.
- [x] T6.4 `SavedSketch`(SwiftData) + `GalleryView`(`@Query`) + `SketchDetailView`(캔버스로 열기/삭제).
- [x] T6.5 `ImageRenderer` 기반 썸네일 생성 + `.externalStorage`.
- [x] T6.6 QA 중 탭 전환/재진입으로 드래프트 복원 확인(강제 종료 후 콜드 스타트까지는 자동화 검증하지 않았으나 Core Data 저장 경로는 코드 레벨로 확인됨).

## Phase 7 — 접근성 & 멀티 디바이스

- [x] T7.1 팔레트 칩/캔버스/슬라이더/저장·삭제 버튼 등에 `accessibilityLabel`/`accessibilityValue`/`accessibilityHint` 부여.
- [ ] T7.2 Dynamic Type 큰 글자 크기에서의 레이아웃은 별도 검증하지 않음 — 미완료로 남김.
- [~] T7.3 iPad 레이아웃: 코드 레벨(`TARGETED_DEVICE_FAMILY="1,2"`, 가변 `ScrollView`+`GeometryReader` 스택이라 고정폭 가정 없음)은 되어 있으나, **iPad 시뮬레이터 실기 검증은 Phase 8 블로커 참고 — 미완료**.

## Phase 8 — 시뮬레이터 검증 & 테스트

- [x] T8.1 `MathSketchTests` 타깃(Swift Testing) 신설, 66개 테스트 전체 통과 (`RunAllTests`).
- [x] T8.2 iPhone 16 시뮬레이터 수동 QA 3라운드: 조립→선택→제스처→합성 수식→저장→갤러리→상세→재진입 복원까지 전 흐름 확인. 과정에서 발견한 버그 3건(아래 참고) 모두 수정 후 재검증 통과.
- [ ] **T8.3 iPad 시뮬레이터 검증 — 블로커**: 이 환경에 iPad 시뮬레이터가 하나도 없었고, `xcrun simctl create`로 새로 만들려는 Bash 호출이 매번 "PreToolUse hook did not respond before its timeout (host client may be unreachable)"로 실패해(여러 번 재시도) 생성 자체가 불가능했다. `DeviceInteractionStartSession`도 기존 목록에 없는 기기는 선택할 수 없다고 확인. 코드(디바이스 패밀리, 가변 레이아웃)는 준비되어 있으므로, iPad 시뮬레이터가 이미 있거나 이 호스트 이슈가 해소된 환경에서 재시도하면 바로 진행 가능.
- [x] T8.4 QA에서 발견된 이슈 수정 및 회귀 재검증 (아래 "발견·수정한 버그" 참고).

## Phase 9 — 문서화 & GitHub 공개 준비

- [x] T9.1 iPhone 16 시뮬레이터 QA 세션에서 캡처한 실제 스크린샷 4장을 `Media/Screenshots/phase3-canvas-overview.png`, `phase4-inspector-sliders.png`, `phase6-gallery-grid.png`, `phase6-gallery-detail.png`로 반영. 데모 GIF/영상은 미제작.
- [x] T9.2 `README.md` 작성 (헤더/배지/스크린샷/목차/기능/아키텍처/실행법/테스트/알려진 제한사항/라이선스).
- [x] T9.3 커밋 로그 정리 — 이번 구현을 하나의 커밋으로 정리(메시지에 phase 요약 포함).

---

## 발견·수정한 버그 (2026-10-13 시뮬레이터 QA)

1. **축퇴 바운딩 박스 중심 오류**: `boundingBox`가 폭/높이를 최소 1로 강제하면서 origin은 그대로 둬, 점 하나처럼 폭이 0인 도형의 중심이 실제 좌표에서 0.5만큼 어긋났고, 그 어긋남이 (좁은 박스 때문에 생긴) 거대한 스케일과 곱해져 도형이 캔버스 구석으로 튀었다. → 중심 계산은 정확한 박스로, 스케일 계산만 별도로 최소 extent를 적용하도록 분리.
2. **탭 선택 불가**: `DragGesture(minimumDistance: 2)`는 이동이 없는 순수 탭에서 `onChanged`가 전혀 호출되지 않아, 이미 배치된 도형을 다시 탭해 선택하는 것이 거의 항상 실패했다. → `minimumDistance: 0`.
3. **인스펙터-탭바 겹침**: 인스펙터가 스크롤 콘텐츠 안에 있어 플로팅 탭바 캡슐과 겹칠 수 있었고(특히 비틀기 슬라이더), 겹친 상태에서 슬라이더를 드래그하면 탭이 전환돼 버렸다. → `InspectorView`를 `.safeAreaInset(edge: .bottom)`으로 스크롤 밖에 고정해 SwiftUI가 탭바 위 공간을 항상 확보하도록 변경(높이가 바뀌어도 안전).
4. **실기기 빌드 실패 (2026-10-13, 무료 Apple ID 계정)**: 실제 iPhone을 대상으로 빌드하면 두 에러가 났다 — (a) `Failed Registering Bundle Identifier: "devplaceholder.CFRNO3IL.MathSketch" cannot be registered ... not available`: Xcode가 타깃 생성 시 자동 부여한 `devplaceholder.<프로젝트해시>.<상품명>` placeholder 번들ID는 Apple 개발자 포털에 등록이 거부된다(유료 멤버십 유무와 무관하게 이 placeholder 패턴 자체가 문제). (b) `Provisioning profile "iOS Team Provisioning Profile: *" doesn't include signing certificate "Apple Development: Kim Minung (RCWSNGQMBH)"`: (a)의 결과로 생긴 매칭 안 되는 캐시된 프로파일 참조, (a)를 고치고 자동 서명이 재생성하면서 함께 해결됨. → `PRODUCT_BUNDLE_IDENTIFIER`를 앱 타깃은 `com.coulson.MathSketch`, 테스트 타깃은 `com.coulson.MathSketch.MathSketchTests`로 정상적인 역-DNS 문자열로 교체. 이후 실기기(iPhone, 무료 Apple ID 개인 팀, `DEVELOPMENT_TEAM=5Z8G42AVKD`) 빌드·설치·실행·테스트(66개) 전부 통과 확인 — **유료 Apple Developer Program 결제 없이도 실기기 테스트가 정상 동작**한다(7일 주기 재서명 등 무료 계정의 일반적인 제약은 남아있음).

## UX 개선 (2026-10-13, 실사용 피드백)

실기기 테스트 후 사용자가 보고한 4가지 문제를 수정했다.

1. **인스펙터가 그리기 시작과 동시에 화면을 가림**: `InspectorView`가 `.safeAreaInset(edge: .bottom)`으로 항상 떠 있는 데다 선택 즉시 슬라이더 5개+색상피커까지 전부 펼쳐져 캔버스 절반을 가렸다. → 헤더(쉐브론+도형명+한 줄 요약)만 보이는 **접힌 상태를 기본값**으로 바꾸고, 헤더를 탭하면 펼쳐지도록 `isExpanded` 토글 추가. 선택이 바뀌면 다시 접힌 상태로 리셋. 명시적 선택 해제(xmark.circle.fill) 버튼도 추가.
2. **요소별 기본 크기가 제각각**: 23종 도형의 기본 매개변수가 서로 다른 스케일로 설계돼 있어(예: 사인파 기본 폭 200 vs 원 지름 80, 나선 반지름 150대) 같이 배치하면 크기 편차가 심했다. → `ShapeKind.parameterSchema`의 기본값을 전 도형이 지름 약 90~110 범위에 들도록 재조정(사인파 폭 200→100, 나선 반지름 공식 재계산, 베지어 고정 앵커 ±40→±50 등). 점/직선/면은 성격상 "지름" 개념이 달라 그대로 둠.
3. **겹치거나 인접한 요소를 탭해도 엉뚱한 것이 선택됨**: `elementID(at:)`가 "확장된 바운딩 박스를 z-순서 역순으로 처음 맞는 것" 방식이라, 패딩(±14pt)된 박스끼리 겹치면 실제로 가까운 도형이 아니라 위에 있는(zIndex 큰) 도형이 항상 이겼다. → 바운딩 박스 대신 **탭 지점에서 각 도형의 실제 경로(선분/폴리곤)까지의 최단 거리**를 계산해 가장 가까운 도형을 선택하도록 `CanvasView`를 재작성(동일 거리일 때만 zIndex로 타이브레이크). `fill` 도형은 내부 터치 시 거리 0(point-in-polygon).
4. **수식 패널의 "느낌" 개선**: 합성 수식 패널이 프로그래밍 DSL 텍스트(`circle(r: 50) · rotate(35)`)만 보여줘 작품이 아니라 코드처럼 읽혔다. → 표시 전용 포맷터 `ArtisticFormulaFormatter`를 신설해, 전체 그림을 "이 그림을 이루는 점들의 집합:" 머리말 + 각 요소를 𝑃₁(𝑡), 𝑃₂(𝑡)… 로 번호 매긴 이탤릭 수학 기호(𝑥, 𝑦, 𝑡) 표기 + 자연어 변형 주석(예: "회전 35°")으로 보여주는 한 편의 수식 선언문처럼 타이포그래피를 다듬었다. 원본 파싱 가능한 DSL 텍스트는 접이식 "원본 수식(복사·붙여넣기용)" 섹션으로 내려 복사/붙여넣기 용도로만 남겼다 — 파싱·왕복 변환 로직은 전혀 바뀌지 않았다.

## 2차 UX 개선 (2026-10-13, 추가 피드백 4건)

1. **수식을 생략 없이 끝까지**: 바로 전 라운드의 `ArtisticFormulaFormatter`가 (a) 일부 도형(정다각형/별다각형/베지어/에피사이클로이드 등)은 설명 문구("정5각형, r=50")로 뭉뚱그렸고, (b) `FormulaBarView`가 `.lineLimit(8)`로 "..." 잘림을 허용하고 있었다. → `ShapeKind.formulaExpression`을 23종 전부 진짜 닫힌형 매개변수 방정식으로 다시 썼다: 정다각형/별다각형은 바닥함수(⌊⌋)를 쓴 구간별 보간 공식, 베지어는 번스타인 다항식에 고정 앵커 좌표까지 전부 대입한 완전식, 선분/반직선/꺾은선도 벡터 보간 공식으로 표현. 나선류(spiral/logSpiral/rose/cardioid/epicycloid/hypocycloid)는 극좌표 `r=...` 한 줄 대신 `𝑥(θ), 𝑦(θ)` 쌍 + 각도 범위까지 전부 표기. `FormulaBarView`의 `lineLimit`는 제거하고 `.fixedSize(horizontal:false, vertical:true)`로 전체 높이를 항상 확보하도록 변경.
2. **실행 취소 / 다시 실행 / 전체 지우기**: `SketchModel`에 undo/redo 스택(최대 50개) 추가. 핵심 설계: 매 `onChanged` 틱이 아니라 **제스처 1회(혹은 유의미한 변화가 생긴 시점)당 스냅샷 1개**만 쌓는다 — `beginContinuousEdit()`/`endContinuousEdit()`를 드래그·핀치·회전 제스처와 슬라이더의 `onEditingChanged`에 연결하고, 순수 탭(이동량 0)은 스냅샷을 찍지 않도록 임계값(이동 1pt/배율 1%/회전 0.5° 이상)을 둬 무의미한 undo 엔트리가 쌓이지 않게 했다. 툴바에 실행취소·다시실행(leading) + 선택삭제·전체지우기(trailing, 확인 알림 포함) 버튼 추가.
3. **앱 아이콘(iOS/iPadOS + visionOS 대비)**: 외부 이미지 생성 도구 없이, 앱 자신의 `SketchCanvasRenderer`/`ShapeKind.rose`로 그린 흰 꽃잎 마크를 보라→자홍→주황 그라디언트 위에 얹어 `ImageRenderer`로 1024×1024 PNG를 렌더링(`RunCodeSnippet`로 임시 SwiftUI 뷰를 실행해 실제 파일시스템에 PNG를 직접 기록하는 방식 — 이 환경에 이미지 생성 도구가 따로 없어도 앱이 이미 가진 렌더링 파이프라인으로 충분했다). `AppIcon.appiconset/Contents.json`을 플랫폼별(`ios`, `visionos`) 항목이 같은 1024 이미지를 가리키도록 구성해 — Apple 문서상 visionOS도 단일 1024 이미지면 충분 — 향후 visionOS 타깃이 생겨도 바로 재사용 가능하게 준비했다.
   - **미해결 블로커**: 자산 자체는 커밋돼 있지만, `ASSETCATALOG_COMPILER_APPICON_NAME`(App Icon Source) 빌드 설정을 이 환경의 `UpdateTargetBuildSetting` 도구가 "Unknown build setting"으로 거부해 자동 연결하지 못했다(Apple 공식 문서는 이 설정명이 현재도 유효하다고 확인되므로 도구 쪽 화이트리스트 누락으로 보인다). pbxproj를 직접 텍스트 편집하는 우회도 시도하지 않았다 — Xcode가 열려 있는 동안 프로젝트 파일을 직접 건드리면 손상 위험이 있어 금지된 조작이기 때문이다. **사용자가 Xcode에서 타깃 → General → App Icons and Launch Screen → App Icon Source를 "AppIcon"으로 선택하는 수동 작업 한 번이 필요하다.**
4. **수식의 "느낌"을 레퍼런스와 동일하게**: 1차 라운드의 요약형 표기(예: "별 5개 꼭짓점, rₒ=50")를 긴 사용자 지정 레퍼런스가 지향하는 것과 같은 "생략 없는 전체 트리고노메트릭 방정식" 스타일로 교체(위 1번 항목과 동일 작업). 레퍼런스의 구체적 출처는 사용자 요청에 따라 코드·커밋·문서 어디에도 이름을 남기지 않았다.

## visionOS 레이어드 아이콘 조사 (2026-10-13)

사용자가 "visionOS용 앱 아이콘을 Apple 문서에 맞게 완성"을 요청해, 단일 이미지보다 더 정확한 구현을 시도했다.

- **Apple 공식 문서로 확인한 사실**: visionOS 앱 아이콘은 배경 레이어 + 그 위에 1~2개 레이어(최대 3layer)로 구성되는 것이 정식 권장 방식이며("A visionOS app icon includes a background layer and one or two layers on top... shadows... alpha channel... embossed appearance"), 이 레이어 구성은 **Icon Composer가 아니라 에셋 카탈로그의 "이미지 스택"**으로 만든다("For tvOS and visionOS targets that still use an AppIcon asset catalog..."). 단, 같은 문서에서 "단일 1024×1024 이미지 한 장"도 명시적으로 유효한 방법이라고 밝히고 있다("For visionOS, you need to supply a single 1024x1024 pixel asset") — 즉 둘 다 "Apple 문서에 맞는" 방법이다.
- **직접 시도**: 흰 꽃잎(앞)·반투명 그림자(중간)·그라디언트(뒤) 3장을 렌더링하고, `AppIcon.imagestack/{Back,Middle,Front}.imagestacklayer/Content.imageset/...png` + 각 단계 `Contents.json`을 추정 스키마로 직접 구성해 실제로 커밋 전에 **빌드해서 actool 로그로 검증**했다. 결과: actool이 이 폴더를 전혀 인식하지 않음(로그에 흔적이 없음 — 기존 `.appiconset`의 visionOS 항목에는 경고가 남았던 것과 대조적) → 확장자/스키마 추정이 틀렸다는 뜻. Apple 공식 문서는 이 내부 포맷을 JSON 스키마로 공개하지 않고 "Xcode에서 Add 버튼으로 레이어를 추가하고 Finder에서 이미지를 드래그하라"는 GUI 절차만 안내한다 — 즉 **이 포맷은 애초에 텍스트로 직접 작성하도록 문서화되어 있지 않다.**
- **최종 처리**: 작동하지 않는 추정 구조는 제거하고, 렌더링된 3장(Back/Middle/Front)을 `Media/AppIconLayers-VisionOS/`에 일반 PNG 소스 파일로 보관했다 — visionOS 타깃이 생기고 나서 Xcode Asset Catalog 편집기에 이 3장을 그대로 드래그해 넣으면 Apple이 문서화한 정식 절차 그대로 완성된다. 기존 `AppIcon.appiconset`(ios+visionos 플랫폼 항목이 같은 단일 1024 이미지를 가리키는 구성)은 그대로 유지 — 이것 자체로 "Apple 문서가 명시한 visionOS 유효 방법" 중 하나이므로 틀린 것이 아니다.
- **교훈**: Xcode 자산 카탈로그의 특수 번들 타입(이미지 스택 등)은 Apple이 공개 문서로 스키마를 제공하지 않는 경우가 있다 — 이럴 때는 추측으로 텍스트를 작성하지 말고, (a) 빌드해서 actool 로그에 흔적이 남는지로 최소 검증하거나, (b) Apple이 실제로 보장하는 대체 경로(이 경우 단일 이미지)로 완성하고 나머지는 "GUI로 드래그만 하면 되는 준비된 소스"로 넘기는 것이 안전하다.

## 앱 아이콘 전 플랫폼 완성 (2026-10-13, 저녁)

- 위 "미해결 블로커" 해결: 타깃 Debug/Release에 `ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon` 추가.
- visionOS 이미지 스택 실패 원인: `.imagestack`/`.imagestacklayer`는 tvOS 형식. visionOS는 `AppIcon.solidimagestack/{Front,Middle,Back}.solidimagestacklayer/Content.imageset`(`idiom: vision`, `scale: 2x`, 1024×1024 PNG, Back은 불투명)이 맞는 형식이라 이 구조로 `Media/AppIconLayers-VisionOS/` 3장을 연결했다. `AppIcon.appiconset`의 `platform: visionos` 항목은 제거.
- `AppIcon.appiconset`에 iOS 다크(투명 배경)·틴티드(그레이스케일) 변형과 macOS 16–1024 전 크기를 추가. 기존 `AppIcon-1024.png`는 그대로 유지.

## Phase 10 — 픽셀 수식 모드 (2026-10-16, PRD FR-10)

계기: 사용자가 수학 예술 작품의 픽셀 색 정의 수식(LaTeX, `\mathrm{rgb}\Big(F(H_0(\tfrac{m-1000}{500}, …)), …\Big)` + 정의 11개, 2000×1200)을 "수식으로 그리기"에 붙여넣자 `51열: 알 수 없는 문자 '×'` 오류. 원인은 오타가 아니라 **그 수식이 SketchFormula DSL이 아닌 전혀 다른 종류(픽셀 함수)** 라는 것 — 그래서 별도 모드로 구현했다.

- [x] T10.1 `LaTeXTokenizer`(전처리기: `\mathrm{rgb}`→rgb, `\left|`/`\right|`→⟦⟧, `\lfloor`→⌊, `\Big(`/`\left(`→(), `\tfrac`→`\frac`, `\,`→공백, `×`/`\cdot`→*, `−`→-; 토큰: 한 글자 식별자, 예약어 rgb, `\command`, 숫자) · `PixelFormulaAST`(`PixelExpr`, `PixelFunction`, `PixelFormulaProgram`, `freeVariables`) · `PixelFormulaParser`(서두 산문 무시, `rgb`부터 최상위 쉼표로 문장 분리, `where`/`and` 제거, 2패스 — 정의 이름 수집 후 파싱, 병치 곱셈, `^{}`, `\frac`, `\sqrt`, `|…|` 중첩(그룹 진입 시 열린 바 카운트 리셋), `\sum` 본문 = 한 항, `\sin^6(…)`, `e^{}`→exp, 자유 변수/함수 정의 검증) · `PixelFormulaEvaluator`(CPU 기준 평가기, 호출마다 새 환경, 합 반복 10만 회 상한, 음수 밑 홀수 정수 지수 부호 유지 `signedPow`).
- [x] T10.2 `MetalShaderTranspiler`(전방 선언 + 사용자 함수 `fn_X(아래첨자…, 매개변수…)` + `\sum` 헬퍼 `sum_N(자유변수…)` 후위 순서 방출 + `ipow`/`spow` + `sanitize` + 64행 밴드 커널) · `PixelFormulaRenderer`(`makeLibrary(source:)` + `mathMode = .safe`/`precise`, 파이프라인 캐시, 공유 버퍼→`CGImage`, `Task.detached` 격리, 밴드 사이 취소 확인, Metal 없을 때 CPU 폴백 64px 폭). 측정: 샘플 2000×1200 전체 렌더 **0.34초**(Mac GPU, 시뮬레이터 컨텍스트), 셰이더 컴파일 약 2.2초(최초 1회, 소스별 캐시).
- [x] T10.3 통합 — `PixelFormulaArtwork {source,width,height,definitionCount}`(Codable, 이미지는 저장하지 않음), `SketchModel.pixelFormula/pixelFormulaImage/pixelRenderPhase`, `applyPixelFormula(source:)`(파싱 → 실행취소 스냅샷 → 1/4 미리보기 → 전체 렌더, 소스별 이미지 캐시 4장), `clearPixelFormula()`, `restore(elements:pixelFormula:)`, 실행취소 스택을 `CanvasSnapshot {elements, pixelFormula}`로 승격, `clearAll()`은 배경까지. `loadFromFormulaInput()`이 `rgb`/`\frac`/`\sum` 등을 보고 픽셀 파서로 라우팅. Core Data `pixelFormulaJSON` 옵셔널 속성(경량 마이그레이션 명시), SwiftData `SavedSketch.pixelFormulaJSON`, 썸네일·캔버스 배경(`SketchDrawing.drawBackdrop` 종횡비 맞춤), 상세 화면 LaTeX 원문 표시, 수식 패널 상태 줄 + LaTeX 원문 전체(접이식, 기본 펼침) + 지우기 버튼, 입력 시트의 "예시 픽셀 수식 넣기" 버튼(`PixelFormulaSamples.sample` — 사용자가 붙여넣은 원문 그대로를 픽스처 겸 예시로 번들).
- [x] T10.4 테스트 17개 추가(총 83개 통과): 전처리기 정규화, 토크나이저 글자 분리, F(0.5)=127/F(1.5)=255/F(−0.1)=0, Σ 포함 범위·병치 곱셈 결합 순위·sin²+cos²=1, 맨 `|…|` 중첩/곱셈, `e^{}`·`\pi`, 샘플 전체 파싱(정의 순서 F H B T K A L U V P Q, `L_{u,s}` 아래첨자), DSL/픽셀 판별, 미정의 이름·인자 수 불일치·rgb 누락 거부, `signedPow`, MSL 소스 구조(함수 시그니처·sum 헬퍼·`v_e` 없음·`ipow`/`spow`), **GPU 셰이더 컴파일 + 100×60 렌더 결과를 CPU 평가기와 100개 픽셀 비교(허용 불일치 ≤3)**, Artwork JSON 왕복, SavedSketch 보존.
- 설계 메모: (1) LaTeX의 `|` 는 여는지 닫는지 문맥으로만 알 수 있어, 파서가 "열린 바 개수"를 추적하고 괄호/중괄호/함수 인자 그룹에 들어갈 때 0으로 리셋한다 — `\frac{Q}{|P|}`가 바깥 `|…|` 안에 있어도 올바르게 파싱된다. (2) `Z(1)`처럼 정의되지 않은 함수는 문법상 `Z·1`로 읽히므로, 파서가 아니라 **자유 변수 검증**("rgb 안에 정의되지 않은 이름 'Z'")에서 잡는다. (3) GPU는 float32라 `cos(32s²)`(s=50이면 인자 8만 라디안)에서 double인 CPU와 수 픽셀 차이가 날 수 있다 — 평탄 영역은 정확히 일치하므로 테스트는 불일치 상한으로 검증한다. (4) 사용자 수식의 렌더 결과(흰 바탕에 보라빛 원 2개 + 아래로 뻗은 검은 원뿔)는 CPU/GPU가 일치하며 LaTeX 원문을 그대로 따른 결과다. 원작 이미지가 없어 작품과의 시각적 일치는 확인하지 못했다.
- 수동 QA(iPhone 16 시뮬레이터): 입력 시트 → 예시 넣기 → 렌더링 → 배경 표시·상태 줄("GPU 0.8초")·LaTeX 원문 전체(1326pt, 생략 없음)·지우기·실행 취소/다시 실행 복원·배경 위에 도형 드롭·갤러리 저장(썸네일에 배경 합성)·상세 화면 LaTeX 섹션·재실행 시 드래프트에서 배경 자동 복원 확인. 스크린샷 `Media/Screenshots/phase11-pixel-formula.png`, `phase11-pixel-formula-sheet.png`.
- **QA에서 잡은 버그**: 첫 "렌더링" 탭에서 앱 크래시 — `MTLValidateFeatureSupport: 'Dispatch Threads with Non-Uniform Threadgroup Size is not supported on this device'`. `dispatchThreads(_:threadsPerThreadgroup:)`는 비균일 스레드그룹을 지원하는 GPU 패밀리에서만 쓸 수 있고, 시뮬레이터 Metal 디바이스(+디버그 스킴의 API 검증 레이어)는 어설션으로 중단한다(스로우가 아니라서 CPU 폴백도 타지 않음). 수정: 그리드를 스레드그룹 단위로 올림한 `dispatchThreadgroups(_:threadsPerThreadgroup:)`로 바꾸고, 유니폼에 `bandRows`를 넣어 커널이 넘치는 스레드를 스스로 버리게 했다. 교훈: `RunCodeSnippet`(Mac 호스트 GPU)에서 잘 돌아도 시뮬레이터/실기기 GPU 패밀리 제약은 별개다 — Metal 코드는 반드시 시뮬레이터에서 한 번 실행해 볼 것.

## 알려진 설계 메모

- "비틀기"는 수학적으로는 전단(shear) 변형이다. UI 라벨은 사용자 친화적으로 "비틀기"를 쓰되, 수식 표기는 `shear(shx, shy)`로 정확히 기술한다 (PRD FR-2).
- Core Data(드래프트 자동저장)와 SwiftData(갤러리)를 분리한 이유: 드래프트는 고빈도·저수명 쓰기(제스처마다)이고 갤러리는 저빈도·고수명 쓰기(명시적 저장)라 접근 패턴이 다르다 — 하나의 스토어로 합치면 고빈도 쓰기가 갤러리 쿼리 성능에 영향을 줄 수 있어 분리했다.
- **색상 ≠ 수식 (2026-10-13 변경)**: 처음에는 색도 합성 수식에 `color(#hex)` 토큰으로 인코딩할 계획이었으나, 사용자 요청으로 방향을 바꿨다. 이제 수식은 순수 기하(도형+변형)만 표현하고, 색은 장식 전용 + "팔레트 서명"(PaletteNamer가 감성적 한글 이름 부여)으로 별도 표현한다. 수식만으로는 색이 복원되지 않으며, 색까지 완전 복원하려면 갤러리의 전체 JSON을 거쳐야 한다 — 이 트레이드오프는 의도된 설계다.
- 기존에 "선분"을 가리키던 ShapeKind 이름 `line`은 기본 요소의 새 "직선(`line`, y=mx+b)"과 충돌해 `segment`로 개명했다.
- Core Data 모델을 `.xcdatamodeld` 대신 코드(`NSManagedObjectModel`/`NSEntityDescription`)로 정의한 이유: 이 환경의 Xcode 도구가 특수 번들 리소스(.xcdatamodeld)를 직접 편집하는 경로를 제공하지 않아, 더 이식성 있고 한 파일로 리뷰 가능한 코드 기반 모델을 택했다.
- **다음 작업**: Phase 5 T5.3(프리셋), Phase 7 T7.2(Dynamic Type 검증), Phase 8 T8.3(iPad 시뮬레이터 검증, 호스트 이슈 해소 후), Phase 10 후속(픽셀 수식 PNG 내보내기, `\begin{cases}` 조건식, 렌더 진행률 표시).
