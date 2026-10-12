# PRD — MathSketch

버전: v0.1
작성일: 2026-10-13
참고 프로젝트: `Formula Simplification`(Mathigram) — MathEngine, Canvas 렌더링, SwiftData 영속성 패턴을 응용

## 1. 배경과 비전

`Formula Simplification`은 "그림 → 수식"(Fourier 근사) 방향을 다뤘다. MathSketch는 반대로, **"수식 조각을 쌓아 그림을 만들고, 그 그림 전체를 하나의 수식으로 환원"**하는 것이 핵심이다.

사용자는 원, 선분, 별, 사인파 같은 "수식을 가진 도형 요소"를 팔레트에서 캔버스로 드래그해 배치하고, 늘이기·회전·비틀기 같은 변형과 색상을 적용한다. 각 요소는 자신의 변형·색이 반영된 고유 수식을 실시간으로 보여주며, 캔버스에 놓인 모든 요소는 하나의 **합성 수식(composite formula)** 문자열로 합쳐진다. 이 합성 수식을 복사해서 다시 입력하면, 동일한 그림이 한 번에(파싱 즉시) 재구성되어야 한다 — 즉 그림과 수식은 서로의 완전한 가역 표현이다.

## 2. 목표 / 비목표

**목표**
- G1. 20종 내외의 서로 다른 도형·선·기하 곡선을 팔레트로 제공하고, 각 도형은 배치 즉시 자신의 매개변수 수식을 라벨로 보여준다.
- G2. 이동·비균일 늘이기(스케일)·회전·비틀기(전단, shear) 제스처를 지원하고, 제스처가 진행되는 동안(끝난 후가 아니라) 해당 요소의 수식 라벨이 수치적으로 실시간 갱신된다.
- G3. 요소의 색상이 합성 수식 문자열에 가역적으로 인코딩된다 (`color` 수식 토큰).
- G4. 캔버스에 있는 모든 요소를 하나의 문자열(`SketchFormula` DSL)로 직렬화/역직렬화할 수 있고, 이 문자열을 입력란에 붙여넣으면 즉시 전체 그림이 재구성된다.
- G5. 앱이 종료되었다가 다시 실행되어도 편집 중이던 캔버스가 그대로 복원된다 (명시적 저장 없이도 유지).
- G6. 완성작은 갤러리에 명시적으로 저장할 수 있고, 썸네일·제목·합성 수식과 함께 다시 불러올 수 있다.
- G7. iPhone 16, iPad(13형 또는 11형) 시뮬레이터에서 전 기능이 동작함을 확인한다.

**비목표**
- 임의 코드 실행이나 외부 수식 라이브러리 연동 없음 (자체 Lexer/Parser/Evaluator만 사용).
- 사진에서 윤곽을 추출하는 Vision 기반 변환(참고 프로젝트의 Convert 탭)은 MathSketch의 1차 범위에 포함하지 않는다. 필요해지면 후속 Phase로 분리한다.
- 3D, 애니메이션 타임라인, 협업(iCloud 동기화)은 1차 범위 밖.
- macOS/visionOS 대응은 1차 범위 밖 (iOS/iPadOS만).

## 3. 사용자 시나리오

