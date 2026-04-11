# Spatial Composer 제스처 입력 툴 + 실행 계획

작성일: 2026-04-11
대상: Codex / 개발자
상태: 실행용 초안 (바로 구현 시작 가능)

---

## 0. 최종 결정

이 프로젝트는 다음처럼 나눈다.

1. **메인 오디오 엔진**: C++20 + `miniaudio` + `Steam Audio`
2. **제스처 입력/경로 저작 툴**: **Godot 4.6.2 stable** 별도 companion app
3. **교환 포맷(v1)**: JSON 파일 import/export
4. **실시간 연동(v1.1 이후)**: 로컬 WebSocket 또는 UDP 추가

### 왜 이렇게 정했는가

- **Unity**는 Splines와 센서 입력이 가능하지만, 라이선스가 폐쇄형이고 무료 사용에도 매출/펀딩 한도 같은 조건이 붙는다. 이번 프로젝트의 기준인 “오픈소스 위주, 상업 사용 가능, 초기 비용 0”과 잘 맞지 않는다.
- **Unreal**도 Sequencer와 3D authoring은 강력하지만, 라이선스/로열티 구조가 더 무겁고 설치·빌드 규모도 크다. 제스처 입력 companion tool 용도로는 과하다.
- **Godot**는 MIT 라이선스라서 상업 사용이 단순하고, Path3D/Curve3D/Animation/Input/WebSocket/모바일 export까지 이미 갖고 있어 **제스처 입력 툴**에 가장 적합하다.
- 반대로 **메인 오디오 엔진 전체를 Godot 안에서 만들지는 않는다.** 이 프로젝트의 핵심은 공간 작곡용 경로 평가, 오프라인 렌더, 향후 오디오 엔진 확장성이므로, 전용 C++ 오디오 스택으로 분리하는 편이 구조적으로 낫다.

---

## 1. Codex에게 내릴 핵심 지시

Codex는 다음 방침을 반드시 따른다.

### 필수 제약

- **Unity, Unreal, JUCE, Tracktion을 초기 버전에 넣지 말 것**
- **Godot는 제스처 입력/경로 저작용 companion tool로만 사용할 것**
- 메인 오디오 엔진은 **C++20 + CMake** 기반으로 만들 것
- v1에서는 **파일 기반 JSON import/export를 먼저 완성**할 것
- 실시간 네트워크 연동은 **JSON round-trip이 안정화된 뒤** 붙일 것
- 의존성은 기본적으로 **MIT / BSD / ISC / Apache-2.0 / BSL-1.0 / public domain** 계열만 허용
- **GPL/LGPL/AGPL 의존성은 추가하지 말 것**. 꼭 필요하면 먼저 `docs/ADR-*.md`로 사유를 기록할 것
- 모든 서드파티 의존성은 `THIRD_PARTY.md`에 **버전, 라이선스, 출처**를 기록할 것

### 1차 목표

사용자가 다음을 할 수 있어야 한다.

- 3D 공간에서 **listener 1개**와 **source 여러 개**를 배치
- source/listener 각각에 대해
  - 수동 키프레임 편집
  - 마우스/키보드 기반 제스처 녹화
  - 매크로 경로 생성(orbit, fly-by, spiral, figure-8)
- 결과를 **JSON 파일**로 저장
- C++ preview renderer가 이 JSON을 읽어서 **오프라인 binaural preview WAV**를 렌더

---

## 2. 기술 선택

## 2.1 제스처 입력/저작 툴

**선택: Godot 4.6.2 stable**

역할:
- 3D scene view
- source/listener 배치
- 경로 편집
- 제스처 녹화
- 매크로 생성
- JSON export/import

Godot를 고른 이유:
- MIT 라이선스
- 3D 경로 시스템(Path3D, Curve3D)
- Animation/track 기반 데이터 모델이 이미 익숙함
- Input 시스템으로 마우스/키보드/게임패드/모바일 센서 확장 가능
- WebSocket 내장
- 데스크톱/모바일 export 가능

**중요**: Godot Editor plugin으로 시작하지 말고, **standalone Godot app**으로 시작할 것.

이유:
- 구현 범위가 작고 빠르다
- 배포가 단순하다
- 나중에 mobile recorder로 분화하기 쉽다
- 메인 오디오 엔진과 결합도를 낮출 수 있다

## 2.2 메인 오디오 엔진

**선택: C++20 + miniaudio + Steam Audio**

