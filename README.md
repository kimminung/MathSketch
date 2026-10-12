<div align="center">

# MathSketch

**수식으로 그림을 그리고, 그림을 다시 하나의 수식으로 — 점·선·면부터 극좌표 곡선까지, 23종의 기하 요소를 조립하는 iOS/iPadOS 앱**

![Swift](https://img.shields.io/badge/Swift-5-orange?logo=swift)
![Platform](https://img.shields.io/badge/platform-iOS%20%7C%20iPadOS-lightgrey)
![iOS](https://img.shields.io/badge/iOS-27.0%2B-blue)
![License](https://img.shields.io/badge/license-Apache%202.0-green)
![Tests](https://img.shields.io/badge/tests-66%20passed-success)

<img src="Media/Screenshots/phase3-canvas-overview.png" width="30%"> <img src="Media/Screenshots/phase4-inspector-sliders.png" width="30%"> <img src="Media/Screenshots/phase6-gallery-detail.png" width="30%">

</div>

## 목차

- [소개](#소개)
- [핵심 기능](#핵심-기능)
- [스크린샷](#스크린샷)
- [아키텍처](#아키텍처)
- [요구 사항 및 실행](#요구-사항-및-실행)
- [테스트](#테스트)
- [알려진 제한사항](#알려진-제한사항)
- [참고 프로젝트](#참고-프로젝트)
- [라이선스](#라이선스)

## 소개

[`Formula Simplification`(Mathigram)](https://github.com) 프로젝트가 "그림 → Fourier 급수 수식"을 다뤘다면, **MathSketch**는 반대 방향이다: 점·선·면 같은 기본 기하 요소부터 원, 별, 사인파, 장미 곡선 같은 복잡한 매개변수 곡선까지 **23종의 "수식을 가진 도형"**을 팔레트에서 캔버스로 끌어와 조립하고, 이동·비균일 스케일·회전·비틀기(전단) 변형과 색을 입혀 하나의 그림을 완성한다.

캔버스에 놓인 모든 요소의 **도형 + 변형**은 실시간으로 하나의 순수 기하 수식(`SketchFormula` DSL) 문자열로 합쳐지고, 이 문자열을 복사해 다시 입력하면 동일한 그림이 즉시 재구성된다. 색상은 의도적으로 수식에서 분리된 **장식 전용** 속성이며, 대신 캔버스에 쓰인 색들은 "팔레트 서명"이라는 감성적인 한글 이름 + 스와치로 따로 표현된다.

## 핵심 기능

- **23종 도형 팔레트** — 기본 요소(점·선·면), 직선류(선분/반직선/꺾은선/원호/베지어), 기본 폐도형(원/타원/정다각형/별), 삼각함수 곡선(사인/코사인/리사주), 극좌표·기하 곡선(나선/장미/카디오이드/아스트로이드/사이클로이드). 각 요소는 배치 즉시 자신의 매개변수 수식 라벨을 보여준다.
- **실시간 제스처 변형** — 드래그로 이동, 두 손가락 핀치/회전으로 균일 스케일·회전, 인스펙터 슬라이더로 비균일 스케일·비틀기(전단)·색상까지 — 변형 중 수식 라벨이 매 프레임 수치로 갱신된다.
- **하나의 합성 수식 (SketchFormula DSL)** — 캔버스 전체를 `도형(인자) · scale(...) · rotate(...) · shear(...) · translate(...) + ...` 형태의 한 줄 문자열로 직렬화/역직렬화. "수식으로 그리기"에 붙여넣으면 그림이 즉시 재구성된다.
- **팔레트 서명** — 색상은 수식에 포함되지 않는 장식 전용 속성. 대신 사용된 색을 모아 Lab 색공간 최근접 매칭으로 "노을빛 주황" 같은 한글 감성 이름을 붙이고, 갤러리 저장 시 제목으로 제안한다.
- **이중 영속성** — 작업 중 캔버스는 Core Data(고빈도 자동저장, Combine 디바운스)로 색까지 포함해 항상 복원되고, 완성작은 SwiftData 갤러리에 명시적으로 저장해 썸네일·수식·팔레트 서명과 함께 다시 열 수 있다.

## 스크린샷

<div align="center">
<img src="Media/Screenshots/phase3-canvas-overview.png" width="32%">
<img src="Media/Screenshots/phase4-inspector-sliders.png" width="32%">
</div>
<p align="center"><sub>캔버스 탭 — 팔레트(기본 요소 점·선·면 포함) · 캔버스 · 합성 수식 패널 / 요소 선택 시 인스펙터(스케일·회전·비틀기 슬라이더 + 색상, 수식 라벨 실시간 갱신)</sub></p>

<div align="center">
<img src="Media/Screenshots/phase6-gallery-grid.png" width="32%">
<img src="Media/Screenshots/phase6-gallery-detail.png" width="32%">
</div>
<p align="center"><sub>갤러리 그리드(팔레트 서명 기반 자동 제목 "숯빛 검정") / 상세 화면 — 합성 수식 전문 + 팔레트 서명 스와치, 캔버스로 열기·삭제</sub></p>

## 아키텍처

```
MathSketch/
  MathEngine/            # Formula Simplification에서 이식한 Lexer/AST/Evaluator/Parser +
                          # SketchFormulaParser/Formatter (DSL 확장, 색상 없음)
  SketchEngine/          # ShapeKind 카탈로그(23종), SketchElement, ElementTransform, ElementColor,
                          # SketchCanvasRenderer(point/stroke/fill), SketchDrawing, FormulaFormatter
  PaletteSignature/       # PaletteNamer(Lab 최근접 매칭 + 50종 감성 색 이름), PaletteSignature
  Model/                 # SketchModel (@Observable, Combine 디바운스 2단: 라벨 150ms / 자동저장 0.8s)
  Persistence/
    Draft/                # Core Data: DraftCanvasStore (단일 row, 코드로 정의한 모델)
    Gallery/               # SwiftData: SavedSketch
  Views/                 # CanvasView, PaletteView, InspectorView, FormulaBarView,
                          # PaletteSignatureView, SketchComposerView, GalleryView, SketchDetailView
  MathSketchApp.swift
  ContentView.swift
MathSketchTests/          # Swift Testing, 66개 테스트 (엔진 왕복 변환, 변형 수학, 팔레트 이름 결정성 등)
Docs/
  PRD-MathSketch.md        # 기술 PRD (FR-1~FR-9, FR-5a)
  TASKS-MathSketch.md      # Phase 0~9 태스크 로그 + 설계 변경 메모
Media/Screenshots/
```

## 요구 사항 및 실행

- Xcode 27, iOS 27 SDK
- `MathSketch.xcodeproj` 를 Xcode로 열고 `MathSketch` 스킴으로 iPhone 16 또는 iPad 시뮬레이터에서 실행 (⌘R)
- `TARGETED_DEVICE_FAMILY = "1,2"` (iPhone + iPad), macOS/visionOS 대상 아님

## 테스트

```
xcodebuild test -scheme MathSketch -destination 'platform=iOS Simulator,name=iPhone 16'
```

Swift Testing 기반 66개 테스트 전체 통과: MathEngine(Lexer/Parser/Evaluator 연산자 우선순위·0 나눗셈 등) · SketchFormula 왕복 변환(23종 도형 전체 + 변형 + 다중 요소 + 색상 미직렬화 확인) · ElementTransform 수학(항등/회전/점 예외/클램핑) · ShapeKind 매개변수 검증 · PaletteNamer 결정성 · SavedSketch 직렬화.

## 알려진 제한사항

- iPhone 16 시뮬레이터에서는 수동 QA로 전 기능(조립·제스처·합성 수식·역변환·팔레트 서명·저장·재실행 복원)을 검증했고, **실제 iPhone(유료 Apple Developer Program 미가입, 무료 개인 팀 서명)에서도 빌드·설치·실행·테스트 66개 전체 통과**를 확인했다. 초기에는 Xcode가 자동 부여한 `devplaceholder.*` placeholder 번들 ID 때문에 실기기 등록이 거부됐는데, 정상적인 역-DNS 번들 ID(`com.coulson.MathSketch`)로 바꿔 해결했다 — 유료 멤버십은 실기기 디버그 실행 자체에는 필요 없다.
- **iPad 시뮬레이터 검증은 이 환경에서 iPad 시뮬레이터를 새로 생성하는 도구 호출이 반복적으로 타임아웃되어 보류되었다** — iPad 기기/시뮬레이터가 이미 있는 환경에서는 동일 빌드로 바로 검증 가능할 것으로 예상된다 (`TARGETED_DEVICE_FAMILY`에 iPad 포함, 레이아웃은 가변 스택이라 깨지지는 않지만 iPad 전용 멀티컬럼 레이아웃은 아직 없음).
- 캔버스 조작은 드래그(이동) + 두 손가락 핀치/회전(균일 스케일/회전) + 인스펙터 슬라이더(비균일 스케일/비틀기/색)로 구현되어 있다 — PRD가 언급한 전용 모서리/회전/비틀기 "핸들" 오버레이 대신 이 조합을 택했다(Docs/TASKS-MathSketch.md 설계 메모 참고).

## 참고 프로젝트

MathEngine(Lexer/AST/Parser/Evaluator), `Canvas` 즉시모드 렌더링, SwiftData `Data`-JSON 직렬화 패턴을 `Formula Simplification`(Mathigram) 프로젝트에서 응용했다.

## 라이선스

Apache 2.0 — [LICENSE](LICENSE) 참고.