1. **조립**: 사용자가 팔레트에서 "별" 도형을 캔버스로 드래그한다. 배치되는 순간 `star(points: 5, r: 60)`와 같은 공식 라벨이 요소 옆에 나타난다. 두 손가락으로 모서리 핸들을 당겨 비균일하게 늘이면, 라벨의 스케일 계수가 실시간으로 바뀐다.
2. **변형**: 사용자가 비틀기 핸들을 드래그해 전단 변형을 적용하면 라벨에 `shear(0.18, 0)` 항이 나타나고, 회전 핸들로 35도 돌리면 `rotate(35)`가 추가된다. 색상 피커에서 주황색을 고르면 `color(#FF5733)`가 추가된다.
3. **합성**: 사용자가 원, 사인파, 별 세 요소를 배치한 뒤 하단 "합성 수식" 패널을 보면, 세 요소가 `+`로 연결된 하나의 `SketchFormula` 문자열이 실시간으로 표시된다.
4. **재구성**: 사용자가 이 합성 수식 문자열을 복사해 "수식으로 그리기" 입력창에 붙여넣고 그리기를 누르면, 세 요소가 정확히 같은 위치·크기·회전·색으로 한 번에 그려진다.
5. **지속성**: 사용자가 작업 중 앱을 백그라운드로 보내고 기기를 재부팅한 뒤 앱을 다시 열면, 직전에 배치하던 요소들이 그대로 캔버스에 있다.
6. **갤러리**: 사용자가 "저장"을 눌러 작품에 제목을 붙이면 갤러리에 썸네일로 나타나고, 탭하면 상세 화면에서 합성 수식 전문과 함께 다시 열거나 삭제할 수 있다.

## 4. 기능 요구사항

### FR-1. 도형 카탈로그 (ShapeKind)
다음 4개 분류, 20종 내외의 매개변수 도형을 제공한다. 각 도형은 로컬 좌표계 기준 매개변수 `t ∈ [0, 2π]` (또는 선형 도형은 `t ∈ [0,1]`)의 `x(t), y(t)` 정의와, 사람이 읽는 수식 표기(예: `x(t)=r·cos t`)를 함께 갖는다.
- **직선류**: 선분(`line`), 반직선(`ray`), 꺾은선(`polyline`, n개 제어점), 원호(`arc`, 시작각/끝각), 2차 베지어(`quadBezier`), 3차 베지어(`cubicBezier`)
- **기본 폐도형**: 원(`circle`), 타원(`ellipse`), 정다각형(`polygon`, 변의 수 3~12), 별다각형(`star`, 꼭짓점 수 + 내/외 반지름)
- **삼각함수 곡선**: 사인파(`sine`), 코사인파(`cosine`), 리사주 곡선(`lissajous`)
- **극좌표/기하 곡선**: 아르키메데스 나선(`spiral`), 로그 나선(`logSpiral`), 장미 곡선(`rose`, k값), 카디오이드(`cardioid`), 아스트로이드(`astroid`), 사이클로이드류(`epicycloid`/`hypocycloid`, 스피로그래프)

각 ShapeKind은 고유 매개변수(최대 6개 Double)를 가지며, 매개변수 범위를 벗어나면 안전하게 클램프한다(비정상 값으로 NaN 생성 금지).

### FR-2. 요소 변형 (ElementTransform)
요소마다 다음 변형을 독립적으로 가진다: 위치 `translate(tx, ty)`, 비균일 스케일 `scale(sx, sy)` (스케일 범위 0.1~8.0), 회전 `rotate(θ)` (도 단위, -180~180 랩어라운드), 전단(비틀기) `shear(shx, shy)` (-1.0~1.0). 최종 점은 `P' = R(θ)·Sh(shx,shy)·S(sx,sy)·P(t) + T` 순서로 계산한다 (순서는 고정, UI에서 설명).

### FR-3. 제스처 입력
- 한 손가락 드래그 → `translate` 갱신.
- 선택된 요소의 모서리 스케일 핸들 드래그 → 해당 축의 `scale` 갱신 (양 모서리 핸들로 sx/sy 독립 조절).
- 회전 핸들 드래그 또는 두 손가락 회전 제스처 → `rotate` 갱신.
- 전용 비틀기 핸들 드래그 → `shear` 갱신.
- 모든 제스처는 `DragGesture`/`RotateGesture`의 `onChanged`마다(제스처 종료를 기다리지 않고) 요소의 수식 라벨 문자열을 갱신한다. 라벨 갱신은 숫자 포맷팅만 하므로 디바운스 없이 매 프레임 반영 가능해야 한다 — 무거운 파싱이 필요한 합성 수식 재생성만 150ms 디바운스한다.