역할:
- 프로젝트 JSON 로드
- 시간 t에서 source/listener transform 평가
- 샘플/블록 단위 렌더 루프
- binaural preview 렌더
- 오프라인 WAV 출력

초기 범위:
- direct sound binaural preview 우선
- reflections / occlusion / room simulation은 2단계

## 2.3 교환 포맷

**선택: JSON 파일**

v1에서 JSON을 먼저 택하는 이유:
- 디버깅이 쉽다
- Git diff가 가능하다
- Godot/C++ 양쪽에서 쉽게 처리 가능하다
- live link가 없어도 end-to-end 검증이 가능하다

## 2.4 실시간 연동

**v1에서는 제외**

v1.1 이후 순서:
1. 로컬 파일 round-trip 검증
2. 로컬 WebSocket 또는 UDP로 preview sync 추가
3. 필요시 모바일 remote/controller 추가

---

## 3. 라이선스 정책

### 승인된 기본 스택

| 구성요소 | 선택 | 라이선스 | 사용 방침 |
|---|---|---:|---|
| Gesture tool | Godot 4.6.2 | MIT | 채택 |
| Audio core | miniaudio | Public domain 또는 MIT No Attribution | 채택 |
| Spatial renderer | Steam Audio 4.8.1 | Apache-2.0 | 채택 |
| JSON(optional) | nlohmann/json | MIT | 허용 |
| Live link(optional) | standalone Asio | BSL-1.0 | 허용 |

### 금지/보류

- Unity: 초기 무료 사용은 가능하지만 폐쇄형 라이선스이며 조건이 붙으므로 **초기 채택 금지**
- Unreal: 무료 시작 가능하지만 로열티/seat 고려가 필요하므로 **초기 채택 금지**
- GPL/LGPL/AGPL 계열: 이번 단계에서는 **추가 금지**

### Codex 주의사항

- 새 의존성을 추가하면 반드시 `THIRD_PARTY.md`와 `LICENSES/` 디렉토리를 업데이트할 것
- 라이선스가 애매하면 추가하지 말고 먼저 문서화할 것
- 네트워크/OSC 때문에 LGPL 라이브러리를 넣지 말 것. 초기에는 JSON과 permissive dependency만 사용할 것

---

## 4. 아키텍처

```text
+----------------------------+
| Godot Companion App        |
| - Scene View               |
| - Keyframe Editor          |
| - Gesture Recorder         |
| - Macro Path Generator     |
| - JSON Import / Export     |
+-------------+--------------+
              |
              | project.json
              v
+----------------------------+
| C++ Spatial Preview Engine |
| - Project Loader           |
| - Trajectory Evaluator     |
| - Audio Scheduler          |
| - Binaural Renderer        |
| - Offline WAV Writer       |
+----------------------------+
```

### 원칙

- 저작(authoring)과 렌더(rendering)를 분리한다.
- 경로 데이터의 단일 진실 원천(single source of truth)은 **JSON trajectory model**이다.
- Godot는 **UI/입력/시각화**, C++는 **오디오 렌더링**을 담당한다.

---

## 5. 데이터 모델

## 5.1 최상위 프로젝트 구조

```json
{
  "format_version": 1,
  "project": {
    "title": "demo",
    "sample_rate": 48000,
    "duration_sec": 30.0,
    "tempo_bpm": 120.0
  },
  "listener": {
    "id": "listener_main",
    "track": { ... }
  },
  "sources": [
    {
      "id": "src_cello",
      "audio_asset": "assets/cello.wav",
      "gain_db": 0.0,
      "track": { ... }
    }
  ],
  "groups": []
}
```

## 5.2 TrajectoryTrack

```json
{
  "space": "world",
  "interpolation": "bezier",
  "keys": [
    {
      "t": 0.0,
      "position": [0.0, 0.0, 0.0],
      "rotation_euler_deg": [0.0, 0.0, 0.0],
      "ease_in": "auto",
      "ease_out": "auto"
    },
    {
      "t": 2.5,
      "position": [1.2, 0.5, -2.0],
      "rotation_euler_deg": [0.0, 35.0, 0.0],
      "ease_in": "auto",
      "ease_out": "auto"
    }
  ]
}
```

### 허용값

- `space`: `world | listener | group`
- `interpolation`: `linear | bezier | catmull_rom`

### 설계 원칙

- **v1은 keyframe + spline 중심**
- 녹화 데이터(raw samples)는 내부 임시 데이터로 둘 수 있지만, **저장/교환 포맷은 keyframe curve**를 기본으로 할 것
- orientation은 v1부터 포함한다. listener는 방향 정보가 중요하기 때문이다.