### FR-4. 요소 색상 (ElementColor)
- `ColorPicker`로 RGB(A) 선택, 내부적으로 `#RRGGBB` 16진 표기와 HSB 성분을 함께 보관.
- 합성 수식 문자열에는 `color(#RRGGBB)` 토큰으로 직렬화되며, 파싱 시 다시 `Color`로 복원된다.

### FR-5. SketchFormula DSL (합성 수식 — "하나의 수식")
기존 참고 프로젝트의 Lexer(숫자/식별자/`+-*/^`/괄호/쉼표)를 그대로 재사용하고, 다음을 확장한다:
- 함수 호출에 **이름 있는 인자**(`circle(r: 40)`)를 허용.
- 변형/색 **수정자 체인**을 `·`(가운데점) 또는 `*`로 연결: `shapeCall · scale(sx,sy) · rotate(θ) · shear(shx,shy) · translate(tx,ty) · color(#hex)`.
- 요소 여러 개는 `+`로 연결한 한 줄 문자열이 캔버스 전체를 표현하는 **단일 SketchFormula**가 된다. 예:
  `circle(r: 40) · scale(1.2, 0.8) · rotate(35) · shear(0, 0.15) · translate(120, 60) · color(#FF5733) + star(points: 5, r: 60) · rotate(10) · translate(-80, -40) · color(#33A1FF)`
- 파서는 이 문자열을 `[SketchElement]`로 역직렬화하고, 포맷터는 `[SketchElement]`를 위 문자열로 직렬화한다(왕복 변환 보장, 유닛 테스트로 검증).
- 요소 수 상한 200개, 수식 문자열 길이 상한 20,000자.
- "수식으로 그리기" 입력창에 유효한 SketchFormula를 붙여넣고 확정하면, 파싱 성공 시 캔버스 전체가 **그 즉시(디바운스 없이) 1회 렌더**로 교체된다. 파싱 실패 시 어떤 토큰/열에서 실패했는지 에러 배너로 표시한다 (참고 프로젝트의 `MathSyntaxError` 패턴 재사용).

### FR-6. 캔버스 & 렌더링
- SwiftUI `Canvas`로 그린다 (참고 프로젝트와 동일하게 커스텀 `Shape` 대신 즉시 모드 렌더링).
- 각 요소는 로컬 매개변수 샘플링(기본 128 샘플, 도형 복잡도에 따라 48~256으로 조정) 후 변형을 적용한 `Path`로 그린다.
- 선택된 요소는 바운딩 박스와 4개 스케일 핸들 + 1개 회전 핸들 + 1개 비틀기 핸들을 오버레이로 표시한다.

### FR-7. 영속성 — 작업 중 캔버스 (드래프트 자동저장)
- **Core Data** 단일 엔티티(`DraftCanvas`, 사실상 싱글턴 row)에 현재 캔버스의 `[SketchElement]`를 JSON `Data`로 저장한다.
- 저장 트리거는 **Combine**: 요소 변경(이동/변형/추가/삭제/색상)마다 `PassthroughSubject<Void, Never>`에 신호를 보내고, `.debounce(for: .seconds(0.8), scheduler: DispatchQueue.main)`로 묶어 백그라운드 `NSManagedObjectContext.perform`에서 저장한다. 제스처 중 수식 라벨 갱신(FR-3)과는 별개의 디바운스 큐다.
- 앱 실행 시(`MyApp.swift`의 `init` 또는 최초 `onAppear`) `DraftCanvas`를 조회해 있으면 캔버스를 복원하고, 없으면 빈 캔버스로 시작한다.
- 앱이 강제 종료되어도 마지막 디바운스 저장 시점까지는 복원 가능해야 한다 (시뮬레이터에서 "앱 스와이프 종료 후 재실행" 시나리오로 검증).

### FR-8. 영속성 — 갤러리 (명시적 저장)
- **SwiftData** `@Model` `SavedSketch { title, createdAt, thumbnailData(.externalStorage), formulaText, elementCount }` — 참고 프로젝트의 `SavedArtwork` 패턴을 그대로 응용.
- 갤러리는 `@Query(sort: \SavedSketch.createdAt, order: .reverse)`로 그리드 표시, 상세 화면에서 "캔버스로 열기"(드래프트를 이 작품으로 교체) 또는 삭제.
- 썸네일은 `ImageRenderer`로 캔버스를 PNG화해 저장.

### FR-9. 상태 관리 / 바인딩
- 루트 상태는 `@Observable final class SketchModel`로 관리하고 `.environment`로 주입.
- 요소 리스트, 선택 인덱스, 인스펙터(스케일/회전/비틀기/색상 슬라이더 및 피커)는 `@Bindable` + `Binding`으로 뷰에 연결한다 (참고 프로젝트 `SettingsView`/`DrawView` 패턴).
- Combine은 FR-7의 자동저장 디바운스, 그리고 "합성 수식 패널" 텍스트 재계산 디바운스(150ms, 요소 변경 시)에 한정해서 사용한다 — 무분별한 `ObservableObject`/`@Published`로의 회귀는 금지.

## 5. 비기능 요구사항

- **성능**: 요소 추가/변형 시 메인 스레드는 포인트 변형(곱셈 수준의 가벼운 연산)만 담당하고, SketchFormula 전체 재파싱/재직렬화처럼 무거운 작업은 `Task.detached(priority: .userInitiated)`로 분리한다 (참고 프로젝트 `DrawModel.render` 패턴).
- **정확성**: MathLexer/Parser/Evaluator 확장부(이름 있는 인자, 수정자 체인, 색 토큰)에 대해 Swift Testing으로 왕복 변환(직렬화→파싱→동일 요소 목록) 테스트를 반드시 둔다.
- **접근성**: 모든 팔레트 버튼·핸들에 `accessibilityLabel`/`accessibilityValue`(현재 각도/배율 등 수치 포함)를 부여하고, Dynamic Type을 지원한다.
- **멀티 디바이스**: iPhone 16과 iPad(세로/가로, 멀티태스킹 분할 화면 최소 대응)에서 레이아웃이 깨지지 않아야 한다 — `TARGETED_DEVICE_FAMILY = "1,2"`.
- **데이터 안전성**: Core Data 드래프트 저장과 SwiftData 갤러리 저장은 서로 다른 스토어이므로, 하나가 손상되어도 다른 하나에 영향이 없어야 한다(독립 컨테이너).

## 6. 아키텍처 개요

```
MathSketch/
  MathEngine/           # 참고 프로젝트에서 이식: Lexer, AST, Parser, Evaluator, FormulaFormatter
  SketchEngine/          # 신규: ShapeKind 카탈로그, SketchElement, ElementTransform, ElementColor,
                         #       SketchFormulaParser/Formatter(DSL 확장), SketchCanvasRenderer
  Model/                 # SketchModel(@Observable), InspectorModel, GalleryModel
  Persistence/
    Draft/               # Core Data: DraftCanvasStore (단일 row 자동저장)
    Gallery/             # SwiftData: SavedSketch, @Query 기반 조회
  Views/
    CanvasView.swift     # 메인 캔버스 + 제스처 핸들
    PaletteView.swift    # 도형 팔레트 (드래그 소스)
    InspectorView.swift  # 선택 요소의 변형/색 슬라이더
    FormulaBarView.swift # 합성 수식 표시 + "수식으로 그리기" 입력
    GalleryView.swift
    SketchDetailView.swift
  MathSketchApp.swift
  ContentView.swift
```

## 7. 라이선스

Apache 2.0 (참고 프로젝트와 동일).