---

## 6. 제스처 입력 모델

## 6.1 입력 방식

v1에서 반드시 지원할 것:

1. **수동 키프레임 편집**
2. **마우스 드래그 기반 제스처 녹화**
3. **매크로 경로 생성**

v2에서 추가:

4. 게임패드
5. 모바일 센서(gyroscope / accelerometer)
6. 라이브 네트워크 입력

## 6.2 제스처 녹화 파이프라인

제스처 녹화는 raw sample을 그대로 최종 저장하지 않는다.

### 녹화 단계

- 60 Hz로 위치/회전 샘플링
- 기록 대상: 선택된 source 또는 listener
- 녹화 중에는 ghost trail을 화면에 표시

### 후처리 단계

- 노이즈 감소(가벼운 smoothing)
- 점 수 축약(point simplification)
- 의미 있는 지점만 남겨 keyframe으로 변환
- spline 재구성
- 사용자가 수동 수정 가능해야 함

### 구현 메모

- point simplification은 **Ramer–Douglas–Peucker 계열** 또는 유사 알고리즘으로 충분
- 시간 축은 반드시 유지할 것
- 결과 curve는 사람이 다시 편집 가능한 형태여야 함

## 6.3 매크로 경로

v1 기본 제공 매크로:

- `orbit`
- `fly_by`
- `spiral`
- `figure_8`

각 매크로 공통 파라미터:

- 시작 시간
- 지속 시간
- 중심점
- 반지름/폭/높이
- 회전수 또는 속도
- easing
- 좌표 기준(`world`, `listener`, `group`)

매크로는 두 모드를 제공한다.

1. **Editable procedural clip**
2. **Bake to keys**

v1에서는 구현 부담을 줄이기 위해 아래처럼 시작해도 된다.

- 내부적으로 즉시 keyframe으로 bake
- 나중에 procedural clip 보존 기능 추가

---

## 7. UI 요구사항 (Godot Companion App)

필수 화면:

1. **3D Scene View**
2. **Track List**
3. **Timeline / Keyframe Lane**
4. **Inspector**
5. **Transport Bar (Play / Stop / Record / Scrub)**

### 최소 UX

- source는 서로 다른 색/아이콘으로 구분
- listener는 별도 아이콘으로 고정 표시
- 선택된 객체의 path만 강조 표시
- 현재 playhead 시간 표시
- path control point를 마우스로 직접 이동 가능

### 조작 규칙

- 좌클릭: 선택
- 드래그: 위치 이동
- 단축키 `K`: 현재 시간에 key 추가
- 단축키 `R`: record arm / record start
- 단축키 `M`: macro 생성 메뉴
- 스페이스: 재생/정지

---

## 8. 저장 포맷 / 파일 구조

권장 레포 구조:

```text
repo/
  apps/
    gesture_tool_godot/
    spatial_preview_cli/
  shared/
    schemas/
      project.schema.json
    examples/
      simple_orbit/
      listener_flythrough/
  docs/
    spatial_composer_gesture_plan.md
    THIRD_PARTY.md
    ADR/
  third_party/
    miniaudio/
    steam_audio/
    nlohmann_json/        # optional
    asio/                 # optional, live link 단계에서만
  LICENSES/
```

---

## 9. 구현 단계

## Phase 0 — 레포 스캐폴딩

### 목표

프로젝트 구조와 빌드/문서 기본틀을 만든다.

### 해야 할 일

- CMake 기반 `spatial_preview_cli` 생성
- Godot project 생성
- `docs/THIRD_PARTY.md` 작성
- `shared/schemas/project.schema.json` 초안 작성
- `shared/examples/simple_orbit/` 예제 추가

### 완료 조건

- 레포가 열리고 구조가 일관적이어야 함
- README에서 각 앱의 역할이 명확해야 함

## Phase 1 — JSON 중심 authoring pipeline

### 목표

Godot에서 경로를 만들고 JSON으로 저장한 뒤, C++가 그것을 읽을 수 있게 한다.

### Godot 쪽 작업

- source/listener 노드 생성/삭제
- 수동 keyframe 추가/수정/삭제
- path 시각화
- JSON export/import

### C++ 쪽 작업

- JSON parser
- schema validator(간단한 구조 검증부터)
- trajectory evaluator
- 시간 `t`에서 source/listener position/orientation 계산

### 완료 조건

- example JSON을 로드해 경로를 정확히 재현할 수 있음
- playhead scrub 시 transform이 정상 평가됨

## Phase 2 — Gesture recording + Macro generation

### 목표

사용자가 손으로 움직여 경로를 빠르게 만든다.

### Godot 쪽 작업

- 마우스 드래그 녹화
- raw sample trail 표시
- 녹화 종료 후 keyframe curve 생성
- orbit / fly_by / spiral / figure_8 매크로 생성

### 완료 조건

- 10초짜리 제스처 녹화 후 keyframe curve가 생성됨
- orbit 매크로 1개 이상으로 즉시 path 생성 가능

## Phase 3 — Offline binaural preview

### 목표

JSON project를 오디오로 렌더한다.

### C++ 쪽 작업

- miniaudio 엔진 초기화
- 오디오 asset 로드
- trajectory evaluator를 오디오 블록 루프에 연결
- Steam Audio direct binaural rendering 연결
- WAV 파일 출력

### 완료 조건

- `simple_orbit` 예제를 렌더하면 binaural WAV가 생성됨
- source와 listener가 시간에 따라 이동하는 효과를 들을 수 있음

## Phase 4 — Live preview (선택)

### 목표

Godot authoring 툴에서 수정한 내용을 실시간으로 preview engine에 반영한다.

### 권장 순서

- 먼저 file save + reload hotkey
- 그 다음 local WebSocket 또는 UDP sync

### 완료 조건

- playhead / selected track / current transform을 live sync 가능

## Phase 5 — Mobile recorder (선택)

### 목표

같은 Godot codebase를 모바일로 export하여 휴대폰을 제스처 컨트롤러처럼 사용한다.

### 완료 조건

- Android build에서 gyroscope / accelerometer를 사용해 listener 또는 source trajectory 녹화 가능

---

## 10. C++ 엔진 상세 요구사항

## 10.1 모듈 분리

최소한 아래 모듈로 나눈다.

- `ProjectLoader`
- `TrajectoryEvaluator`
- `AudioAssetRegistry`
- `SpatialPreviewRenderer`
- `OfflineRenderCommand`

## 10.2 평가 규칙

- 위치/회전 평가는 **오디오 블록 경계마다** 최소 1회 수행
- 추후 품질이 필요하면 block 내부 substep 보간 추가
- v1은 direct binaural 우선
- reflections, occlusion, room은 토글 가능 확장 포인트만 만들어 둔다

## 10.3 실패 시 fallback

Steam Audio 통합이 예상보다 지연되면:

1. 먼저 trajectory + asset scheduler + WAV render를 완성
2. 임시로 단순 stereo preview를 제공
3. Steam Audio binaural을 그 위에 교체 가능한 renderer로 삽입

핵심은 **trajectory pipeline을 먼저 완성**하는 것이다.

---

## 11. Godot 앱 상세 요구사항

## 11.1 Scene 구성

권장 scene/script 구조:

```text
apps/gesture_tool_godot/
  scenes/
    Main.tscn
    WorldView.tscn
    TimelineView.tscn
    InspectorPanel.tscn
  scripts/
    AppState.gd
    ProjectModel.gd
    TrajectoryTrack.gd
    GestureRecorder.gd
    MacroGenerator.gd
    JsonSerializer.gd
    SelectionController.gd
```

## 11.2 최소 기능

- source 생성 / 삭제
- listener 1개 고정
- key 추가 / 삭제 / 이동
- path 표시 on/off
- record 버튼
- macro 생성 버튼
- export/import 버튼

## 11.3 구현 우선순위

1. world-space path만 먼저
2. 그 다음 listener-relative
3. 그 다음 group-relative

이 순서로 구현할 것.

---

## 12. 테스트 시나리오

## Test A — Manual keys

- listener 고정
- source 1개 생성
- 0초, 2초, 4초 key 추가
- export 후 re-import
- path와 key 개수가 동일해야 함

## Test B — Gesture record

- source 1개 선택
- 5초간 마우스로 이동 녹화
- 녹화 종료 후 keyframe curve 생성
- raw trail보다 key 개수는 줄어야 함
- 재생 시 경로가 크게 어긋나지 않아야 함

## Test C — Macro orbit

- source 1개에 orbit 생성
- duration 8초, radius 2m
- export 후 C++ preview로 렌더
- 8초 동안 source가 listener 주변을 회전하는 청감이 나와야 함

## Test D — Listener movement

- listener도 path를 가짐
- source는 고정
- 렌더 결과에서 청자 이동 효과가 반영되어야 함

---

## 13. 완료 정의 (Definition of Done)

v1 완료 조건:

- Godot companion app에서 source/listener trajectory를 만들 수 있다
- trajectory를 JSON으로 저장/불러올 수 있다
- 수동 keyframe, gesture record, macro path가 모두 동작한다
- C++ preview renderer가 JSON을 읽어 오프라인 binaural preview WAV를 만든다
- 예제 프로젝트 2개 이상이 동작한다
- `THIRD_PARTY.md`와 라이선스 파일이 정리되어 있다

---

## 14. 이번 단계에서 하지 않을 것

- DAW plugin packaging
- VST/AU/AAX hosting
- 멀티유저 협업
- OSC full spec 지원
- 네트워크 멀티플레이어형 동기화
- 룸 음향 정밀 시뮬레이션 UI
- VR headset 전용 UX

이것들은 나중 단계로 미룬다.

---

## 15. Codex 실행 프롬프트

아래를 그대로 Codex에 주면 된다.

```text
Read docs/spatial_composer_gesture_plan.md and implement Phase 0 and Phase 1 completely, then implement the smallest useful subset of Phase 2.

Constraints:
- Do not use Unity, Unreal, JUCE, or Tracktion.
- Use Godot 4.6.2 stable for the gesture companion app.
- Use C++20 + CMake for the preview engine.
- Prefer permissive licenses only (MIT/BSD/ISC/Apache-2.0/BSL/Public Domain).
- Do not add GPL/LGPL/AGPL dependencies.
- Use JSON as the source-of-truth project format.
- Keep the code organized so that the Godot app handles authoring/UI and the C++ app handles audio/rendering.

Deliverables:
1. Repo scaffold.
2. shared JSON schema.
3. Godot app with listener/source placement, manual keyframes, import/export.
4. C++ project loader and trajectory evaluator.
5. At least one working example project.
6. Update THIRD_PARTY.md with all dependencies and licenses.

If you have time left, add gesture recording with mouse input and one macro generator (orbit).
```

---

## 16. 참고 자료 / 선택 근거

### Godot

- Godot 라이선스(MIT): <https://godotengine.org/license/>
- Godot 최신 안정 버전 4.6.2 다운로드 페이지: <https://godotengine.org/download/windows/>
- Path3D: <https://docs.godotengine.org/en/stable/classes/class_path3d.html>
- Curve3D: <https://docs.godotengine.org/en/stable/classes/class_curve3d.html>
- Input: <https://docs.godotengine.org/en/stable/classes/class_input.html>
- WebSocketPeer: <https://docs.godotengine.org/en/stable/classes/class_websocketpeer.html>

### Unity / Unreal 비교 근거

- Unity pricing / threshold: <https://unity.com/products/pricing-updates>
- Unity runtime fee cancellation / pricing changes: <https://support.unity.com/hc/en-us/articles/30322080156692-Cancellation-of-the-Runtime-Fee-and-Pricing-Changes>
- Unity Splines: <https://docs.unity3d.com/Packages/com.unity.splines%40latest/>
- Unreal licensing: <https://www.unrealengine.com/license>
- Unreal EULA: <https://www.unrealengine.com/en-US/eula/unreal>
- Unreal Sequencer overview: <https://dev.epicgames.com/documentation/en-us/unreal-engine/cinematics-and-movie-making-in-unreal-engine>

### Audio stack

- miniaudio: <https://github.com/dr-soft/miniaudio>
- miniaudio manual / node graph: <https://miniaud.io/docs/manual/index.html>
- miniaudio Steam Audio example: <https://miniaud.io/docs/examples/engine_steamaudio.html>
- Steam Audio repo (Apache-2.0): <https://github.com/ValveSoftware/steam-audio>
- Steam Audio C API: <https://valvesoftware.github.io/steam-audio/doc/capi/index.html>
- Steam Audio HRTF / custom HRTF: <https://valvesoftware.github.io/steam-audio/doc/capi/hrtf.html>

### Optional utilities

- nlohmann/json (MIT): <https://github.com/nlohmann/json>
- standalone Asio (BSL-1.0): <https://github.com/chriskohlhoff/asio>

---

## 17. 한 줄 요약

**Unity/Unreal은 쓰지 말고, Godot를 제스처 입력 전용 companion app으로 쓰자. 메인 렌더 엔진은 C++ + miniaudio + Steam Audio로 분리하고, v1은 JSON 기반 authoring → offline binaural preview까지 먼저 완성한다.**
